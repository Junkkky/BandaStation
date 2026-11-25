import { useState } from 'react';
import { Button } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { Chart } from './SpaceNavigation/Chart';
import { ZoomKnob } from './SpaceNavigation/DisplayArt';
import { type ChartData, distanceLabel } from './SpaceNavigation/types';

const zoomLevels = [1, 2, 4, 8] as const;

const sections = {
  bow: 'Нос',
  midship: 'Середина',
  stern: 'Корма',
} as const;

const results = {
  flying: 'Полёт',
  inside: 'Внутри корпуса',
  rim: 'На кромке корпуса',
  rescue: 'Аварийный маяк активен',
  returned: 'Возвращена',
  lost: 'Капсула потеряна',
} as const;

type HullSection = keyof typeof sections;

type Launcher = {
  id: string;
  number: number;
  iron: number;
  operational: BooleanLike;
  can_assemble: BooleanLike;
  has_pod: BooleanLike;
  open: BooleanLike;
  loaded: BooleanLike;
  passengers: number;
};

type Flight = {
  id: string;
  name: string;
  target: string;
  section: HullSection;
  result: keyof typeof results;
  eta: number;
};

type Data = ChartData & {
  launch_ready: BooleanLike;
  launch_range: number;
  scan_ready: BooleanLike;
  iron_cost: number;
  launchers: Launcher[];
  flights: Flight[];
};

export function ShipDropPods() {
  const { data } = useBackend<Data>();
  return (
    <Window width={960} height={650}>
      <Window.Content>
        {data.sector ? (
          <DropControl key={data.sector} data={data} />
        ) : (
          <main className="SpaceNavigation ShipWeapons--offline">
            <p className="SpaceNavigation__help" role="status">
              Нет связи с кораблём
            </p>
          </main>
        )}
      </Window.Content>
    </Window>
  );
}

function DropControl({ data }: { data: Data }) {
  const { act } = useBackend();
  const [contactId, selectContact] = useState<number | null>(null);
  const [launcherId, selectLauncher] = useState<string | null>(null);
  const [section, selectSection] = useState<HullSection | null>(null);
  const [zoom, setZoom] = useState(4);

  const launchers = [...data.launchers].sort((a, b) => a.number - b.number);
  const launcher =
    launchers.find((entry) => entry.id === launcherId) ?? launchers[0];
  const contact = data.ship_contacts.find((entry) => entry.id === contactId);
  const distance = contact
    ? Math.hypot(data.x - contact.x, data.y - contact.y)
    : null;
  const contactName =
    contact?.identity?.callsign ||
    (contact ? `Контакт ${contact.id}` : 'Цель не выбрана');
  const blocker = !data.launch_ready
    ? 'Пуск доступен в свободном полёте'
    : !launcher
      ? 'На борту нет пусковых установок'
      : !launcher.operational
        ? 'Установка недоступна'
        : !launcher.has_pod
          ? 'Соберите капсулу на установке'
          : launcher.open
            ? 'Закройте люк капсулы'
            : !launcher.loaded
              ? 'Загрузите капсулу'
              : !contact
                ? 'Выберите корабль на карте'
                : distance !== null && distance > data.launch_range
                  ? 'Цель вне дальности пуска'
                  : !section
                    ? 'Выберите секцию корпуса'
                    : '';

  return (
    <main className="SpaceNavigation ShipWeapons ShipDropPods">
      <header>
        <div className="SpaceNavigation__nameplate">
          <strong>{data.vessel_name}</strong>
          <span>ДЕСАНТНЫЙ ПОСТ</span>
        </div>
        <ZoomKnob zoom={zoom} onChange={setZoom} levels={zoomLevels} />
      </header>
      <div className="ShipWeapons__body">
        <section className="SpaceNavigation__plot" aria-label="Карта сектора">
          <div className="SpaceNavigation__screen-label">КАРТА СЕКТОРА</div>
          <Chart
            data={data}
            zoom={zoom}
            focusedContact={contactId}
            hoveredTarget={null}
            onContact={selectContact}
          />
          <div className="SpaceNavigation__legend ShipDropPods__plot-footer">
            <span>
              Дальность пуска ·{' '}
              {distanceLabel(data.launch_range, data.au_scale)}
            </span>
            <Button
              icon="satellite-dish"
              disabled={!data.scan_ready}
              onClick={() => act('scan')}
            >
              Сканировать
            </Button>
          </div>
        </section>
        <aside
          className="SpaceNavigation__contacts ShipDropPods__panel"
          aria-label="Управление высадкой"
        >
          <div className="SpaceNavigation__screen-label">ВЫСАДКА</div>
          <div className="ShipDropPods__controls">
            <div className="ShipDropPods__target">
              <strong>{contactName}</strong>
              {distance !== null && (
                <span>{distanceLabel(distance, data.au_scale)}</span>
              )}
            </div>
            <div
              className="ShipDropPods__sections"
              role="group"
              aria-label="Секция корпуса"
            >
              {(Object.keys(sections) as HullSection[]).map((value) => (
                <Button
                  key={value}
                  selected={section === value}
                  aria-pressed={section === value}
                  onClick={() => selectSection(value)}
                >
                  {sections[value]}
                </Button>
              ))}
            </div>
            <p className="SpaceNavigation__help">
              Щит при подлёте направит капсулу на кромку выбранной секции.
            </p>
            {!!launchers.length && (
              <div
                className="ShipDropPods__rack"
                role="group"
                aria-label="Пусковые установки"
              >
                {launchers.map((entry) => (
                  <Button
                    key={entry.id}
                    selected={entry.id === launcher?.id}
                    aria-pressed={entry.id === launcher?.id}
                    onClick={() => selectLauncher(entry.id)}
                  >
                    <strong>Установка №{entry.number}</strong>
                    <span>{launcherStatus(entry, data.iron_cost)}</span>
                  </Button>
                ))}
              </div>
            )}
            {launcher && !launcher.has_pod && (
              <div className="ShipDropPods__fabrication">
                <small>
                  {launcher.iron < data.iron_cost
                    ? 'Загрузите листы железа в установку'
                    : launcher.operational && !launcher.can_assemble
                      ? 'Освободите площадку'
                      : null}
                </small>
                <Button
                  icon="wrench"
                  disabled={!launcher.can_assemble}
                  onClick={() => act('assemble', { launcher: launcher.id })}
                >
                  Собрать капсулу
                </Button>
              </div>
            )}
            {!!data.flights.length && (
              <ul className="ShipDropPods__flights" aria-label="Журнал высадки">
                {data.flights.map((flight) => (
                  <li key={flight.id}>
                    <strong>{flight.name}</strong>
                    <span>
                      {flight.target} · {sections[flight.section]}
                    </span>
                    <span className="ShipDropPods__result">
                      {results[flight.result]}
                      {flight.result === 'flying' &&
                        ` · ${Math.ceil(flight.eta)} с`}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </div>
          <footer className="ShipDropPods__launch">
            <div role="status">{blocker || 'Готово к пуску'}</div>
            <Button
              className="ShipDropPods__fire"
              icon="rocket"
              disabled={!!blocker}
              onClick={() => {
                if (!blocker && launcher && contact && section) {
                  act('launch', {
                    launcher: launcher.id,
                    contact: contact.id,
                    section,
                  });
                }
              }}
            >
              Запустить капсулу
            </Button>
          </footer>
        </aside>
      </div>
    </main>
  );
}

function launcherStatus(launcher: Launcher, ironCost: number) {
  if (!launcher.operational) {
    return 'Недоступна';
  }
  if (!launcher.has_pod) {
    return `Железо ${launcher.iron}/${ironCost}`;
  }
  if (launcher.open) {
    return 'Люк открыт';
  }
  if (launcher.passengers) {
    return `Экипаж ${launcher.passengers}/2`;
  }
  return launcher.loaded ? 'Груз загружен' : 'Капсула пуста';
}
