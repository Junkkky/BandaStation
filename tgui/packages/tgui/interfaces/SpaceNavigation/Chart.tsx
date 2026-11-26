import { useEffect, useRef, useState } from 'react';
import { Button } from 'tgui-core/components';

import { useApproachClock } from './Descent';
import {
  JumpPointGlyph,
  PlanetGlyph,
  ShipGlyph,
  StationGlyph,
  SunGlyph,
  ZoneArt,
} from './DisplayArt';
import {
  type ChartData,
  distanceLabel,
  type FiringSector,
  type LandingPad,
  type Position,
  VECTOR_SECONDS,
} from './types';

/** Seconds a sensor pulse takes to spread from the hull to the edge of sensor range. */
const SCAN_WAVE = 1.5;
/** Seconds a distress signal keeps pulsing on the chart after a sensor pulse finds it. */
const SOS_PULSE = 10;

/** Sensor pulse ring: spreads from the hull, slowing towards the edge of sensor range, and fades out. */
function ScanWave(props: {
  age: number;
  x: number;
  y: number;
  radius: number;
}) {
  const { age, x, y, radius } = props;
  const seconds = useApproachClock(age, SCAN_WAVE);
  if (seconds >= SCAN_WAVE) return null;
  const progress = seconds / SCAN_WAVE;
  return (
    <circle
      cx={x}
      cy={y}
      r={radius * (1 - (1 - progress) ** 2)}
      fill="none"
      stroke="#82de89"
      strokeWidth={2}
      strokeOpacity={1 - progress}
      pointerEvents="none"
    />
  );
}

const aimKeys: Partial<Record<string, Position>> = {
  ArrowUp: { x: 0, y: 10 },
  ArrowRight: { x: 10, y: 0 },
  ArrowDown: { x: 0, y: -10 },
  ArrowLeft: { x: -10, y: 0 },
};

type Props = {
  data: ChartData;
  zoom: number;
  firingSector?: FiringSector;
  aimPoint?: Position | null;
  aimValid?: boolean;
  onAim?: (position: Position) => void;
  hoveredTarget: string | null;
  focusedContact: number | null;
  onContact: (id: number) => void;
  onSite?: (id: string) => void;
  onPad?: (number: number) => void;
};

export function Chart({
  aimPoint,
  aimValid,
  data,
  firingSector,
  focusedContact,
  onAim,
  onContact,
  onSite,
  onPad,
  zoom,
  hoveredTarget,
}: Props) {
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const drag = useRef<Position | null>(null);
  const svg = useRef<SVGSVGElement>(null);
  const scale = 0.16 * zoom;
  const width = 620;
  const height = 440;
  const centre = { x: data.x + pan.x, y: data.y + pan.y };
  const point = (x: number, y: number) => ({
    x: width / 2 + (x - centre.x) * scale,
    y: height / 2 - (y - centre.y) * scale,
  });
  const own = point(data.x, data.y);
  const aim = aimPoint && point(aimPoint.x, aimPoint.y);
  const disabled = !!(data.preparing || data.relocating);

  useEffect(() => {
    const release = () => {
      drag.current = null;
    };
    const move = (event: MouseEvent) => {
      if (!drag.current || !svg.current) return;
      const matrix = svg.current.getScreenCTM();
      if (!matrix?.a || !matrix.d) return;
      const dx = (event.clientX - drag.current.x) / matrix.a;
      const dy = (event.clientY - drag.current.y) / matrix.d;
      drag.current = { x: event.clientX, y: event.clientY };
      setPan((prior) => ({ x: prior.x - dx / scale, y: prior.y + dy / scale }));
    };
    document.addEventListener('mousemove', move);
    document.addEventListener('mouseup', release);
    document.addEventListener('visibilitychange', release);
    window.addEventListener('blur', release);
    return () => {
      document.removeEventListener('mousemove', move);
      document.removeEventListener('mouseup', release);
      document.removeEventListener('visibilitychange', release);
      window.removeEventListener('blur', release);
    };
  }, [scale]);

  const grid: number[] = [];
  for (
    let x = Math.floor((centre.x - width / 2 / scale) / 250) * 250;
    x <= centre.x + width / 2 / scale;
    x += 250
  )
    grid.push(x);
  const rows: number[] = [];
  for (
    let y = Math.floor((centre.y - height / 2 / scale) / 250) * 250;
    y <= centre.y + height / 2 / scale;
    y += 250
  )
    rows.push(y);
  const bodies = data.celestial_bodies || [];
  const radius = (firingSector?.range ?? 0) * scale;
  const radians = ((firingSector?.arc ?? 0) * Math.PI) / 180;
  const edgeX = radius * Math.sin(radians);
  const edgeY = -radius * Math.cos(radians);

  return (
    <div className="SpaceNavigation__chart-stage">
      <div className="SpaceNavigation__map-controls">
        {' '}
        <Button
          compact
          icon="crosshairs"
          tooltip="Центрировать на корабле"
          aria-label="Центрировать на корабле"
          onClick={() => setPan({ x: 0, y: 0 })}
        />
      </div>
      <svg
        ref={svg}
        width={width}
        height={height}
        viewBox={`0 0 ${width} ${height}`}
        className="SpaceNavigation__chart"
        aria-label={
          onAim
            ? 'Карта наведения. ЛКМ выбирает точку, стрелки двигают прицел, ПКМ перемещает карту.'
            : 'Карта контактов. Выбор левой кнопкой, перемещение правой.'
        }
        tabIndex={onAim ? 0 : undefined}
        onClick={
          onAim &&
          ((event) => {
            const chart = event.currentTarget;
            const matrix = chart.getScreenCTM();
            if (!matrix) return;
            const cursor = chart.createSVGPoint();
            cursor.x = event.clientX;
            cursor.y = event.clientY;
            const chartPoint = cursor.matrixTransform(matrix.inverse());
            if (
              !(
                chartPoint.x >= 0 &&
                chartPoint.x <= width &&
                chartPoint.y >= 0 &&
                chartPoint.y <= height
              )
            )
              return;
            onAim({
              x: centre.x + (chartPoint.x - width / 2) / scale,
              y: centre.y - (chartPoint.y - height / 2) / scale,
            });
          })
        }
        onKeyDown={
          onAim &&
          ((event) => {
            const step = aimKeys[event.key];
            if (
              !step ||
              !firingSector ||
              event.target !== event.currentTarget
            ) {
              return;
            }
            event.preventDefault();
            const angle = (firingSector.heading * Math.PI) / 180;
            const distance = (firingSector.range + firingSector.min_range) / 2;
            const origin = aimPoint || {
              x: data.x + Math.sin(angle) * distance,
              y: data.y + Math.cos(angle) * distance,
            };
            onAim({ x: origin.x + step.x, y: origin.y + step.y });
          })
        }
        onContextMenu={(event) => event.preventDefault()}
        onMouseDown={(event) => {
          if (event.button !== 2) return;
          event.preventDefault();
          drag.current = { x: event.clientX, y: event.clientY };
        }}
      >
        <defs>
          <marker
            id="velocity-arrow"
            viewBox="0 0 10 10"
            refX="8"
            refY="5"
            markerWidth="7"
            markerHeight="7"
            orient="auto"
          >
            <path d="M0 1L8 5L0 9" fill="none" stroke="#91d7d0" />
          </marker>
          <filter id="sensor-noise">
            <feTurbulence
              type="fractalNoise"
              baseFrequency="0.9"
              seed={Math.floor(Math.random() * 1000)}
            />
            <feColorMatrix values="0 0 0 0 0.85 0 0 0 0 0.9 0 0 0 0 0.75 0 0 0 1.4 -0.6" />
          </filter>
        </defs>
        <g stroke="#233936" strokeOpacity=".65">
          {grid.map((x) => (
            <line
              key={x}
              x1={point(x, 0).x}
              x2={point(x, 0).x}
              y1={0}
              y2={height}
            />
          ))}
          {rows.map((y) => (
            <line
              key={y}
              y1={point(0, y).y}
              y2={point(0, y).y}
              x1={0}
              x2={width}
            />
          ))}
        </g>
        <g
          fill="none"
          stroke="#64796b"
          strokeOpacity=".4"
          strokeDasharray="3 3"
        >
          {bodies.map((body) => (
            <circle
              key={body.name}
              cx={point(body.orbit_x, body.orbit_y).x}
              cy={point(body.orbit_x, body.orbit_y).y}
              r={
                Math.hypot(body.x - body.orbit_x, body.y - body.orbit_y) * scale
              }
            />
          ))}
          {data.routes
            .filter((site) => site.kind === 'planet')
            .map((site) => (
              <circle
                key={site.id}
                cx={point(0, 0).x}
                cy={point(0, 0).y}
                r={Math.hypot(site.x, site.y) * scale}
              />
            ))}
          {bodies.length > 0 &&
            data.routes
              .filter((site) => site.kind === 'station')
              .map((site) => (
                <circle
                  key={site.id}
                  cx={point(bodies[0].x, bodies[0].y).x}
                  cy={point(bodies[0].x, bodies[0].y).y}
                  r={
                    Math.hypot(site.x - bodies[0].x, site.y - bodies[0].y) *
                    scale
                  }
                />
              ))}
        </g>
        {bodies
          .filter(
            (body) =>
              !data.routes.some(
                (site) =>
                  site.kind === 'planet' &&
                  Math.hypot(site.x - body.x, site.y - body.y) < 1,
              ),
          )
          .map((body) => (
            <g
              key={body.name}
              transform={`translate(${point(body.x, body.y).x} ${point(body.x, body.y).y})`}
            >
              <title>{body.name}</title>
              <PlanetGlyph
                radius={Math.max(16, body.radius)}
                kind={body.kind}
              />
            </g>
          ))}
        {data.zones.map((zone, index) => (
          <g
            className="SpaceNavigation__map-feature"
            key={index}
            transform={`translate(${point(zone.x, zone.y).x} ${point(zone.x, zone.y).y})`}
          >
            <circle r={zone.radius * scale} fill="transparent" stroke="none" />
            <title>
              {zone.kind === 'meteors' ? 'Метеоритный поток' : zone.name}
            </title>
            <ZoneArt
              kind={zone.kind}
              radius={zone.radius * scale}
              direction={zone.direction}
            />
            <text
              className="nav-feature-label nav-chart-label nav-chart-label--muted"
              x={zone.radius * scale * 0.8 + 7}
              y="0"
              pointerEvents="none"
            >
              {zone.kind === 'meteors' ? 'Метеоритный поток' : zone.name}
            </text>
          </g>
        ))}
        {data.star && (
          <g
            transform={`translate(${point(data.star.x, data.star.y).x} ${point(data.star.x, data.star.y).y})`}
            className="SpaceNavigation__map-feature"
          >
            {data.star.name && <title>{data.star.name}</title>}
            <circle
              r={data.star.radius * 1.8}
              fill="transparent"
              stroke="none"
            />
            <SunGlyph radius={data.star.radius} />
            <text
              className="nav-feature-label nav-chart-label"
              x={-data.star.radius - 8}
              y={-data.star.radius - 5}
              textAnchor="end"
            >
              {data.star.name}
            </text>
          </g>
        )}
        <g stroke="#bdad80" strokeWidth={0.65}>
          {data.terrain.map((rock, index) => (
            <line
              key={index}
              x1={point(rock.x, rock.y).x}
              y1={point(rock.x, rock.y).y}
              x2={point(rock.end_x, rock.end_y).x}
              y2={point(rock.end_x, rock.end_y).y}
            />
          ))}
        </g>
        {data.path?.length > 0 && (
          <polyline
            fill="none"
            stroke="#a48e65"
            points={[own, ...data.path.map(([x, y]) => point(x, y))]
              .map((p) => `${p.x},${p.y}`)
              .join(' ')}
          />
        )}
        {firingSector && (
          <path
            aria-label="Сектор обстрела выбранного орудия"
            d={`M0 0 L${-edgeX} ${edgeY} A${radius} ${radius} 0 0 1 ${edgeX} ${edgeY} Z`}
            fill="#e9a14a"
            fillOpacity={0.18}
            stroke="#e9a14a"
            strokeOpacity={0.85}
            strokeDasharray="4 3"
            transform={`translate(${own.x} ${own.y}) rotate(${firingSector.heading})`}
            pointerEvents="none"
          />
        )}
        {data.routes.map((site, siteIndex) => {
          const p = point(site.x, site.y);
          const selected =
            focusedContact === null &&
            site.id === (data.inspected || data.selected);
          return (
            <g
              key={site.id}
              transform={`translate(${p.x} ${p.y})`}
              className={`SpaceNavigation__marker ${selected ? 'is-selected' : ''} ${hoveredTarget === `site:${site.id}` ? 'is-hovered' : ''}`}
              role={onSite ? 'button' : undefined}
              tabIndex={onSite ? 0 : undefined}
              aria-label={site.name}
              aria-disabled={onSite ? disabled || !!site.failed : undefined}
              onClick={
                onSite && (() => !disabled && !site.failed && onSite(site.id))
              }
              onKeyDown={
                onSite &&
                ((event) => {
                  if (event.key === 'Enter' && !disabled && !site.failed)
                    onSite(site.id);
                })
              }
              stroke={selected ? '#edc587' : site.sos ? '#e0533f' : '#7b9c86'}
            >
              <title>{site.name}</title>
              <circle
                className="nav-marker-focus"
                r={site.kind === 'planet' ? 33 : 15}
                pointerEvents="none"
              />
              <circle
                r={site.kind === 'planet' ? 31 : 18}
                fill="transparent"
                stroke="none"
              />
              <g
                style={{
                  color: selected ? '#e7c689' : '#9cc8b7',
                }}
              >
                {site.kind === 'planet' ? (
                  <PlanetGlyph
                    radius={selected ? 25 : 17}
                    kind={
                      bodies.find(
                        (body) =>
                          Math.hypot(body.x - site.x, body.y - site.y) < 1,
                      )?.kind || 'barren'
                    }
                  />
                ) : site.kind === 'station' ? (
                  <StationGlyph />
                ) : site.kind === 'jump' ? (
                  <>
                    <circle
                      className="SpaceNavigation__jump-range"
                      r={(data.jump_point_range || 0) * scale}
                    />
                    <JumpPointGlyph />
                  </>
                ) : (
                  <g>
                    <path d="M0-8L8 0L0 8L-8 0Z" fill="#10221d" />
                    <path d="M-3 0H3M0-3V3" strokeWidth="1" />
                  </g>
                )}
              </g>
              <g
                className="nav-object-label"
                pointerEvents="none"
                fill="none"
                strokeWidth=".6"
                strokeOpacity=".55"
              >
                <path
                  d={`M${site.kind === 'planet' ? 27 : 13} -4l11-${siteIndex % 2 ? 13 : 25}h50`}
                />
              </g>
              <text
                className={`nav-object-label nav-chart-label ${selected ? 'nav-chart-label--selected' : ''}`}
                x={site.kind === 'planet' ? 39 : 25}
                y={siteIndex % 2 ? -20 : -32}
                pointerEvents="none"
              >
                {site.kind === 'signal' && !site.sos ? site.type : site.name}
              </text>
              {!!site.sos &&
                data.scan_age !== null &&
                data.scan_age < SOS_PULSE && (
                  <circle
                    r={9}
                    fill="none"
                    stroke="#e0533f"
                    className="SpaceNavigation__sos"
                  />
                )}
            </g>
          );
        })}
        {onPad &&
          zoom >= PAD_ZOOM &&
          data.survey?.pads &&
          data.routes
            .filter(
              (site) =>
                site.kind === 'planet' &&
                site.id === data.selected &&
                focusedContact === null,
            )
            .map((site) => (
              <LandingPads
                key={site.id}
                at={point(site.x, site.y)}
                pads={data.survey?.pads || []}
                kind={
                  bodies.find(
                    (body) => Math.hypot(body.x - site.x, body.y - site.y) < 1,
                  )?.kind || 'barren'
                }
                disabled={disabled}
                onPad={onPad}
              />
            ))}
        {data.ship_contacts.map((contact) => {
          const p = point(contact.x, contact.y);
          return (
            <g
              key={contact.id}
              className={`SpaceNavigation__marker ${contact.id === focusedContact ? 'is-selected' : ''} ${hoveredTarget === `contact:${contact.id}` ? 'is-hovered' : ''}`}
              role="button"
              tabIndex={0}
              aria-label={`Контакт ${contact.id} · ${contact.identity?.callsign || 'Неопознанное судно'}`}
              aria-pressed={contact.id === focusedContact}
              onClick={() => onContact(contact.id)}
              onKeyDown={(event) => {
                if (event.key === 'Enter' || event.key === ' ') {
                  event.preventDefault();
                  onContact(contact.id);
                  onAim?.({ x: contact.x, y: contact.y });
                }
              }}
            >
              <title>{`К${contact.id} · ${contact.identity?.callsign || 'Неопознанное судно'} · ${Math.floor(contact.age)} с`}</title>
              <circle cx={p.x} cy={p.y} r={13} fill="transparent" />
              <circle
                className="nav-marker-focus"
                cx={p.x}
                cy={p.y}
                r="10"
                pointerEvents="none"
              />
              <circle
                cx={p.x}
                cy={p.y}
                r={5}
                fill="none"
                stroke={
                  contact.id === focusedContact
                    ? '#edc587'
                    : contact.age >= 20
                      ? '#6e7664'
                      : '#d2a46a'
                }
              />
              <text
                className="nav-object-label nav-chart-label nav-chart-label--contact"
                x={p.x + 12}
                y={p.y + 4}
                pointerEvents="none"
              >
                К{contact.id}
                {contact.identity ? ` / ${contact.identity.callsign}` : ' / ?'}
              </text>
              {contact.id === focusedContact &&
                contact.vx !== undefined &&
                contact.vy !== undefined && (
                  <Velocity
                    origin={p}
                    vx={contact.vx}
                    vy={contact.vy}
                    scale={scale}
                  />
                )}
            </g>
          );
        })}
        {data.scan_age !== null && data.scan_age < SCAN_WAVE && (
          <ScanWave
            age={data.scan_age}
            x={own.x}
            y={own.y}
            radius={data.sensor_range * scale}
          />
        )}
        {data.trajectory.map(({ x, y, seconds }, index) => {
          const previous = index ? data.trajectory[index - 1] : data;
          const dx = x - previous.x,
            dy = y - previous.y;
          const angle =
            dx || dy ? (Math.atan2(dx, dy) * 180) / Math.PI : data.course;
          const position = point(x, y);
          return (
            <path
              key={seconds}
              className="nav-prediction"
              d="M0-5L3.5 3L0 1L-3.5 3Z"
              transform={`translate(${position.x} ${position.y}) rotate(${angle}) scale(${1 - index * 0.12})`}
              fill="#91d7d0"
              fillOpacity={1 - index * 0.2}
              stroke="#080e0d"
              strokeWidth=".65"
              pointerEvents="none"
            >
              <title>{`+${seconds} с при текущей тяге`}</title>
            </path>
          );
        })}
        <g
          transform={`translate(${own.x} ${own.y})`}
          pointerEvents="none"
          style={{ color: '#c4e9d7' }}
        >
          <circle
            r={data.dock_range * scale}
            fill="none"
            stroke="#a6d4c3"
            strokeWidth=".5"
            strokeOpacity=".35"
            strokeDasharray="2 5"
          >
            <title>Дальность стыковки и посадки</title>
          </circle>
          {!!data.shield_up && (
            <circle
              r={18}
              fill="none"
              stroke="#8bcfdc"
              strokeWidth={1}
              opacity={0.8}
            >
              <title>Щит поднят</title>
            </circle>
          )}
          <g transform={`rotate(${data.course})`}>
            <ShipGlyph />
          </g>
        </g>
        {aim && (
          <g
            aria-label="Точка прицеливания"
            pointerEvents="none"
            fill="none"
            stroke={aimValid ? '#d5edb1' : '#eb9b79'}
          >
            <line
              x1={own.x}
              y1={own.y}
              x2={aim.x}
              y2={aim.y}
              strokeDasharray="4 4"
              opacity={0.8}
            />
            <g transform={`translate(${aim.x} ${aim.y})`}>
              <circle r={7} fill="#0b1514" />
              <path d="M-11 0h8m6 0h8M0-11v8m0 6v8" />
            </g>
          </g>
        )}
        {data.impact_waves?.map((impact) => {
          const location =
            impact.kind === 'terrain'
              ? impact
              : impact.contact === null
                ? data
                : data.ship_contacts.find(
                    (contact) => contact.id === impact.contact,
                  );
          if (!location) return null;
          const center = point(location.x, location.y);
          return (
            <circle
              key={impact.id}
              className="SpaceNavigation__impact-wave"
              cx={center.x}
              cy={center.y}
              r={22}
              stroke={impact.kind === 'shield' ? '#87deef' : '#fb776b'}
              strokeWidth={1.6}
              fill="none"
              vectorEffect="non-scaling-stroke"
              pointerEvents="none"
              aria-hidden="true"
            />
          );
        })}
        {data.drop_pods?.map((pod) => {
          const p = point(pod.x, pod.y);
          return (
            <g
              key={pod.id}
              transform={`translate(${p.x} ${p.y})`}
              pointerEvents="none"
            >
              <title>Дроп-под</title>
              <path
                d="M0 -5 L4 0 L0 5 L-4 0 Z"
                fill="#a1e6ee"
                stroke="#246171"
              />
              <path d="M-7 0 H-4 M4 0 H7" stroke="#a1e6ee" />
            </g>
          );
        })}
        {data.kinetic_shots?.map((shot) => {
          const p = point(shot.x, shot.y);
          return (
            <g
              key={shot.id}
              opacity={shot.finished ? 0.45 : 1}
              pointerEvents="none"
            >
              <title>Кинетический снаряд</title>
              {!shot.finished && shot.heading !== undefined && (
                <path
                  d="M0 0 V12"
                  transform={`translate(${p.x} ${p.y}) rotate(${shot.heading})`}
                  stroke="#ff9f59"
                  strokeWidth={2}
                  strokeLinecap="round"
                />
              )}
              <circle
                cx={p.x}
                cy={p.y}
                r={3.5}
                fill="#fff1ba"
                stroke="#ad6237"
              />
            </g>
          );
        })}
        <g fill="#718870" stroke="#718870">
          <text x={12} y={54} stroke="none">
            N ↑
          </text>
          <path d={`M12 ${height - 30}h100`} />
          <text x={12} y={height - 12} stroke="none">
            {distanceLabel(100 / scale, data.au_scale)}
          </text>
        </g>
        <text className="nav-system-title" x="14" y="27" pointerEvents="none">
          {data.sector_name}
        </text>
        {data.interference > 0 && (
          <rect
            width={width}
            height={height}
            filter="url(#sensor-noise)"
            opacity={0.6 * data.interference}
            pointerEvents="none"
          />
        )}
      </svg>
    </div>
  );
}

function Velocity({
  origin,
  vx,
  vy,
  scale,
}: {
  origin: Position;
  vx: number;
  vy: number;
  scale: number;
}) {
  if (Math.hypot(vx, vy) < 0.01) return null;
  // The tip is where the vessel will be after VECTOR_SECONDS of unchanged motion.
  return (
    <line
      pointerEvents="none"
      x1={origin.x}
      y1={origin.y}
      x2={origin.x + vx * VECTOR_SECONDS * scale}
      y2={origin.y - vy * VECTOR_SECONDS * scale}
      stroke="#91d7d0"
      strokeWidth={2}
      markerEnd="url(#velocity-arrow)"
    />
  );
}

/** Chart zoom at which a surveyed planet shows its landing pads */
const PAD_ZOOM = 4;
/** Radius of the planet drawn with its pads */
const PAD_PLANET_RADIUS = 80;

/**
 * A surveyed planet drawn large with its landing pads, each where it lies on the survey schematic: the generated
 * square of the surface is inscribed in the disc.
 */
function LandingPads({
  at,
  pads,
  kind,
  disabled,
  onPad,
}: {
  at: Position;
  pads: LandingPad[];
  kind: string;
  disabled: boolean;
  onPad: (number: number) => void;
}) {
  const half = PAD_PLANET_RADIUS / Math.SQRT2;
  return (
    <g transform={`translate(${at.x} ${at.y})`}>
      <g style={{ color: '#e7c689' }}>
        <circle r={PAD_PLANET_RADIUS + 4} fill="#090f10" />
        <PlanetGlyph radius={PAD_PLANET_RADIUS} kind={kind} />
      </g>
      {pads.map((pad) => {
        const x = (pad.x - 0.5) * 2 * half;
        const y = (0.5 - pad.y) * 2 * half;
        const usable = !disabled && !!pad.free;
        return (
          <g
            key={pad.number}
            transform={`translate(${x} ${y})`}
            className={`SpaceNavigation__pad ${pad.chosen ? 'is-chosen' : ''} ${usable ? '' : 'is-taken'}`}
            role="button"
            tabIndex={usable ? 0 : -1}
            aria-label={`Площадка ${pad.number}: ${pad.label}`}
            aria-disabled={!usable}
            onClick={() => usable && onPad(pad.number)}
            onKeyDown={(event) =>
              event.key === 'Enter' && usable && onPad(pad.number)
            }
          >
            <title>{`Площадка ${pad.number}: ${pad.label}${pad.free ? '' : ' · занята'}`}</title>
            <circle r={9} fill="transparent" stroke="none" />
            <rect x={-5} y={-5} width={10} height={10} />
            <text x={9} y={4}>
              {pad.number}
            </text>
          </g>
        );
      })}
    </g>
  );
}
