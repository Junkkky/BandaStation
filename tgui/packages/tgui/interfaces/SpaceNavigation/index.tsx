// AI EDIT START - Ship navigation console in the existing CRT instrument style
import { useState } from 'react';
import { Button, DraggableControl } from 'tgui-core/components';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { Chart } from './Chart';
import { distanceLabel, type NavigationData, speedLabel } from './types';
import { useHelm } from './useHelm';

export const SpaceNavigation = () => {
  const { data } = useBackend<NavigationData>();
  return (
    <Window width={940} height={560}>
      <Window.Content>
        {data.sector ? (
          <Navigation key={data.sector} data={data} />
        ) : (
          'Нет связи с навигационным комплексом'
        )}
      </Window.Content>
    </Window>
  );
};

function Navigation({ data }: { data: NavigationData }) {
  const { act } = useBackend();
  const helm = useHelm(data);
  const [focusedContact, setFocusedContact] = useState<number | null>(null);
  const moored = !!(data.docked || data.coupled);
  const contact = data.ship_contacts.find(
    (record) => record.id === focusedContact,
  );
  const distance = (value: number) => distanceLabel(value, data.au_scale);
  const reverse =
    data.vx * Math.sin((data.course * Math.PI) / 180) +
      data.vy * Math.cos((data.course * Math.PI) / 180) <
    -0.05;
  const needle = Math.PI * (1 - Math.min(1, data.speed / 5));
  const mode = data.preparing
    ? 'ПОДГОТОВКА'
    : moored
      ? data.landed
        ? 'НА ПОВЕРХНОСТИ'
        : 'ПРИСТЫКОВАН'
      : data.autopilot
        ? 'АВТОПИЛОТ'
        : data.speed > 0.05
          ? 'ПОЛЁТ'
          : 'СТОП';
  const selectSite = (id: string) => {
    setFocusedContact(null);
    act('select', { value: id });
  };

  return (
    <main className="SpaceNavigation">
      <header>
        <strong>НАВИГАЦИЯ</strong>
        <span>{mode}</span>
      </header>
      <div className="SpaceNavigation__body">
        <section className="SpaceNavigation__plot">
          <Chart
            data={data}
            focusedContact={focusedContact}
            onContact={setFocusedContact}
            onSite={selectSite}
          />
          <div className="SpaceNavigation__legend">
            <span>▲ Судно</span>
            <span>◇ Цель</span>
            <span>↗ Вектор движения</span>
          </div>
          <div className="SpaceNavigation__routes">
            {data.routes.map((site) => (
              <Button
                key={site.id}
                fluid
                compact
                selected={site.id === data.selected}
                disabled={site.failed || data.preparing || data.relocating}
                onClick={() => selectSite(site.id)}
              >
                <span>{site.name}</span>
                <span>{distance(site.distance)}</span>
              </Button>
            ))}
          </div>
          {focusedContact !== null && (
            <p className="SpaceNavigation__help" role="status">
              {contact ? (
                <>
                  К{contact.id} ·{' '}
                  {contact.identity
                    ? `${contact.identity.callsign} [${contact.identity.faction}]`
                    : 'Неопознанное судно'}
                  {' · '}
                  {contact.mode === 'signal'
                    ? 'канал связи'
                    : contact.mode === 'passive'
                      ? 'пассивный канал'
                      : 'активный канал'}
                  {' · '}давность {Math.floor(contact.age)} с · дистанция ≈{' '}
                  {distance(Math.hypot(contact.x - data.x, contact.y - data.y))}
                  {contact.vx !== undefined && contact.vy !== undefined
                    ? ` · Скорость ≈ ${speedLabel(Math.hypot(contact.vx, contact.vy), data.au_scale)}`
                    : ' · Движение не определено'}
                </>
              ) : (
                `Отметка ${focusedContact} устарела`
              )}
            </p>
          )}
        </section>
        <aside className="SpaceNavigation__telemetry">
          <div className="SpaceNavigation__instruments">
            <div className="SpaceNavigation__sensor-speed">
              <Button
                className="SpaceNavigation__scan"
                icon="satellite-dish"
                tooltip="Сканирование"
                aria-label="Сканирование"
                disabled={!data.scan_ready}
                onClick={() => act('scan')}
              >
                <span
                  role="status"
                  aria-label={
                    data.scan_ready
                      ? 'Сканирование доступно'
                      : 'Сканирование недоступно'
                  }
                  className={`SpaceNavigation__lamp ${data.scan_ready ? 'ready' : ''}`}
                />
              </Button>
              <div
                className="SpaceNavigation__speedometer"
                role="meter"
                aria-label="Скорость корабля"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={Math.min(100, (data.speed / 5) * 100)}
                aria-valuetext={speedLabel(data.speed, data.au_scale)}
              >
                <svg viewBox="0 0 100 58" aria-hidden="true">
                  <path className="gauge" d="M10 50a40 40 0 0 1 80 0" />
                  <path
                    d={`M50 50L${50 + 36 * Math.cos(needle)} ${50 - 36 * Math.sin(needle)}`}
                  />
                  <circle cx="50" cy="50" r="3" />
                </svg>
                <output>
                  {reverse ? '−' : ''}
                  {speedLabel(data.speed, data.au_scale)}
                </output>
              </div>
            </div>
            <dl>
              <dt>Координаты</dt>
              <dd>
                {distance(data.x)} / {distance(data.y)}
              </dd>
              <dt>Курс</dt>
              <dd>
                {Math.round(data.course)}° / {Math.round(data.ordered_course)}°
              </dd>
              <dt>Дистанция</dt>
              <dd>{data.selected ? distance(data.distance) : '—'}</dd>
            </dl>
          </div>
          <div className="SpaceNavigation__helm">
            <div className="SpaceNavigation__throttle">
              <div className="SpaceNavigation__scale" aria-hidden="true">
                {['+100', '+50', '0', '−50', '−100'].map((mark) => (
                  <span key={mark}>{mark}</span>
                ))}
              </div>
              <DraggableControl
                value={data.throttle}
                minValue={-100}
                maxValue={100}
                step={5}
                stepPixelSize={3.5}
                dragMatrix={[0, -1]}
                updateRate={150}
                tickWhileDragging
                disabled={helm.blocked}
                unit="%"
                onChange={(_, value) => helm.setThrottle(value)}
              >
                {({ displayValue, handleDragStart, inputElement }) => (
                  <>
                    <div
                      className="SpaceNavigation__lever"
                      role="slider"
                      tabIndex={helm.blocked ? -1 : 0}
                      aria-label="Тяга, проценты"
                      aria-valuemin={-100}
                      aria-valuemax={100}
                      aria-valuenow={displayValue}
                      aria-disabled={helm.blocked}
                      style={{ top: `${12 + (100 - displayValue) * 0.7}px` }}
                      onMouseDown={handleDragStart}
                    />
                    {inputElement}
                    <output>{displayValue}%</output>
                  </>
                )}
              </DraggableControl>
            </div>
            <div className="SpaceNavigation__helm-buttons">
              <div className="SpaceNavigation__engine-control">
                <Button
                  icon="power-off"
                  selected={!!data.engines_running}
                  tooltip={
                    data.engines_running
                      ? 'Выключить двигатели'
                      : 'Запустить двигатели'
                  }
                  disabled={
                    data.preparing ||
                    data.relocating ||
                    (!data.engines_running && data.engines <= 0)
                  }
                  onClick={() =>
                    act('engine', { value: data.engines_running ? 0 : 1 })
                  }
                />
                <span>ДВИГАТЕЛИ {data.engines_running ? 'ВКЛ' : 'ВЫКЛ'}</span>
              </div>
              <div
                className="SpaceNavigation__maneuvers"
                role="group"
                aria-label="Управление кораблём"
              >
                <Button
                  disabled={helm.blocked}
                  tooltip="Рыскание влево"
                  onClick={() => act('turn', { value: -15 })}
                >
                  ↶
                </Button>
                <Button
                  disabled={helm.blocked}
                  tooltip="Увеличить тягу"
                  onClick={() => helm.changeThrottle(5)}
                >
                  ↑
                </Button>
                <Button
                  disabled={helm.blocked}
                  tooltip="Рыскание вправо"
                  onClick={() => act('turn', { value: 15 })}
                >
                  ↷
                </Button>
                <Button
                  disabled={helm.lateralBlocked}
                  tooltip="Боковая тяга влево: удерживать"
                  selected={data.maneuver_direction === 8}
                  onMouseDown={(event) => {
                    if (event.button === 0) helm.hold('left');
                  }}
                >
                  ←
                </Button>
                <Button
                  disabled={helm.blocked}
                  tooltip="Уменьшить тягу"
                  onClick={() => helm.changeThrottle(-5)}
                >
                  ↓
                </Button>
                <Button
                  disabled={helm.lateralBlocked}
                  tooltip="Боковая тяга вправо: удерживать"
                  selected={data.maneuver_direction === 4}
                  onMouseDown={(event) => {
                    if (event.button === 0) helm.hold('right');
                  }}
                >
                  →
                </Button>
              </div>
              <Button
                fluid
                disabled={
                  helm.blocked ||
                  data.planning ||
                  !data.selected ||
                  data.selected === data.docked ||
                  data.engines <= 0 ||
                  data.throttle <= 0
                }
                onClick={() => act('autopilot')}
              >
                АВТОПИЛОТ
              </Button>
              <Button
                fluid
                className="SpaceNavigation__stop"
                disabled={data.relocating}
                onClick={() => act('stop')}
              >
                {data.jumping
                  ? 'ОТМЕНА'
                  : data.braking
                    ? 'ТОРМОЖЕНИЕ…'
                    : 'ТОРМОЖЕНИЕ'}
              </Button>
              <p className="SpaceNavigation__help">
                {data.braking_distance === null
                  ? 'Нет тяги для торможения'
                  : `Тормозной путь ≈ ${distance(data.braking_distance)}`}
              </p>
            </div>
          </div>
          <section className="SpaceNavigation__docking" aria-label="Стыковка">
            <Button
              fluid
              disabled={
                focusedContact !== null
                  ? !contact || !data.can_request_ship_dock
                  : !data.can_dock
              }
              onClick={() =>
                act(focusedContact === null ? 'dock' : 'ship_dock', {
                  value: focusedContact,
                })
              }
            >
              {focusedContact !== null
                ? 'ЗАПРОС СТЫКОВКИ'
                : data.landing
                  ? 'ПОСАДКА'
                  : 'СТЫКОВКА'}
            </Button>
            {moored && (
              <Button
                fluid
                disabled={
                  !data.engines_running ||
                  data.preparing ||
                  data.relocating ||
                  data.engines <= 0
                }
                onClick={() => act('depart')}
              >
                {data.landed ? 'ВЗЛЁТ' : 'ОТСТЫКОВКА'}
              </Button>
            )}
          </section>
          {data.docking_request && (
            <div className="SpaceNavigation__request">
              <span>
                К{data.docking_request.contact ?? '?'}: запрос на стыковку
              </span>
              <Button
                disabled={!data.can_request_ship_dock}
                onClick={() =>
                  act('accept_ship_dock', {
                    value: data.docking_request?.token,
                  })
                }
              >
                ПРИНЯТЬ
              </Button>
              <Button
                onClick={() =>
                  act('decline_ship_dock', {
                    value: data.docking_request?.token,
                  })
                }
              >
                ОТКЛОНИТЬ
              </Button>
            </div>
          )}
          {data.planet && (
            <p className="SpaceNavigation__help">
              {data.planet.biome} · {data.planet.atmosphere} ·{' '}
              {Math.round(data.planet.temperature - 273.15)} °C ·{' '}
              {data.planet.breathable
                ? 'Пригодна для дыхания'
                : 'Требуется EVA-снаряжение'}
            </p>
          )}
        </aside>
      </div>
      <footer role="status">{data.status}</footer>
    </main>
  );
}
// AI EDIT END
