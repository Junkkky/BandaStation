import { useState } from 'react';
import { Button, Icon } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { Chart, type MuzzleFlash } from './SpaceNavigation/Chart';
import { ZoomKnob } from './SpaceNavigation/DisplayArt';
import {
  type ChartData,
  type Contact,
  distanceLabel,
  type FiringSector,
  type Position,
} from './SpaceNavigation/types';

const zoomLevels = [1, 2, 4, 8] as const;

const statusLabels = {
  ready: 'Готово',
  firing: 'Очередь',
  charging: 'Накопитель заряжается',
  reload: 'Перезарядка',
  empty: 'Нет снарядов',
  fault: 'Неисправно',
  moored: 'Вне свободного полёта',
  obstructed: 'Дуло перекрыто',
};

type Weapon = FiringSector & {
  id: string;
  name: string;
  shells: number;
  capacity: number;
  loader?: { shells: number; capacity: number; online: BooleanLike } | null;
  status: keyof typeof statusLabels;
  reload: number;
  reload_duration: number;
};

type Data = ChartData & {
  weapons: Weapon[];
  muzzle_flashes?: MuzzleFlash[];
  can_control: BooleanLike;
  power_ready: BooleanLike;
  scan_ready: BooleanLike;
};

export function ShipWeapons() {
  const { data } = useBackend<Data>();
  return (
    <Window width={1060} height={670}>
      <Window.Content>
        {data.sector ? (
          <FireControl key={data.sector} data={data} />
        ) : (
          <main className="SpaceNavigation ShipWeapons ShipWeapons--offline">
            <p className="SpaceNavigation__help" role="status">
              Нет связи с кораблём
            </p>
          </main>
        )}
      </Window.Content>
    </Window>
  );
}

function FireControl({ data }: { data: Data }) {
  const { act } = useBackend();
  const [mountId, selectMount] = useState<string | null>(null);
  const [focusedContact, setFocusedContact] = useState<number | null>(null);
  const [aimPoint, setAimPoint] = useState<Position | null>(null);
  const [hoveredTarget, setHoveredTarget] = useState<string | null>(null);
  const [zoom, setZoom] = useState(4);
  const mount =
    data.weapons.find((weapon) => weapon.id === mountId) ?? data.weapons[0];
  const aimProblem =
    aimPoint && mount ? pointProblem(data, mount, aimPoint) : '';
  const blocker = firingBlocker(data, mount, aimPoint, aimProblem);
  const pointLabel = aimPoint
    ? `X ${Math.round(aimPoint.x)} · Y ${Math.round(aimPoint.y)}`
    : 'Не выбрана';

  return (
    <main className="SpaceNavigation ShipWeapons">
      <header>
        <div className="SpaceNavigation__nameplate">
          <strong title={data.vessel_name}>
            {data.vessel_name || 'Оружейная консоль'}
          </strong>
          {!!data.vessel_name && <span>УПРАВЛЕНИЕ ОГНЁМ</span>}
        </div>
        <ZoomKnob zoom={zoom} onChange={setZoom} levels={zoomLevels} />
      </header>

      <div className="ShipWeapons__body">
        <section
          className="SpaceNavigation__plot"
          aria-labelledby="gunnery-chart-label"
        >
          <div
            className="SpaceNavigation__screen-label"
            id="gunnery-chart-label"
          >
            КАРТА СЕКТОРА
          </div>
          <Chart
            data={data}
            zoom={zoom}
            focusedContact={focusedContact}
            hoveredTarget={hoveredTarget}
            firingSector={mount}
            muzzleFlashes={data.muzzle_flashes}
            aimPoint={aimPoint}
            aimValid={!!mount && !aimProblem}
            onAim={mount ? setAimPoint : undefined}
            onContact={setFocusedContact}
          />
          <div className="SpaceNavigation__legend ShipWeapons__legend">
            {mount && (
              <span>
                <i className="ShipWeapons__sector-swatch" aria-hidden="true" />
                Сектор огня · {distanceLabel(mount.range, data.au_scale)}
              </span>
            )}
            <span>
              <i className="ShipWeapons__shot-swatch" aria-hidden="true" />
              Снаряд
            </span>
          </div>
        </section>

        <aside
          className="ShipWeapons__instruments"
          aria-label="Орудия и контакты"
        >
          <section
            className="SpaceNavigation__contacts ShipWeapons__mounts"
            aria-labelledby="gunnery-mounts-label"
          >
            <div
              className="SpaceNavigation__screen-label"
              id="gunnery-mounts-label"
            >
              ОРУДИЯ
            </div>
            <div className="SpaceNavigation__routes">
              {data.weapons.map((weapon) => (
                <div className="ShipWeapons__mount" key={weapon.id}>
                  <Button
                    selected={weapon.id === mount?.id}
                    aria-pressed={weapon.id === mount?.id}
                    onClick={() => selectMount(weapon.id)}
                    tooltip={weapon.name}
                  >
                    <span>{weapon.name}</span>
                  </Button>
                  <div className="ShipWeapons__mount-reading">
                    <span data-state={weapon.status}>
                      {statusLabels[weapon.status]}
                    </span>
                    <span className="ShipWeapons__ammo">
                      Снаряды{' '}
                      <b>
                        {weapon.shells}/{weapon.capacity}
                      </b>
                    </span>
                  </div>
                  {weapon.loader && (
                    <div className="ShipWeapons__mount-reading">
                      <span data-state={weapon.loader.online ? 'ready' : 'off'}>
                        {weapon.loader.online
                          ? 'Лоток на борту'
                          : 'Подача отключена'}
                      </span>
                      <span className="ShipWeapons__ammo">
                        <b>
                          {weapon.loader.shells}/{weapon.loader.capacity}
                        </b>
                      </span>
                    </div>
                  )}
                  <div className="ShipWeapons__reload">
                    {weapon.status === 'reload' && (
                      <>
                        <progress
                          max={weapon.reload_duration}
                          value={weapon.reload_duration - weapon.reload}
                          aria-label={`Перезарядка · ${weapon.name}`}
                        />
                        <span>{weapon.reload.toFixed(1)} с</span>
                      </>
                    )}
                  </div>
                </div>
              ))}
              {!data.weapons.length && (
                <p className="SpaceNavigation__help">
                  Корабельные орудия отсутствуют
                </p>
              )}
            </div>
          </section>

          <section
            className="SpaceNavigation__contacts"
            aria-labelledby="gunnery-contacts-label"
          >
            <div
              className="SpaceNavigation__screen-label"
              id="gunnery-contacts-label"
            >
              КОНТАКТЫ
            </div>
            <div className="SpaceNavigation__routes">
              {data.ship_contacts.map((record) => {
                const label = `К${record.id} · ${contactName(record)}`;
                return (
                  <Button
                    key={record.id}
                    selected={record.id === focusedContact}
                    aria-pressed={record.id === focusedContact}
                    tooltip={label}
                    onClick={() => setFocusedContact(record.id)}
                    onMouseEnter={() =>
                      setHoveredTarget(`contact:${record.id}`)
                    }
                    onMouseLeave={() => setHoveredTarget(null)}
                  >
                    <span>{label}</span>
                    <span>{contactDistance(data, record)}</span>
                  </Button>
                );
              })}
              {!data.ship_contacts.length && (
                <p className="SpaceNavigation__help">
                  {data.scan_ready
                    ? 'Нет отметок. Запустите сонар.'
                    : 'Нет отметок. Сонар недоступен.'}
                </p>
              )}
            </div>
          </section>
        </aside>
      </div>

      <div className="SpaceNavigation__telemetry ShipWeapons__command">
        <div className="SpaceNavigation__mode-screen ShipWeapons__solution">
          <div className="ShipWeapons__target">
            <span>ТОЧКА ПРИЦЕЛИВАНИЯ</span>
            <strong title={pointLabel}>{pointLabel}</strong>
          </div>
          {aimPoint && (
            <div className="ShipWeapons__distance">
              <span>ДАЛЬНОСТЬ</span>
              <strong>{contactDistance(data, aimPoint)}</strong>
            </div>
          )}
          <p
            className="ShipWeapons__fire-status"
            id="gunnery-fire-status"
            data-ready={!blocker}
            role="status"
          >
            {blocker || 'Наведение готово'}
          </p>
        </div>
        <Button
          className="SpaceNavigation__scan"
          selected={data.scan_age !== null && data.scan_age < 1.5}
          disabled={!data.scan_ready}
          tooltip="Сканировать сектор"
          aria-label="Сканировать сектор"
          onClick={() => act('scan')}
        >
          <Icon name="satellite-dish" />
          <span className="SpaceNavigation__key-label">СОНАР</span>
          <span
            aria-hidden="true"
            className={`SpaceNavigation__lamp ${data.scan_ready ? 'ready' : ''}`}
          />
        </Button>
        <Button
          className="ShipWeapons__fire-key"
          disabled={!!blocker}
          aria-label="Огонь"
          aria-describedby="gunnery-fire-status"
          onClick={() => {
            if (mount && aimPoint) {
              act('fire', { weapon: mount.id, x: aimPoint.x, y: aimPoint.y });
            }
          }}
        >
          <Icon name="crosshairs" />
          <span className="SpaceNavigation__key-label">ОГОНЬ</span>
          <span
            aria-hidden="true"
            className={`SpaceNavigation__lamp ${!blocker ? 'ready' : ''}`}
          />
        </Button>
      </div>
    </main>
  );
}

function firingBlocker(
  data: Data,
  mount: Weapon | undefined,
  aimPoint: Position | null,
  aimProblem: string,
) {
  if (!data.can_control) return 'Управление недоступно';
  if (!mount) return 'Корабельные орудия отсутствуют';
  if (!aimPoint) return 'Укажите точку на карте в секторе орудия';
  if (mount.status !== 'ready') return statusLabels[mount.status];
  if (!data.power_ready) return 'Не хватает питания на выстрел';
  return aimProblem;
}

function pointProblem(origin: Position, sector: FiringSector, aim: Position) {
  const dx = aim.x - origin.x;
  const dy = aim.y - origin.y;
  const distance = Math.hypot(dx, dy);
  if (distance > sector.range) return 'Точка за пределом дальности';
  if (distance <= sector.min_range) return 'Точка слишком близко к корпусу';
  const bearing = (Math.atan2(dx, dy) * 180) / Math.PI;
  const offAxis = Math.abs(((bearing - sector.heading + 540) % 360) - 180);
  if (offAxis > sector.arc) return 'Точка вне сектора обстрела';
  return '';
}

function contactName(contact: Contact) {
  return contact.identity?.callsign || 'Неопознанное судно';
}

function contactDistance(chart: ChartData, contact: Position) {
  return distanceLabel(
    Math.hypot(contact.x - chart.x, contact.y - chart.y),
    chart.au_scale,
  );
}
