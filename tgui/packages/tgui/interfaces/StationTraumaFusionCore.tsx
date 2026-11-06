import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  NumberInput,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  missing?: BooleanLike;
  active: BooleanLike;
  tripped: BooleanLike;
  overdrive: BooleanLike;
  interlock: BooleanLike;
  auto: BooleanLike;
  level: number;
  max_level: number;
  target: number;
  output: number;
  heat: number;
  power: number;
  fuel_flow: number;
  injection_limit: number;
  injection_max: number;
  grid: BooleanLike;
  batteries: { charge: number; charging: BooleanLike; input: number }[];
  exhaust_pressure: number;
  room_temperature: number | null;
  radiation: number;
  fuel: { name: string; amount: number; capacity: number }[];
};

const heatRanges = {
  good: [-Infinity, 0.5],
  average: [0.5, 0.9],
  bad: [0.9, Infinity],
} as const;

export const StationTraumaFusionCore = () => {
  const { data } = useBackend<Data>();
  if (data.missing) {
    return (
      <Window width={560} height={140}>
        <Window.Content>
          <NoticeBox>Термоядерное ядро корабля не найдено</NoticeBox>
        </Window.Content>
      </Window>
    );
  }
  return (
    <Window width={720} height={600}>
      <Window.Content scrollable>
        <Stack>
          <Stack.Item grow>
            <Reaction />
          </Stack.Item>
          <Stack.Item width="300px">
            <Grid />
            <Safety />
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

function Reaction() {
  const { act, data } = useBackend<Data>();
  return (
    <Section
      title="Реакция"
      buttons={
        <Button
          icon="power-off"
          selected={data.active}
          disabled={!!data.tripped}
          onClick={() => act('power')}
        >
          {data.active ? 'Работает' : 'Остановлено'}
        </Button>
      }
    >
      {!!data.tripped && (
        <NoticeBox danger>
          Аварийная остановка по перегреву: пуск после остывания
        </NoticeBox>
      )}
      {!!data.overdrive && (
        <NoticeBox>Форсаж с мостика: двойной расход трития</NoticeBox>
      )}
      <LabeledList>
        <LabeledList.Item label="Режим">
          <Button selected={data.auto} onClick={() => act('auto')}>
            Автоматический
          </Button>
          <Button selected={!data.auto} onClick={() => act('auto')}>
            Ручной
          </Button>
        </LabeledList.Item>
        <LabeledList.Item label="Мощность (задание)">
          <NumberInput
            value={data.level}
            disabled={!!data.auto}
            minValue={0}
            maxValue={data.max_level}
            step={5}
            unit="%"
            onChange={(value) => act('level', { value })}
          />{' '}
          {data.level > 100 && !data.auto && (
            <Box inline color="average">
              перегрузка
            </Box>
          )}
        </LabeledList.Item>
        <LabeledList.Item label="Цель реакции">{data.target} %</LabeledList.Item>
        <LabeledList.Item label="Отдача">
          <ProgressBar
            value={data.output / data.max_level}
            ranges={{
              good: [-Infinity, 100 / data.max_level],
              average: [100 / data.max_level, Infinity],
            }}
          >
            {data.output} %
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Нагрев ядра">
          <ProgressBar value={data.heat / 100} ranges={heatRanges}>
            {data.heat} %
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Впрыск трития">
          {data.fuel_flow} моль/с, предел{' '}
          <NumberInput
            value={data.injection_limit}
            minValue={0}
            maxValue={data.injection_max}
            step={0.1}
            unit="моль/с"
            onChange={(value) => act('injection', { value })}
          />
        </LabeledList.Item>
        {data.fuel.map((gauge) => (
          <LabeledList.Item key={gauge.name} label={`Запас: ${gauge.name}`}>
            <ProgressBar
              value={gauge.capacity ? gauge.amount / gauge.capacity : 0}
              ranges={{
                good: [0.5, Infinity],
                average: [0.2, 0.5],
                bad: [-Infinity, 0.2],
              }}
            >
              {gauge.amount} моль
            </ProgressBar>
          </LabeledList.Item>
        ))}
        <LabeledList.Item label="Магистраль гелия">
          {data.exhaust_pressure} кПа
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
}

function Grid() {
  const { data } = useBackend<Data>();
  return (
    <Section title="Электросеть">
      {!data.grid && (
        <NoticeBox>Под ядром нет кабеля: питание в сеть не идёт</NoticeBox>
      )}
      <LabeledList>
        <LabeledList.Item label="Выработка">{data.power} кВт</LabeledList.Item>
        {data.batteries.map((battery, index) => (
          <LabeledList.Item key={index} label={`СМЕС ${index + 1}`}>
            <ProgressBar
              value={battery.charge / 100}
              ranges={{
                good: [0.5, Infinity],
                average: [0.2, 0.5],
                bad: [-Infinity, 0.2],
              }}
            >
              {battery.charge} %{' '}
              {battery.charging ? `· заряд ${battery.input} кВт` : ''}
            </ProgressBar>
          </LabeledList.Item>
        ))}
      </LabeledList>
    </Section>
  );
}

function Safety() {
  const { act, data } = useBackend<Data>();
  return (
    <Section title="Безопасность">
      <LabeledList>
        <LabeledList.Item label="Аварийная блокировка">
          <Button.Confirm
            color={data.interlock ? 'good' : 'bad'}
            confirmContent={data.interlock ? 'Снять защиту?' : 'Включить?'}
            onClick={() => act('interlock')}
          >
            {data.interlock ? 'Включена' : 'Отключена'}
          </Button.Confirm>
        </LabeledList.Item>
        <LabeledList.Item label="Радиация">
          {data.radiation ? `до ${data.radiation} клеток` : 'нет'}
        </LabeledList.Item>
        <LabeledList.Item label="Температура отсека">
          {data.room_temperature ?? '—'} °C
        </LabeledList.Item>
      </LabeledList>
      {!data.interlock && (
        <NoticeBox danger mt={1}>
          Без блокировки перегретое ядро не остановится и может взорваться
        </NoticeBox>
      )}
    </Section>
  );
}
