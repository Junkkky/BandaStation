import { type FuelGauge, fuelShare } from './types';

export function AnalogDial({
  label,
  share,
  readout,
  title,
  scaleMax = 100,
  reserve = false,
}: {
  label: string;
  share: number;
  readout: string;
  title?: string;
  scaleMax?: number;
  reserve?: boolean;
}) {
  const value = Math.max(0, Math.min(1, share));
  const point = (fraction: number, radius: number) => {
    const angle = ((140 + fraction * 260) * Math.PI) / 180;
    return {
      x: 60 + radius * Math.cos(angle),
      y: 60 + radius * Math.sin(angle),
    };
  };
  const needle = point(value, 38);
  return (
    <div
      className="SpaceNavigation__dial"
      role="meter"
      aria-label={label}
      aria-valuemin={0}
      aria-valuemax={scaleMax}
      aria-valuenow={value * scaleMax}
      aria-valuetext={title || readout}
      title={title}
    >
      <svg viewBox="0 0 120 120" aria-hidden="true">
        <circle className="dial-rim" cx="60" cy="60" r="57" />
        <circle className="dial-face" cx="60" cy="60" r="52" />
        {Array.from({ length: 21 }, (_, i) => {
          const from = point(i / 20, i % 5 === 0 ? 38 : 42);
          const to = point(i / 20, 46);
          const labelAt = point(i / 20, 29);
          return (
            <g key={i}>
              <line
                className={reserve && i < 4 ? 'dial-reserve' : 'dial-tick'}
                x1={from.x}
                y1={from.y}
                x2={to.x}
                y2={to.y}
              />
              {i % 5 === 0 && (
                <text x={labelAt.x} y={labelAt.y + 2.5} textAnchor="middle">
                  {(scaleMax * i) / 20}
                </text>
              )}
            </g>
          );
        })}
        <text className="dial-name" x="60" y="72" textAnchor="middle">
          {label}
        </text>
        <line
          className="dial-needle-shadow"
          x1="61"
          y1="62"
          x2={needle.x + 1}
          y2={needle.y + 2}
        />
        <line
          className="dial-needle"
          x1="60"
          y1="60"
          x2={needle.x}
          y2={needle.y}
        />
        <circle className="dial-hub" cx="60" cy="60" r="5" />
        <rect
          className="dial-readout"
          x="26"
          y="86"
          width="68"
          height="16"
          rx="2"
        />
        <text className="dial-value" x="60" y="97" textAnchor="middle">
          {readout}
        </text>
      </svg>
    </div>
  );
}

export function FuelGauges({ gauges }: { gauges: FuelGauge[] }) {
  return (
    <div className="SpaceNavigation__fuel">
      {gauges.map((gauge) => (
        <AnalogDial
          key={gauge.name}
          label={gauge.name.toUpperCase()}
          share={fuelShare(gauge)}
          readout={`${Math.round(fuelShare(gauge) * 100)}%`}
          title={`${Math.round(fuelShare(gauge) * 100)}%, ${gauge.amount} моль`}
          reserve
        />
      ))}
    </div>
  );
}
