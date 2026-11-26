import type { BooleanLike } from 'tgui-core/react';

export type Position = { x: number; y: number };
export type Site = Position & {
  id: string;
  name: string;
  kind: string;
  type: string;
  distance: number;
  failed: BooleanLike;
  /** A distress beacon transmits there. */
  sos?: BooleanLike;
};
export type Contact = Position & {
  id: number;
  age: number;
  mode: string;
  vx?: number;
  vy?: number;
  identity?: { callsign: string; faction: string };
};
export type CelestialBody = Position & {
  name: string;
  radius: number;
  kind: string;
  orbit_x: number;
  orbit_y: number;
};
export type FuelGauge = {
  name: string;
  /** Moles in the connected supply network. */
  amount: number;
  /** Standard fill of the connected canisters of this gas, moles; 0 without a canister. */
  capacity: number;
};
/** Share of the connected canisters' standard fill, 0 to 1; 0 without a canister. */
export function fuelShare(gauge: FuelGauge) {
  return gauge.capacity > 0 ? Math.min(1, gauge.amount / gauge.capacity) : 0;
}

/** Below a fifth of the standard fill, or nothing connected at all. */
export function fuelLow(gauge: FuelGauge) {
  return fuelShare(gauge) < 0.2;
}

export type Compartment = {
  name: string;
  /** Mean floor pressure in the compartment, kPa; null without open floor. */
  pressure: number | null;
  low_pressure: BooleanLike;
  fire: BooleanLike;
  /** Hull tiles open to space. */
  breaches: number;
};
/** A landing pad of a surveyed planet; x and y are its share of the surface square from the south-west */
export type LandingPad = {
  number: number;
  x: number;
  y: number;
  label: string;
  free: BooleanLike;
  chosen: BooleanLike;
};

export type NavigationData = Position & {
  board?: {
    jumps: { id: string; name: string; available: BooleanLike }[];
    transponder: { callsign: string | null; enabled: BooleanLike } | null;
  };
  vessel_name?: string;
  au_scale: number;
  status: string;
  sector: string;
  sector_name: string;
  jumping: BooleanLike;
  /** Share of the current bluespace jump flown, 0-1, or null outside one */
  jump_progress: number | null;
  /** How close the hull has to be to a jump point to start a jump */
  jump_point_range?: number;
  star: Position & { name: string | null; radius: number };
  celestial_bodies: CelestialBody[];
  vx: number;
  vy: number;
  trajectory: (Position & { seconds: number })[];
  course: number;
  ordered_course: number;
  speed: number;
  /** Full scale of the speedometer, shared by every hull. */
  speed_scale: number;
  throttle: number;
  maneuver_direction: number;
  braking: BooleanLike;
  braking_distance: number | null;
  /** Powered emergency manoeuvring thrusters are braking. */
  emergency_braking: BooleanLike;
  /** Any compartment has equipment power. */
  ship_power: BooleanLike;
  engines: number;
  engines_running: BooleanLike;
  core_overdrive: BooleanLike;
  afterburner: BooleanLike;
  can_afterburner: BooleanLike;
  core_heat: number | null;
  fuel: FuelGauge[] | null;
  engine_fault: BooleanLike;
  can_start_engines: BooleanLike;
  helm: BooleanLike;
  autopilot: BooleanLike;
  preparing: BooleanLike;
  planning: BooleanLike;
  relocating: BooleanLike;
  landed: BooleanLike;
  selected: string | null;
  docked: string | null;
  coupled: BooleanLike;
  docking_request: { token: number; contact: number | null } | null;
  station_docking?: {
    required: BooleanLike;
    state: 'none' | 'pending' | 'approved';
    canRequest: BooleanLike;
    canCancel: BooleanLike;
    expiresIn: number | null;
    dockName: string | null;
    automatic: BooleanLike;
  };
  can_request_ship_dock: BooleanLike;
  dockable_contacts: number[];
  boardable_contacts?: number[];
  can_board_site?: BooleanLike | null;
  boarding?: { incoming: BooleanLike; eta: number } | null;
  boarding_connected?: BooleanLike;
  boarding_release_ready?: BooleanLike;
  boarding_release_eta?: number | null;
  can_cancel_release?: BooleanLike;
  landing: BooleanLike;
  distance: number;
  eta: number | null;
  scan_ready: BooleanLike;
  /** Seconds since the last sensor pulse, or null before the first one. */
  scan_age: number | null;
  /** Sensor noise from 0 to 1, as near the star. */
  interference: number;
  sensor_range: number;
  dock_range: number;
  can_dock: BooleanLike;
  routes: Site[];
  path: [number, number][];
  zones: (Position & {
    name: string;
    kind: string;
    radius: number;
    direction: number;
  })[];
  terrain: (Position & { end_x: number; end_y: number })[];
  ship_contacts: Contact[];
  kinetic_shots?: (Position & {
    id: number;
    heading?: number;
    finished: BooleanLike;
  })[];
  shield_up?: BooleanLike;
  drop_pods?: (Position & { id: number })[];
  impact_waves?: (
    | { id: number; kind: 'ship' | 'shield'; contact: number | null }
    | (Position & { id: number; kind: 'terrain' })
  )[];
  /** What the selected planet shows to the eye from orbit, before any survey */
  planet_look?: string | null;
  /** Site looked up on the chart while the autopilot flies to the selected one */
  inspected?: string | null;
  /** What the survey has read of the selected planet; a field is missing until enough of the planet is covered */
  planet?: {
    biome?: string;
    atmosphere?: string;
    temperature?: number;
    breathable?: BooleanLike;
    modifiers?: string[];
    caves?: string;
    ore?: string;
  };
  /** This ship's survey of the selected planet */
  survey?: {
    covered: BooleanLike;
    mapping: number;
    mapped: BooleanLike;
    failed: BooleanLike;
    pads: LandingPad[] | null;
  };
  approach: {
    elapsed: number;
    duration: number;
    departing: BooleanLike;
    site: string;
    scene: 'planet' | 'ruin' | 'cargo' | 'asteroids';
    biome: string | null;
    loading: BooleanLike;
    planet_timing?: {
      orbit_duration: number;
      descent_start: number | null;
      entry_start: number | null;
      entry_end: number | null;
      liftoff: number | null;
      ascent_cloud: number | null;
      ascent_orbit: number | null;
    };
  } | null;
  compartments: Compartment[];
  /** Hull silhouette rows, north first: space outside, `#` wall, `!` breach, otherwise the compartment code. */
  hull: string[];
};

/** Data rendered by the shared chart, without helm or docking controls. */
export type ChartData = Pick<
  NavigationData,
  | 'x'
  | 'y'
  | 'sector'
  | 'sector_name'
  | 'vessel_name'
  | 'au_scale'
  | 'course'
  | 'star'
  | 'celestial_bodies'
  | 'preparing'
  | 'relocating'
  | 'routes'
  | 'inspected'
  | 'path'
  | 'zones'
  | 'terrain'
  | 'ship_contacts'
  | 'kinetic_shots'
  | 'drop_pods'
  | 'impact_waves'
  | 'shield_up'
  | 'trajectory'
  | 'sensor_range'
  | 'dock_range'
  | 'jump_point_range'
  | 'survey'
  | 'interference'
  | 'scan_age'
> & { selected?: NavigationData['selected'] };

export type FiringSector = {
  heading: number;
  arc: number;
  range: number;
  min_range: number;
};

export function compartmentDamaged(room: Compartment) {
  return !!(room.breaches || room.fire || room.low_pressure);
}

/** Seconds of unchanged motion represented by a velocity vector. */
export const VECTOR_SECONDS = 60;

/**
 * Closest point of approach from the sensor fix, dead-reckoned to now.
 * Uses only the observed contact track, so a stale fix gives a stale forecast.
 */
export function closestApproach(own: NavigationData, contact: Contact) {
  if (contact.vx === undefined || contact.vy === undefined) return null;
  const rx = contact.x + contact.vx * contact.age - own.x;
  const ry = contact.y + contact.vy * contact.age - own.y;
  const vx = contact.vx - own.vx;
  const vy = contact.vy - own.vy;
  const closing = vx * vx + vy * vy;
  // Matched velocities keep the current separation; past CPA means opening.
  const time = closing < 1e-6 ? 0 : Math.max(0, -(rx * vx + ry * vy) / closing);
  return { distance: Math.hypot(rx + vx * time, ry + vy * time), time };
}

export function distanceLabel(value: number, scale: number) {
  return `${(value * scale).toFixed(Math.abs(value) >= 10 ? 3 : 5)} а.е.`;
}

export function speedLabel(value: number, scale: number) {
  const kilometres = Math.abs(value) * scale * 149597870.7;
  const lightSpeed = kilometres / 299792.458;
  return lightSpeed >= 0.01
    ? `${lightSpeed.toFixed(2)} c`
    : `${Math.round(kilometres)} км/с`;
}
