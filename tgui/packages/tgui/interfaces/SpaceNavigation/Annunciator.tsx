import { compartmentDamaged, fuelLow, type NavigationData } from './types';

type Lamp = {
  label: string;
  title: string;
  tone: 'good' | 'warn' | 'bad';
  lit: boolean;
};

/** Fixed row of warning lamps: each keeps its place and label, only its light changes. */
export function Annunciator({ data }: { data: NavigationData }) {
  const lamps: Lamp[] = [
    {
      label: 'ДВИГ',
      title: 'Двигатели работают',
      tone: 'good',
      lit: !!data.engines_running && !data.engine_fault,
    },
    {
      label: 'ФОРСАЖ',
      title: 'Форсаж термоядерного ядра',
      tone: 'warn',
      lit: !!data.core_overdrive,
    },
    {
      label: 'ПЕРЕГР',
      title: 'Перегрев термоядерного ядра',
      tone: 'bad',
      lit: (data.core_heat ?? 0) >= 75,
    },
    {
      label: 'НЕИСПР',
      title: 'Неисправность двигательной установки',
      tone: 'bad',
      lit: !!data.engine_fault,
    },
    {
      label: 'ТОПЛ',
      title: 'Мало топлива или канистры не подключены',
      tone: 'bad',
      lit: !!data.fuel?.some(fuelLow),
    },
    {
      label: 'ТОРМ',
      title: 'Торможение',
      tone: 'warn',
      lit: !!data.braking,
    },
    {
      label: 'ДРЕЙФ',
      title: 'Движение без тяги',
      tone: 'warn',
      lit: data.speed > 0.05 && (!data.engines_running || data.engines <= 0),
    },
    {
      label: 'АВАР',
      title: 'Аварийное торможение маневровыми двигателями',
      tone: 'bad',
      lit: !!data.emergency_braking,
    },
    {
      label: 'АВТО',
      title: 'Автопилот',
      tone: 'good',
      lit: !!data.autopilot,
    },
    {
      label: 'ПРЫЖОК',
      title: 'Блюспейс-прыжок',
      tone: 'warn',
      lit: !!data.jumping,
    },
    {
      label: 'ЗАПРОС',
      title: 'Входящий запрос стыковки',
      tone: 'warn',
      lit: !!data.docking_request,
    },
    {
      label: 'ОТСЕК',
      title: 'Повреждены отсеки',
      tone: 'bad',
      lit: data.compartments.some(compartmentDamaged),
    },
  ];
  return (
    <ul className="SpaceNavigation__annunciator" aria-label="Сигнальные лампы">
      {lamps.map((lamp) => (
        <li
          key={lamp.label}
          className={lamp.lit ? `lit ${lamp.tone}` : undefined}
          title={lamp.title}
          aria-label={`${lamp.title}: ${lamp.lit ? 'горит' : 'не горит'}`}
        >
          {lamp.label}
        </li>
      ))}
    </ul>
  );
}
