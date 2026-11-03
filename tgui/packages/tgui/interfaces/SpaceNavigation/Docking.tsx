import { useRef } from 'react';

import { pointOnPath, useApproachClock } from './Descent';
import type { NavigationData } from './types';

type Props = {
  approach: NonNullable<NavigationData['approach']>;
};

const WIDTH = 620;
const HEIGHT = 440;
// The hull's western seam meets the destination's eastern berth.
const BERTH = { x: 250, y: 220 };
const APPROACH = 'M 590 60 C 565 175, 490 220, 400 220 L 262 220';
// Nominal range covered by the schematic, in metres.
const RANGE = 2000;
const HULL = '#7fa08d';
const HULL_FILL = '#1d2a24';

/** Fast closing, then a slow final approach along the docking axis. */
function easeOut(progress: number) {
  return 1 - (1 - progress) ** 3;
}

function Station() {
  return (
    <g stroke={HULL} fill={HULL_FILL}>
      <rect x={80} y={170} width={160} height={100} />
      <rect x={110} y={130} width={60} height={40} />
      <rect x={120} y={270} width={80} height={45} />
      <rect x={30} y={195} width={50} height={50} />
      <line x1={140} y1={130} x2={140} y2={90} />
      <circle cx={140} cy={86} r={4} fill="none" />
      <rect x={240} y={210} width={10} height={20} fill="#2d3d34" />
    </g>
  );
}

function Cargo() {
  const containers = [
    { x: 150, y: 170, angle: -8 },
    { x: 90, y: 240, angle: 14 },
    { x: 175, y: 230, angle: 4 },
    { x: 60, y: 160, angle: -20 },
  ];
  return (
    <g stroke={HULL} fill={HULL_FILL}>
      {containers.map((box) => (
        <g
          key={`${box.x}-${box.y}`}
          transform={`rotate(${box.angle} ${box.x + 32} ${box.y + 16})`}
        >
          <rect x={box.x} y={box.y} width={64} height={32} />
          <line
            x1={box.x + 21}
            y1={box.y}
            x2={box.x + 21}
            y2={box.y + 32}
          />
          <line
            x1={box.x + 43}
            y1={box.y}
            x2={box.x + 43}
            y2={box.y + 32}
          />
        </g>
      ))}
    </g>
  );
}

function Asteroids() {
  const rocks = [
    'M 180 150 L 215 140 L 238 165 L 226 196 L 190 200 L 170 178 Z',
    'M 90 200 L 130 186 L 158 214 L 146 252 L 104 262 L 80 232 Z',
    'M 175 250 L 205 246 L 226 270 L 210 296 L 180 292 Z',
    'M 40 140 L 70 128 L 92 150 L 80 176 L 50 172 Z',
    'M 60 280 L 86 274 L 98 300 L 74 316 L 52 302 Z',
  ];
  return (
    <g stroke={HULL} fill={HULL_FILL}>
      {rocks.map((rock) => (
        <path key={rock} d={rock} />
      ))}
    </g>
  );
}

/** Space docking plot: the hull closes on the destination and settles onto its docking axis. */
export function Docking({ approach }: Props) {
  const path = useRef<SVGPathElement>(null);
  const seconds = useApproachClock(approach.elapsed, approach.duration);
  const progress = Math.min(1, seconds / approach.duration);
  const departing = !!approach.departing;
  // Casting off starts slowly and gathers speed away from the berth, nose first.
  const travel = departing ? 1 - progress ** 2 : easeOut(progress);
  const point = pointOnPath(path.current, travel) || {
    x: 590,
    y: 60,
    angle: 100,
  };
  const ship = departing ? { ...point, angle: point.angle + 180 } : point;
  const distance = Math.round(RANGE * (1 - travel));
  // Derivative of the eased travel over the manoeuvre, in metres per second.
  const speed = departing
    ? (RANGE * 2 * progress) / approach.duration
    : (RANGE * 3 * (1 - progress) ** 2) / approach.duration;
  const phase = departing
    ? progress < 0.15
      ? 'ОТДАЧА ЗАХВАТОВ'
      : progress < 1
        ? 'ОТХОД ОТ ПРИЧАЛА'
        : 'СВОБОДНЫЙ ПОЛЁТ'
    : travel < 0.5
      ? 'СБЛИЖЕНИЕ'
      : travel < 0.85
        ? 'УРАВНИВАНИЕ СКОРОСТЕЙ'
        : progress < 1
          ? 'ВЫХОД НА СТЫКОВОЧНУЮ ОСЬ'
          : approach.loading
            ? 'ЗАХВАТ ОБЪЕКТА СЕНСОРАМИ'
            : 'СОЕДИНЕНИЕ';
  const title = departing ? 'РАССТЫКОВКА' : 'СТЫКОВКА';
  const left = Math.max(0, Math.ceil(approach.duration - seconds));
  const aligned = travel >= 0.85;

  return (
    <>
      <div className="SpaceNavigation__plot-head">
        <span>
          {title} · {approach.site}
        </span>
        <span>
          {phase} · T−{Math.floor(left / 60)}:
          {String(left % 60).padStart(2, '0')}
        </span>
      </div>
      <svg
        width={WIDTH}
        height={HEIGHT}
        viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
        className="SpaceNavigation__chart SpaceNavigation__descent"
        aria-label={`${title}: ${phase}`}
      >
        {approach.scene === 'cargo' ? (
          <Cargo />
        ) : approach.scene === 'asteroids' ? (
          <Asteroids />
        ) : (
          <Station />
        )}
        <g stroke={aligned ? '#82de89' : '#526d60'} strokeDasharray="2 6">
          <line x1={BERTH.x + 12} y1={BERTH.y} x2={560} y2={BERTH.y - 45} />
          <line x1={BERTH.x + 12} y1={BERTH.y} x2={560} y2={BERTH.y + 45} />
        </g>
        <path
          ref={path}
          d={APPROACH}
          fill="none"
          stroke="#e6c78b"
          strokeDasharray="6 6"
        />
        <circle
          cx={BERTH.x + 12}
          cy={BERTH.y}
          r={5}
          fill="none"
          stroke="#e6c78b"
        />
        <g transform={`translate(${ship.x} ${ship.y}) rotate(${ship.angle})`}>
          <path d="M10 0L-8 -7L-4 0L-8 7Z" fill="#d6edc0" />
        </g>
        <g fill="#a5b6a6" fontSize={12}>
          <text x={430} y={380}>
            ДИСТАНЦИЯ {distance.toLocaleString('ru-RU')} м
          </text>
          <text x={430} y={400}>
            СКОРОСТЬ {speed.toFixed(1)} м/с
          </text>
        </g>
      </svg>
      {!!approach.loading && progress >= 1 && (
        <p className="SpaceNavigation__help" role="status">
          Уточнение положения объекта…
        </p>
      )}
    </>
  );
}
