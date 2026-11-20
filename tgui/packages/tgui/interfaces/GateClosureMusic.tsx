import { useState } from 'react';
import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Slider,
  Stack,
  Table,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Track = {
  name: string;
  length: number;
};

type Category = 'ambient' | 'combat' | 'situations';

type Data = {
  ambient: Track[];
  combat: Track[];
  situations: Track[];
  folder: string;
  unreadable: string[];
  mode: Category | null;
  current: string | null;
  elapsed: number;
  length: number;
  switching: BooleanLike;
  next: string | null;
  volume: number;
  listeners: number;
};

const TABS: { category: Category; title: string; icon: string }[] = [
  { category: 'ambient', title: 'Эмбиент', icon: 'cloud' },
  { category: 'combat', title: 'Боевая', icon: 'khanda' },
  { category: 'situations', title: 'Ситуации', icon: 'bolt' },
];

const formatTime = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

export const GateClosureMusic = () => {
  const { act, data } = useBackend<Data>();
  const [tab, setTab] = useState<Category>('ambient');
  const tracks = data[tab] || [];
  const playlist = tab !== 'situations';
  const modeTitle = TABS.find((entry) => entry.category === data.mode)?.title;

  return (
    <Window title="Gate Closure — проигрыватель" width={480} height={560}>
      <Window.Content>
        <Stack fill vertical>
          {!!data.unreadable?.length && (
            <Stack.Item>
              <NoticeBox danger>
                Не прочитана длина, файлы пропущены (перепакуйте: ffmpeg -i
                in.ogg -c:a copy out.ogg): {data.unreadable.join(', ')}
              </NoticeBox>
            </Stack.Item>
          )}
          <Stack.Item>
            <Section
              title="Сейчас играет"
              buttons={
                <>
                  <Button
                    icon="forward"
                    tooltip="Следующий трек"
                    disabled={data.mode !== 'ambient' && data.mode !== 'combat'}
                    onClick={() => act('next')}
                  />
                  <Button
                    icon="shuffle"
                    tooltip="Перемешать оставшиеся треки"
                    disabled={data.mode !== 'ambient' && data.mode !== 'combat'}
                    onClick={() => act('shuffle')}
                  />
                  <Button
                    icon="stop"
                    color="bad"
                    disabled={!data.mode}
                    onClick={() => act('stop')}
                  >
                    Стоп
                  </Button>
                </>
              }
            >
              <LabeledList>
                <LabeledList.Item label="Трек">
                  {data.current ||
                    (data.switching ? 'Переключение…' : 'Тишина')}
                </LabeledList.Item>
                <LabeledList.Item label="Режим">
                  {modeTitle || '—'}
                </LabeledList.Item>
                <LabeledList.Item label="Время">
                  <ProgressBar
                    value={data.length ? data.elapsed / data.length : 0}
                  >
                    {formatTime(data.elapsed)} / {formatTime(data.length)}
                  </ProgressBar>
                </LabeledList.Item>
                {!!data.next && (
                  <LabeledList.Item label="Далее">{data.next}</LabeledList.Item>
                )}
                <LabeledList.Item label="Громкость">
                  <Slider
                    minValue={0}
                    maxValue={100}
                    step={5}
                    value={data.volume}
                    onChange={(_, value) => act('volume', { volume: value })}
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Слушают">
                  {data.listeners}
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Tabs fluid>
              {TABS.map((entry) => (
                <Tabs.Tab
                  key={entry.category}
                  icon={entry.icon}
                  selected={tab === entry.category}
                  onClick={() => setTab(entry.category)}
                >
                  {entry.title} ({(data[entry.category] || []).length})
                </Tabs.Tab>
              ))}
            </Tabs>
          </Stack.Item>
          <Stack.Item grow>
            <Section
              fill
              scrollable
              buttons={
                <>
                  {playlist && (
                    <Button
                      icon="play"
                      color="good"
                      disabled={!tracks.length}
                      selected={data.mode === tab}
                      onClick={() => act('playlist', { category: tab })}
                    >
                      Включить вперемешку
                    </Button>
                  )}
                  <Button
                    icon="rotate"
                    tooltip="Перечитать папки с треками (когда музыка остановлена)"
                    disabled={!!data.mode}
                    onClick={() => act('rescan')}
                  />
                </>
              }
            >
              {tracks.length ? (
                <Table>
                  {tracks.map((track, index) => (
                    <Table.Row key={track.name} className="candystripe">
                      <Table.Cell>
                        <Button
                          fluid
                          icon="play"
                          selected={
                            data.mode === tab && data.current === track.name
                          }
                          onClick={() =>
                            act('track', { category: tab, index: index + 1 })
                          }
                        >
                          {track.name}
                        </Button>
                      </Table.Cell>
                      <Table.Cell collapsing textAlign="right">
                        <Box color="label">{formatTime(track.length)}</Box>
                      </Table.Cell>
                    </Table.Row>
                  ))}
                </Table>
              ) : (
                <NoticeBox>
                  Нет треков. Положите .ogg в {data.folder}
                  {tab}/ и перечитайте папки.
                </NoticeBox>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
