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
        <span>{damaged.length ? `повреждено ${damaged.length}` : 'норма'}</span>
      </h2>
      {width ? (
        <svg
          viewBox={`-3 -3 ${width + 6} ${hull.length + 6}`}
          preserveAspectRatio="xMidYMid meet"
          shapeRendering="geometricPrecision"
          aria-hidden="true"
          onMouseLeave={() => setHovered(null)}
        >
          <defs>
            <pattern
              id="hull-deck-grid"
              width="1"
              height="1"
              patternUnits="userSpaceOnUse"
            >
              <path
                d="M1 0H0V1"
                fill="none"
                stroke="#b6c9a0"
                strokeOpacity=".3"
                strokeWidth=".08"
              />
            </pattern>
          </defs>
          <g
            pointerEvents="none"
            fill="none"
            stroke="#6c9d87"
            strokeWidth=".08"
            strokeOpacity=".5"
          >
            <path
              d={`M${width / 2} -3V${hull.length + 3}M-3 ${hull.length / 2}H${width + 3}`}
              strokeDasharray=".4 .7"
            />
            <path
              d={`M-2 2V-2H2M${width - 2} -2H${width + 2}V2M${width + 2} ${hull.length - 2}V${hull.length + 2}H${width - 2}M2 ${hull.length + 2}H-2V${hull.length - 2}`}
            />
          </g>
          <g
            transform="translate(.6 .8)"
            fill="#081410"
            stroke="#9db99a"
            strokeOpacity=".35"
            strokeWidth=".12"
            pointerEvents="none"
          >
            {runs.map((run) => (
              <rect
                key={`depth-${run.x}-${run.y}`}
                x={run.x}
                y={run.y}
                width={run.length}
                height="1"
              />
            ))}
          </g>
          {runs.map((run) => {
            const index = CELL_CODES.indexOf(run.code);
            const room = index < 0 ? undefined : rooms[index];
            return (
              <g key={`${run.x}-${run.y}`}>
                <rect
                  x={run.x}
                  y={run.y}
                  width={run.length}
                  height={1}
                  className={cellClass(run.code, room, index === hovered)}
                  onMouseEnter={() => setHovered(room ? index : null)}
                />
                {index >= 0 && (
                  <rect
                    x={run.x}
                    y={run.y}
                    width={run.length}
                    height="1"
                    fill="url(#hull-deck-grid)"
                    pointerEvents="none"
                  />
                )}
              </g>
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
            : null}
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
