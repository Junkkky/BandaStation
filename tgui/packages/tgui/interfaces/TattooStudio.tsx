import {
  type PointerEvent,
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react';
import {
  Box,
  Button,
  ColorBox,
  Dropdown,
  Input,
  Section,
  Stack,
} from 'tgui-core/components';
import { clamp } from 'tgui-core/math';
import type { BooleanLike } from 'tgui-core/react';
import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { bresenhamLine } from './common/SpriteEditor/helpers';
import { Dir } from './common/SpriteEditor/Types/types';

type SessionData = {
  role: 'artist' | 'client';
  practice?: BooleanLike;
  phase: 'draft' | 'review' | 'applying';
  zone: string;
  targetName: string;
  revision: number;
};

type Stencil = { id: string; name: string };

type StudioData = SessionData & {
  mode?: undefined;
  canSave?: BooleanLike;
  saveByDefault?: BooleanLike;
  direction: Dir;
  body: string;
  mask: string;
  draft: string;
  palette: string[];
  drawRejected?: number;
  drawRejectedRevision?: number | null;
  occupied?: Dir[];
  stencils?: Stencil[] | null;
  stencilLimit?: number;
  stencilError?: string | null;
};

type RemovalData = SessionData & {
  mode: 'removal';
  tattoos: { id: string; side: string; image: string }[];
  selected: string | null;
};

const SIZE = 32;
const DETAIL = SIZE * 2;
const EMPTY = '0'.repeat(DETAIL * DETAIL);
const PIXEL_DIGITS =
  '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_';
const PATCH_PIXELS = 400;
const ACK_TIMEOUT = 2000;

function nextDraftPatch(from: string, to: string, revision: number) {
  if (from === to) return null;
  const expected = from.split('');
  let patch = '';
  for (let i = 0; i < from.length && patch.length < PATCH_PIXELS * 3; i++) {
    if (from[i] === to[i]) continue;
    patch += PIXEL_DIGITS[Math.floor(i / 64)] + PIXEL_DIGITS[i % 64] + to[i];
    expected[i] = to[i];
  }
  return { patch, revision, pixels: expected.join('') };
}

type DrawPatch = NonNullable<ReturnType<typeof nextDraftPatch>>;
const pigments: Record<string, string> = {
  '#262638': 'Графит',
  '#aa264b': 'Кармин',
  '#176b78': 'Бирюза',
  '#dc962d': 'Охра',
  '#8253b2': 'Фиолетовый',
  '#f3f2ed': 'Белый',
  '#9ca5ae': 'Серебристый',
  '#f1d344': 'Жёлтый',
  '#ee7634': 'Оранжевый',
  '#dc3540': 'Алый',
  '#e98aad': 'Розовый',
  '#398c54': 'Зелёный',
  '#304d8c': 'Тёмно-синий',
  '#63b5da': 'Голубой',
  '#835638': 'Коричневый',
};
const directions: [Dir, string][] = [
  [Dir.SOUTH, 'Спереди'],
  [Dir.NORTH, 'Со спины'],
  [Dir.EAST, 'Лицом вправо'],
  [Dir.WEST, 'Лицом влево'],
];
type Point = [number, number];
type Surface = {
  body: HTMLImageElement;
  alpha: Uint8ClampedArray;
  x: number;
  y: number;
  width: number;
  height: number;
};

function loadImage(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = url;
  });
}

async function loadSurface(bodyUrl: string, maskUrl: string): Promise<Surface> {
  const [body, mask] = await Promise.all([
    loadImage(bodyUrl),
    loadImage(maskUrl),
  ]);
  if (mask.width !== SIZE || mask.height !== SIZE) throw Error('Invalid mask');
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = SIZE;
  const ctx = canvas.getContext('2d')!;
  ctx.drawImage(mask, 0, 0);
  const alpha = ctx.getImageData(0, 0, SIZE, SIZE).data;
  let left = SIZE,
    top = SIZE,
    right = -1,
    bottom = -1;
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      if (!alpha[(y * SIZE + x) * 4 + 3]) continue;
      left = Math.min(left, x);
      top = Math.min(top, y);
      right = Math.max(right, x);
      bottom = Math.max(bottom, y);
    }
  }
  if (right < left) throw Error('Empty mask');
  left = Math.max(0, left - 1);
  top = Math.max(0, top - 1);
  return {
    body,
    alpha,
    x: left * 2,
    y: top * 2,
    width: (Math.min(SIZE, right + 2) - left) * 2,
    height: (Math.min(SIZE, bottom + 2) - top) * 2,
  };
}

function renderTattoo(
  surface: Surface,
  pixels: string,
  palette: string[],
  editor: HTMLCanvasElement,
  preview: HTMLCanvasElement,
) {
  const ctx = editor.getContext('2d')!;
  const world = preview.getContext('2d')!;
  const { x, y, width, height } = surface;
  ctx.clearRect(0, 0, width, height);
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(
    surface.body,
    x / 2,
    y / 2,
    width / 2,
    height / 2,
    0,
    0,
    width,
    height,
  );
  world.clearRect(0, 0, SIZE, SIZE);
  world.drawImage(surface.body, 0, 0, SIZE, SIZE);
  for (let dy = 0; dy < height; dy += 2) {
    for (let dx = 0; dx < width; dx += 2) {
      const wx = (x + dx) / 2;
      const wy = (y + dy) / 2;
      if (!surface.alpha[(wy * SIZE + wx) * 4 + 3]) {
        ctx.fillStyle = 'rgba(0, 0, 0, 0.65)';
        ctx.fillRect(dx, dy, 2, 2);
        continue;
      }
      const colors: number[] = [];
      for (let i = 0; i < 4; i++) {
        const ix = i % 2,
          iy = Math.floor(i / 2);
        const color = parseInt(
          pixels[(y + dy + iy) * DETAIL + x + dx + ix],
          16,
        );
        if (!palette[color - 1]) continue;
        ctx.fillStyle = palette[color - 1];
        ctx.fillRect(dx + ix, dy + iy, 1, 1);
        colors.push(color);
      }
      // The world sprite uses the most frequent ink, breaking ties in reading order.
      let most = 0;
      for (const ink of colors) {
        const count = colors.filter((other) => ink === other).length;
        if (count <= most) continue;
        most = count;
        world.fillStyle = palette[ink - 1];
      }
      if (most) world.fillRect(wx, wy, 1, 1);
    }
  }
}

export function TattooStudio() {
  const { data } = useBackend<StudioData | RemovalData>();
  if (data.mode === 'removal') {
    return <RemovalStudio />;
  }
  return (
    <Window
      width={610}
      height={
        (data.palette.length > 8 ? 590 : 540) +
        (data.role === 'artist' && data.phase === 'draft' && data.stencils
          ? 90
          : 0)
      }
      title="Тату-машинка"
    >
      <Window.Content scrollable>
        <Studio
          key={JSON.stringify([
            data.targetName,
            data.zone,
            data.direction,
            data.role,
            data.phase,
          ])}
        />
      </Window.Content>
    </Window>
  );
}

function RemovalStudio() {
  const { act, data } = useBackend<RemovalData>();
  const artist = data.role === 'artist';
  const choosing = artist && data.phase === 'draft';
  const [choice, setChoice] = useState<string>();
  const current = choosing
    ? (data.tattoos.find((tattoo) => tattoo.id === choice) ?? data.tattoos[0])
    : data.tattoos.find((tattoo) => tattoo.id === data.selected);

  return (
    <Window width={510} height={450} title="Сведение татуировки">
      <Window.Content scrollable>
        <Section title={`${data.targetName} · ${data.zone}`}>
          {choosing && (
            <Box mb={1}>
              {data.tattoos.map((tattoo) => (
                <Button
                  key={tattoo.id}
                  {...{ role: 'button' }}
                  selected={current?.id === tattoo.id}
                  onClick={() => setChoice(tattoo.id)}
                >
                  {tattoo.side}
                </Button>
              ))}
            </Box>
          )}
          {data.phase === 'draft' && !artist ? (
            <Box>Мастер выбирает татуировку для сведения.</Box>
          ) : current ? (
            <>
              {!choosing && <Box color="label">{current.side}</Box>}
              <img
                src={current.image}
                alt={`Татуировка: ${data.zone}, ${current.side}`}
                style={{
                  width: '100%',
                  height: 230,
                  objectFit: 'contain',
                  imageRendering: 'pixelated',
                }}
              />
            </>
          ) : (
            <Box>На этом участке нет доступной для сведения татуировки.</Box>
          )}
        </Section>
        <Section>
          {choosing && current && (
            <Button
              onClick={() =>
                act('select', { id: current.id, revision: data.revision })
              }
            >
              {data.practice ? 'Проверить выбор' : 'Показать клиенту'}
            </Button>
          )}
          {data.phase === 'review' && (
            <>
              <Box mb={1}>
                {data.practice
                  ? 'После сведения рисунок исчезнет с манекена.'
                  : 'После сведения рисунок исчезнет с тела и из сохранённых татуировок персонажа.'}
              </Box>
              {artist && !data.practice ? (
                <Box mb={1}>Клиент решает, сводить ли татуировку.</Box>
              ) : (
                <Button
                  color="bad"
                  disabled={!current}
                  onClick={() => act('approve', { revision: data.revision })}
                >
                  {data.practice
                    ? 'Свести с манекена'
                    : 'Согласиться на сведение'}
                </Button>
              )}
              <Button
                onClick={() => act('revise', { revision: data.revision })}
              >
                {artist ? 'Выбрать другую' : 'Попросить выбрать другую'}
              </Button>
            </>
          )}
          {data.phase === 'applying' && (
            <Box mb={1}>Идёт сведение татуировки…</Box>
          )}
          <Button onClick={() => act('cancel')}>
            {data.phase === 'review' && !artist
              ? 'Отказаться'
              : 'Прервать сеанс'}
          </Button>
        </Section>
      </Window.Content>
    </Window>
  );
}

function Studio() {
  const { act, data } = useBackend<StudioData>();
  const artist = data.role === 'artist';
  const canSave = !artist && !data.practice && !!data.canSave;
  const [saveChoice, setSaveChoice] = useState<{
    revision: number;
    save: boolean;
  }>();
  const save =
    canSave &&
    (saveChoice?.revision === data.revision
      ? saveChoice.save
      : !!data.saveByDefault);
  const choosing = artist && data.phase === 'draft';
  const occupied = data.occupied || [];
  const editable = choosing && !occupied.includes(data.direction);
  const remote = data.draft || EMPTY;
  const server = useRef({
    pixels: remote,
    revision: data.revision,
    rejected: data.drawRejected,
  });
  const [sync, setSync] = useState<'idle' | 'sending' | 'timeout' | 'rejected'>(
    'idle',
  );
  const [painting, setPainting] = useState(false);
  const [cursor, setCursor] = useState<Point | null>(null);
  const [surface, setSurface] = useState<Surface | null>(null);
  const [failed, setFailed] = useState(false);
  const [color, setColor] = useState(1);
  const [pixels, setPixels] = useState(remote);
  const current = useRef(remote);
  const committed = useRef(remote);
  const flight = useRef<DrawPatch | null>(null);
  const sendTimer = useRef<number | undefined>(undefined);
  const strokeTimer = useRef<number | undefined>(undefined);
  const history = useRef<string[]>([]);
  const stroke = useRef<{ id: number; before: string; point: Point } | null>(
    null,
  );
  const editor = useRef<HTMLCanvasElement>(null);
  const preview = useRef<HTMLCanvasElement>(null);
  const actual = useRef<HTMLCanvasElement>(null);
  const motor = useRef<HTMLAudioElement | null>(null);
  const motorIdle = useRef<number | undefined>(undefined);
  const stopMotor = useCallback(() => {
    if (motorIdle.current === undefined) return;
    window.clearTimeout(motorIdle.current);
    motorIdle.current = undefined;
    if (motor.current) {
      motor.current.pause();
      motor.current.currentTime = 0;
    }
  }, []);

  useEffect(() => {
    if (!editable) return;
    const audio = new Audio(resolveAsset('tattoo_machine.ogg'));
    audio.loop = true;
    audio.volume = 0.2;
    motor.current = audio;
    return () => {
      stopMotor();
      motor.current = null;
    };
  }, [editable, stopMotor]);

  useEffect(() => {
    let active = true;
    setSurface(null);
    setFailed(false);
    loadSurface(data.body, data.mask).then(
      (result) => {
        if (active) setSurface(result);
      },
      () => {
        if (active) setFailed(true);
      },
    );
    return () => {
      active = false;
    };
  }, [data.body, data.mask]);

  const sendPatch = useCallback(
    (packet: DrawPatch) => {
      window.clearTimeout(sendTimer.current);
      flight.current = packet;
      setSync('sending');
      let attempts = 0;
      function send() {
        if (flight.current !== packet) return;
        if (attempts === 3) {
          setSync('timeout');
          return;
        }
        attempts++;
        act('draw_patch', { patch: packet.patch, revision: packet.revision });
        sendTimer.current = window.setTimeout(send, ACK_TIMEOUT);
      }
      send();
    },
    [act],
  );

  const flush = useCallback(() => {
    if (flight.current) return;
    const next = nextDraftPatch(
      server.current.pixels,
      committed.current,
      server.current.revision,
    );
    if (next) sendPatch(next);
    else setSync('idle');
  }, [sendPatch]);

  useEffect(
    () => () => {
      window.clearTimeout(sendTimer.current);
      window.clearTimeout(strokeTimer.current);
    },
    [],
  );

  // A status-only update must not rewind the brush or clear unsent edits.
  useEffect(() => {
    const previous = server.current;
    if (
      previous.pixels === remote &&
      previous.revision === data.revision &&
      previous.rejected === data.drawRejected
    )
      return;
    server.current = {
      pixels: remote,
      revision: data.revision,
      rejected: data.drawRejected,
    };
    const sent = flight.current;
    if (sent) {
      if (sent.revision !== data.revision && sent.pixels === remote) {
        window.clearTimeout(sendTimer.current);
        flight.current = null;
        flush();
      } else if (
        sent.revision !== data.revision ||
        (previous.rejected !== data.drawRejected &&
          (data.drawRejectedRevision == null ||
            data.drawRejectedRevision === sent.revision))
      ) {
        window.clearTimeout(sendTimer.current);
        setSync('rejected');
      }
      return;
    }
    if (previous.pixels === remote) return;
    if (editable && current.current !== previous.pixels) {
      // A local stroke may have started while a server-side stencil was being applied.
      const combined = remote.split('');
      for (let i = 0; i < remote.length; i++) {
        if (current.current[i] !== previous.pixels[i])
          combined[i] = current.current[i];
      }
      current.current = committed.current = combined.join('');
      setPixels(current.current);
      flush();
      return;
    }
    current.current = committed.current = remote;
    history.current = [];
    stroke.current = null;
    setPainting(false);
    stopMotor();
    setPixels(remote);
  }, [
    remote,
    data.revision,
    data.drawRejected,
    data.drawRejectedRevision,
    editable,
    flush,
    stopMotor,
  ]);

  useEffect(() => {
    if (surface && editor.current && preview.current) {
      renderTattoo(
        surface,
        pixels,
        data.palette,
        editor.current,
        preview.current,
      );
      if (cursor) {
        const detail = editor.current.getContext('2d')!;
        detail.save();
        detail.globalCompositeOperation = 'difference';
        detail.fillStyle = 'white';
        detail.fillRect(cursor[0] - surface.x, cursor[1] - surface.y, 1, 1);
        detail.restore();
      }
      const ctx = actual.current?.getContext('2d');
      ctx?.clearRect(0, 0, SIZE, SIZE);
      ctx?.drawImage(preview.current, 0, 0);
    }
  }, [surface, pixels, data.palette, cursor]);

  function commit(next: string) {
    window.clearTimeout(strokeTimer.current);
    strokeTimer.current = undefined;
    current.current = committed.current = next;
    setPixels(next);
    flush();
  }

  function remember(before: string) {
    history.current.push(before);
    if (history.current.length > 32) history.current.shift();
  }

  function position(event: PointerEvent<HTMLCanvasElement>): Point {
    const r = event.currentTarget.getBoundingClientRect();
    return [
      clamp(
        surface!.x +
          Math.floor(((event.clientX - r.left) / r.width) * surface!.width),
        -1,
        DETAIL,
      ),
      clamp(
        surface!.y +
          Math.floor(((event.clientY - r.top) / r.height) * surface!.height),
        -1,
        DETAIL,
      ),
    ];
  }

  function paint(point: Point) {
    if (!surface || !stroke.current) return;
    const chars = current.current.split('');
    const plot = (x: number, y: number) => {
      if (x < 0 || y < 0 || x >= DETAIL || y >= DETAIL) return;
      const cell = Math.floor(y / 2) * SIZE + Math.floor(x / 2);
      if (surface.alpha[cell * 4 + 3])
        chars[y * DETAIL + x] = color.toString(16);
    };
    bresenhamLine(...stroke.current.point, ...point, plot);
    plot(...point);
    stroke.current.point = point;
    const next = chars.join('');
    if (next === current.current) return;
    current.current = next;
    setPixels(next);
    if (strokeTimer.current === undefined) {
      strokeTimer.current = window.setTimeout(() => {
        strokeTimer.current = undefined;
        committed.current = current.current;
        flush();
      }, 150);
    }
    if (color && motor.current) {
      if (motorIdle.current === undefined) {
        motor.current.play().catch(() => {});
      }
      window.clearTimeout(motorIdle.current);
      motorIdle.current = window.setTimeout(stopMotor, 500);
    }
  }

  function finishStroke() {
    if (!stroke.current) return;
    const { before } = stroke.current;
    stroke.current = null;
    setPainting(false);
    if (before !== current.current) {
      remember(before);
      commit(current.current);
    }
  }

  function finishPointerStroke(event: PointerEvent<HTMLCanvasElement>) {
    if (stroke.current?.id !== event.pointerId) return;
    stopMotor();
    finishStroke();
  }

  const hasInk = pixels !== EMPTY;
  const busy = sync !== 'idle' || painting || pixels !== remote;
  const scale = surface
    ? Math.min(12, Math.floor(252 / Math.max(surface.width, surface.height)))
    : 1;
  return (
    <>
      <Section title={`${data.targetName} · ${data.zone}`}>
        {directions.map(([dir, label]) => (
          <Button
            key={dir}
            selected={dir === data.direction}
            disabled={
              !choosing ||
              occupied.includes(dir) ||
              hasInk ||
              busy ||
              dir === data.direction
            }
            tooltip={
              occupied.includes(dir)
                ? 'На этой стороне уже есть татуировка'
                : undefined
            }
            onClick={() => act('direction', { direction: dir })}
          >
            {label}
          </Button>
        ))}
      </Section>
      <Stack>
        <Stack.Item grow basis={0}>
          <Section title="Эскиз на коже">
            <Box
              textAlign="center"
              height="255px"
              style={{ alignContent: 'center' }}
            >
              {surface ? (
                <canvas
                  ref={editor}
                  width={surface.width}
                  height={surface.height}
                  aria-label="Эскиз на выбранном участке кожи"
                  aria-description={
                    editable
                      ? 'Стрелки перемещают кисть, пробел ставит точку.'
                      : undefined
                  }
                  tabIndex={editable ? 0 : undefined}
                  onBlur={() => setCursor(null)}
                  onKeyDown={(event) => {
                    if (!editable || stroke.current) return;
                    const [x, y] = cursor || [
                      surface.x + Math.floor(surface.width / 2),
                      surface.y + Math.floor(surface.height / 2),
                    ];
                    if (event.key === ' ') {
                      stroke.current = {
                        id: -1,
                        before: current.current,
                        point: [x, y],
                      };
                      paint([x, y]);
                      finishStroke();
                      setCursor([x, y]);
                    } else {
                      const delta: Record<string, Point> = {
                        ArrowLeft: [-1, 0],
                        ArrowRight: [1, 0],
                        ArrowUp: [0, -1],
                        ArrowDown: [0, 1],
                      };
                      if (!delta[event.key]) return;
                      setCursor([
                        clamp(
                          x + delta[event.key][0],
                          surface.x,
                          surface.x + surface.width - 1,
                        ),
                        clamp(
                          y + delta[event.key][1],
                          surface.y,
                          surface.y + surface.height - 1,
                        ),
                      ]);
                    }
                    event.preventDefault();
                    event.stopPropagation();
                  }}
                  style={{
                    width: surface.width * scale,
                    height: surface.height * scale,
                    imageRendering: 'pixelated',
                    touchAction: 'none',
                    cursor: editable ? 'crosshair' : 'default',
                  }}
                  onPointerDown={(event) => {
                    if (
                      !editable ||
                      !event.isPrimary ||
                      event.button !== 0 ||
                      stroke.current
                    )
                      return;
                    event.currentTarget.setPointerCapture(event.pointerId);
                    setPainting(true);
                    setCursor(null);
                    const point = position(event);
                    stroke.current = {
                      id: event.pointerId,
                      before: current.current,
                      point,
                    };
                    paint(point);
                  }}
                  onPointerMove={(event) => {
                    if (stroke.current?.id === event.pointerId)
                      paint(position(event));
                  }}
                  onPointerUp={finishPointerStroke}
                  onPointerCancel={finishPointerStroke}
                  onLostPointerCapture={finishPointerStroke}
                />
              ) : failed ? (
                'Участок недоступен в этом ракурсе.'
              ) : (
                'Загрузка спрайта…'
              )}
            </Box>
          </Section>
        </Stack.Item>
        <Stack.Item width="145px">
          <Section title={data.practice ? 'На манекене' : 'На персонаже'} fill>
            <Box textAlign="center">
              <canvas
                ref={preview}
                width={SIZE}
                height={SIZE}
                aria-label="Игровой спрайт с татуировкой"
                style={{ width: 96, height: 96, imageRendering: 'pixelated' }}
              />
              <Box color="label">Спрайт 32 × 32</Box>
              <canvas
                ref={actual}
                width={SIZE}
                height={SIZE}
                aria-label="Спрайт в исходном размере"
                style={{ imageRendering: 'pixelated' }}
              />
            </Box>
          </Section>
        </Stack.Item>
      </Stack>
      {editable && (
        <Section title="Чернила">
          {data.palette.map((value, index) => (
            <Button
              key={value}
              selected={color === index + 1}
              tooltip={value}
              aria-label={`Чернила ${pigments[value.toLowerCase()] || value}`}
              onClick={() => setColor(index + 1)}
            >
              <ColorBox color={value} mr={0.5} />
              {pigments[value.toLowerCase()] || value}
            </Button>
          ))}
          <Button
            icon="eraser"
            selected={color === 0}
            onClick={() => setColor(0)}
          >
            Ластик
          </Button>
          <Button
            icon="rotate-left"
            disabled={!history.current.length}
            onClick={() => commit(history.current.pop()!)}
          >
            Отменить штрих
          </Button>
          <Button.Confirm
            disabled={!hasInk}
            confirmContent="Очистить?"
            onClick={() => {
              remember(current.current);
              commit(EMPTY);
            }}
          >
            Очистить
          </Button.Confirm>
        </Section>
      )}
      <Section>
        {artist && (sync === 'timeout' || sync === 'rejected') && (
          <Box mb={1}>
            <Box color="bad" mb={0.5}>
              {sync === 'timeout'
                ? 'Нет подтверждения от сервера.'
                : 'Сервер отклонил изменения.'}{' '}
              Ваш эскиз остался на холсте.
            </Box>
            <Button
              onClick={() => {
                if (sync === 'timeout' && flight.current) {
                  sendPatch(flight.current);
                } else {
                  flight.current = null;
                  flush();
                }
              }}
            >
              Повторить отправку
            </Button>
          </Box>
        )}
        {data.phase === 'draft' &&
          (artist ? (
            <Button
              color="good"
              disabled={!surface || !hasInk || busy}
              onClick={() => act('review')}
            >
              {data.practice ? 'Проверить эскиз' : 'Показать на согласование'}
            </Button>
          ) : (
            <Box inline mr={1}>
              Мастер рисует эскиз.
              <Button ml={1} onClick={() => act('sync')}>
                Обновить эскиз
              </Button>
            </Box>
          ))}
        {data.phase === 'review' && (
          <>
            {canSave && (
              <Box mb={1}>
                <Button.Checkbox
                  {...{ role: 'checkbox' }}
                  aria-checked={save}
                  checked={save}
                  onClick={() =>
                    setSaveChoice({ revision: data.revision, save: !save })
                  }
                >
                  Сохранить для этого персонажа
                </Button.Checkbox>
                <Box color="label">
                  Рисунок появится и в следующих раундах, если поставить
                  галочку.
                </Box>
              </Box>
            )}
            {artist && !data.practice ? (
              <Box inline mr={1}>
                Клиент рассматривает эскиз.
              </Box>
            ) : (
              <Button
                color="good"
                disabled={!surface}
                onClick={() =>
                  act('approve', { revision: data.revision, save })
                }
              >
                {data.practice ? 'Нанести на манекен' : 'Одобрить нанесение'}
              </Button>
            )}
            <Button onClick={() => act('revise', { revision: data.revision })}>
              {artist ? 'Изменить эскиз' : 'Попросить правки'}
            </Button>
          </>
        )}
        {data.phase === 'applying' && (
          <Box inline mr={1}>
            Идёт нанесение татуировки…
          </Box>
        )}
        <Button color="bad" onClick={() => act('cancel')}>
          Прервать сеанс
        </Button>
      </Section>
      {choosing && data.stencils && (
        <StencilLibrary
          stencils={data.stencils}
          busy={busy}
          hasInk={hasInk}
          editable={editable}
        />
      )}
      {choosing && !data.stencils && data.stencilError && (
        <Box color="bad">{data.stencilError}</Box>
      )}
    </>
  );
}

function StencilLibrary({
  stencils,
  busy,
  hasInk,
  editable,
}: {
  stencils: Stencil[];
  busy: boolean;
  hasInk: boolean;
  editable: boolean;
}) {
  const { act, data } = useBackend<StudioData>();
  const [name, setName] = useState('');
  const [selectedId, setSelectedId] = useState<string>();
  const selected =
    stencils.find((stencil) => stencil.id === selectedId) ?? stencils[0];
  const limit = data.stencilLimit ?? 12;
  const trimmedName = name.trim();
  return (
    <Section title={`Мои трафареты · ${stencils.length}/${limit}`}>
      {selected && (
        <Stack align="center" mb={0.5}>
          <Stack.Item grow minWidth={0}>
            <Dropdown
              fluid
              selected={selected.id}
              displayText={selected.name}
              options={stencils.map((stencil) => ({
                value: stencil.id,
                displayText: stencil.name,
              }))}
              onSelected={setSelectedId}
            />
          </Stack.Item>
          <Stack.Item>
            <Button
              disabled={busy || !editable || hasInk}
              tooltip={hasInk ? 'Для трафарета нужен чистый холст' : undefined}
              onClick={() =>
                act('apply_stencil', {
                  id: selected.id,
                  revision: data.revision,
                })
              }
            >
              На холст
            </Button>
            <Button.Confirm
              key={selected.id}
              disabled={busy}
              confirmContent="Удалить трафарет?"
              onClick={() =>
                act('delete_stencil', {
                  id: selected.id,
                  revision: data.revision,
                })
              }
            >
              Удалить
            </Button.Confirm>
          </Stack.Item>
        </Stack>
      )}
      <Stack align="center">
        <Stack.Item grow minWidth={0}>
          <Input
            fluid
            maxLength={32}
            placeholder="Название нового трафарета"
            aria-label="Название нового трафарета"
            value={name}
            onChange={setName}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            disabled={
              busy || !hasInk || !trimmedName || stencils.length >= limit
            }
            tooltip={
              stencils.length >= limit
                ? 'Чтобы сохранить новый трафарет, удалите один из старых'
                : undefined
            }
            onClick={() =>
              act('save_stencil', {
                name: trimmedName,
                revision: data.revision,
              })
            }
          >
            Сохранить эскиз
          </Button>
        </Stack.Item>
      </Stack>
      {data.stencilError && (
        <Box mt={0.5} color="bad">
          {data.stencilError}
        </Box>
      )}
    </Section>
  );
}
