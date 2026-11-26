type Props = {
  /** Heading over the bar */
  title: string;
  /** Line under the bar, left of the percentage */
  caption?: string;
  /** 0-1 */
  value: number;
  segments?: number;
};

/** Phosphor progress bar of lit segments, shared by the ship consoles. */
export function SegmentedProgress({
  title,
  caption,
  value,
  segments = 28,
}: Props) {
  const share = Math.min(1, Math.max(0, value));
  const lit = Math.round(share * segments);
  const percent = Math.floor(share * 100);
  return (
    <div
      className="SpaceNavigation__progress"
      role="progressbar"
      aria-label={title}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-valuenow={percent}
    >
      <div className="SpaceNavigation__progress-title">{title}</div>
      <div className="SpaceNavigation__progress-track">
        {Array.from({ length: segments }, (_, index) => (
          <span key={index} className={index < lit ? 'is-lit' : undefined} />
        ))}
      </div>
      <div className="SpaceNavigation__progress-foot">
        <span>{caption}</span>
        <span>{percent}%</span>
      </div>
    </div>
  );
}
