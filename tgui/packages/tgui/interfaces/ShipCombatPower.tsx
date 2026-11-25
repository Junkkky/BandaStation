import { useState } from 'react';
import { Button, Icon, ProgressBar } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

const circuits = [
  { id: 'shields', name: 'Щиты', icon: 'shield-alt' },
  { id: 'engines', name: 'Двигатели', icon: 'rocket' },
  { id: 'weapons', name: 'Орудия', icon: 'crosshairs' },
] as const;

type Circuit = (typeof circuits)[number]['id'];
type Shares = Record<Circuit, number>;

const presets: { name: string; shares: Shares }[] = [
  { name: 'Баланс', shares: { shields: 30, engines: 40, weapons: 30 } },
  { name: 'Щиты', shares: { shields: 65, engines: 20, weapons: 15 } },
  { name: 'Двигатели', shares: { shields: 15, engines: 70, weapons: 15 } },
  { name: 'Орудия', shares: { shields: 15, engines: 20, weapons: 65 } },
];

type Telemetry = {
  missing?: BooleanLike;
  vessel?: string;
  online: BooleanLike;
  revision: number;
  shares: Shares;
  watts: Shares;
  available_watts: number;
  max_watts: number;
  thrust_limit: number;
  shield_present: BooleanLike;
  shield_working: BooleanLike;
  shield_enabled: BooleanLike;
  shield_raised: BooleanLike;
  shield_charge: number;
  shield_capacity: number;
  shield_sustained: BooleanLike;
  shield_recovery: number;
  gun_charge: number;
  gun_capacity: number;
};

export function ShipCombatPower() {
  const { data } = useBackend<Telemetry>();
  return (
    <Window width={705} height={465}>
      <Window.Content scrollable>
        {data.missing || !data.shares ? (
          <main className="SpaceNavigation ShipCombatPower">
            <p className="SpaceNavigation__help" role="status">
              Распределитель боевого питания недоступен
            </p>
          </main>
        ) : (
          <CombatPower data={data} />
        )}
      </Window.Content>
    </Window>
  );
}

function CombatPower({ data }: { data: Telemetry }) {
  const { act } = useBackend();
  const [draft, setDraft] = useState<{
    shares: Shares;
    revision: number;
  } | null>(null);
  const shares = draft?.revision === data.revision ? draft.shares : data.shares;
  const total = shares.shields + shares.engines + shares.weapons;
  const changed = circuits.some(({ id }) => shares[id] !== data.shares[id]);

  function allocate(next: Shares) {
    act('allocate', { ...next, revision: data.revision });
  }

  return (
    <main className="SpaceNavigation ShipCombatPower">
      <header>
        <div className="SpaceNavigation__nameplate">
          <strong>{data.vessel || 'Боевое питание'}</strong>
          <span>РАСПРЕДЕЛИТЕЛЬ БОЕВОГО ПИТАНИЯ</span>
        </div>
        <div className="ShipCombatPower__input">
          <span>{data.online ? 'ДОСТУПНО' : 'НЕТ ПОДАЧИ'}</span>
          <strong>{kilo(data.available_watts, 'кВт')}</strong>
          <span>Лимит {kilo(data.max_watts, 'кВт')}</span>
        </div>
      </header>

      <section
        className="SpaceNavigation__contacts ShipCombatPower__panel"
        aria-label="Распределение мощности"
      >
        <div className="SpaceNavigation__screen-label">
          <span>КОНТУРЫ</span>
          <span>ДОЛЯ / ПОТРЕБЛЕНИЕ</span>
        </div>
        <div className="ShipCombatPower__circuits">
          {circuits.map(({ id, name, icon }) => (
            <div className="ShipCombatPower__circuit" key={id}>
              <div className="ShipCombatPower__circuit-label">
                <Icon name={icon} /> {name}
              </div>
              <label className="ShipCombatPower__share">
                <input
                  type="range"
                  aria-label={`Доля мощности · ${name}`}
                  value={shares[id]}
                  aria-valuetext={`${shares[id]}%`}
                  min={0}
                  max={100}
                  step={1}
                  onChange={({ currentTarget }) =>
                    setDraft({
                      shares: { ...shares, [id]: currentTarget.valueAsNumber },
                      revision: data.revision,
                    })
                  }
                />
                <span aria-hidden="true">{shares[id]}%</span>
              </label>
              <span className="ShipCombatPower__watts">
                {kilo(data.watts[id], 'кВт')}
              </span>
            </div>
          ))}
          <div className="ShipCombatPower__actions">
            <span role="status" data-invalid={total !== 100}>
              {total === 100
                ? 'Распределено 100%'
                : `Сумма долей ${total}% · требуется 100%`}
            </span>
            <Button
              icon="check"
              disabled={total !== 100 || !changed}
              onClick={() => allocate(shares)}
            >
              Применить
            </Button>
          </div>
          <div className="ShipCombatPower__presets" aria-label="Режимы питания">
            {presets.map((preset) => (
              <Button
                key={preset.name}
                selected={circuits.every(
                  ({ id }) => data.shares[id] === preset.shares[id],
                )}
                onClick={() => allocate(preset.shares)}
              >
                {preset.name}
              </Button>
            ))}
          </div>
        </div>
      </section>

      <div className="ShipCombatPower__readouts">
        <section
          className="SpaceNavigation__contacts ShipCombatPower__panel"
          aria-label="Щит"
        >
          <div className="SpaceNavigation__screen-label">
            <span>ЩИТ</span>
            <span data-raised={!!data.shield_raised}>{shieldStatus(data)}</span>
          </div>
          <div className="ShipCombatPower__readout">
            <ProgressBar
              value={data.shield_charge}
              maxValue={data.shield_capacity}
              color="teal"
            >
              {kilo(data.shield_charge, 'кДж')} /{' '}
              {kilo(data.shield_capacity, 'кДж')}
            </ProgressBar>
            <Button
              icon="power-off"
              disabled={!data.shield_working}
              onClick={() => act('toggle_shield')}
            >
              {data.shield_enabled ? 'Опустить щит' : 'Поднять щит'}
            </Button>
          </div>
        </section>
        <section
          className="SpaceNavigation__contacts ShipCombatPower__panel"
          aria-label="Тяга и накопители"
        >
          <div className="SpaceNavigation__screen-label">ТЯГА И НАКОПИТЕЛИ</div>
          <div className="ShipCombatPower__readout">
            <div className="ShipCombatPower__thrust">
              <span>Лимит тяги</span>
              <strong>{data.thrust_limit}%</strong>
            </div>
            <ProgressBar
              value={data.gun_charge}
              maxValue={Math.max(1, data.gun_capacity)}
            >
              {data.gun_capacity
                ? `Орудия · ${kilo(data.gun_charge, 'кДж')} / ${kilo(data.gun_capacity, 'кДж')}`
                : 'Орудия отсутствуют'}
            </ProgressBar>
          </div>
        </section>
      </div>
    </main>
  );
}

function shieldStatus(data: Telemetry) {
  if (!data.shield_present) return 'ГЕНЕРАТОР ОТСУТСТВУЕТ';
  if (!data.shield_working) return 'ГЕНЕРАТОР НЕДОСТУПЕН';
  if (!data.shield_enabled) return 'ВЫКЛЮЧЕН';
  if (data.shield_raised) return 'ПОДНЯТ';
  if (data.shield_recovery > 0)
    return `ВОССТАНОВЛЕНИЕ · ${data.shield_recovery.toFixed(1)} с`;
  if (!data.shield_sustained) return 'НЕ ХВАТАЕТ ПИТАНИЯ';
  return 'НАБИРАЕТ ЗАРЯД';
}

function kilo(value: number, unit: string) {
  return `${(value / 1000).toFixed(1)} ${unit}`;
}
