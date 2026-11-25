import { useState } from 'react';
import { Button } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { SegmentedProgress } from '../SpaceNavigation/SegmentedProgress';
import { POPULATED, RINGS, STARS } from './galaxy';

/** A charted system of ours: Epsilon Eridani or a frontier system */
type System = {
  id: string;
  name: string;
  x: number;
  y: number;
  /** Size of a frontier system; null for Epsilon Eridani */
  size: string | null;
  planets: number | null;
  route: BooleanLike;
  available: BooleanLike;
};

type Data = {
  vessel_name?: string;
  sector?: string;
  sector_name?: string;
  systems?: System[];
  target?: string | null;
  target_name?: string | null;
  progress?: number | null;
  drive?: BooleanLike;
  /** Whether the ship is at one of its system's jump points */
  at_jump_point?: BooleanLike;
};

type Selection = { system: string } | { star: string } | null;

/** How far from the straight course a star may lie to mark a corridor of the jump */
const CORRIDOR_REACH = 45;

/** Bluespace jump terminal: the galaxy map, the systems a jump from here, and the jump under way. */
export const BluespaceTerminal = () => {
  const { act, data } = useBackend<Data>();
  const [selection, setSelection] = useState<Selection>(null);
  const systems = data.systems || [];
  const here = systems.find((system) => system.id === data.sector);
  const target = systems.find((system) => system.id === data.target);
  const jumping = typeof data.progress === 'number';
  const corridor = here && target ? corridorOf(here, target) : null;
  const chosen =
    selection && 'system' in selection
      ? systems.find((system) => system.id === selection.system)
      : undefined;
  return (
    <Window width={1000} height={760}>
      <Window.Content>
        <main className="SpaceNavigation">
          <header>
            <div className="SpaceNavigation__nameplate">
              <strong title={data.vessel_name || ''}>
                {data.vessel_name || 'ТЕРМИНАЛ'}
              </strong>
              <span>БЛЮСПЕЙС-ПЕРЕХОДЫ / BSD–01</span>
            </div>
          </header>
          <div className="SpaceNavigation__survey">
            <section className="SpaceNavigation__plot">
              <div className="SpaceNavigation__screen-label">
                <span>КАРТА ГАЛАКТИКИ</span>
                <span className="SpaceNavigation__mode">
                  {(data.sector_name || 'НЕТ ДАННЫХ').toUpperCase()}
                </span>
              </div>
              <svg
                className="SpaceNavigation__galaxy"
                viewBox="0 0 1024 1024"
                role="img"
                aria-label="Карта галактики"
              >
                <polygon
                  className="populated"
                  points={POPULATED.map(([x, y]) => `${x},${y}`).join(' ')}
                />
                {RINGS.map(([radius, label]) => (
                  <g key={label} className="ring">
                    <circle cx={512} cy={512} r={radius} />
                    <text x={512} y={512 - radius - 8} textAnchor="middle">
                      {label}
                    </text>
                  </g>
                ))}
                <text className="uncharted" x={110} y={36} textAnchor="middle">
                  НЕИЗВЕДАННЫЙ КОСМОС
                </text>
                <text
                  className="uncharted"
                  x={900}
                  y={1004}
                  textAnchor="middle"
                >
                  НЕИЗВЕДАННЫЙ КОСМОС
                </text>
                {STARS.map(([name, x, y]) => (
                  <circle
                    key={name + x + y}
                    className={`star ${selection && 'star' in selection && selection.star === name ? 'is-selected' : ''}`}
                    cx={x}
                    cy={y}
                    r={3}
                    onClick={() => setSelection({ star: name })}
                  >
                    <title>{name}</title>
                  </circle>
                ))}
                {corridor && jumping && (
                  <JumpCorridor
                    points={corridor}
                    progress={data.progress || 0}
                  />
                )}
                {systems.map((system) => (
                  <SystemMark
                    key={system.id}
                    system={system}
                    here={system.id === data.sector}
                    selected={chosen?.id === system.id}
                    onClick={() => setSelection({ system: system.id })}
                  />
                ))}
              </svg>
            </section>
            <aside className="SpaceNavigation__telemetry" aria-label="Привод">
              <div className="SpaceNavigation__engraving">
                <span>БЛЮСПЕЙС-ПРИВОД</span>
                <span>01</span>
              </div>
              <div className="SpaceNavigation__flight-screen">
                <div className="SpaceNavigation__screen-label">
                  <span>СОСТОЯНИЕ</span>
                  <span>{data.drive ? 'ЗАРЯЖЕН' : 'НЕ ГОТОВ'}</span>
                </div>
                <div className="SpaceNavigation__screen-body">
                  {jumping ? (
                    <SegmentedProgress
                      title="БЛЮСПЕЙС-ПЕРЕХОД"
                      caption={data.target_name || ''}
                      value={data.progress || 0}
                    />
                  ) : (
                    <dl>
                      <dt>СИСТЕМА</dt>
                      <dd title={data.sector_name || ''}>
                        {data.sector_name || '—'}
                      </dd>
                      <dt>МАРШРУТЫ</dt>
                      <dd>
                        {systems.filter((system) => system.available).length}
                      </dd>
                    </dl>
                  )}
                </div>
              </div>
              <div className="SpaceNavigation__engraving">
                <span>ЦЕЛЬ ПЕРЕХОДА</span>
                <span>02</span>
              </div>
              <div className="SpaceNavigation__flight-screen">
                <div className="SpaceNavigation__screen-label">
                  <span>ВЫБРАННАЯ ТОЧКА</span>
                </div>
                <div className="SpaceNavigation__screen-body">
                  <Selected
                    selection={selection}
                    system={chosen}
                    here={data.sector}
                    atJumpPoint={!!data.at_jump_point}
                  />
                </div>
              </div>
              <div className="SpaceNavigation__engraving">
                <span>УПРАВЛЕНИЕ</span>
                <span>03</span>
              </div>
              <div className="SpaceNavigation__engine-control">
                <Button
                  icon="circle-nodes"
                  tooltip="Начать переход к выбранной системе"
                  disabled={jumping || !chosen?.available}
                  onClick={() => chosen && act('jump', { id: chosen.id })}
                >
                  <span className="SpaceNavigation__key-label">ПУСК</span>
                </Button>
                <Button
                  icon="xmark"
                  tooltip="Отменить переход"
                  disabled={!jumping}
                  onClick={() => act('cancel')}
                >
                  <span className="SpaceNavigation__key-label">ОТМЕНА</span>
                </Button>
              </div>
            </aside>
          </div>
        </main>
      </Window.Content>
    </Window>
  );
};

/** One of our systems: bold where a jump can take the ship, ringed where the ship is */
function SystemMark({
  system,
  here,
  selected,
  onClick,
}: {
  system: System;
  here: boolean;
  selected: boolean;
  onClick: () => void;
}) {
  const radius = 5 + (system.planets || 3);
  return (
    <g
      className={`system ${system.available ? 'is-open' : ''} ${selected ? 'is-selected' : ''}`}
      transform={`translate(${system.x} ${system.y})`}
      onClick={onClick}
    >
      <title>{system.name}</title>
      {here && <circle className="here" r={radius + 8} />}
      <circle r={radius} />
      <text x={radius + 6} y={5}>
        {system.name}
      </text>
    </g>
  );
}

/** What the selected point offers */
function Selected({
  selection,
  system,
  here,
  atJumpPoint,
}: {
  selection: Selection;
  system: System | undefined;
  here?: string;
  atJumpPoint: boolean;
}) {
  if (!selection) {
    return <p className="SpaceNavigation__help">Цель не выбрана.</p>;
  }
  if (!system) {
    return (
      <dl>
        <dt>СИСТЕМА</dt>
        <dd>{'star' in selection ? selection.star : ''}</dd>
        <dt>ПЕРЕХОД</dt>
        <dd>Блюспейс-переход недоступен</dd>
      </dl>
    );
  }
  return (
    <dl>
      <dt>СИСТЕМА</dt>
      <dd title={system.name}>{system.name}</dd>
      {system.size && (
        <>
          <dt>РАЗМЕР</dt>
          <dd>
            {system.size}, планет: {system.planets}
          </dd>
        </>
      )}
      <dt>ПЕРЕХОД</dt>
      <dd>
        {system.id === here
          ? 'Корабль в этой системе'
          : system.available
            ? 'Маршрут доступен'
            : system.route
              ? atJumpPoint
                ? 'Привод не готов или манёвр не завершён'
                : 'Выйдите к точке перехода'
              : 'Блюспейс-переход недоступен'}
      </dd>
    </dl>
  );
}

/**
 * The corridor a jump follows: from the system the ship left to its target through the stars lying near the course,
 * in order along it.
 */
function corridorOf(from: System, to: System): [number, number][] {
  const dx = to.x - from.x;
  const dy = to.y - from.y;
  const length = Math.hypot(dx, dy) || 1;
  const steps: [number, number, number][] = [];
  for (const [, x, y] of STARS) {
    const along = ((x - from.x) * dx + (y - from.y) * dy) / (length * length);
    if (along <= 0.08 || along >= 0.92) continue;
    const aside = Math.abs((x - from.x) * dy - (y - from.y) * dx) / length;
    if (aside <= CORRIDOR_REACH) steps.push([along, x, y]);
  }
  steps.sort((a, b) => a[0] - b[0]);
  const corridor: [number, number][] = [[from.x, from.y]];
  let last = 0;
  for (const [along, x, y] of steps) {
    if (along - last < 0.15) continue;
    corridor.push([x, y]);
    last = along;
  }
  corridor.push([to.x, to.y]);
  return corridor;
}

/** The corridor in dashes, and the ship [progress] of the way along it */
function JumpCorridor({
  points,
  progress,
}: {
  points: [number, number][];
  progress: number;
}) {
  const lengths = points
    .slice(1)
    .map((point, index) =>
      Math.hypot(point[0] - points[index][0], point[1] - points[index][1]),
    );
  const total = lengths.reduce((sum, value) => sum + value, 0) || 1;
  let left = Math.min(1, Math.max(0, progress)) * total;
  let ship = points[0];
  for (let index = 0; index < lengths.length; index++) {
    if (left <= lengths[index]) {
      const share = lengths[index] ? left / lengths[index] : 0;
      const [x1, y1] = points[index];
      const [x2, y2] = points[index + 1];
      ship = [x1 + (x2 - x1) * share, y1 + (y2 - y1) * share];
      break;
    }
    left -= lengths[index];
    ship = points[index + 1];
  }
  return (
    <g className="corridor">
      <polyline points={points.map(([x, y]) => `${x},${y}`).join(' ')} />
      {points.slice(1, -1).map(([x, y], index) => (
        <circle key={index} className="waypoint" cx={x} cy={y} r={6} />
      ))}
      <circle className="ship" cx={ship[0]} cy={ship[1]} r={7} />
    </g>
  );
}
