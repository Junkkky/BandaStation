// AI EDIT START - combustion chamber engineering controls
import {
  Button,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
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
  feed_rate: number;
  ratio: number | null;
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

export const ShipCombustion = () => {
  const { act, data } = useBackend<Data>();
  const idle = data.phase === 'off' || data.phase === 'locked';
  return (
    <Window width={660} height={600}>
      <Window.Content scrollable>
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
          <Button
            disabled={data.phase !== 'locked'}
            onClick={() => act('reset')}
          >
            Сброс защиты
          </Button>
        </Section>
        <Section title="Подача смеси">
          <LabeledList>
            <LabeledList.Item label="Топливная линия">
              <Button
                selected={data.supply}
                onClick={() => act('supply')}
              >
                {data.supply ? 'Открыта' : 'Перекрыта'}
              </Button>
            </LabeledList.Item>
            <LabeledList.Item label="Инжектор">
              {data.feeding ? 'Подача' : 'Закрыт'}
            </LabeledList.Item>
            <LabeledList.Item label="Предел подачи">
              <NumberInput
                value={data.feed_rate}
                minValue={0.1}
                maxValue={5}
                step={0.1}
                unit="л/цикл"
                onChange={(value) => act('rate', { value })}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Боковой вход · тритий">
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
        <Button icon="link" disabled={!idle} onClick={() => act('reconnect')}>
          Переподключить оборудование
        </Button>
      </Window.Content>
    </Window>
  );
};
// AI EDIT END
