/** Probe ballistics from the server (planet_survey.dm); the server's flight is the one that counts. */
export type Physics = {
  orbit_radius: number;
  launch_z: number;
  /** Seconds for one turn of the orbit */
  orbit_period: number;
  gravity: number;
  step: number;
  steps: number;
  escape: number;
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

/** Where the ship is on its orbit at [angle] degrees, in screen units */
export function orbitPoint(physics: Physics, angle: number): [number, number] {
  const turn = (angle * Math.PI) / 180;
  return [
    physics.orbit_radius * Math.cos(turn),
    physics.orbit_radius * Math.sin(turn),
  ];
}

/**
 * The same flight the server works out, launched from [angle] of the orbit and aimed at [aimX], [aimY] on the
 * planet's face with [power] (0-1): every step's point, ending on the planet, past the escape distance or when the
 * steps run out.
 */
export function simulateFlight(
  physics: Physics,
  angle: number,
  aimX: number,
  aimY: number,
  power: number,
): Vector[] {
  let [x, y] = orbitPoint(physics, angle);
  let z = physics.launch_z;
  const aimZ = Math.sqrt(Math.max(0, 1 - aimX * aimX - aimY * aimY));
  const dx = aimX - x;
  const dy = aimY - y;
  const dz = aimZ - z;
  const speed =
    (physics.speed_min + power * (physics.speed_max - physics.speed_min)) /
    Math.hypot(dx, dy, dz);
  let vx = dx * speed;
  let vy = dy * speed;
  let vz = dz * speed;
  const points: Vector[] = [[x, y, z]];
  for (let step = 1; step <= physics.steps; step++) {
    const reach = Math.hypot(x, y, z);
    const pull = physics.gravity / (reach * reach * reach);
    vx -= x * pull * physics.step;
    vy -= y * pull * physics.step;
    vz -= z * pull * physics.step;
    x += vx * physics.step;
    y += vy * physics.step;
    z += vz * physics.step;
    const now = Math.hypot(x, y, z);
    if (now <= 1) {
      points.push([x / now, y / now, z / now]);
      return points;
    }
    points.push([x, y, z]);
    if (now > physics.escape) return points;
  }
  return points;
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
