import {
  PlanetGlyph,
  RuinGlyph,
  ShipGlyph,
  StationGlyph,
  ZoneArt,
} from './DisplayArt';
import {
  closestApproach,
  distanceLabel,
  type NavigationData,
  speedLabel,
} from './types';

type Props = {
  data: NavigationData;
  focusedContact: number | null;
};

/** Compass bearing from the hull to a point, clockwise from north. */
function bearing(data: NavigationData, x: number, y: number) {
  const angle = (Math.atan2(x - data.x, y - data.y) * 180) / Math.PI;
  return `${Math.round((angle + 360) % 360)}°`;
}

/** Sensor readout of the selected target: what it reads as, where it lies and how it moves. */
export function Scanner({ data, focusedContact }: Props) {
  const distance = (value: number) => distanceLabel(value, data.au_scale);
  const contact =
    focusedContact !== null
      ? data.ship_contacts.find((record) => record.id === focusedContact)
      : undefined;
  const site =
    focusedContact === null
      ? data.routes.find((route) => route.id === data.selected)
      : undefined;
  const rows: [string, string][] = [];
  if (contact) {
    const approach = closestApproach(data, contact);
    rows.push(
      ['ДИСТ', distance(Math.hypot(contact.x - data.x, contact.y - data.y))],
      ['ПЕЛ', bearing(data, contact.x, contact.y)],
    );
    if (contact.vx !== undefined && contact.vy !== undefined)
      rows.push(
        ['СКОР', speedLabel(Math.hypot(contact.vx, contact.vy), data.au_scale)],
        [
          'ОТН',
          speedLabel(
            Math.hypot(contact.vx - data.vx, contact.vy - data.vy),
            data.au_scale,
          ),
        ],
      );
    if (approach)
      rows.push([
        contact.age >= 20 ? 'CPA*' : 'CPA',
        approach.time > 0
          ? `${distance(approach.distance)} / ${Math.round(approach.time)} с`
          : 'Расходимся',
      ]);
    rows.push(
      [
        'КАНАЛ',
        contact.mode === 'signal'
          ? 'СВЯЗЬ'
          : contact.mode === 'passive'
            ? 'ПАСС'
            : 'АКТ',
      ],
      ['ДАВН', `${Math.round(contact.age)} с`],
    );
  } else if (site) {
    rows.push(
      ['ДИСТ', distance(site.distance)],
      ['ПЕЛ', bearing(data, site.x, site.y)],
    );
    if (site.kind === 'planet' && data.planet) {
      rows.push(
        ['АТМ', data.planet.atmosphere],
        ['ТЕМП', `${Math.round(data.planet.temperature - 273.15)} °C`],
        ['СРЕДА', data.planet.breathable ? 'Пригодна' : 'EVA'],
      );
      if (data.planet.modifiers.length)
        rows.push(['ОСОБ', data.planet.modifiers.join(', ')]);
    }
    if (site.failed) rows.push(['СИГНАЛ', 'Потерян']);
  }
  if (!rows.length) {
    return <p className="SpaceNavigation__help">Выберите цель</p>;
  }
  return (
    <div className="SpaceNavigation__routes SpaceNavigation__scanner">
      <figure className="SpaceNavigation__scanner-preview">
        <svg
          viewBox="0 0 200 132"
          role="img"
          aria-label={
            contact
              ? 'Схематичное изображение корабля'
              : site?.kind === 'planet'
                ? 'Схематичное изображение планеты'
                : 'Схематичное изображение объекта'
          }
        >
          <path
            d="M12 18v-8h12M176 10h12v8M188 110v8h-12M24 118H12v-8M100 8v116M8 66h184"
            fill="none"
            stroke="#527e6e"
            strokeWidth=".5"
            strokeDasharray="2 3"
          />
          <g transform="translate(100 66)" style={{ color: '#b8d8b8' }}>
            {contact ? (
              <g transform="scale(3)">
                <ShipGlyph />
              </g>
            ) : site?.kind === 'planet' ? (
              <PlanetGlyph
                radius={46}
                kind={
                  data.celestial_bodies?.find(
                    (body) => Math.hypot(body.x - site.x, body.y - site.y) < 1,
                  )?.kind || 'barren'
                }
              />
            ) : site?.kind === 'station' ? (
              <g transform="scale(2.8)">
                <StationGlyph />
              </g>
            ) : site?.type === 'Астероиды' ? (
              <ZoneArt kind="asteroids" radius={48} />
            ) : (
              <g transform="scale(1.25)">
                <RuinGlyph />
              </g>
            )}
          </g>
        </svg>
        <figcaption>
          <strong>
            {contact
              ? `К${contact.id} / ${contact.identity?.callsign || 'НЕТ ОТВЕТА'}`
              : site?.kind === 'signal' && !site.sos
                ? site.type
                : site?.name}
          </strong>
          {contact?.identity && <small>{contact.identity.faction}</small>}
        </figcaption>
      </figure>
      <div role="list">
        {rows.map(([label, value]) => (
          <div
            key={label}
            role="listitem"
            className="SpaceNavigation__compartment"
            title={
              label === 'CPA*'
                ? 'Устаревшая отметка: прогноз сближения неточен'
                : value
            }
          >
            <span>{label}</span>
            <span>{value}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
