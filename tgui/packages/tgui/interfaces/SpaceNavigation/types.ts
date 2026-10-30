// AI EDIT START - Navigation telemetry shared by the chart and helm
import type { BooleanLike } from 'tgui-core/react';

export type Position = { x: number; y: number };
export type Site = Position & {
  id: string;
  name: string;
  kind: string;
  distance: number;
  failed: BooleanLike;
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
export type NavigationData = Position & {
  au_scale: number;
  status: string;
  sector: string;
  sector_name: string;
  jumping: BooleanLike;
  star: Position;
  celestial_bodies: CelestialBody[];
  vx: number;
  vy: number;
  trajectory: (Position & { seconds: number })[];
  course: number;
  ordered_course: number;
  speed: number;
  throttle: number;
  maneuver_direction: number;
  braking: BooleanLike;
  braking_distance: number | null;
  engines: number;
  engines_running: BooleanLike;
  engine_phase: string | null;
  fuel: { tritium: number; oxygen: number } | null;
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
  can_request_ship_dock: BooleanLike;
  landing: BooleanLike;
  distance: number;
  eta: number | null;
  scan_ready: BooleanLike;
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
  planet?: {
    biome: string;
    atmosphere: string;
    temperature: number;
    breathable: BooleanLike;
  };
};

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
// AI EDIT END
