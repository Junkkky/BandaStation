import { afterEach, expect, it, mock, spyOn } from 'bun:test';
import {
  fireEvent,
  act as reactAct,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import { useAtomValue } from 'jotai';
import * as actions from '../events/act';
import { backendStateAtom, gameDataAtom, store } from '../events/store';
import { Dir } from './common/SpriteEditor/Types/types';
import { TattooStudio } from './TattooStudio';

const originalImage = globalThis.Image;
afterEach(() => {
  globalThis.Image = originalImage;
  mock.restore();
});

it('reviews the exact tattoo before removal and only lets the customer or mannequin artist confirm', () => {
  const act = spyOn(actions, 'sendAct');
  const front = { id: 'front', side: 'вид спереди', image: 'front.png' };
  const back = { id: 'back', side: 'вид сзади', image: 'back.png' };
  const draft = {
    mode: 'removal',
    role: 'artist',
    phase: 'draft',
    revision: 1,
    targetName: 'Клиент',
    zone: 'Левая рука',
    tattoos: [front, back],
    selected: null,
  };
  store.set(gameDataAtom, draft);
  const view = render(<TattooStudio />);
  fireEvent.click(screen.getByRole('button', { name: 'вид сзади' }));
  expect(screen.getByRole('img').getAttribute('src')).toBe(back.image);
  fireEvent.click(screen.getByText('Показать клиенту'));
  expect(act).toHaveBeenLastCalledWith('select', { id: back.id, revision: 1 });

  const review = { ...draft, phase: 'review', revision: 2, selected: back.id };
  store.set(gameDataAtom, review);
  view.rerender(<TattooStudio />);
  expect(screen.queryByText('Согласиться на сведение')).toBeNull();
  fireEvent.click(screen.getByText('Выбрать другую'));
  expect(act).toHaveBeenLastCalledWith('revise', { revision: 2 });

  store.set(gameDataAtom, { ...review, role: 'client' });
  view.rerender(<TattooStudio />);
  expect(screen.getByRole('img').getAttribute('src')).toBe(back.image);
  expect(screen.getByText(/из сохранённых татуировок/)).toBeDefined();
  fireEvent.click(screen.getByText('Отказаться'));
  expect(act).toHaveBeenLastCalledWith('cancel');
  fireEvent.click(screen.getByText('Согласиться на сведение'));
  expect(act).toHaveBeenLastCalledWith('approve', { revision: 2 });

  store.set(gameDataAtom, { ...review, practice: 1 });
  view.rerender(<TattooStudio />);
  fireEvent.click(screen.getByText('Свести с манекена'));
  expect(act).toHaveBeenLastCalledWith('approve', { revision: 2 });

  store.set(gameDataAtom, { ...review, phase: 'applying' });
  view.rerender(<TattooStudio />);
  expect(screen.getByText('Идёт сведение татуировки…')).toBeDefined();
  fireEvent.click(screen.getByText('Прервать сеанс'));
  expect(act).toHaveBeenLastCalledWith('cancel');
});

function mockLimb(mask = new Uint8ClampedArray(32 * 32 * 4).fill(255)) {
  const fillRect = mock();
  globalThis.Image = class extends originalImage {
    set src(_url: string) {
      this.width = this.height = 32;
      this.dispatchEvent(new Event('load'));
    }
  };
  spyOn(HTMLCanvasElement.prototype, 'getContext').mockReturnValue({
    clearRect() {},
    drawImage() {},
    fillRect,
    save() {},
    restore() {},
    getImageData: () => ({ data: mask }),
  } as unknown as CanvasRenderingContext2D);
  return fillRect;
}

const artistDraft = {
  role: 'artist',
  phase: 'draft',
  revision: 1,
  palette: ['#262638'],
  body: 'body.png',
  mask: 'mask.png',
};
const centerDot = '1'.padStart(2081, '0').padEnd(4096, '0');

it('chooses an angle for drawing and shows all four views for approval', async () => {
  mockLimb();
  const act = spyOn(actions, 'sendAct');
  const draft = { ...artistDraft, direction: Dir.SOUTH };
  const tattooViews = [
    { direction: Dir.EAST, image: 'east.png' },
    { direction: Dir.NORTH, image: 'north.png' },
    { direction: Dir.WEST, image: 'west.png' },
    { direction: Dir.SOUTH, image: 'south.png' },
  ];
  store.set(gameDataAtom, { ...draft, tattooViews });
  const view = render(<TattooStudio />);
  await screen.findByLabelText('Эскиз на выбранном участке кожи');
  expect(screen.queryAllByRole('img')).toHaveLength(0);
  fireEvent.click(screen.getByText('Лицом вправо'));
  expect(act).toHaveBeenLastCalledWith('direction', { direction: Dir.EAST });

  const inked = { ...draft, draft: centerDot, revision: 2 };
  store.set(gameDataAtom, inked);
  view.rerender(<TattooStudio />);
  fireEvent.click(screen.getByText('Лицом влево'));
  expect(act).toHaveBeenCalledTimes(1);

  for (const [phase, role] of [
    ['review', 'artist'],
    ['review', 'client'],
    ['applying', 'client'],
  ]) {
    store.set(gameDataAtom, { ...inked, phase, role, tattooViews });
    await reactAct(async () => view.rerender(<TattooStudio />));
    expect(
      screen
        .getAllByRole('img')
        .map((image) => [image.getAttribute('alt'), image.getAttribute('src')]),
    ).toEqual([
      ['Татуировка · Спереди', 'south.png'],
      ['Татуировка · Со спины', 'north.png'],
      ['Татуировка · Лицом вправо', 'east.png'],
      ['Татуировка · Лицом влево', 'west.png'],
    ]);
    if (phase === 'review' && role === 'client') {
      fireEvent.click(screen.getByText('Одобрить нанесение'));
      expect(act).toHaveBeenLastCalledWith('approve', {
        revision: 2,
        save: false,
      });
    } else {
      expect(screen.queryByText('Одобрить нанесение')).toBeNull();
    }
  }
});

it('updates the watching customer from server strokes through review without reopening', async () => {
  const ink = mockLimb();
  const act = spyOn(actions, 'sendAct');
  // RoutedComponent subscribes to the backend atom and renders the active interface.
  function CustomerWindow() {
    useAtomValue(backendStateAtom, { store });
    return <TattooStudio />;
  }
  const customer = { ...artistDraft, role: 'client' };
  store.set(gameDataAtom, customer);
  render(<CustomerWindow />);
  await screen.findByLabelText('Эскиз на выбранном участке кожи');
  expect(ink).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText('Обновить эскиз'));
  expect(act).toHaveBeenLastCalledWith('sync');
  await reactAct(async () =>
    store.set(gameDataAtom, { ...customer, draft: centerDot, revision: 2 }),
  );
  expect(ink).toHaveBeenCalledWith(32, 32, 1, 1);
  await reactAct(async () =>
    store.set(gameDataAtom, {
      ...customer,
      draft: centerDot,
      revision: 3,
      phase: 'review',
    }),
  );
  expect(screen.queryByText('Мастер рисует эскиз.')).toBeNull();
  fireEvent.click(screen.getByText('Одобрить нанесение'));
  expect(act).toHaveBeenLastCalledWith('approve', { revision: 3, save: false });
});

it('uploads a large edit in URL-safe batches and keeps newer strokes until every batch is acknowledged', async () => {
  mockLimb();
  spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue(undefined);
  const act = spyOn(actions, 'sendAct');
  const original = '1'.repeat(810).padEnd(4096, '0');
  store.set(gameDataAtom, { ...artistDraft, draft: original });
  const view = render(<TattooStudio />);
  const canvas = await screen.findByLabelText(
    'Эскиз на выбранном участке кожи',
  );
  fireEvent.click(screen.getByText('Очистить'));
  fireEvent.click(screen.getByText('Очистить?'));
  fireEvent.keyDown(canvas, { key: ' ' });
  store.set(gameDataAtom, {
    ...artistDraft,
    draft: original,
    stencilError: 'Ошибка имени',
  });
  view.rerender(<TattooStudio />);
  for (const [batch, count] of [400, 400, 11].entries()) {
    const [action, args] = act.mock.calls[batch]!;
    expect(action).toBe('draw_patch');
    expect(args?.revision).toBe(batch + 1);
    const patch = String(args?.patch);
    expect(patch).toHaveLength(count * 3);
    expect(encodeURIComponent(patch)).toBe(patch);
    expect(encodeURIComponent(JSON.stringify(args)).length).toBeLessThan(1800);
    if (batch === 0) expect(patch.slice(0, 6)).toBe('000010');
    if (batch === 2) expect(patch.slice(-3)).toBe('WW1');
    fireEvent.click(screen.getByText('Показать на согласование'));
    expect(act).toHaveBeenCalledTimes(batch + 1);
    const changed = (batch + 1) * 400;
    const remote =
      batch === 2 ? centerDot : '0'.repeat(changed) + original.slice(changed);
    store.set(gameDataAtom, {
      ...artistDraft,
      draft: remote,
      revision: batch + 2,
    });
    view.rerender(<TattooStudio />);
  }
  fireEvent.click(screen.getByText('Показать на согласование'));
  expect(act).toHaveBeenLastCalledWith('review');
});

it('retries a missing acknowledgement a bounded number of times and allows manual recovery', async () => {
  mockLimb();
  spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue(undefined);
  const act = spyOn(actions, 'sendAct');
  store.set(gameDataAtom, artistDraft);
  const view = render(<TattooStudio />);
  const canvas = await screen.findByLabelText(
    'Эскиз на выбранном участке кожи',
  );
  const timers = spyOn(window, 'setTimeout');
  fireEvent.keyDown(canvas, { key: ' ' });
  for (let i = 0; i < 3; i++) {
    expect(act).toHaveBeenLastCalledWith('draw_patch', {
      patch: 'WW1',
      revision: 1,
    });
    const index = timers.mock.calls.findLastIndex(
      ([, delay]) => delay === 2000,
    );
    const timer = timers.mock.results[index];
    expect(timer.type).toBe('return');
    window.clearTimeout(timer.value as ReturnType<typeof window.setTimeout>);
    const callback = timers.mock.calls[index][0];
    reactAct(() => callback());
  }
  expect(timers.mock.calls.filter(([, delay]) => delay === 2000)).toHaveLength(
    3,
  );
  expect(act).toHaveBeenCalledTimes(3);
  fireEvent.click(screen.getByText('Повторить отправку'));
  expect(act).toHaveBeenCalledTimes(4);
  store.set(gameDataAtom, {
    ...artistDraft,
    drawRejected: 1,
    drawRejectedRevision: 1,
  });
  view.rerender(<TattooStudio />);
  expect(screen.getByText(/Сервер отклонил изменения/)).toBeDefined();
  fireEvent.click(screen.getByText('Повторить отправку'));
  expect(act).toHaveBeenLastCalledWith('draw_patch', {
    patch: 'WW1',
    revision: 1,
  });
  store.set(gameDataAtom, {
    ...artistDraft,
    draft: centerDot,
    revision: 2,
    drawRejected: 1,
    drawRejectedRevision: 1,
  });
  view.rerender(<TattooStudio />);
  expect(screen.queryByText('Повторить отправку')).toBeNull();
  fireEvent.click(screen.getByText('Показать на согласование'));
  expect(act).toHaveBeenLastCalledWith('review');
});

it('saves an acknowledged sketch, applies the stencil to a blank canvas and edits it', async () => {
  mockLimb();
  spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue(undefined);
  const act = spyOn(actions, 'sendAct');
  const draft = {
    role: 'artist',
    phase: 'draft',
    revision: 1,
    palette: ['#262638'],
    body: 'body.png',
    mask: 'mask.png',
    stencils: [],
  };
  store.set(gameDataAtom, draft);
  const view = render(<TattooStudio />);
  const canvas = await screen.findByLabelText(
    'Эскиз на выбранном участке кожи',
  );
  const name = screen.getByRole('textbox', {
    name: 'Название нового трафарета',
  });
  expect(name.getAttribute('maxlength')).toBe('32');
  fireEvent.input(name, { target: { value: '  Солнце  ' } });
  fireEvent.click(screen.getByText('Сохранить эскиз'));
  expect(act).not.toHaveBeenCalled();

  fireEvent.keyDown(canvas, { key: ' ' });
  expect(act).toHaveBeenLastCalledWith('draw_patch', {
    patch: 'WW1',
    revision: 1,
  });
  const pixels = centerDot;
  fireEvent.click(screen.getByText('Сохранить эскиз'));
  expect(act).toHaveBeenCalledTimes(1);
  store.set(gameDataAtom, { ...draft, draft: pixels, revision: 2 });
  view.rerender(<TattooStudio />);
  fireEvent.click(screen.getByText('Сохранить эскиз'));
  expect(act).toHaveBeenLastCalledWith('save_stencil', {
    name: 'Солнце',
    revision: 2,
  });

  const library = { ...draft, stencils: [{ id: 'sun', name: 'Солнце' }] };
  store.set(gameDataAtom, { ...library, draft: pixels, revision: 2 });
  view.rerender(<TattooStudio />);
  fireEvent.click(screen.getByText('На холст'));
  expect(act).toHaveBeenCalledTimes(2);
  store.set(gameDataAtom, { ...library, revision: 3 });
  view.rerender(<TattooStudio />);
  fireEvent.click(screen.getByText('На холст'));
  expect(act).toHaveBeenLastCalledWith('apply_stencil', {
    id: 'sun',
    revision: 3,
  });
  store.set(gameDataAtom, { ...library, draft: pixels, revision: 4 });
  view.rerender(<TattooStudio />);
  fireEvent.keyDown(canvas, { key: 'ArrowRight' });
  fireEvent.keyDown(canvas, { key: ' ' });
  expect(act).toHaveBeenLastCalledWith('draw_patch', {
    patch: 'WX1',
    revision: 4,
  });
});

it('confirms deletion of the selected personal stencil and hides the library from the customer', async () => {
  mockLimb();
  const act = spyOn(actions, 'sendAct');
  const draft = {
    role: 'artist',
    phase: 'draft',
    revision: 3,
    palette: ['#262638'],
    draft: '1'.padEnd(4096, '0'),
    body: 'body.png',
    mask: 'mask.png',
    stencils: [
      { id: 'sun', name: 'Солнце' },
      { id: 'moon', name: 'Луна' },
    ],
    stencilLimit: 2,
    stencilError: 'В картридже нет нужного пигмента.',
  };
  store.set(gameDataAtom, draft);
  const view = render(<TattooStudio />);
  await screen.findByLabelText('Эскиз на выбранном участке кожи');
  expect(screen.getByText('Мои трафареты · 2/2')).toBeDefined();
  expect(screen.getByText(draft.stencilError)).toBeDefined();
  fireEvent.input(
    screen.getByRole('textbox', { name: 'Название нового трафарета' }),
    {
      target: { value: 'Третий' },
    },
  );
  fireEvent.click(screen.getByText('Сохранить эскиз'));
  expect(act).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText('Солнце'));
  fireEvent.click(await screen.findByText('Луна'));
  fireEvent.click(screen.getByText('Удалить'));
  expect(act).not.toHaveBeenCalled();
  fireEvent.click(screen.getByText('Удалить трафарет?'));
  expect(act).toHaveBeenLastCalledWith('delete_stencil', {
    id: 'moon',
    revision: 3,
  });
  for (const change of [
    { role: 'client' },
    { phase: 'review' },
    { stencils: null, stencilError: null },
  ]) {
    store.set(gameDataAtom, { ...draft, ...change });
    await reactAct(async () => view.rerender(<TattooStudio />));
    expect(screen.queryByText(/Мои трафареты/)).toBeNull();
    expect(screen.queryByText(draft.stencilError)).toBeNull();
  }
  store.set(gameDataAtom, {
    ...draft,
    stencils: null,
    stencilError: 'Личная библиотека недоступна.',
  });
  await reactAct(async () => view.rerender(<TattooStudio />));
  expect(screen.getByText('Личная библиотека недоступна.')).toBeDefined();
  expect(screen.queryByText('Сохранить эскиз')).toBeNull();
});

it('plays a local motor while a stroke lays down fresh ink and stops on idle or release', async () => {
  const mask = new Uint8ClampedArray(32 * 32 * 4).fill(255);
  mask[3] = 0;
  mockLimb(mask);
  const play = spyOn(HTMLMediaElement.prototype, 'play').mockResolvedValue(
    undefined,
  );
  const pause = spyOn(HTMLMediaElement.prototype, 'pause').mockImplementation(
    () => {},
  );
  const act = spyOn(actions, 'sendAct');
  store.set(gameDataAtom, {
    role: 'artist',
    phase: 'draft',
    palette: ['#262638'],
    revision: 1,
    body: 'body.png',
    mask: 'mask.png',
  });
  const view = render(<TattooStudio />);
  const canvas = await screen.findByLabelText(
    'Эскиз на выбранном участке кожи',
  );
  Object.assign(canvas, {
    getBoundingClientRect: () => new DOMRect(0, 0, 64, 64),
    setPointerCapture() {},
  });
  const pointer = (type: string, x: number) =>
    fireEvent(
      canvas,
      new PointerEvent(type, {
        bubbles: true,
        isPrimary: true,
        button: 0,
        pointerId: 1,
        clientX: x,
        clientY: 0,
      }),
    );
  pointer('pointerdown', 0);
  expect(play).not.toHaveBeenCalled();
  pointer('pointermove', 4);
  expect(play).toHaveBeenCalledTimes(1);
  expect(act).not.toHaveBeenCalled();
  pointer('pointermove', 7);
  expect(play).toHaveBeenCalledTimes(1);
  await waitFor(() => expect(pause).toHaveBeenCalledTimes(1));
  expect(act.mock.calls[0]?.[0]).toBe('draw_patch');
  pointer('pointermove', 7);
  expect(play).toHaveBeenCalledTimes(1);
  pointer('pointermove', 8);
  expect(play).toHaveBeenCalledTimes(2);
  pointer('pointerup', 8);
  expect(pause).toHaveBeenCalledTimes(2);
  fireEvent.click(screen.getByText('Ластик'));
  pointer('pointerdown', 8);
  pointer('pointercancel', 8);
  expect(play).toHaveBeenCalledTimes(2);
  fireEvent.click(screen.getByText('Графит'));
  pointer('pointerdown', 8);
  expect(play).toHaveBeenCalledTimes(3);
  pointer('pointercancel', 8);
  expect(pause).toHaveBeenCalledTimes(3);
  pointer('pointerdown', 9);
  pointer('lostpointercapture', 9);
  expect(pause).toHaveBeenCalledTimes(4);
  play.mockRejectedValueOnce(
    new DOMException('Playback interrupted', 'AbortError'),
  );
  pointer('pointerdown', 10);
  view.unmount();
  expect(pause).toHaveBeenCalledTimes(5);
});

it.each([
  0, 1,
])('allows the customer to override save preference %i for one revision', async (saveByDefault) => {
  mockLimb();
  const act = spyOn(actions, 'sendAct');
  const review = {
    role: 'client',
    phase: 'review',
    canSave: 1,
    saveByDefault,
    revision: 1,
    palette: [],
    body: 'body.png',
    mask: 'mask.png',
  };
  store.set(gameDataAtom, review);
  const view = render(<TattooStudio />);
  await screen.findByLabelText('Эскиз на выбранном участке кожи');
  const checkbox = screen.getByRole('checkbox', {
    name: 'Сохранить для этого персонажа',
  });
  const approve = screen.getByText('Одобрить нанесение');
  expect(checkbox.getAttribute('aria-checked')).toBe(String(!!saveByDefault));
  fireEvent.click(approve);
  expect(act).toHaveBeenLastCalledWith('approve', {
    revision: 1,
    save: !!saveByDefault,
  });

  fireEvent.click(checkbox);
  fireEvent.click(approve);
  expect(act).toHaveBeenLastCalledWith('approve', {
    revision: 1,
    save: !saveByDefault,
  });
  store.set(gameDataAtom, { ...review, revision: 2 });
  view.rerender(<TattooStudio />);
  expect(checkbox.getAttribute('aria-checked')).toBe(String(!!saveByDefault));
  fireEvent.click(approve);
  expect(act).toHaveBeenLastCalledWith('approve', {
    revision: 2,
    save: !!saveByDefault,
  });

  for (const change of [
    { canSave: 0 },
    { role: 'artist' },
    { role: 'artist', practice: 1 },
  ]) {
    store.set(gameDataAtom, { ...review, ...change });
    await reactAct(async () => view.rerender(<TattooStudio />));
    expect(screen.queryByRole('checkbox')).toBeNull();
  }
});
