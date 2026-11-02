import { type FuelGauge, fuelShare } from './types';

// End of the low-fuel arc, at a fifth of the half-circle dial.
const LOW_END = Math.PI * 0.8;

/** Small needle dials like the speedometer; warnings are lit on the annunciator, not written here. */
export function FuelGauges({ gauges }: { gauges: FuelGauge[] }) {
  return (
    <div className="SpaceNavigation__fuel">
      {gauges.map((gauge) => {
        const share = fuelShare(gauge);
        const percent = Math.round(share * 100);
        const needle = Math.PI * (1 - share);
        return (
          <div
            key={gauge.name}
            className="SpaceNavigation__fuel-dial"
            role="meter"
            aria-label={gauge.name}
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={percent}
            aria-valuetext={`${percent}%, ${gauge.amount} моль`}
            title={`${gauge.amount} моль`}
          >
            <svg viewBox="0 0 100 58" aria-hidden="true">
              <path className="gauge" d="M10 50a40 40 0 0 1 80 0" />
              <path
                className="reserve"
                d={`M10 50A40 40 0 0 1 ${50 + 40 * Math.cos(LOW_END)} ${50 - 40 * Math.sin(LOW_END)}`}
              />
              <path
                d={`M50 50L${50 + 34 * Math.cos(needle)} ${50 - 34 * Math.sin(needle)}`}
              />
              <circle cx="50" cy="50" r="4" />
            </svg>
            <span>{gauge.name}</span>
            <strong>{percent}%</strong>
          </div>
        );
      })}
    </div>
  );
}
