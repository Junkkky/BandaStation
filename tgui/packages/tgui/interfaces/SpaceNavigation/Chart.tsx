// AI EDIT START - CRT sector chart with hover labels and right-button panning
import { useEffect, useRef, useState } from 'react';
import { Button, Dropdown } from 'tgui-core/components';

import { distanceLabel, type NavigationData, type Position } from './types';

type Props = {
  data: NavigationData;
  focusedContact: number | null;
  onContact: (id: number) => void;
  onSite: (id: string) => void;
};

export function Chart({ data, focusedContact, onContact, onSite }: Props) {
  const [zoom, setZoom] = useState(1);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const drag = useRef<Position | null>(null);
  const svg = useRef<SVGSVGElement>(null);
  const scale = 0.16 * zoom;
  const width = 620;
  const height = 300;
  const centre = { x: data.x + pan.x, y: data.y + pan.y };
  const point = (x: number, y: number) => ({
    x: width / 2 + (x - centre.x) * scale,
    y: height / 2 - (y - centre.y) * scale,
  });
  const own = point(data.x, data.y);
  const disabled = !!(data.preparing || data.relocating);

  useEffect(() => {
    const release = () => {
      drag.current = null;
    };
    const move = (event: MouseEvent) => {
      if (!drag.current || !svg.current) return;
      const bounds = svg.current.getBoundingClientRect();
      if (!bounds.width || !bounds.height) return;
      const dx = (event.clientX - drag.current.x) * (width / bounds.width);
      const dy = (event.clientY - drag.current.y) * (height / bounds.height);
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

  return (
    <>
      <div className="SpaceNavigation__plot-head">
        <span>{data.sector_name}</span>
        <Button
          compact
          icon="crosshairs"
          tooltip="Центрировать на корабле"
          aria-label="Центрировать на корабле"
          onClick={() => setPan({ x: 0, y: 0 })}
        />
        <Dropdown
          width="65px"
          selected={`${zoom}×`}
          options={['0.5×', '1×', '2×', '4×']}
          onSelected={(value) => setZoom(Number.parseFloat(value))}
        />
      </div>
      <svg
        ref={svg}
        width={width}
        height={height}
        viewBox={`0 0 ${width} ${height}`}
        className="SpaceNavigation__chart"
        aria-label="Карта контактов. Выбор левой кнопкой, перемещение правой."
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
        </defs>
        <g stroke="#22352c">
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
        <g fill="none" stroke="#354239">
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
        {data.star && (
          <circle
            cx={point(data.star.x, data.star.y).x}
            cy={point(data.star.x, data.star.y).y}
            r={10}
            fill="#e7c47b"
          />
        )}
        {bodies.map((body) => (
          <circle
            key={body.name}
            cx={point(body.x, body.y).x}
            cy={point(body.x, body.y).y}
            r={body.radius}
            fill={body.kind === 'lava' ? '#9d4931' : '#9aa9a0'}
            stroke="#c4ae88"
          >
            <title>{body.name}</title>
          </circle>
        ))}
        {data.zones.map((zone, index) => (
          <g key={index}>
            <circle
              cx={point(zone.x, zone.y).x}
              cy={point(zone.x, zone.y).y}
              r={zone.radius * scale}
              fill={zone.kind === 'nebula' ? '#5a5582' : '#825f32'}
              fillOpacity={0.15}
              stroke={zone.kind === 'nebula' ? '#6a718e' : '#b77558'}
            >
              <title>{zone.name}</title>
            </circle>
            {zone.kind === 'meteors' && (
              <path
                d="M0-24V24M0 24L-8 12M0 24L8 12"
                transform={`translate(${point(zone.x, zone.y).x} ${point(zone.x, zone.y).y}) rotate(${zone.direction})`}
                fill="none"
                stroke="#b77558"
              />
            )}
          </g>
        ))}
        <g stroke="#bdad80" strokeWidth={3}>
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
        {data.routes.map((site) => {
          const p = point(site.x, site.y);
          return (
            <g
              key={site.id}
              transform={`translate(${p.x} ${p.y})`}
              className="SpaceNavigation__marker"
              role="button"
              tabIndex={0}
              aria-label={site.name}
              aria-disabled={disabled || !!site.failed}
              onClick={() => !disabled && !site.failed && onSite(site.id)}
              onKeyDown={(event) => {
                if (event.key === 'Enter' && !disabled && !site.failed)
                  onSite(site.id);
              }}
              stroke={site.id === data.selected ? '#edc587' : '#7b9c86'}
            >
              <title>{site.name}</title>
              <circle r={13} fill="transparent" stroke="none" />
              {site.kind === 'planet' ? (
                <circle r={6} fill="#33473a" />
              ) : (
                <path d="M0-7L7 0L0 7L-7 0Z" fill="#080e0d" />
              )}
            </g>
          );
        })}
        {data.ship_contacts.map((contact) => {
          const p = point(contact.x, contact.y);
          return (
            <g
              key={contact.id}
              className="SpaceNavigation__marker"
              role="button"
              tabIndex={0}
              aria-label={`Контакт ${contact.id}`}
              onClick={() => onContact(contact.id)}
              onKeyDown={(event) =>
                event.key === 'Enter' && onContact(contact.id)
              }
            >
              <title>{`К${contact.id} · ${contact.identity?.callsign || 'Неопознанное судно'} · ${Math.floor(contact.age)} с`}</title>
              <circle cx={p.x} cy={p.y} r={13} fill="transparent" />
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
        <Velocity origin={own} vx={data.vx} vy={data.vy} scale={scale} />
        <path
          d="M0-15L7 10L-7 10Z"
          pointerEvents="none"
          fill="#19281f"
          stroke="#d6edc0"
          transform={`translate(${own.x} ${own.y}) rotate(${data.course})`}
        />
        <g fill="#718870" stroke="#718870">
          <text x={12} y={18} stroke="none">
            N ↑
          </text>
          <path d={`M12 ${height - 30}h100`} />
          <text x={12} y={height - 12} stroke="none">
            {distanceLabel(100 / scale, data.au_scale)}
          </text>
        </g>
      </svg>
    </>
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
  const speed = Math.hypot(vx, vy);
  if (speed < 0.01) return null;
  const length = Math.max(36, Math.min(140, speed * scale * 90));
  return (
    <line
      pointerEvents="none"
      x1={origin.x}
      y1={origin.y}
      x2={origin.x + (vx / speed) * length}
      y2={origin.y - (vy / speed) * length}
      stroke="#91d7d0"
      strokeWidth={2}
      markerEnd="url(#velocity-arrow)"
    />
  );
}
// AI EDIT END
