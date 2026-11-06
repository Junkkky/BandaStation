import {
  Button,
  NoticeBox,
  ProgressBar,
  Section,
  Table,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  missing?: BooleanLike;
  engines_running: BooleanLike;
  total: number;
  engines: {
    id: string;
    number: number;
    size: string;
    power: number;
    enabled: BooleanLike;
    integrity: number;
    status: string;
    thrust: number;
  }[];
};

export const StationTraumaEngines = () => {
  const { act, data } = useBackend<Data>();
  if (data.missing) {
    return (
      <Window width={520} height={140}>
        <Window.Content>
          <NoticeBox>Пульт не установлен на корабле</NoticeBox>
        </Window.Content>
      </Window>
    );
  }
  return (
    <Window width={640} height={480}>
      <Window.Content scrollable>
        <Section
          title={`Сопла · тяга ${data.total} %`}
          buttons={data.engines_running ? 'Двигатели запущены' : 'Двигатели остановлены'}
        >
          <Table>
            <Table.Row header>
              <Table.Cell>№</Table.Cell>
              <Table.Cell>Размер</Table.Cell>
              <Table.Cell>Состояние</Table.Cell>
              <Table.Cell>Целостность</Table.Cell>
              <Table.Cell textAlign="right">Тяга</Table.Cell>
              <Table.Cell collapsing />
            </Table.Row>
            {data.engines.map((engine) => (
              <Table.Row key={engine.id} className="candystripe">
                <Table.Cell py={0.5}>{engine.number}</Table.Cell>
                <Table.Cell>
                  {engine.size} · {engine.power}
                </Table.Cell>
                <Table.Cell
                  color={
                    !engine.enabled
                      ? 'label'
                      : data.engines_running && engine.thrust < 100
                        ? 'bad'
                        : undefined
                  }
                >
                  {engine.status}
                </Table.Cell>
                <Table.Cell>
                  <ProgressBar
                    value={engine.integrity / 100}
                    ranges={{
                      good: [0.7, Infinity],
                      average: [0.3, 0.7],
                      bad: [-Infinity, 0.3],
                    }}
                  >
                    {engine.integrity} %
                  </ProgressBar>
                </Table.Cell>
                <Table.Cell textAlign="right">{engine.thrust} %</Table.Cell>
                <Table.Cell collapsing>
                  <Button
                    icon="power-off"
                    selected={engine.enabled}
                    tooltip={engine.enabled ? 'Отключить сопло' : 'Включить сопло'}
                    onClick={() => act('toggle', { id: engine.id })}
                  />
                </Table.Cell>
              </Table.Row>
            ))}
          </Table>
        </Section>
      </Window.Content>
    </Window>
  );
};
