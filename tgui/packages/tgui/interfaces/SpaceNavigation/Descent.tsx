import { useEffect, useRef, useState } from 'react';

import type { NavigationData } from './types';

type Props = {
  descent: NonNullable<NavigationData['descent']>;
};

const WIDTH = 620;
const HEIGHT = 440;
const PLANET = { x: 330, y: 270, radius: 125 };
// Orbit to the planet's western limb, as plotted by the descent computer.
const APPROACH = 'M 575 45 C 340 25, 140 90, 207 252';
const BIOME_COLOURS: Record<string, string> = {
  barren: '#8b8f8c',
  frozen: '#cfe3ee',
  arid: '#c89a5f',
  lush: '#4d8a43',
  lava: '#a8442c',
};

/** Seconds into the descent, extrapolated between server updates. */
function useDescentClock(elapsed: number, duration: number) {
  const [now, setNow] = useState(elapsed);
  useEffect(() => {
    const received = performance.now();
    let frame = requestAnimationFrame(function tick() {
      setNow(
        Math.min(duration, elapsed + (performance.now() - received) / 1000),
      );
      frame = requestAnimationFrame(tick);
    });
    return () => cancelAnimationFrame(frame);
  }, [elapsed, duration]);
  return now;
}

/** Planetary descent plot: the hull follows its approach to the landing site. */
export function Descent({ descent }: Props) {
  const path = useRef<SVGPathElement>(null);
  const seconds = useDescentClock(descent.elapsed, descent.duration);
  const progress = Math.min(1, seconds / descent.duration);
  const entry = progress > 0.25 && progress < 0.75;
  let ship = { x: 575, y: 45, angle: 180 };
  if (path.current) {
    const length = path.current.getTotalLength();
    const here = path.current.getPointAtLength(progress * length);
    const ahead = path.current.getPointAtLength(
      Math.min(length, progress * length + 1),
    );
    const behind = path.current.getPointAtLength(
      Math.max(0, progress * length - 1),
    );
    ship = {
      x: here.x,
      y: here.y,
      angle:
        (Math.atan2(ahead.y - behind.y, ahead.x - behind.x) * 180) / Math.PI,
    };
  }
  const colour = (descent.biome && BIOME_COLOURS[descent.biome]) || '#8b8f8c';
  const phase =
    progress < 0.25
      ? 'СХОД С ОРБИТЫ'
      : progress < 0.75
        ? 'ВХОД В АТМОСФЕРУ'
        : progress < 1
          ? 'ЗАХОД НА ТОЧКУ ВЫСАДКИ'
          : descent.surveying
            ? 'ОЖИДАНИЕ КАРТЫ ПОВЕРХНОСТИ'
            : 'КАСАНИЕ';
  const left = Math.max(0, Math.ceil(descent.duration - seconds));
  const heat = entry ? Math.sin(((progress - 0.25) / 0.5) * Math.PI) : 0;

  return (
    <>
      <div className="SpaceNavigation__plot-head">
        <span>ПОСАДКА · {descent.site}</span>
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
        aria-label={`Посадка: ${phase}`}
      >
        <circle
          cx={PLANET.x}
          cy={PLANET.y}
          r={PLANET.radius + 9}
          fill="none"
          stroke={colour}
          strokeOpacity={0.25}
          strokeWidth={6}
        />
        <circle
          cx={PLANET.x}
          cy={PLANET.y}
          r={PLANET.radius}
          fill={colour}
          fillOpacity={0.55}
          stroke={colour}
        />
        <path
          ref={path}
          d={APPROACH}
          fill="none"
          stroke="#e6c78b"
          strokeDasharray="6 6"
        />
        <circle cx={207} cy={252} r={4} fill="none" stroke="#e6c78b" />
        <g
          transform={`translate(${ship.x} ${ship.y}) rotate(${ship.angle}) scale(${1 - progress * 0.4})`}
        >
          {heat > 0 && (
            <circle
              r={9 + heat * 5}
              fill="#ff9d4d"
              fillOpacity={0.15 + heat * 0.35}
            />
          )}
          <path d="M8 0L-6 -5L-3 0L-6 5Z" fill="#d6edc0" />
        </g>
      </svg>
      {!!descent.surveying && (
        <p className="SpaceNavigation__help" role="status">
          Картографирование поверхности…
        </p>
      )}
    </>
  );
}
