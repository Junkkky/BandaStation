import { type Compartment, compartmentDamaged } from './types';

/** Hull compartments, damaged first; the server reads the state from the physical hull. */
export function Compartments({ rooms }: { rooms: Compartment[] }) {
  const sorted = [...rooms].sort(
    (a, b) => Number(compartmentDamaged(b)) - Number(compartmentDamaged(a)),
  );
  return (
    <div className="SpaceNavigation__routes" role="list">
      {sorted.map((room) => (
        <div
          key={room.name}
          role="listitem"
          title={room.name}
          className={`SpaceNavigation__compartment ${compartmentDamaged(room) ? 'damaged' : ''}`}
        >
          <span>{room.name}</span>
          <span>{describe(room)}</span>
        </div>
      ))}
      {!rooms.length && <p className="SpaceNavigation__help">Нет данных</p>}
    </div>
  );
}

function describe(room: Compartment) {
  const parts: string[] = [];
  if (room.breaches) parts.push(`пробоина ×${room.breaches}`);
  if (room.fire) parts.push('пожар');
  parts.push(room.pressure === null ? 'без настила' : `${room.pressure} кПа`);
  return parts.join(' · ');
}
