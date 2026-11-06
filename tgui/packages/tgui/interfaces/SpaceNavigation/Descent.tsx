import { useEffect, useRef, useState } from 'react';
import { PlanetGlyph, ShipGlyph } from './DisplayArt';
import type { NavigationData } from './types';

type Props = {
  approach: NonNullable<NavigationData['approach']>;
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

/** Seconds into the approach, extrapolated between server updates. */
export function useApproachClock(elapsed: number, duration: number) {
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

/** Position and heading of the hull at a fraction of a plotted path. */
export function pointOnPath(path: SVGPathElement | null, progress: number) {
  if (!path) return null;
  const length = path.getTotalLength();
  const here = path.getPointAtLength(progress * length);
  const ahead = path.getPointAtLength(Math.min(length, progress * length + 1));
  const behind = path.getPointAtLength(Math.max(0, progress * length - 1));
  return {
    x: here.x,
    y: here.y,
    angle: (Math.atan2(ahead.y - behind.y, ahead.x - behind.x) * 180) / Math.PI,
  };
}

/** Planetary descent plot: the hull follows its approach to the landing site. */
export function Descent({ approach }: Props) {
  const path = useRef<SVGPathElement>(null);
  const seconds = useApproachClock(approach.elapsed, approach.duration);
  const progress = Math.min(1, seconds / approach.duration);
  const departing = !!approach.departing;
  // An ascent flies the descent path backwards, nose first.
  const flown = departing ? 1 - progress : progress;
  const entry = flown > 0.25 && flown < 0.75;
  const point = pointOnPath(path.current, flown) || {
    x: 575,
    y: 45,
    angle: 180,
  };
  const ship = departing ? { ...point, angle: point.angle + 180 } : point;
  const colour = (approach.biome && BIOME_COLOURS[approach.biome]) || '#8b8f8c';
  const phase = departing
    ? progress < 0.25
      ? 'ОТРЫВ ОТ ПОВЕРХНОСТИ'
      : progress < 0.75
        ? 'ПРОХОД АТМОСФЕРЫ'
        : progress < 1
          ? 'ВЫХОД НА ОРБИТУ'
          : 'ОРБИТА'
    : progress < 0.25
      ? 'СХОД С ОРБИТЫ'
      : progress < 0.75
        ? 'ВХОД В АТМОСФЕРУ'
        : progress < 1
          ? 'ЗАХОД НА ТОЧКУ ВЫСАДКИ'
          : approach.loading
            ? 'ОЖИДАНИЕ КАРТЫ ПОВЕРХНОСТИ'
            : 'КАСАНИЕ';
  const title = departing ? 'ВЗЛЁТ' : 'ПОСАДКА';
  const left = Math.max(0, Math.ceil(approach.duration - seconds));
  const heat = entry ? Math.sin(((flown - 0.25) / 0.5) * Math.PI) : 0;

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
        <circle
          cx={PLANET.x}
          cy={PLANET.y}
          r={PLANET.radius + 9}
          fill="none"
          stroke={colour}
          strokeOpacity={0.25}
          strokeWidth={6}
        />
        <g transform={`translate(${PLANET.x} ${PLANET.y})`}>
          <PlanetGlyph
            radius={PLANET.radius}
            kind={approach.biome || 'barren'}
          />
        </g>
        <path
          ref={path}
          d={APPROACH}
          fill="none"
          stroke="#e6c78b"
          strokeDasharray="6 6"
        />
        <circle cx={207} cy={252} r={4} fill="none" stroke="#e6c78b" />
        <g
          transform={`translate(${ship.x} ${ship.y}) rotate(${ship.angle}) scale(${1 - flown * 0.4})`}
        >
          {heat > 0 && (
            <circle
              r={9 + heat * 5}
              fill="#ff9d4d"
              fillOpacity={0.15 + heat * 0.35}
            />
          )}
          <g transform="rotate(90)" style={{ color: '#c4e9d7' }}>
            <ShipGlyph />
          </g>
        </g>
      </svg>
      {!!approach.loading && (
        <p className="SpaceNavigation__help" role="status">
          Картографирование поверхности…
        </p>
      )}
    </>
  );
}
