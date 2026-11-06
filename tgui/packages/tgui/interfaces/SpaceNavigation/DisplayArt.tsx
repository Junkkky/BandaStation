import { useId } from 'react';

export function PlanetGlyph({
  radius = 24,
  kind = 'frozen',
}: {
  radius?: number;
  kind?: string;
}) {
  const id = useId().replaceAll(':', '');
  const color =
    kind === 'lava' ? '#eeab66' : kind === 'arid' ? '#d9bd81' : '#9bd6c7';
  return (
    <g pointerEvents="none" transform={`scale(${radius / 32})`}>
      <defs>
        <radialGradient id={`globe-${id}`} cx="32%" cy="28%" r="80%">
          <stop offset="0" stopColor={color} stopOpacity=".28" />
          <stop offset=".65" stopColor={color} stopOpacity=".1" />
          <stop offset="1" stopColor="#060f11" />
        </radialGradient>
        <clipPath id={`globe-clip-${id}`}>
          <circle r="32" />
        </clipPath>
      </defs>
      <circle
        r="37"
        fill={color}
        fillOpacity=".035"
        stroke={color}
        strokeOpacity=".25"
        strokeWidth=".6"
      />
      <circle
        r="32"
        fill={`url(#globe-${id})`}
        stroke={color}
        strokeWidth="1.2"
      />
      <g
        clipPath={`url(#globe-clip-${id})`}
        transform="rotate(-22)"
        fill="none"
        stroke={color}
        strokeOpacity=".6"
        strokeWidth=".65"
      >
        <ellipse rx="12" ry="32" />
        <ellipse rx="25" ry="32" />
        <ellipse rx="32" ry="10" />
        <ellipse rx="32" ry="24" />
        <path d="M0-32V32M-32 0H32" />
        <path
          d="M-24-17l11-5 6 4 9-2 6 7-7 8-10 2-7-5-7 2zM8 8l9-6 9 4-3 7-9 3-3 10-6-3-2-8z"
          fill={color}
          fillOpacity=".09"
          strokeOpacity=".4"
        />
      </g>
      <path
        d="M-39-25v-13h13M26-38h13v13M39 25v13H26M-26 38h-13V25"
        fill="none"
        stroke={color}
        strokeWidth=".8"
        strokeOpacity=".5"
      />
    </g>
  );
}

export function ShipGlyph() {
  return (
    <path
      className="nav-ship-silhouette"
      d="M0-15l5 6v7l6 5v9L5 8v6H-5V8l-6 4V3l6-5v-7z"
      fill="currentColor"
      stroke="currentColor"
      strokeWidth=".5"
      pointerEvents="none"
    />
  );
}

export function StationGlyph() {
  return (
    <g
      pointerEvents="none"
      fill="#10211d"
      stroke="currentColor"
      strokeWidth="1"
    >
      <path d="M-6-6H6V6H-6zM-15-3h9v6h-9zM6-3h9v6H6zM-3-15h6v9h-6zM-3 6h6v9h-6z" />
      <circle r="11" fill="none" strokeOpacity=".5" />
      <circle r="3" fill="currentColor" fillOpacity=".35" />
    </g>
  );
}

export function ZoomKnob({
  zoom,
  onChange,
  disabled = false,
}: {
  zoom: number;
  onChange: (value: number) => void;
  disabled?: boolean;
}) {
  const levels = [0.5, 1, 2, 4];
  const value = levels.indexOf(zoom);
  return (
    <div className="SpaceNavigation__zoom-hardware">
      <span className="SpaceNavigation__zoom-label">МАСШТАБ</span>
      <div className="SpaceNavigation__zoom-knob">
        <span className="zoom-mark zoom-mark-0">0.5</span>
        <span className="zoom-mark zoom-mark-1">1</span>
        <span className="zoom-mark zoom-mark-2">2</span>
        <span className="zoom-mark zoom-mark-3">4</span>
        <div
          className="SpaceNavigation__rotary"
          style={{ transform: `rotate(${-120 + value * 80}deg)` }}
        >
          <i />
        </div>
        <input
          type="range"
          disabled={disabled}
          min="0"
          max="3"
          step="1"
          value={value}
          aria-label="Масштаб карты"
          aria-valuetext={`${zoom}×`}
          title="Масштаб: перетащите ручку влево или вправо; клавиши ← →"
          onChange={(event) =>
            onChange(levels[Number(event.currentTarget.value)])
          }
        />
      </div>
    </div>
  );
}

export function SunGlyph({ radius }: { radius: number }) {
  const id = useId().replaceAll(':', '');
  return (
    <g className="nav-star" pointerEvents="none">
      <defs>
        <radialGradient id={`halo-${id}`}>
          <stop offset="0" stopColor="#dfbc78" stopOpacity=".12" />
          <stop offset="1" stopColor="#ecac4c" stopOpacity="0" />
        </radialGradient>
        <clipPath id={`sun-clip-${id}`}>
          <circle r={radius} />
        </clipPath>
      </defs>
      <circle r={radius * 3} fill={`url(#halo-${id})`} />
      <circle
        r={radius}
        fill="#dfbc78"
        fillOpacity=".08"
        stroke="#dfbc78"
        strokeWidth=".8"
      />
      <g
        clipPath={`url(#sun-clip-${id})`}
        fill="none"
        stroke="#dfbc78"
        strokeWidth=".5"
        strokeOpacity=".5"
      >
        {[-0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75].map((y) => (
          <path key={y} d={`M${-radius} ${radius * y}H${radius}`} />
        ))}
      </g>
    </g>
  );
}

export function ZoneArt({
  kind,
  radius,
  direction = 0,
}: {
  kind: string;
  radius: number;
  direction?: number;
}) {
  const id = useId().replaceAll(':', '');
  if (kind === 'asteroids')
    return (
      <g
        pointerEvents="none"
        fill="none"
        stroke="#adab8b"
        strokeWidth=".45"
        strokeOpacity=".7"
      >
        {Array.from({ length: 32 }, (_, i) => {
          const a = i * 2.39996;
          const r = radius * 0.86 * Math.sqrt((i + 0.5) / 32);
          const size = 0.65 + (i % 4) * 0.3;
          return (
            <path
              key={i}
              transform={`translate(${Math.cos(a) * r} ${Math.sin(a) * r}) rotate(${i * 31}) scale(${size})`}
              d="M-2-1L0-2.5 2-1 2 1 .5 2.5-2 1z"
              vectorEffect="non-scaling-stroke"
            />
          );
        })}
      </g>
    );
  if (kind === 'corona' || kind === 'nebula') {
    const color = kind === 'corona' ? '#dfac5f' : '#759f9a';
    return (
      <g pointerEvents="none">
        <defs>
          <radialGradient id={`cloud-${id}`}>
            <stop
              offset="0"
              stopColor={color}
              stopOpacity={kind === 'corona' ? '.22' : '.2'}
            />
            <stop offset=".5" stopColor={color} stopOpacity=".085" />
            <stop offset="1" stopColor={color} stopOpacity="0" />
          </radialGradient>
        </defs>
        {kind === 'corona' ? (
          <>
            <circle r={radius * 1.12} fill={`url(#cloud-${id})`} />
            {Array.from({ length: 7 }, (_, i) => (
              <ellipse
                key={i}
                rx={radius * 0.9}
                ry={radius * (0.11 + (i % 3) * 0.035)}
                transform={`rotate(${i * 51})`}
                fill={`url(#cloud-${id})`}
                opacity=".6"
              />
            ))}
          </>
        ) : (
          Array.from({ length: 7 }, (_, i) => (
            <ellipse
              key={i}
              cx={Math.sin(i * 2.5) * radius * 0.36}
              cy={Math.cos(i * 1.8) * radius * 0.24}
              rx={radius * (0.5 + (i % 3) * 0.12)}
              ry={radius * (0.33 + (i % 2) * 0.14)}
              transform={`rotate(${-32 + i * 11})`}
              fill={`url(#cloud-${id})`}
            />
          ))
        )}
      </g>
    );
  }
  if (kind === 'meteors')
    return (
      <g
        pointerEvents="none"
        transform={`rotate(${direction})`}
        stroke="#c4ad7d"
        strokeWidth=".6"
        strokeLinecap="round"
      >
        {Array.from({ length: 9 }, (_, i) => {
          const x = Math.sin(i * 2.4) * radius * 0.65;
          const y = Math.cos(i * 1.7) * radius * 0.65;
          return (
            <g key={i}>
              <path
                d={`M${x} ${y - radius * 0.23}l${radius * 0.035} ${radius * 0.23}`}
                opacity=".28"
              />
              <path
                d={`M${x + radius * 0.025} ${y - radius * 0.06}l${radius * 0.01} ${radius * 0.06}`}
                opacity=".8"
              />
            </g>
          );
        })}
      </g>
    );
  return null;
}

export function RuinGlyph() {
  return (
    <g
      pointerEvents="none"
      fill="#152b28"
      stroke="currentColor"
      strokeWidth=".6"
    >
      <g transform="rotate(-14)">
        <path d="M-23-8h12v-7h20v8h16v18H7v11H-9V10h-14zM-18-5h9V7h-9zM-5-11H5V17H-5zM10-3h11V7H10z" />
        <path
          d="M-33-17h15v7h-15zM-33 1h12v7h-12zM18-18h14v12H18z"
          fill="none"
        />
        <path
          d="M-30-17v7M-25-17v7M22-18v12M27-18v12M-5-4H5M-5 5H5M-5 12H5"
          opacity=".6"
        />
      </g>
      <path
        d="M-38-25v-9h9M29-34h9v9M38 25v9h-9M-29 34h-9v-9"
        fill="none"
        opacity=".4"
      />
    </g>
  );
}
