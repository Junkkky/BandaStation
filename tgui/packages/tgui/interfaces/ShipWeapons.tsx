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
const buttonRole = { role: 'button' };
const presets = [
  { id: 'all', label: 'Вся батарея' },
  { id: 'kinetic', label: 'Кинетика' },
  { id: 'energy', label: 'Энергия' },
] as const;
type Preset = (typeof presets)[number]['id'];

const statusLabels = {
  ready: 'Готово',
  firing: 'Ведёт огонь',
  charging: 'Накопитель заряжается',
  reload: 'Перезарядка',
  empty: 'Нет боеприпасов',
  low_power: 'Не хватает питания на выстрел',
  fault: 'Неисправно',
  moored: 'Вне свободного полёта',
  obstructed: 'Дуло перекрыто',
};

type Weapon = FiringSector & {
  id: string;
  family: Exclude<Preset, 'all'>;
  name: string;
  ammo_name: string | null;
  shells: number;
  capacity: number;
  energy_per_shot: number;
  capacitor_charge: number | null;
  capacitor_capacity: number;
  loader?: { shells: number; capacity: number; online: BooleanLike } | null;
  status: keyof typeof statusLabels;
  reload: number;
  reload_duration: number;
};

type Data = ChartData & {
  weapons: Weapon[];
  muzzle_flashes?: MuzzleFlash[];
  can_control: BooleanLike;
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
  const [selection, setSelection] = useState<Preset | string[]>('all');
  const [focusedContact, setFocusedContact] = useState<number | null>(null);
  const [aimPoint, setAimPoint] = useState<Position | null>(null);
  const [hoveredTarget, setHoveredTarget] = useState<string | null>(null);
  const [zoom, setZoom] = useState(4);
  const mounts = data.weapons.map((weapon) => ({
    weapon,
    selected: Array.isArray(selection)
      ? selection.includes(weapon.id)
      : selection === 'all' || selection === weapon.family,
    problem: aimPoint ? pointProblem(data, weapon, aimPoint) : '',
  }));
  const selected = mounts.filter((mount) => mount.selected);
  const selectedIds = selected.map(({ weapon }) => weapon.id);
  const inSector = selected.filter((mount) => !mount.problem);
  const readyCount = aimPoint
    ? inSector.filter(({ weapon }) => weapon.status === 'ready').length
    : 0;
  const canFire = !!data.can_control && readyCount > 0;
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
            firingSectors={selected.map(({ weapon }) => weapon)}
            muzzleFlashes={data.muzzle_flashes}
            aimPoint={aimPoint}
            aimValid={!!inSector.length}
            onAim={data.weapons.length ? setAimPoint : undefined}
            onContact={setFocusedContact}
          />
          <div className="SpaceNavigation__legend ShipWeapons__legend">
            {!!selected.length && (
              <span>
                <i className="ShipWeapons__sector-swatch" aria-hidden="true" />
                Секторы · до{' '}
                {distanceLabel(
                  Math.max(...selected.map(({ weapon }) => weapon.range)),
                  data.au_scale,
                )}
              </span>
            )}
            <span>
              <i className="ShipWeapons__shot-swatch" aria-hidden="true" />
              Трасса выстрела
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
              ОРУДИЙНАЯ БАТАРЕЯ
              <span>
                Выбрано {selected.length} из {mounts.length}
              </span>
            </div>
            <div className="SpaceNavigation__tabs ShipWeapons__presets">
              {presets.map(({ id, label }) => (
                <Button
                  key={id}
                  {...buttonRole}
                  selected={selection === id}
                  aria-pressed={selection === id}
                  disabled={
                    !mounts.some(
                      ({ weapon }) => id === 'all' || weapon.family === id,
                    )
                  }
                  onClick={() => setSelection(id)}
                >
                  {label}
                </Button>
              ))}
            </div>
            <div className="ShipWeapons__mount-list">
              {mounts.map(({ weapon, selected, problem }) => (
                <WeaponRow
                  key={weapon.id}
                  weapon={weapon}
                  selected={selected}
                  problem={problem}
                  onSolo={() => setSelection([weapon.id])}
                  onToggle={() =>
                    setSelection(
                      selected
                        ? selectedIds.filter((id) => id !== weapon.id)
                        : [...selectedIds, weapon.id],
                    )
                  }
                />
              ))}
              {!data.weapons.length && (
                <p className="SpaceNavigation__help">
                  Корабельные орудия отсутствуют
                </p>
              )}
            </div>
          </section>

          <section
            className="SpaceNavigation__contacts ShipWeapons__contacts"
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
                    {...buttonRole}
                    selected={record.id === focusedContact}
                    aria-pressed={record.id === focusedContact}
                    onClick={() => {
                      setFocusedContact(record.id);
                      setAimPoint({ x: record.x, y: record.y });
                    }}
                    onMouseEnter={() =>
                      setHoveredTarget(`contact:${record.id}`)
                    }
                    onMouseLeave={() => setHoveredTarget(null)}
                  >
                    <span title={label}>{label}</span>
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
            data-ready={canFire}
            role="status"
          >
            {firingStatus(data, selected.length, aimPoint, readyCount)}
          </p>
        </div>
        <Button
          className="SpaceNavigation__scan"
          selected={data.scan_age !== null && data.scan_age < 1.5}
          disabled={!data.scan_ready}
          {...buttonRole}
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
          disabled={!canFire}
          {...buttonRole}
          aria-label={`Дать залп · ${readyCount}`}
          aria-disabled={!canFire}
          aria-describedby="gunnery-fire-status"
          onClick={(event) => {
            if (canFire && aimPoint && !event.repeat) {
              act('fire', {
                weapons: selectedIds,
                x: aimPoint.x,
                y: aimPoint.y,
              });
            }
          }}
        >
          <Icon name="crosshairs" />
          <span className="SpaceNavigation__key-label">ЗАЛП ×{readyCount}</span>
          <span
            aria-hidden="true"
            className={`SpaceNavigation__lamp ${canFire ? 'ready' : ''}`}
          />
        </Button>
      </div>
    </main>
  );
}

function WeaponRow({
  weapon,
  selected,
  problem,
  onToggle,
  onSolo,
}: {
  weapon: Weapon;
  selected: boolean;
  problem: string;
  onToggle: () => void;
  onSolo: () => void;
}) {
  const { status, loader } = weapon;
  return (
    <div className="ShipWeapons__mount">
      <Button
        className="ShipWeapons__toggle"
        {...buttonRole}
        aria-pressed={selected}
        selected={selected}
        onClick={onToggle}
      >
        <strong className="ShipWeapons__mount-name">
          <Icon name={selected ? 'square-check' : 'square-o'} />
          {weapon.name}
        </strong>
        <span className="ShipWeapons__mount-reading">
          <span data-ready={status === 'ready' && !problem}>
            {(status === 'ready' && problem) || statusLabels[status]}
            {status === 'reload' && ` · ${weapon.reload.toFixed(1)} с`}
          </span>
          {weapon.ammo_name && (
            <span title={weapon.ammo_name}>
              БК {weapon.shells}/{weapon.capacity}
            </span>
          )}
          {weapon.capacitor_charge !== null && (
            <span title="Заряд накопителя">
              <Icon name="bolt" />{' '}
              {Math.floor(weapon.capacitor_charge / 100) / 10}/
              {weapon.capacitor_capacity / 1000} кДж
            </span>
          )}
        </span>
        <small className="ShipWeapons__specs">
          {loader && (
            <span>
              {loader.online ? 'Лоток' : 'Лоток откл.'} {loader.shells}/
              {loader.capacity}
            </span>
          )}
          <span>{weapon.energy_per_shot / 1000} кДж/выстр.</span>
          <span>Цикл {weapon.reload_duration} с</span>
        </small>
      </Button>
      <Button
        className="ShipWeapons__solo"
        {...buttonRole}
        aria-label={`Выбрать только это орудие · ${weapon.name}`}
        onClick={onSolo}
      >
        Только
      </Button>
    </div>
  );
}

function firingStatus(
  data: Data,
  selectedCount: number,
  aimPoint: Position | null,
  readyCount: number,
) {
  if (!data.can_control) return 'Управление недоступно';
  if (!data.weapons.length) return 'Корабельные орудия отсутствуют';
  if (!selectedCount) return 'Выберите орудия для залпа';
  if (!aimPoint) return 'Укажите точку на карте или выберите контакт';
  return `Готовность к залпу · ${readyCount} из ${selectedCount}`;
}

function pointProblem(origin: Position, sector: FiringSector, aim: Position) {
  const dx = aim.x - origin.x;
  const dy = aim.y - origin.y;
  const distance = Math.hypot(dx, dy);
  if (distance > sector.range) return 'Вне дальности';
  if (distance <= sector.min_range) return 'Слишком близко';
  const bearing = (Math.atan2(dx, dy) * 180) / Math.PI;
  const offAxis = Math.abs(((bearing - sector.heading + 540) % 360) - 180);
  if (offAxis > sector.arc) return 'Вне сектора';
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
