// AI EDIT START - combustion chamber engineering controls
import {
  Button,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  phase: string;
  fault: string | null;
  equipment_fault: string | null;
  pressure: number | null;
  temperature: number | null;
  line_pressure: number | null;
  supply: BooleanLike;
  feeding: BooleanLike;
  ratio: number | null;
  devices: {
    role: keyof typeof roles;
    name: string | null;
    status: string;
    value: number | null;
    max: number | null;
    unit: string | null;
  }[];
  fuel: { tritium: number; oxygen: number };
  engines: {
    id: string;
    number: number;
    position: string;
    status: string;
    output: number;
    temperature: number | null;
    pressure: number | null;
  }[];
};

const phases = {
  off: 'Выключена',
  starting: 'Розжиг',
  running: 'Работает',
  purging: 'Продувка',
  locked: 'Блокировка',
};

const roles = {
  mixer: 'Смеситель',
  inlet: 'Инжектор подачи',
  outlet: 'Откачка камеры',
  purge: 'Инжектор продувки',
  igniter: 'Воспламенитель',
};

export const ShipCombustion = () => {
  const { act, data } = useBackend<Data>();
  const idle = data.phase === 'off' || data.phase === 'locked';
  return (
    <Window width={1060} height={600}>
      <Window.Content scrollable>
        <Stack>
          <Stack.Item grow>
            <Controls />
          </Stack.Item>
          <Stack.Item width="400px">
            <Section title="Оборудование">
              <Table>
                {data.devices.map((device) => (
                  <Table.Row key={device.role} className="candystripe">
                    <Table.Cell py={0.5}>
                      {roles[device.role]}
                      <br />
                      <span
                        style={{ opacity: 0.7 }}
                        title={device.name ?? undefined}
                      >
                        {device.status}
                      </span>
                    </Table.Cell>
                    <Table.Cell textAlign="right">
                      {device.value !== null && device.max !== null && (
                        <NumberInput
                          value={device.value}
                          minValue={0}
                          maxValue={device.max}
                          step={1}
                          unit={device.unit ?? undefined}
                          onChange={(value) =>
                            act('setting', { role: device.role, value })
                          }
                        />
                      )}
                    </Table.Cell>
                    <Table.Cell collapsing>
                      <Button
                        icon="link"
                        disabled={!idle}
                        tooltip={
                          device.role === 'igniter'
                            ? 'Сохраните воспламенитель в мультитул (ПКМ) и нажмите, держа мультитул в руке'
                            : 'Сохраните устройство в мультитул и нажмите, держа мультитул в руке'
                        }
                        onClick={() => act('link', { role: device.role })}
                      />
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table>
              <Button
                mt={1}
                icon="rotate"
                disabled={!idle}
                onClick={() => act('reconnect')}
              >
                Переподключить по меткам
              </Button>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

function Controls() {
  const { act, data } = useBackend<Data>();
  const idle = data.phase === 'off' || data.phase === 'locked';
  return (
    <>
      <Section title="Камера сгорания">
        {!!(data.fault || data.equipment_fault) && (
          <NoticeBox danger>{data.fault || data.equipment_fault}</NoticeBox>
        )}
        <LabeledList>
          <LabeledList.Item label="Состояние">
            {phases[data.phase]}
          </LabeledList.Item>
          <LabeledList.Item label="Температура">
            {data.temperature ?? '—'} K
          </LabeledList.Item>
          <LabeledList.Item label="Давление камеры">
            {data.pressure ?? '—'} кПа
          </LabeledList.Item>
          <LabeledList.Item label="Давление магистрали">
            {data.line_pressure ?? '—'} кПа
          </LabeledList.Item>
        </LabeledList>
        <Button
          mt={1}
          icon="power-off"
          disabled={
            data.phase !== 'off' ||
            !!data.fault ||
            !!data.equipment_fault ||
            !data.supply
          }
          onClick={() => act('start')}
        >
          Запуск
        </Button>
        <Button
          disabled={idle || data.phase === 'purging'}
          onClick={() => act('stop')}
        >
          Остановка
        </Button>
        <Button disabled={!idle} onClick={() => act('purge')}>
          Продувка
        </Button>
        <Button disabled={data.phase !== 'locked'} onClick={() => act('reset')}>
          Сброс защиты
        </Button>
      </Section>
      <Section title="Подача смеси">
        <LabeledList>
          <LabeledList.Item label="Топливная линия">
            <Button selected={data.supply} onClick={() => act('supply')}>
              {data.supply ? 'Открыта' : 'Перекрыта'}
            </Button>
          </LabeledList.Item>
          <LabeledList.Item label="Инжектор">
            {data.feeding ? 'Подача' : 'Закрыт'}
          </LabeledList.Item>
          <LabeledList.Item label="Тритий в смеси">
            <NumberInput
              value={data.ratio ?? 0}
              disabled={data.ratio === null}
              minValue={1}
              maxValue={50}
              step={1}
              unit="%"
              onChange={(value) => act('ratio', { value })}
            />
          </LabeledList.Item>
          <LabeledList.Item label="Кислород в смеси">
            <NumberInput
              value={data.ratio === null ? 0 : 100 - data.ratio}
              disabled={data.ratio === null}
              minValue={50}
              maxValue={99}
              step={1}
              unit="%"
              onChange={(value) => act('oxygen_ratio', { value })}
            />
          </LabeledList.Item>
          <LabeledList.Item label="Запас трития">
            {data.fuel?.tritium ?? '—'} моль
          </LabeledList.Item>
          <LabeledList.Item label="Запас кислорода">
            {data.fuel?.oxygen ?? '—'} моль
          </LabeledList.Item>
        </LabeledList>
      </Section>
      {!!data.engines.length && (
        <Section title="Двигатели">
          <Table>
            <Table.Row header>
              <Table.Cell>№</Table.Cell>
              <Table.Cell>Координаты X / Y</Table.Cell>
              <Table.Cell>Состояние</Table.Cell>
              <Table.Cell textAlign="right">Тяга</Table.Cell>
              <Table.Cell textAlign="right">K</Table.Cell>
              <Table.Cell textAlign="right">кПа</Table.Cell>
            </Table.Row>
            {data.engines.map((engine) => (
              <Table.Row key={engine.id}>
                <Table.Cell>{engine.number}</Table.Cell>
                <Table.Cell>{engine.position}</Table.Cell>
                <Table.Cell
                  color={
                    data.phase === 'running' && engine.output < 100
                      ? 'bad'
                      : undefined
                  }
                >
                  {engine.status}
                </Table.Cell>
                <Table.Cell textAlign="right">{engine.output}%</Table.Cell>
                <Table.Cell textAlign="right">
                  {engine.temperature ?? '—'}
                </Table.Cell>
                <Table.Cell textAlign="right">
                  {engine.pressure ?? '—'}
                </Table.Cell>
              </Table.Row>
            ))}
          </Table>
        </Section>
      )}
    </>
  );
}
// AI EDIT END
