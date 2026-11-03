import { useState } from 'react';

import { type Compartment, compartmentDamaged } from './types';

/** Compartment cell codes of the hull rows, by report index; matches `COMPARTMENT_CELL_CODES` on the server. */
const CELL_CODES =
  'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

type Props = {
  rooms: Compartment[];
  /** Hull silhouette rows, north first: see `compartment_report()`. */
  hull: string[];
};

type Run = { x: number; y: number; length: number; code: string };

/** Hull silhouette coloured by compartment state; the server reads the state from the physical hull. */
export function Compartments({ rooms, hull }: Props) {
  const [hovered, setHovered] = useState<number | null>(null);
  const width = Math.max(0, ...hull.map((row) => row.length));
  const runs: Run[] = [];
  hull.forEach((row, y) => {
    for (let x = 0; x < row.length; ) {
      const code = row[x];
      let end = x + 1;
      while (end < row.length && row[end] === code) end++;
      if (code !== ' ') runs.push({ x, y, length: end - x, code });
      x = end;
    }
  });
  const damaged = rooms.filter(compartmentDamaged);
  const focus = hovered === null ? undefined : rooms[hovered];

  return (
    <section className="SpaceNavigation__hull" aria-label="Отсеки">
      <h2>
        ОТСЕКИ{' '}
        <span>
          {damaged.length ? `повреждено ${damaged.length}` : 'норма'}
        </span>
      </h2>
      {width ? (
        <svg
          viewBox={`-0.5 -0.5 ${width + 1} ${hull.length + 1}`}
          preserveAspectRatio="xMidYMid meet"
          shapeRendering="crispEdges"
          aria-hidden="true"
          onMouseLeave={() => setHovered(null)}
        >
          {runs.map((run) => {
            const index = CELL_CODES.indexOf(run.code);
            const room = index < 0 ? undefined : rooms[index];
            return (
              <rect
                key={`${run.x}-${run.y}`}
                x={run.x}
                y={run.y}
                width={run.length}
                height={1}
                className={cellClass(run.code, room, index === hovered)}
                onMouseEnter={() => setHovered(room ? index : null)}
              />
            );
          })}
        </svg>
      ) : (
        <p className="SpaceNavigation__help">Нет данных</p>
      )}
      <p className="SpaceNavigation__help" role="status">
        {focus
          ? `${focus.name}: ${describe(focus)}`
          : damaged.length
            ? damaged
                .map((room) => `${room.name}: ${describe(room)}`)
                .join('; ')
            : 'Все отсеки в норме'}
      </p>
    </section>
  );
}

function cellClass(
  code: string,
  room: Compartment | undefined,
  hovered: boolean,
) {
  if (code === '#') return 'wall';
  if (code === '!') return 'breach';
  const state = !room
    ? ''
    : room.fire
      ? 'fire'
      : room.breaches || room.low_pressure
        ? 'leak'
        : '';
  return `floor ${state} ${hovered ? 'hovered' : ''}`;
}

function describe(room: Compartment) {
  const parts: string[] = [];
  if (room.breaches) parts.push(`пробоина ×${room.breaches}`);
  if (room.fire) parts.push('пожар');
  parts.push(room.pressure === null ? 'без настила' : `${room.pressure} кПа`);
  return parts.join(' · ');
}
