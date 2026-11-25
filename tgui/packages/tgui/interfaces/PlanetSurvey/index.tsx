import { type MouseEvent, useEffect, useRef, useState } from 'react';
import { Button } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { PlanetGlyph } from '../SpaceNavigation/DisplayArt';
import { SegmentedProgress } from '../SpaceNavigation/SegmentedProgress';
import {
  behindPlanet,
  footprintOutline,
  type Physics,
  simulateFlight,
  toView,
  type Vector,
} from './probe';

type Flight = {
  id: string;
  /** Kept points of the flight in the planet's frame */
  path: Vector[];
  elapsed: number;
  duration: number;
};

type Facts = {
  biome: string;
  atmosphere: string;
  temperature: number;
  breathable: BooleanLike;
  modifiers: string[];
  caves: string;
  ore: string;
};

/** Places are shares of the surface square from its south-west corner */
type Schematic = {
  rows: string[];
  pads: { rect: number[]; label: string }[];
  caves: [number, number][];
  structures?: number[][];
  organic?: [number, number, number][];
};

type Survey = {
  name: string;
  kind: string;
  probes: number;
  /** Share of the whole planet read, 0-1 */
  coverage: number;
  hits: Vector[];
  flights: Flight[];
  reload: number;
  covered: BooleanLike;
  efficient: BooleanLike;
  mapping: number;
  mapped: BooleanLike;
  generating: BooleanLike;
  failed: BooleanLike;
  facts?: Facts;
  schematic?: Schematic;
};

type Data = {
  vessel_name: string | null;
  planet: Survey | null;
  reason?: string;
  physics: Physics;
};

export const PlanetSurvey = () => {
  const { data } = useBackend<Data>();
  return (
    <Window width={1100} height={720}>
      <Window.Content>
        <main className="SpaceNavigation">
          <header>
            <div className="SpaceNavigation__nameplate">
              <strong title={data.vessel_name || ''}>
                {data.vessel_name || 'СКАНЕР'}
              </strong>
              <span>СКАНИРОВАНИЕ МЕСТНОСТИ / SRV–01</span>
            </div>
          </header>
          {data.planet ? (
            <SurveyBody survey={data.planet} physics={data.physics} />
          ) : (
            <p className="SpaceNavigation__help">{data.reason}</p>
          )}
        </main>
      </Window.Content>
    </Window>
  );
};

function SurveyBody({ survey, physics }: { survey: Survey; physics: Physics }) {
  const [back, setBack] = useState(false);
  const [screen, setScreen] = useState<'probes' | 'map'>('probes');
  const showMap = screen === 'map' && !!survey.schematic;
  return (
    <div className="SpaceNavigation__survey">
      <section className="SpaceNavigation__plot">
        <div className="SpaceNavigation__screen-label">
          <span>{survey.name.toUpperCase()}</span>
          <div className="SpaceNavigation__sides">
            <Button
              selected={!showMap && !back}
              onClick={() => {
                setScreen('probes');
                setBack(false);
              }}
            >
              ЛИЦЕВАЯ
            </Button>
            <Button
              selected={!showMap && back}
              onClick={() => {
                setScreen('probes');
                setBack(true);
              }}
            >
              ОБРАТНАЯ
            </Button>
            <Button
              selected={showMap}
              disabled={!survey.schematic}
              onClick={() => setScreen('map')}
            >
              СХЕМА
            </Button>
          </div>
        </div>
        {showMap && survey.schematic ? (
          <SchematicView schematic={survey.schematic} />
        ) : (
          <ProbeField survey={survey} physics={physics} back={back} />
        )}
      </section>
      <aside className="SpaceNavigation__telemetry" aria-label="Сканирование">
        <div className="SpaceNavigation__engraving">
          <span>ПОКРЫТИЕ ПОВЕРХНОСТИ</span>
          <span>01</span>
        </div>
        <div className="SpaceNavigation__flight-screen">
          <div className="SpaceNavigation__screen-label">
            <span>ЗОНДЫ</span>
            <span>
              {survey.probes} / ЦЕЛЬ {physics.efficient}
            </span>
          </div>
          <Meter label="ПЛАНЕТА" value={survey.coverage} goal={physics.goal} />
        </div>
        <div className="SpaceNavigation__engraving">
          <span>КАРТОГРАФИРОВАНИЕ</span>
          <span>02</span>
        </div>
        <div className="SpaceNavigation__flight-screen">
          {survey.failed ? (
            <p className="SpaceNavigation__help">
              Картографирование не удалось: поверхность не поддаётся съёмке.
            </p>
          ) : (
            <SegmentedProgress
              title="КАРТОГРАФИРОВАНИЕ"
              segments={20}
              caption={
                survey.mapped
                  ? 'Схема готова'
                  : !survey.covered
                    ? 'Ожидание покрытия'
                    : survey.mapping >= 1
                      ? 'Обработка данных…'
                      : survey.generating
                        ? 'Съёмка рельефа'
                        : 'Обработка снимков'
              }
              value={survey.mapped ? 1 : Math.min(survey.mapping, 0.99)}
            />
          )}
        </div>
        <div className="SpaceNavigation__engraving">
          <span>ДАННЫЕ ПЛАНЕТЫ</span>
          <span>03</span>
        </div>
        <div className="SpaceNavigation__flight-screen">
          <div className="SpaceNavigation__screen-label">
            <span>СВОДКА</span>
          </div>
          {survey.facts ? (
            <dl>
              <dt>СРЕДА</dt>
              <dd>{survey.facts.biome}</dd>
              <dt>АТМОСФЕРА</dt>
              <dd>{survey.facts.atmosphere}</dd>
              <dt>ТЕМПЕРАТУРА</dt>
              <dd>{Math.round(survey.facts.temperature - 273.15)} °C</dd>
              <dt>ДЫХАНИЕ</dt>
              <dd>{survey.facts.breathable ? 'Пригодна' : 'EVA'}</dd>
              <dt>ПЕЩЕРЫ</dt>
              <dd>{survey.facts.caves}</dd>
              <dt>РУДА</dt>
              <dd>{survey.facts.ore}</dd>
              {survey.facts.modifiers.length > 0 && (
                <>
                  <dt>ОСОБЕННОСТИ</dt>
                  <dd>{survey.facts.modifiers.join(', ')}</dd>
                </>
              )}
            </dl>
          ) : (
            <p className="SpaceNavigation__help">
              Покройте зондами обе стороны планеты.
            </p>
          )}
        </div>
      </aside>
    </div>
  );
}

function Meter({
  label,
  value,
  goal,
}: {
  label: string;
  value: number;
  goal: number;
}) {
  return (
    <div className="SpaceNavigation__meter">
      <span>{label}</span>
      <div className="SpaceNavigation__meter-bar">
        <span style={{ width: `${Math.round(value * 100)}%` }} />
        <i style={{ left: `${goal * 100}%` }} />
      </div>
      <span>{Math.floor(value * 100)}%</span>
    </div>
  );
}

/** Seconds a full sweep of the launch power takes, up and back down */
const POWER_SWEEP = 3;

/** The planet with the ground read so far, the probes in flight and the aim. */
function ProbeField({
  survey,
  physics,
  back,
}: {
  survey: Survey;
  physics: Physics;
  back: boolean;
}) {
  const { act } = useBackend();
  const svg = useRef<SVGSVGElement>(null);
  const [aim, setAim] = useState<[number, number] | null>(null);
  const [chargeStart, setChargeStart] = useState<number | null>(null);
  const [lastPower, setLastPower] = useState(0.5);
  const [now, setNow] = useState(Date.now());
  const received = useRef(Date.now());
  useEffect(() => {
    received.current = Date.now();
  }, [survey.flights]);
  const animating = chargeStart !== null || survey.flights.length > 0;
  useEffect(() => {
    if (!animating) return;
    let frame = requestAnimationFrame(function tick() {
      setNow(Date.now());
      frame = requestAnimationFrame(tick);
    });
    return () => cancelAnimationFrame(frame);
  }, [animating]);
  const ready = !survey.covered && !survey.failed;
  const power =
    chargeStart === null ? lastPower : sweep((now - chargeStart) / 1000);
  const preview = aim ? simulateFlight(physics, aim[0], aim[1], power) : null;

  const pointer = (event: MouseEvent): [number, number] | null => {
    const matrix = svg.current?.getScreenCTM();
    if (!matrix) return null;
    const x = (event.clientX - matrix.e) / matrix.a;
    const y = -(event.clientY - matrix.f) / matrix.d;
    const limit = physics.aim_limit;
    return [
      Math.max(-limit, Math.min(limit, x)),
      Math.max(-limit, Math.min(limit, y)),
    ];
  };
  const release = () => {
    if (chargeStart === null || !aim) return;
    const launched = sweep((Date.now() - chargeStart) / 1000);
    setChargeStart(null);
    setLastPower(launched);
    act('launch', { x: aim[0], y: aim[1], power: launched, back });
  };

  const sinceData = (now - received.current) / 1000;
  return (
    <svg
      ref={svg}
      className={`SpaceNavigation__field ${ready ? '' : 'is-idle'}`}
      viewBox="-2.2 -1.55 4.4 3.1"
      onMouseMove={(event) => setAim(pointer(event))}
      onMouseLeave={() => {
        setAim(null);
        setChargeStart(null);
      }}
      onMouseDown={(event) => {
        if (!ready || event.button !== 0) return;
        setAim(pointer(event));
        setChargeStart(Date.now());
      }}
      onMouseUp={release}
    >
      <g style={{ color: '#a9d9cb' }} transform="scale(1)">
        <PlanetGlyph radius={1} kind={survey.kind} />
      </g>
      {/* drawn solid and faded as one, so overlapping footprints merge into one read area */}
      <g className="SpaceNavigation__cap">
        {survey.hits.map((hit, index) => {
          const outline = footprintOutline(hit, back, physics.footprint);
          return (
            outline && (
              <polygon
                key={index}
                points={outline.map(([x, y]) => `${x},${y}`).join(' ')}
              />
            )
          );
        })}
      </g>
      {survey.hits.map((hit, index) => {
        const [x, y, z] = toView(hit, back);
        return (
          z >= 0 && (
            <circle key={index} cx={x} cy={-y} r={0.025} fill="#e4bf79" />
          )
        );
      })}
      {survey.flights.map((flight) => (
        <FlightTrace
          key={flight.id}
          flight={flight}
          back={back}
          share={Math.min(1, (flight.elapsed + sinceData) / flight.duration)}
        />
      ))}
      {ready && preview && (
        <polyline
          points={preview
            .slice(0, Math.ceil(preview.length / 3))
            .map(([x, y]) => `${x},${-y}`)
            .join(' ')}
          fill="none"
          stroke="#e4bf79"
          strokeWidth={0.012}
          strokeDasharray="0.04 0.04"
        />
      )}
      {ready && aim && (
        <g transform={`translate(${aim[0]} ${-aim[1]})`} stroke="#e4bf79">
          <circle r={0.05} fill="none" strokeWidth={0.01} />
          <path
            d="M-0.09 0h0.06M0.03 0h0.06M0 -0.09v0.06M0 0.03v0.06"
            strokeWidth={0.01}
          />
        </g>
      )}
      {ready && (
        <g transform="translate(-0.5 1.3)">
          <rect
            width={1}
            height={0.05}
            fill="#13221f"
            stroke="#364a46"
            strokeWidth={0.008}
          />
          <rect width={power} height={0.05} fill="#a9d9cb" />
        </g>
      )}
      {survey.reload > 0 && ready && (
        <text x={0} y={1.45} textAnchor="middle" fontSize={0.08} fill="#a5bfb3">
          ПЕРЕЗАРЯДКА
        </text>
      )}
    </svg>
  );
}

/** Launch power for a button held [seconds]: up to full and back, again and again */
function sweep(seconds: number) {
  const phase = (seconds % POWER_SWEEP) / POWER_SWEEP;
  return phase < 0.5 ? phase * 2 : 2 - phase * 2;
}

/** A probe [share] of the way along its flight, with its trail; dim where the planet hides it */
function FlightTrace({
  flight,
  back,
  share,
}: {
  flight: Flight;
  back: boolean;
  share: number;
}) {
  const points = flight.path.map((point) => toView(point, back));
  const along = share * (points.length - 1);
  const passed = Math.floor(along);
  const trail = points.slice(0, passed + 1);
  const from = points[passed];
  const to = points[Math.min(points.length - 1, passed + 1)];
  const part = along - passed;
  const head: Vector = [0, 1, 2].map(
    (axis) => from[axis] + (to[axis] - from[axis]) * part,
  ) as Vector;
  trail.push(head);
  return (
    <g>
      <polyline
        points={trail.map(([x, y]) => `${x},${-y}`).join(' ')}
        fill="none"
        stroke="#a9d9cb"
        strokeOpacity={0.5}
        strokeWidth={0.01}
      />
      <circle
        cx={head[0]}
        cy={-head[1]}
        r={0.03}
        fill="#d7d6c8"
        fillOpacity={behindPlanet(head) ? 0.25 : 1}
      />
    </g>
  );
}

type Run = { x: number; y: number; length: number; code: string };

const TERRAIN_CLASS: Record<string, string> = {
  '#': 'rock',
  '.': 'ground',
  '~': 'liquid',
};

/** The mapped surface: terrain, landing pads, cave entrances and, for an efficient survey, structures and life */
function SchematicView({ schematic }: { schematic: Schematic }) {
  const size = schematic.rows.length;
  const runs: Run[] = [];
  schematic.rows.forEach((row, y) => {
    for (let x = 0; x < row.length; ) {
      const code = row[x];
      let end = x + 1;
      while (end < row.length && row[end] === code) end++;
      if (TERRAIN_CLASS[code]) runs.push({ x, y, length: end - x, code });
      x = end;
    }
  });
  // shares of the square to schematic cells, north up
  const at = (x: number, y: number): [number, number] => [
    x * size,
    (1 - y) * size,
  ];
  return (
    <svg
      className="SpaceNavigation__schematic"
      viewBox={`-2 -2 ${size + 4} ${size + 4}`}
      role="img"
      aria-label="Схема местности"
    >
      {runs.map((run, index) => (
        <rect
          key={index}
          className={TERRAIN_CLASS[run.code]}
          x={run.x}
          y={run.y}
          width={run.length}
          height={1}
        />
      ))}
      {schematic.organic?.map(([x, y, radius], index) => {
        const [cx, cy] = at(x, y);
        return (
          <circle
            key={`life${index}`}
            className="organic"
            cx={cx}
            cy={cy}
            r={radius * size}
            strokeWidth={0.4}
          >
            <title>Органический фон</title>
          </circle>
        );
      })}
      {schematic.structures?.map(([west, south, east, north], index) => {
        const [x, y] = at(west, north);
        return (
          <rect
            key={`ruin${index}`}
            className="structure"
            x={x}
            y={y}
            width={(east - west) * size}
            height={(north - south) * size}
            strokeWidth={0.5}
          >
            <title>Искусственная структура</title>
          </rect>
        );
      })}
      {schematic.caves.map(([x, y], index) => {
        const [cx, cy] = at(x, y);
        return (
          <path
            key={`cave${index}`}
            className="cave"
            d={`M${cx} ${cy - 1.4}l1.3 2.2h-2.6z`}
          >
            <title>Вход в пещеры</title>
          </path>
        );
      })}
      {schematic.pads.map((pad, index) => {
        const [west, south, east, north] = pad.rect;
        const [x, y] = at(west, north);
        return (
          <g key={`pad${index}`} className="SpaceNavigation__pad">
            <title>{`Площадка ${index + 1}: ${pad.label}`}</title>
            <rect
              x={x}
              y={y}
              width={(east - west) * size}
              height={(north - south) * size}
              strokeWidth={0.5}
            />
            <text x={x + 0.5} y={y - 0.8} fontSize={3}>
              {index + 1}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
