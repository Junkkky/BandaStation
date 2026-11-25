import { type MouseEvent, useEffect, useMemo, useRef, useState } from 'react';
import { Button, Icon } from 'tgui-core/components';
import { clamp01 } from 'tgui-core/math';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { PlanetGlyph } from '../SpaceNavigation/DisplayArt';
import { SegmentedProgress } from '../SpaceNavigation/SegmentedProgress';
import {
  behindPlanet,
  footprintOutline,
  type Physics,
  launcherPoint,
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

/** What a survey tells of its planet; a field is missing until enough of the planet is read */
type Facts = {
  biome?: string;
  atmosphere?: string;
  temperature?: number;
  breathable?: BooleanLike;
  caves?: string;
  ore?: string;
  modifiers?: string[];
};

/** Places are shares of the surface square from its south-west corner; "?" marks ground the probes did not read */
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
  mapping: number;
  mapped: BooleanLike;
  generating: BooleanLike;
  failed: BooleanLike;
  facts: Facts;
};

/** A saved map of the archive */
type SavedMap = {
  name: string;
  coverage: number;
  facts: Facts;
  schematic: Schematic | null;
};

type Data = {
  vessel_name: string | null;
  planet: Survey | null;
  /** Why nothing is held: no planet in range, carrier moving, carrier moored, no link */
  standby?: 'range' | 'unstable' | 'landed' | 'offline';
  archive_count: number;
  archive_index: number;
  archive?: SavedMap;
  disk_ready: BooleanLike;
  physics: Physics;
};

/** Standby lines of the scope, as an instrument puts them */
const STANDBY: { [reason: string]: string } = {
  range: 'ДАЛЬНОСТЬ ВНЕ РАБОЧЕГО ДИАПАЗОНА',
  unstable: 'НОСИТЕЛЬ НЕ СТАБИЛИЗИРОВАН',
  landed: 'НОСИТЕЛЬ НА СТОЯНКЕ',
  offline: 'НЕТ СВЯЗИ С НОСИТЕЛЕМ',
};

export const PlanetSurvey = () => {
  const { act, data } = useBackend<Data>();
  const [screen, setScreen] = useState<'front' | 'back' | 'map'>('front');
  const survey = data.planet;
  const onMap = screen === 'map';
  const shownFacts = onMap ? data.archive?.facts : survey?.facts;
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
          <div className="SpaceNavigation__survey">
            <section className="SpaceNavigation__plot">
              <div className="SpaceNavigation__screen-label">
                <span>
                  {onMap
                    ? data.archive
                      ? `АРХИВ ${data.archive_index} / ${data.archive_count} · ${data.archive.name.toUpperCase()}`
                      : 'АРХИВ ПУСТ'
                    : survey
                      ? survey.name.toUpperCase()
                      : 'НЕТ ЦЕЛИ'}
                </span>
                <span className="SpaceNavigation__mode">
                  {onMap
                    ? data.archive
                      ? `ПОКРЫТИЕ ${Math.floor(data.archive.coverage * 100)}%`
                      : ''
                    : survey
                      ? screen === 'back'
                        ? 'ОБРАТНАЯ СТОРОНА'
                        : 'ЛИЦЕВАЯ СТОРОНА'
                      : 'STANDBY'}
                </span>
              </div>
              {onMap ? (
                data.archive?.schematic ? (
                  <SchematicView schematic={data.archive.schematic} />
                ) : (
                  <Standby
                    title="НЕТ СОХРАНЁННЫХ КАРТ"
                    reason="КАРТОГРАФИРУЙТЕ ПЛАНЕТУ"
                  />
                )
              ) : survey ? (
                <ProbeField
                  survey={survey}
                  physics={data.physics}
                  back={screen === 'back'}
                />
              ) : (
                <Standby
                  title="ОБЪЕКТ НЕ ЗАХВАЧЕН"
                  reason={STANDBY[data.standby || 'range']}
                />
              )}
            </section>
            <aside
              className="SpaceNavigation__telemetry"
              aria-label="Сканирование"
            >
              <div className="SpaceNavigation__engraving">
                <span>ПОКРЫТИЕ ПОВЕРХНОСТИ</span>
                <span>01</span>
              </div>
              <div className="SpaceNavigation__flight-screen">
                <div className="SpaceNavigation__screen-label">
                  <span>ЗОНДЫ</span>
                  <span>
                    {survey
                      ? `${data.physics.probe_limit - survey.probes} / ${data.physics.probe_limit}`
                      : '—'}
                  </span>
                </div>
                <Meter
                  value={survey?.coverage || 0}
                  marks={data.physics.tiers}
                />
              </div>
              <div className="SpaceNavigation__engraving">
                <span>КАРТОГРАФИРОВАНИЕ</span>
                <span>02</span>
              </div>
              <div className="SpaceNavigation__flight-screen SpaceNavigation__screen-body">
                {survey?.failed ? (
                  <p className="SpaceNavigation__help">
                    Картографирование не удалось: поверхность не поддаётся
                    съёмке.
                  </p>
                ) : (
                  <SegmentedProgress
                    title="КАРТОГРАФИРОВАНИЕ"
                    segments={20}
                    caption={
                      !survey
                        ? 'Нет цели'
                        : survey.mapped
                          ? 'Схема готова'
                          : !survey.covered
                            ? survey.coverage >= data.physics.land
                              ? 'Можно картографировать'
                              : 'Ожидание покрытия'
                            : survey.mapping >= 1
                              ? 'Обработка данных…'
                              : survey.generating
                                ? 'Съёмка рельефа'
                                : 'Обработка снимков'
                    }
                    value={
                      survey?.mapped ? 1 : Math.min(survey?.mapping || 0, 0.99)
                    }
                  />
                )}
              </div>
              <div className="SpaceNavigation__engraving">
                <span>{onMap ? 'ДАННЫЕ АРХИВА' : 'ДАННЫЕ ПЛАНЕТЫ'}</span>
                <span>03</span>
              </div>
              <div className="SpaceNavigation__flight-screen SpaceNavigation__screen-body is-tall">
                <FactList facts={shownFacts} tiers={data.physics.tiers} />
              </div>
              <div className="SpaceNavigation__engraving">
                <span>УПРАВЛЕНИЕ</span>
                <span>04</span>
              </div>
              <div className="SpaceNavigation__engine-control SpaceNavigation__survey-keys">
                <Button
                  icon="circle-half-stroke"
                  selected={screen === 'front'}
                  tooltip="Лицевая сторона планеты"
                  onClick={() => {
                    setScreen('front');
                    act('interface_click');
                  }}
                >
                  <span className="SpaceNavigation__key-label">ЛИЦ</span>
                </Button>
                <Button
                  icon="rotate"
                  selected={screen === 'back'}
                  tooltip="Обратная сторона планеты"
                  onClick={() => {
                    setScreen('back');
                    act('interface_click');
                  }}
                >
                  <span className="SpaceNavigation__key-label">ОБР</span>
                </Button>
                <Button
                  icon="map"
                  selected={onMap}
                  tooltip="Архив карт местности"
                  onClick={() => {
                    setScreen('map');
                    act('interface_click');
                  }}
                >
                  <span className="SpaceNavigation__key-label">СХЕМА</span>
                </Button>
                <Button
                  icon="satellite-dish"
                  disabled={
                    !survey ||
                    !!survey.covered ||
                    survey.coverage < data.physics.land
                  }
                  tooltip="Закончить зондирование и картографировать"
                  onClick={() => act('map')}
                >
                  <span className="SpaceNavigation__key-label">КАРТ</span>
                </Button>
                <Button
                  icon="backward-step"
                  disabled={data.archive_count < 2}
                  tooltip="Предыдущая карта архива"
                  onClick={() => {
                    setScreen('map');
                    act('archive_previous');
                  }}
                >
                  <span className="SpaceNavigation__key-label">НАЗАД</span>
                </Button>
                <Button
                  icon="forward-step"
                  disabled={data.archive_count < 2}
                  tooltip="Следующая карта архива"
                  onClick={() => {
                    setScreen('map');
                    act('archive_next');
                  }}
                >
                  <span className="SpaceNavigation__key-label">ВПЕРЁД</span>
                </Button>
                <Button
                  icon="microchip"
                  disabled={!data.disk_ready}
                  tooltip="Извлечь данные на диск"
                  onClick={() => act('extract')}
                >
                  <span className="SpaceNavigation__key-label">ИЗВЛ</span>
                </Button>
              </div>
            </aside>
          </div>
        </main>
      </Window.Content>
    </Window>
  );
};

/** The scope with nothing to show on it */
function Standby({ title, reason }: { title: string; reason: string }) {
  return (
    <svg
      className="SpaceNavigation__field is-idle"
      viewBox="-2.5 -2.5 5 5"
      role="img"
      aria-label={title}
    >
      <g className="SpaceNavigation__standby">
        <circle r={1} />
        <circle r={0.5} />
        <path d="M-1.3 0H-0.15M0.15 0H1.3M0 -1.3V-0.15M0 0.15V1.3" />
      </g>
      <text
        className="SpaceNavigation__standby-title"
        y={-1.5}
        textAnchor="middle"
      >
        {title}
      </text>
      <text
        className="SpaceNavigation__standby-reason"
        y={1.65}
        textAnchor="middle"
      >
        {reason}
      </text>
    </svg>
  );
}

/** The planet's data, a line for each fact; facts not yet read show the coverage they need */
function FactList({ facts, tiers }: { facts?: Facts; tiers: number[] }) {
  const locked = (tier: number) => (
    <span className="SpaceNavigation__locked">
      <Icon name="lock" /> {Math.round(tiers[tier] * 100)}%
    </span>
  );
  const read = facts || {};
  return (
    <dl>
      <dt>СРЕДА</dt>
      <dd title={read.biome}>{read.biome ?? locked(0)}</dd>
      <dt>АТМОСФЕРА</dt>
      <dd title={read.atmosphere}>{read.atmosphere ?? locked(0)}</dd>
      <dt>ТЕМПЕРАТУРА</dt>
      <dd>
        {read.temperature !== undefined
          ? `${Math.round(read.temperature - 273.15)} °C`
          : locked(1)}
      </dd>
      <dt>ДЫХАНИЕ</dt>
      <dd>
        {read.breathable !== undefined
          ? read.breathable
            ? 'Пригодна'
            : 'EVA'
          : locked(1)}
      </dd>
      <dt>ПЕЩЕРЫ</dt>
      <dd title={read.caves}>{read.caves ?? locked(1)}</dd>
      <dt>РУДА</dt>
      <dd title={read.ore}>{read.ore ?? locked(2)}</dd>
      <dt>ОСОБЕННОСТИ</dt>
      <dd title={read.modifiers?.join(', ')}>
        {read.modifiers
          ? read.modifiers.length
            ? read.modifiers.join(', ')
            : 'Нет'
          : locked(2)}
      </dd>
    </dl>
  );
}

/** Coverage of the whole planet, with a mark at each share that tells more */
function Meter({ value, marks }: { value: number; marks: number[] }) {
  return (
    <div className="SpaceNavigation__meter">
      <span>ПОКРЫТИЕ</span>
      <div className="SpaceNavigation__meter-bar">
        <span style={{ width: `${Math.round(value * 100)}%` }} />
        {marks.map((mark) => (
          <i key={mark} style={{ left: `${mark * 100}%` }} />
        ))}
      </div>
      <span>{Math.floor(value * 100)}%</span>
    </div>
  );
}

/** How long the flash where a probe reads the ground lasts, ms */
const LANDING_FLASH = 900;
/** Seconds a full sweep of the launch power takes, up and back down */
const POWER_SWEEP = 3;
/** How long the launcher kicks back and flashes as it throws a probe, ms */
const LAUNCH_KICK = 350;
/** How long a lost probe's mark stays where it left the screen, ms */
const LOST_MARK = 1400;

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
  // the launcher's kick back from its last throw, against the throw
  const [kick, setKick] = useState<{ at: number; x: number; y: number }>({
    at: 0,
    x: 0,
    y: 0,
  });
  // where probes that missed were last seen, as the viewer sees them
  const [lost, setLost] = useState<{ x: number; y: number; at: number }[]>([]);
  const lastFlights = useRef<Flight[]>(survey.flights);
  const lastHits = useRef(survey.hits.length);
  useEffect(() => {
    const ids = new Set(survey.flights.map((flight) => flight.id));
    const gone = lastFlights.current.filter((flight) => !ids.has(flight.id));
    const struck = survey.hits.length - lastHits.current;
    // flights that ended beyond the ones that struck the ground were lost
    const missed = gone.length - Math.max(0, struck);
    if (missed > 0) {
      const at = Date.now();
      const fresh = gone.slice(0, missed).map((flight) => {
        const [x, y] = toView(flight.path[flight.path.length - 1], back);
        return { x, y, at };
      });
      setLost((old) => [
        ...old.filter((mark) => at - mark.at < LOST_MARK),
        ...fresh,
      ]);
    }
    lastFlights.current = survey.flights;
    lastHits.current = survey.hits.length;
  }, [survey.flights, survey.hits.length]);
  // a flash where each new probe reads the ground
  const [landings, setLandings] = useState<{ index: number; at: number }[]>([]);
  const seenHits = useRef(survey.hits.length);
  useEffect(() => {
    const count = survey.hits.length;
    if (count > seenHits.current) {
      const at = Date.now();
      const fresh: { index: number; at: number }[] = [];
      for (let index = seenHits.current; index < count; index++) {
        fresh.push({ index, at });
      }
      setLandings((old) =>
        [...old, ...fresh].filter((landing) => at - landing.at < LANDING_FLASH),
      );
    }
    seenHits.current = count;
  }, [survey.hits.length]);
  const ready =
    !survey.covered && !survey.failed && survey.probes < physics.probe_limit;
  // redrawn only while something on the field moves
  const settled = Date.now();
  const animating =
    chargeStart !== null ||
    survey.flights.length > 0 ||
    settled - kick.at < LAUNCH_KICK ||
    lost.some((mark) => settled - mark.at < LOST_MARK) ||
    landings.some((landing) => settled - landing.at < LANDING_FLASH);
  useEffect(() => {
    if (!animating) return;
    let frame = requestAnimationFrame(function tick() {
      setNow(Date.now());
      frame = requestAnimationFrame(tick);
    });
    return () => cancelAnimationFrame(frame);
  }, [animating]);
  const power =
    chargeStart === null ? lastPower : sweep((now - chargeStart) / 1000);
  // the ground read changes only as probes strike or the view turns, not with every frame of a flight
  const caps = useMemo(
    () =>
      [true, false].map((far) =>
        survey.hits
          .map((hit) => footprintOutline(hit, back, physics.footprint, far))
          .filter((outline): outline is [number, number][] => !!outline)
          .map((outline) => outline.map(([x, y]) => `${x},${y}`).join(' ')),
      ),
    [survey.hits, back, physics.footprint],
  );
  const sinceData = (now - received.current) / 1000;
  const launcher = launcherPoint(physics);
  const preview = aim ? simulateFlight(physics, aim[0], aim[1], power) : null;
  // the tilted orbit seen from the front: an ellipse, its upper half behind the planet
  const orbitHeight =
    physics.orbit_radius * Math.cos((physics.orbit_tilt * Math.PI) / 180);
  const kickShare = Math.min(1, (now - kick.at) / LAUNCH_KICK);
  const recoil = (1 - kickShare) ** 2 * 0.06;

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
    const reach = Math.hypot(aim[0] - launcher[0], aim[1] - launcher[1]) || 1;
    setKick({
      at: Date.now(),
      x: (aim[0] - launcher[0]) / reach,
      y: (aim[1] - launcher[1]) / reach,
    });
    act('launch', { x: aim[0], y: aim[1], power: launched, back });
  };

  return (
    <svg
      ref={svg}
      className={`SpaceNavigation__field ${ready ? '' : 'is-idle'}`}
      viewBox="-2.5 -2.5 5 5"
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
      {/* the far half of the orbit, behind the planet */}
      <path
        d={`M${-physics.orbit_radius} 0A${physics.orbit_radius} ${orbitHeight} 0 0 1 ${physics.orbit_radius} 0`}
        fill="none"
        stroke="#527e6e"
        strokeOpacity={0.45}
        strokeWidth={0.01}
        strokeDasharray="0.05 0.08"
      />
      <g style={{ color: '#a9d9cb' }} transform="scale(1)">
        <PlanetGlyph radius={1} kind={survey.kind} />
      </g>
      {/* ground read on the face turned away, seen through the planet, then on the near face; each merged into one area */}
      {[true, false].map((far) => (
        <g
          key={far ? 'far' : 'near'}
          className={`SpaceNavigation__cap ${far ? 'is-far' : ''}`}
        >
          {caps[far ? 0 : 1].map((points, index) => (
            <polygon key={index} points={points} />
          ))}
        </g>
      ))}
      {survey.hits.map((hit, index) => {
        const [x, y, z] = toView(hit, back);
        return (
          z >= 0 && (
            <circle key={index} cx={x} cy={-y} r={0.025} fill="#e4bf79" />
          )
        );
      })}
      {landings.map(({ index, at }) => {
        const hit = survey.hits[index];
        const share = (now - at) / LANDING_FLASH;
        if (!hit || share >= 1) return null;
        const [x, y, z] = toView(hit, back);
        return (
          <circle
            key={`flash${index}`}
            cx={x}
            cy={-y}
            r={0.04 + 0.3 * share}
            fill="none"
            stroke="#e4bf79"
            strokeWidth={0.02}
            strokeOpacity={(1 - share) * (z >= 0 ? 1 : 0.35)}
          />
        );
      })}
      {/* the near half of the orbit, in front of the planet, with the ship holding the launcher at its lowest point */}
      <path
        d={`M${physics.orbit_radius} 0A${physics.orbit_radius} ${orbitHeight} 0 0 1 ${-physics.orbit_radius} 0`}
        fill="none"
        stroke="#527e6e"
        strokeWidth={0.01}
        strokeDasharray="0.05 0.08"
      />
      {/* which way the orbit carries the probes */}
      <path
        d={`M0.17 ${orbitHeight - 0.035}L0.23 ${orbitHeight}L0.17 ${orbitHeight + 0.035}M0.26 ${orbitHeight - 0.035}L0.32 ${orbitHeight}L0.26 ${orbitHeight + 0.035}`}
        fill="none"
        stroke="#7fae9b"
        strokeWidth={0.012}
      />
      <g
        transform={`translate(${launcher[0] - kick.x * recoil} ${-launcher[1] + kick.y * recoil}) rotate(90)`}
      >
        <path
          d="M0 -0.09L0.07 0.07L0 0.03L-0.07 0.07Z"
          fill="#1d2b28"
          stroke="#d7d6c8"
          strokeWidth={0.012}
        />
      </g>
      {kickShare < 1 && (
        <circle
          cx={launcher[0]}
          cy={-launcher[1]}
          r={0.05 + 0.22 * kickShare}
          fill="none"
          stroke="#e4bf79"
          strokeWidth={0.015}
          strokeOpacity={1 - kickShare}
        />
      )}
      {lost.map((mark) => {
        const share = (now - mark.at) / LOST_MARK;
        if (share >= 1) return null;
        // where it left the screen, pulled inside so the mark can be read
        const x = Math.max(-2.2, Math.min(2.2, mark.x));
        const y = Math.max(-2.1, Math.min(2.1, -mark.y));
        return (
          <text
            key={`lost${mark.at}${mark.x}`}
            x={x}
            y={y}
            textAnchor="middle"
            fontSize={0.09}
            fill="#e0533f"
            fillOpacity={1 - share}
          >
            ЗОНД ПОТЕРЯН
          </text>
        );
      })}
      {survey.flights.map((flight) => (
        <FlightTrace
          key={flight.id}
          flight={flight}
          back={back}
          share={clamp01((flight.elapsed + sinceData) / flight.duration)}
        />
      ))}
      {ready && preview && (
        <polyline
          points={preview.map(([x, y]) => `${x},${-y}`).join(' ')}
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
        <g transform="translate(-0.5 2.3)">
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
        <text x={0} y={2.25} textAnchor="middle" fontSize={0.09} fill="#a5bfb3">
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

/** The mapped surface: terrain, landing pads, cave entrances and, for a thorough survey, structures and life; unread ground is fogged */
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
      viewBox={`-3 -3 ${size + 6} ${size + 6}`}
      shapeRendering="geometricPrecision"
      role="img"
      aria-label="Схема местности"
    >
      <defs>
        <pattern
          id="survey-ground-grid"
          width="1"
          height="1"
          patternUnits="userSpaceOnUse"
        >
          <path
            d="M1 0H0V1"
            fill="none"
            stroke="#b6c9a0"
            strokeOpacity=".3"
            strokeWidth=".08"
          />
        </pattern>
      </defs>
      <g fill="none" stroke="#6c9d87" strokeWidth=".08" strokeOpacity=".5">
        <path
          d={`M${size / 2} -3V${size + 3}M-3 ${size / 2}H${size + 3}`}
          strokeDasharray=".4 .7"
        />
        <path
          d={`M-2 2V-2H2M${size - 2} -2H${size + 2}V2M${size + 2} ${size - 2}V${size + 2}H${size - 2}M2 ${size + 2}H-2V${size - 2}`}
        />
      </g>
      {/* the depth under the read ground; unread ground ("?") is left dark */}
      <g
        transform="translate(.6 .8)"
        fill="#081410"
        stroke="#9db99a"
        strokeOpacity=".35"
        strokeWidth=".12"
      >
        {runs.map((run, index) => (
          <rect key={index} x={run.x} y={run.y} width={run.length} height={1} />
        ))}
      </g>
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
      {runs.map((run, index) => (
        <rect
          key={`grid${index}`}
          x={run.x}
          y={run.y}
          width={run.length}
          height={1}
          fill="url(#survey-ground-grid)"
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
