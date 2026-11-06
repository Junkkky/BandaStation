import {
  Box,
  Button,
  NoticeBox,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

const dockStatuses = {
  free: { label: 'Свободен', color: 'good' },
  approved: { label: 'Заход разрешён', color: 'average' },
  reserved: { label: 'Зарезервирован', color: 'average' },
  occupied: { label: 'Занят', color: 'label' },
  unavailable: { label: 'Недоступен', color: 'bad' },
} as const;

type Dock = {
  id: string;
  name: string;
  dock_class: string | null;
  status: keyof typeof dockStatuses;
  ship: string | null;
};

type Request = {
  ship_id: string;
  token: string;
  ship: string;
  dock_id: string;
  dock: string;
  approved: BooleanLike;
  seconds_left: number;
};

type TrafficData = {
  sector?: string;
  docks: Dock[];
  requests: Request[];
};

export function StationTrafficControl() {
  const { act, data } = useBackend<TrafficData>();
  const { docks, requests, sector } = data;
  const freeDocks = new Set(
    docks?.filter((dock) => dock.status === 'free').map((dock) => dock.id),
  );

  return (
    <Window title="Центр управления полётами" width={660} height={460}>
      <Window.Content scrollable>
        {!sector ? (
          <NoticeBox danger>Нет связи с диспетчерской сетью.</NoticeBox>
        ) : (
          <Stack vertical>
            <Stack.Item>
              <Section
                title="Причалы"
                buttons={<Box color="label">{sector}</Box>}
              >
                {!docks.length ? (
                  <Box color="label">
                    На станции нет зарегистрированных причалов.
                  </Box>
                ) : (
                  <Table>
                    {docks.map((dock) => (
                      <Table.Row key={dock.id}>
                        <Table.Cell bold>{dock.name}</Table.Cell>
                        <Table.Cell color="label">
                          {dock.dock_class || 'Штатный'}
                        </Table.Cell>
                        <Table.Cell color={dockStatuses[dock.status].color}>
                          {dockStatuses[dock.status].label}
                        </Table.Cell>
                        <Table.Cell>{dock.ship || '—'}</Table.Cell>
                      </Table.Row>
                    ))}
                  </Table>
                )}
              </Section>
            </Stack.Item>
            <Stack.Item>
              <Section title="Запросы на стыковку">
                {!requests.length ? (
                  <Box color="label">Нет запросов на рассмотрении.</Box>
                ) : (
                  requests.map((request) => (
                    <Stack key={request.token} align="center" mb={0.75}>
                      <Stack.Item grow>
                        <Box bold>{request.ship}</Box>
                        <Box color="label">
                          {request.dock} ·{' '}
                          {request.approved ? 'Разрешено' : 'На рассмотрении'} ·{' '}
                          {request.seconds_left} с
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        {!request.approved && (
                          <Button
                            icon="check"
                            disabled={!freeDocks.has(request.dock_id)}
                            onClick={() =>
                              act('approve', {
                                ship_id: request.ship_id,
                                token: request.token,
                              })
                            }
                          >
                            Разрешить
                          </Button>
                        )}
                        <Button
                          icon="ban"
                          color="bad"
                          onClick={() =>
                            act('deny', {
                              ship_id: request.ship_id,
                              token: request.token,
                            })
                          }
                        >
                          {request.approved ? 'Отозвать' : 'Отклонить'}
                        </Button>
                      </Stack.Item>
                    </Stack>
                  ))
                )}
              </Section>
            </Stack.Item>
          </Stack>
        )}
      </Window.Content>
    </Window>
  );
}
