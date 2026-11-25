/** Probe ballistics from the server (planet_survey.dm); the server's flight is the one that counts. */
export type Physics = {
  orbit_radius: number;
  /** How far the orbit is tilted towards the viewer, degrees */
  orbit_tilt: number;
  /** How far a throw at no or full power lands short of or past the aim, degrees */
  power_spread: number;
  /** How far the ship's motion bends a flight along the orbit, planet radii */
  drift_bend: number;
  /** Aimed further than this from the centre a probe misses */
  miss_reach: number;
  escape: number;
  path_points: number;
  speed_min: number;
  speed_max: number;
  aim_limit: number;
  footprint: number;
  goal: number;
  /** Coverage from which the survey can be mapped and landed on */
  land: number;
  probe_limit: number;
  /** Coverage at which the survey tells more, lowest first */
  tiers: number[];
};

export type Vector = [number, number, number];

/** The launcher, at the lowest point of the tilted orbit, in front of the planet */
export function launcherPoint(physics: Physics): Vector {
  const tilt = (physics.orbit_tilt * Math.PI) / 180;
  return [
    0,
    -physics.orbit_radius * Math.cos(tilt),
    physics.orbit_radius * Math.sin(tilt),
  ];
}

/**
 * The same flight the server works out (planet_survey.dm), thrown from the launcher at [aimX], [aimY] on the planet's
 * face with [power] (0-1): an arc bent along the orbit, striking the aim at half power, short of it weaker and past it
 * stronger; aimed well wide of the planet, it misses. Ends on the planet or, missing, out in space.
 */
export function simulateFlight(
  physics: Physics,
  aimX: number,
  aimY: number,
  power: number,
): Vector[] {
  const start = launcherPoint(physics);
  const startDir = start.map((value) => value / physics.orbit_radius) as Vector;
  const reach = Math.hypot(aimX, aimY);
  let end: Vector;
  if (reach > physics.miss_reach) {
    end = [
      (aimX * physics.escape) / reach,
      (aimY * physics.escape) / reach,
      0,
    ];
  } else {
    const aim: Vector =
      reach > 1
        ? [aimX / reach, aimY / reach, 0]
        : [aimX, aimY, Math.sqrt(1 - reach * reach)];
    const toward = dot(startDir, aim);
    let back = startDir.map((value, axis) => value - toward * aim[axis]);
    let backLength = Math.hypot(...back);
    if (backLength < 0.001) {
      back = [0, -1, 0];
      backLength = 1;
    }
    const turn = ((power - 0.5) * physics.power_spread * Math.PI) / 180;
    end = aim.map(
      (value, axis) =>
        value * Math.cos(turn) - (back[axis] / backLength) * Math.sin(turn),
    ) as Vector;
  }
  const endLength = Math.hypot(...end);
  const middle = startDir.map((value, axis) => value + end[axis] / endLength);
  const middleLength = Math.max(0.001, Math.hypot(...middle));
  const height =
    1.5 +
    (Math.acos(Math.max(-1, Math.min(1, dot(startDir, end) / endLength))) *
      180) /
      Math.PI /
      150;
  const control = middle.map(
    (value, axis) =>
      (value / middleLength) * height + (axis === 0 ? physics.drift_bend : 0),
  );
  const points: Vector[] = [start];
  for (let index = 1; index < physics.path_points; index++) {
    const share = index / physics.path_points;
    points.push(
      [0, 1, 2].map(
        (axis) =>
          (1 - share) ** 2 * start[axis] +
          2 * (1 - share) * share * control[axis] +
          share ** 2 * end[axis],
      ) as Vector,
    );
  }
  points.push(end);
  return points;
}

function dot(a: Vector, b: Vector) {
  return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

/** A point of the planet's frame as the viewer of [back] sees it: the back face is turned half round */
export function toView([x, y, z]: Vector, back: boolean): Vector {
  return back ? [-x, y, -z] : [x, y, z];
}

/** Whether a point is hidden behind the planet from the viewer */
export function behindPlanet([x, y, z]: Vector) {
  return z < 0 && x * x + y * y < 1;
}

/**
 * Outline of the ground a probe striking [hit] reads, seen by the viewer of [back], in screen units: its part on the
 * near face, or with [far] its part on the face turned away, seen through the planet. Points on the other face are
 * laid on the rim. Null if it has no part on that face.
 */
export function footprintOutline(
  hit: Vector,
  back: boolean,
  footprint: number,
  far = false,
): [number, number][] | null {
  const centre = toView(hit, back);
  const helper: Vector = Math.abs(centre[0]) < 0.9 ? [1, 0, 0] : [0, 1, 0];
  const first = normalise(cross(centre, helper));
  const second = cross(centre, first);
  const angle = (footprint * Math.PI) / 180;
  const outline: [number, number][] = [];
  let seen = false;
  for (let index = 0; index < 48; index++) {
    const turn = (index / 48) * Math.PI * 2;
    const point: Vector = [0, 1, 2].map(
      (axis) =>
        Math.cos(angle) * centre[axis] +
        Math.sin(angle) *
          (Math.cos(turn) * first[axis] + Math.sin(turn) * second[axis]),
    ) as Vector;
    if (far ? point[2] < 0 : point[2] >= 0) {
      seen = true;
      outline.push([point[0], -point[1]]);
    } else {
      const flat = Math.hypot(point[0], point[1]) || 1;
      outline.push([point[0] / flat, -point[1] / flat]);
    }
  }
  return seen ? outline : null;
}

function cross(a: Vector, b: Vector): Vector {
  return [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0],
  ];
}

function normalise(a: Vector): Vector {
  const length = Math.hypot(...a) || 1;
  return [a[0] / length, a[1] / length, a[2] / length];
}
