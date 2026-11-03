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
      ['Отметка', `К${contact.id}`],
      [
        'Опознание',
        contact.identity
          ? `${contact.identity.callsign} · ${contact.identity.faction}`
          : 'Нет ответа',
      ],
      [
        'Дистанция',
        distance(Math.hypot(contact.x - data.x, contact.y - data.y)),
      ],
      ['Пеленг', bearing(data, contact.x, contact.y)],
    );
    if (contact.vx !== undefined && contact.vy !== undefined) {
      rows.push([
        'Отн. скорость',
        speedLabel(
          Math.hypot(contact.vx - data.vx, contact.vy - data.vy),
          data.au_scale,
        ),
      ]);
    }
    if (approach) {
      rows.push([
        'Сближение',
        approach.time > 0
          ? `${distance(approach.distance)} через ${Math.round(approach.time)} с`
          : 'Расходимся',
      ]);
    }
    rows.push(['Отметка получена', `${Math.round(contact.age)} с назад`]);
  } else if (site) {
    rows.push(
      ['Тип', site.type],
      ['Дистанция', distance(site.distance)],
      ['Пеленг', bearing(data, site.x, site.y)],
    );
    if (site.failed) {
      rows.push(['Сигнал', 'Потерян']);
    }
  }
  if (!rows.length) {
    return <p className="SpaceNavigation__help">Выберите цель</p>;
  }
  return (
    <div className="SpaceNavigation__routes" role="list">
      {rows.map(([label, value]) => (
        <div
          key={label}
          role="listitem"
          className="SpaceNavigation__compartment"
        >
          <span>{label}</span>
          <span>{value}</span>
        </div>
      ))}
    </div>
  );
}
