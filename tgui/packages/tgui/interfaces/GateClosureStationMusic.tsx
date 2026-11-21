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
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Track = {
  name: string;
  length: number;
};

type Data = {
  tracks: Track[];
  folder: string;
  unreadable: string[];
  current: string | null;
  index: number;
  elapsed: number;
  length: number;
  paused: BooleanLike;
  autoplay: BooleanLike;
  volume: number;
  listeners: number;
};

const formatTime = (seconds: number) =>
  `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;

export const GateClosureStationMusic = () => {
  const { act, data } = useBackend<Data>();
  const tracks = data.tracks || [];
  const playing = !!data.current;

  return (
    <Window title="Gate Closure — звуки станции" width={460} height={540}>
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
                    icon="backward"
                    tooltip="Предыдущий"
                    disabled={!tracks.length}
                    onClick={() => act('step', { direction: -1 })}
                  />
                  <Button
                    icon={data.paused ? 'play' : 'pause'}
                    tooltip={data.paused ? 'Продолжить' : 'Пауза'}
                    disabled={!playing}
                    onClick={() => act('pause')}
                  />
                  <Button
                    icon="forward"
                    tooltip="Следующий"
                    disabled={!tracks.length}
                    onClick={() => act('step', { direction: 1 })}
                  />
                  <Button
                    icon="stop"
                    color="bad"
                    disabled={!playing}
                    onClick={() => act('stop')}
                  >
                    Стоп
                  </Button>
                </>
              }
            >
              <LabeledList>
                <LabeledList.Item label="Трек">
                  {data.current
                    ? `${data.current}${data.paused ? ' (пауза)' : ''}`
                    : 'Тишина'}
                </LabeledList.Item>
                <LabeledList.Item label="Время">
                  <ProgressBar
                    value={data.length ? data.elapsed / data.length : 0}
                  >
                    {formatTime(data.elapsed)} / {formatTime(data.length)}
                  </ProgressBar>
                </LabeledList.Item>
                <LabeledList.Item label="Автовоспроизведение">
                  <Button.Checkbox
                    checked={!!data.autoplay}
                    tooltip="Включено: после трека сам начинается следующий. Выключено: после трека тишина."
                    onClick={() => act('autoplay')}
                  >
                    {data.autoplay ? 'Вкл' : 'Выкл'}
                  </Button.Checkbox>
                </LabeledList.Item>
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
          <Stack.Item grow>
            <Section
              fill
              scrollable
              title={`Треки (${tracks.length})`}
              buttons={
                <>
                  <Button
                    icon="upload"
                    tooltip="Загрузить .ogg со своего компьютера в папку на сервере"
                    onClick={() => act('upload')}
                  >
                    Загрузить
                  </Button>
                  <Button
                    icon="rotate"
                    tooltip="Перечитать папку с треками (когда звук остановлен)"
                    disabled={playing}
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
                          selected={data.index === index + 1}
                          onClick={() => act('play', { index: index + 1 })}
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
                  Нет треков. Загрузите .ogg кнопкой выше или положите их в{' '}
                  {data.folder} на сервере и перечитайте папку.
                </NoticeBox>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
