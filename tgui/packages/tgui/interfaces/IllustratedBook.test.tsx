import { beforeEach, describe, expect, it, spyOn } from 'bun:test';
import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from '@testing-library/react';
import { storage } from 'common/storage';
import * as actions from '../events/act';
import { configAtom, gameDataAtom, sharedAtom, store } from '../events/store';
import { IllustratedBook } from './IllustratedBook';

const book = {
  title: 'Хроника',
  author: 'Иван',
  canEdit: 1,
  canIllustrate: 1,
  canImportIllustration: 1,
  revision: 1,
  maxPages: 16,
  maxTextLength: 1000,
  maxCaptionLength: 120,
  pages: [
    { text: 'Первая', image: 'aaaa', caption: 'Снимок' },
    { text: 'Вторая' },
    { text: 'Третья' },
  ],
};

function openPageEditor(value: string) {
  render(<IllustratedBook />);
  fireEvent.click(screen.getAllByText('Править')[0]);
  const field = screen.getByLabelText<HTMLTextAreaElement>('Текст страницы 1');
  fireEvent.change(field, { target: { value } });
  field.focus();
  return field;
}

function prepareBookmarkTest() {
  const saved = new Map<string, unknown>();
  const read = spyOn(storage, 'get').mockImplementation(async (key) =>
    saved.get(key),
  );
  const write = spyOn(storage, 'set').mockImplementation(async (key, value) => {
    saved.set(key, value);
  });
  const channel = spyOn(Byond, 'sendMessage').mockImplementation((message) => {
    if (typeof message === 'object' && message.type === 'setSharedState') {
      store.set(sharedAtom, (prev) => ({
        ...prev,
        [message.key]: JSON.parse(message.value),
      }));
    }
  });
  const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
  const config = store.get(configAtom);
  const shared = store.get(sharedAtom);
  function select(ckey: string, key: string, markers: Record<string, unknown>) {
    store.set(configAtom, {
      ...config,
      client: { ...config.client, ckey },
      window: { ...config.window, key },
    });
    store.set(sharedAtom, markers);
  }
  select('book_reader', '[0x2043]-main', {});
  store.set(gameDataAtom, {
    ...book,
    canEdit: 0,
    canIllustrate: 0,
    hasBookCover: 1,
  });
  return {
    select,
    write,
    send,
    restore() {
      store.set(configAtom, config);
      store.set(sharedAtom, shared);
      read.mockRestore();
      write.mockRestore();
      channel.mockRestore();
      send.mockRestore();
    },
  };
}

describe('IllustratedBook', () => {
  beforeEach(() => {
    store.set(gameDataAtom, book);
  });

  it('opens a reader on the cover and returns to it from the first spread', () => {
    store.set(gameDataAtom, {
      ...book,
      hasBookCover: 1,
      canEdit: 0,
      canIllustrate: 0,
      coverImage: 'Y292ZXI=',
    });
    const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
    render(<IllustratedBook />);
    const cover = screen.getByRole('button', {
      name: 'Открыть книгу «Хроника»',
    });
    expect(cover.textContent).toContain('Иван');
    expect(
      screen.getByAltText('Иллюстрация на обложке').getAttribute('src'),
    ).toBe('data:image/png;base64,Y292ZXI=');
    expect(screen.queryByText('Оформить обложку')).toBeNull();
    expect(screen.queryByText('Вторая')).toBeNull();
    fireEvent.click(cover);
    expect(screen.getByText('Вторая')).toBeDefined();
    fireEvent.click(screen.getByText('Вперёд'));
    expect(screen.getByText('Третья')).toBeDefined();
    fireEvent.click(screen.getByText('Назад'));
    fireEvent.click(screen.getByText('К обложке'));
    expect(
      screen.getByRole('button', { name: 'Открыть книгу «Хроника»' }),
    ).toBeDefined();
    send.mockRestore();
  });

  it('reads a caption without a pen and keeps the stop action available away from that page', () => {
    const held = {
      ...book,
      hasBookCover: 1,
      canEdit: 0,
      canIllustrate: 0,
      canReadAloud: 1,
      readAloudVoiceEnabled: 1,
      pages: [
        { text: '  ', image: 'aaaa' },
        { text: '', image: 'aaaa', caption: 'Снимок' },
        { text: 'Запись' },
      ],
    };
    store.set(gameDataAtom, held);
    const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
    try {
      const { rerender } = render(<IllustratedBook />);
      fireEvent.click(
        screen.getByRole('button', { name: 'Открыть книгу «Хроника»' }),
      );
      expect(screen.getAllByText('Читать вслух')).toHaveLength(1);
      fireEvent.click(screen.getByText('Читать вслух'));
      expect(send).toHaveBeenLastCalledWith('read_aloud', {
        page: 2,
        revision: 1,
      });
      store.set(gameDataAtom, { ...held, readingPage: 2 });
      rerender(<IllustratedBook />);
      expect(screen.getByRole('status').textContent).toBe(
        'Вы читаете страницу 2',
      );
      fireEvent.click(screen.getByText('Вперёд'));
      expect(screen.queryByText('Читать вслух')).toBeNull();
      expect(screen.getByText('Остановить чтение')).toBeDefined();
      fireEvent.click(screen.getByText('Назад'));
      fireEvent.click(screen.getByText('К обложке'));
      fireEvent.click(screen.getByText('Остановить чтение'));
      expect(send).toHaveBeenLastCalledWith('stop_reading');
    } finally {
      send.mockRestore();
    }
  });

  it('offers chat-only reading when speech synthesis is off and hides controls without permission', () => {
    const { rerender } = render(<IllustratedBook />);
    expect(screen.queryByText('Зачитать в чат')).toBeNull();
    expect(screen.queryByText('Читать вслух')).toBeNull();
    store.set(gameDataAtom, {
      ...book,
      canReadAloud: 1,
      readAloudVoiceEnabled: 0,
    });
    rerender(<IllustratedBook />);
    expect(screen.getAllByText('Зачитать в чат')).toHaveLength(2);
    store.set(gameDataAtom, {
      ...book,
      canReadAloud: 0,
      readAloudVoiceEnabled: 1,
    });
    rerender(<IllustratedBook />);
    expect(screen.queryByText('Читать вслух')).toBeNull();
    expect(screen.queryByText('Зачитать в чат')).toBeNull();
  });

  it('resumes the last spread and lets a reader pin, move and remove a bookmark', async () => {
    const { write, send, restore } = prepareBookmarkTest();
    const first = render(<IllustratedBook />);
    fireEvent.click(
      screen.getByRole('button', { name: 'Открыть книгу «Хроника»' }),
    );
    fireEvent.click(screen.getByText('Вперёд'));
    await waitFor(() => expect(write).toHaveBeenCalled());
    first.unmount();

    const resumed = render(<IllustratedBook />);
    fireEvent.click(await screen.findByText('Продолжить чтение · разворот 2'));
    expect(screen.getByText('Третья')).toBeDefined();
    fireEvent.click(screen.getByText('Заложить страницу'));
    expect(await screen.findByText('Снять закладку')).toBeDefined();
    resumed.unmount();

    render(<IllustratedBook />);
    expect(await screen.findByText('К закладке · разворот 2')).toBeDefined();
    fireEvent.click(
      screen.getByRole('button', { name: 'Открыть книгу «Хроника»' }),
    );
    expect(screen.getByText('Вторая')).toBeDefined();
    fireEvent.click(screen.getByText('К обложке'));
    fireEvent.click(screen.getByText('К закладке · разворот 2'));
    expect(
      screen.getByText('Третья').closest('.IllustratedBook__leaf--bookmarked'),
    ).not.toBeNull();
    fireEvent.click(screen.getByText('Назад'));
    fireEvent.click(screen.getByText('Перенести закладку сюда'));
    fireEvent.click(await screen.findByText('Снять закладку'));
    expect(screen.getByText('Заложить страницу')).toBeDefined();
    expect(
      send.mock.calls.every(([action]) => action === 'play_flip_sound'),
    ).toBe(true);
    restore();
  });

  it('keeps a pinned spread private to the reader and the original physical copy', async () => {
    const { select, write, restore } = prepareBookmarkTest();
    try {
      const original = render(<IllustratedBook />);
      fireEvent.click(
        screen.getByRole('button', { name: 'Открыть книгу «Хроника»' }),
      );
      fireEvent.click(screen.getByText('Вперёд'));
      await waitFor(() => expect(write).toHaveBeenCalled());
      fireEvent.click(screen.getByText('Заложить страницу'));
      expect(await screen.findByText('Снять закладку')).toBeDefined();
      original.unmount();

      const originalMarker = store.get(sharedAtom);
      for (const [reader, copy, marker, shouldResume] of [
        ['other_reader', '[0x2043]-main', originalMarker, false],
        ['book_reader', '[0x2044]-main', originalMarker, false],
        ['book_reader', '[0x2043]-main', {}, false],
        ['book_reader', '[0x2043]-main', originalMarker, true],
      ] as const) {
        select(reader, copy, marker);
        const reopened = render(<IllustratedBook />);
        await act(() => Promise.resolve());
        expect(!!screen.queryByText('К закладке · разворот 2')).toBe(
          shouldResume,
        );
        reopened.unmount();
      }
    } finally {
      restore();
    }
  });

  it('keeps the original cover editor on a server without binding colors', () => {
    store.set(gameDataAtom, { ...book, hasBookCover: 1 });
    render(<IllustratedBook />);
    fireEvent.click(screen.getByText('Оформить обложку'));
    expect(screen.queryByRole('group', { name: 'Цвет переплёта' })).toBeNull();
    expect(screen.getByText('Иллюстрация по ссылке')).toBeDefined();
  });

  it('previews and saves the cover image and binding color together', () => {
    const edition = {
      ...book,
      hasBookCover: 1,
      coverImage: null,
      bindingColor: null,
    };
    store.set(gameDataAtom, edition);
    const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
    const { rerender } = render(<IllustratedBook />);
    fireEvent.click(screen.getByText('Оформить обложку'));
    fireEvent.click(screen.getByRole('radio', { name: 'Синий' }));
    fireEvent.click(screen.getByText('Иллюстрация по ссылке'));
    const url = 'https://file.garden/test/cover.png';
    fireEvent.change(screen.getByLabelText('Ссылка на PNG или JPEG'), {
      target: { value: url },
    });
    fireEvent.click(screen.getByText('Показать на обложке'));
    const requestId = send.mock.calls.at(-1)?.[1]?.requestId;
    expect(send).toHaveBeenCalledWith('preview_illustration', {
      page: 'cover',
      revision: 1,
      url,
      requestId: expect.any(String),
    });
    const image = 'Y292ZXI=';
    store.set(gameDataAtom, {
      ...edition,
      illustrationPreview: { requestId, image },
    });
    rerender(<IllustratedBook />);
    expect(
      screen.getByAltText('Иллюстрация на обложке').getAttribute('src'),
    ).toBe(`data:image/png;base64,${image}`);
    fireEvent.click(screen.getByText('Сохранить обложку'));
    expect(send).toHaveBeenCalledWith('save_cover', {
      revision: 1,
      illustrationRequestId: requestId,
      bindingColor: 'blue',
    });
    store.set(gameDataAtom, {
      ...edition,
      revision: 2,
      coverImage: image,
      bindingColor: 'blue',
    });
    rerender(<IllustratedBook />);
    expect(screen.getByText('Оформить обложку')).toBeDefined();
    expect(
      screen.getByAltText('Иллюстрация на обложке').getAttribute('src'),
    ).toBe(`data:image/png;base64,${image}`);
    send.mockRestore();
  });

  it('previews, cancels and saves a binding without altering existing artwork', () => {
    const edition = {
      ...book,
      hasBookCover: 1,
      coverImage: 'Y292ZXI=',
      bindingColor: null,
    };
    store.set(gameDataAtom, edition);
    const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
    const { rerender } = render(<IllustratedBook />);
    fireEvent.click(screen.getByText('Оформить обложку'));
    fireEvent.click(screen.getByRole('radio', { name: 'Красный' }));
    const binding = () =>
      document
        .querySelector('.IllustratedBook')
        ?.getAttribute('data-book-binding');
    expect(binding()).toBe('red');
    fireEvent.click(screen.getByText('К обложке'));
    expect(binding()).toBeNull();
    expect(send).not.toHaveBeenCalled();

    fireEvent.click(screen.getByText('Оформить обложку'));
    fireEvent.click(screen.getByRole('radio', { name: 'Зелёный' }));
    fireEvent.click(screen.getByText('Сохранить обложку'));
    expect(send).toHaveBeenCalledWith('save_cover', {
      revision: 1,
      bindingColor: 'green',
    });
    store.set(gameDataAtom, { ...edition, revision: 2, bindingColor: 'green' });
    rerender(<IllustratedBook />);
    fireEvent.click(
      screen.getByRole('button', { name: 'Открыть книгу «Хроника»' }),
    );
    expect(binding()).toBe('green');
    send.mockRestore();
  });

  it('allows held art without a pen and refuses a stale cover edit', () => {
    const edition = { ...book, hasBookCover: 1, canEdit: 0 };
    store.set(gameDataAtom, edition);
    const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
    const { rerender } = render(<IllustratedBook />);
    fireEvent.click(screen.getByText('Оформить обложку'));
    expect(screen.queryByText('Иллюстрация по ссылке')).toBeNull();
    fireEvent.click(screen.getByText('Взять изображение из руки'));
    expect(send).toHaveBeenCalledWith('attach_cover', { revision: 1 });
    expect(screen.getByText('Взять изображение из руки')).toBeDefined();
    store.set(gameDataAtom, {
      ...edition,
      revision: 2,
      coverImage: 'Y292ZXI=',
    });
    rerender(<IllustratedBook />);
    fireEvent.click(screen.getByText('Оформить обложку'));
    store.set(gameDataAtom, {
      ...edition,
      revision: 3,
      coverImage: 'Y292ZXI=',
    });
    rerender(<IllustratedBook />);
    expect(screen.getByRole('status').textContent).toContain(
      'Книгу уже изменили',
    );
    fireEvent.click(screen.getByText('Взять изображение из руки'));
    expect(send).toHaveBeenCalledTimes(1);
    send.mockRestore();
  });

  it.each([
    ['Жирный', '**'],
    ['Курсив', '*'],
  ])('%s wraps the selected word and can remove the same formatting', (name, mark) => {
    const before = 'До ';
    const word = 'смены';
    const after = ' и после.';
    const field = openPageEditor(before + word + after);
    const button = screen.getByRole('button', { name });
    field.setSelectionRange(before.length, before.length + word.length);
    button.focus();
    fireEvent.click(button);
    expect(field.value).toBe(before + mark + word + mark + after);
    expect(document.activeElement).toBe(field);
    expect(field.value.slice(field.selectionStart, field.selectionEnd)).toBe(
      word,
    );
    fireEvent.click(button);
    expect(field.value).toBe(before + word + after);
  });

  it('removes bold without losing the italic style on the same word', () => {
    const field = openPageEditor('До *смены* и после');
    const start = field.value.indexOf('смены');
    field.setSelectionRange(start, start + 'смены'.length);
    const bold = screen.getByRole('button', { name: 'Жирный' });
    fireEvent.click(bold);
    expect(field.value).toBe('До ***смены*** и после');
    fireEvent.click(bold);
    expect(field.value).toBe('До *смены* и после');
  });

  it.each([
    ['Жирный', 'strong', '**одно** и **два**', 'одно и два'],
    ['Курсив', 'em', '*ветер* и *пыль*', 'ветер и пыль'],
  ])('%s formats the whole phrase and restores its separate spans', (name, tag, original, phrase) => {
    const field = openPageEditor(original);
    field.setSelectionRange(0, original.length);
    const button = screen.getByRole('button', { name });
    fireEvent.click(button);
    const preview = screen.getByText('Предпросмотр').closest('section')!;
    expect(
      Array.from(preview.querySelectorAll(tag)).some(
        (span) => span.textContent === phrase,
      ),
    ).toBe(true);

    fireEvent.click(button);
    expect(field.value).toBe(original);
    expect(field.selectionStart).toBe(0);
    expect(field.selectionEnd).toBe(original.length);
  });

  it.each([
    ['Жирный', '**'],
    ['Курсив', '*'],
  ])('%s leaves the cursor between the new markers', async (name, mark) => {
    const field = openPageEditor('АБ');
    field.setSelectionRange(1, 1);
    fireEvent.click(screen.getByRole('button', { name }));
    expect(field.value).toBe(`А${mark}${mark}Б`);
    await waitFor(() => {
      expect(field.selectionStart).toBe(1 + mark.length);
      expect(field.selectionEnd).toBe(1 + mark.length);
    });
  });

  it.each([
    ['Заголовок', '## Один\n## Два'],
    ['Подзаголовок', '### Один\n### Два'],
    ['Маркированный список', '- Один\n- Два'],
    ['Нумерованный список', '1. Один\n2. Два'],
  ])('%s toggles only the lines touched by the selection', (name, formatted) => {
    const before = 'Сверху\n';
    const lines = 'Один\nДва';
    const after = '\nСнизу';
    const field = openPageEditor(before + lines + after);
    const button = screen.getByRole('button', { name });
    field.setSelectionRange(
      before.length + 1,
      before.length + lines.length + 1,
    );
    fireEvent.click(button);
    expect(field.value).toBe(before + formatted + after);

    field.setSelectionRange(
      before.length,
      before.length + formatted.length + 1,
    );
    fireEvent.click(button);
    expect(field.value).toBe(before + lines + after);
  });

  it('keeps text and caption until the server acknowledges the edit', () => {
    const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
    const { rerender } = render(<IllustratedBook />);
    fireEvent.click(screen.getAllByText('Править')[0]);
    const text = 'Исправленный текст';
    const caption = 'Новая подпись';
    fireEvent.change(screen.getByLabelText('Текст страницы 1'), {
      target: { value: text },
    });
    fireEvent.change(screen.getByLabelText('Подпись к иллюстрации'), {
      target: { value: caption },
    });
    fireEvent.click(screen.getByText('Сохранить'));
    expect(send).toHaveBeenCalledWith('save_page', {
      page: 1,
      revision: 1,
      text,
      caption,
    });
    expect(screen.getByLabelText('Текст страницы 1')).toBeDefined();

    store.set(gameDataAtom, {
      ...book,
      revision: 2,
      pages: [{ ...book.pages[0], text, caption }, ...book.pages.slice(1)],
    });
    rerender(<IllustratedBook />);
    expect(screen.queryByLabelText('Текст страницы 1')).toBeNull();
    expect(screen.getByAltText(caption)).toBeDefined();
    send.mockRestore();
  });

  it('previews the imported copy and saves it together with the manuscript', () => {
    const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
    const { rerender } = render(<IllustratedBook />);
    fireEvent.click(screen.getAllByText('Править')[1]);
    const field = screen.getByLabelText('Текст страницы 2');
    const text = 'Записки куратора';
    const caption = 'В библиотеке';
    const url = 'https://file.garden/test/portrait.jpg';
    const image = 'aW1hZ2U=';
    fireEvent.change(field, { target: { value: text } });
    fireEvent.click(screen.getByText('Иллюстрация по ссылке'));
    fireEvent.change(screen.getByLabelText('Ссылка на PNG или JPEG'), {
      target: { value: url },
    });
    fireEvent.click(screen.getByText('Показать на странице'));
    const requestId = send.mock.calls.at(-1)?.[1]?.requestId;
    expect(send).toHaveBeenCalledWith('preview_illustration', {
      page: 2,
      revision: 1,
      url,
      requestId: expect.any(String),
    });
    fireEvent.click(screen.getByText('Сохранить'));
    expect(send).toHaveBeenCalledTimes(1);
    store.set(gameDataAtom, {
      ...book,
      illustrationPreview: { requestId, image },
    });
    rerender(<IllustratedBook />);
    expect(
      screen.getByAltText('Иллюстрация к странице').getAttribute('src'),
    ).toBe(`data:image/png;base64,${image}`);
    fireEvent.change(screen.getByLabelText('Подпись к иллюстрации'), {
      target: { value: caption },
    });
    fireEvent.click(screen.getByText('Сохранить'));
    expect(send).toHaveBeenCalledWith('save_page', {
      page: 2,
      revision: 1,
      text,
      caption,
      illustrationRequestId: requestId,
    });
    expect(screen.getByLabelText('Текст страницы 2')).toBeDefined();
    store.set(gameDataAtom, {
      ...book,
      revision: 2,
      pages: [book.pages[0], { text, caption, image }, book.pages[2]],
    });
    rerender(<IllustratedBook />);
    expect(screen.queryByLabelText('Текст страницы 2')).toBeNull();
    expect(screen.getByAltText(caption).getAttribute('src')).toBe(
      `data:image/png;base64,${image}`,
    );
    send.mockRestore();
  });

  it('ignores a superseded preview and keeps the original after an import error', () => {
    const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
    const { rerender } = render(<IllustratedBook />);
    fireEvent.click(screen.getAllByText('Править')[0]);
    fireEvent.click(screen.getByText('Иллюстрация по ссылке'));
    const link = screen.getByLabelText('Ссылка на PNG или JPEG');
    fireEvent.change(link, {
      target: { value: 'https://file.garden/a/old.png' },
    });
    fireEvent.click(screen.getByText('Показать на странице'));
    const oldId = send.mock.calls.at(-1)?.[1]?.requestId;
    fireEvent.change(link, {
      target: { value: 'https://file.garden/a/new.png' },
    });
    fireEvent.click(screen.getByText('Показать на странице'));
    const newId = send.mock.calls.at(-1)?.[1]?.requestId;
    expect(newId).not.toBe(oldId);
    store.set(gameDataAtom, {
      ...book,
      illustrationPreview: { requestId: oldId, image: 'b2xk' },
    });
    rerender(<IllustratedBook />);
    expect(screen.getByAltText('Снимок').getAttribute('src')).toBe(
      'data:image/png;base64,aaaa',
    );
    store.set(gameDataAtom, {
      ...book,
      illustrationPreview: { requestId: newId, error: 'Некорректная ссылка' },
    });
    rerender(<IllustratedBook />);
    expect(screen.getByRole('alert').textContent).toBe('Некорректная ссылка');
    fireEvent.click(screen.getByText('Отменить вставку'));
    expect(screen.queryByRole('alert')).toBeNull();
    expect(screen.getByAltText('Снимок').getAttribute('src')).toBe(
      'data:image/png;base64,aaaa',
    );
    expect(send).toHaveBeenCalledTimes(2);
    send.mockRestore();
  });

  it('preserves an unsaved draft when another player edits the book', () => {
    const send = spyOn(actions, 'sendAct').mockImplementation(() => {});
    const { rerender } = render(<IllustratedBook />);
    fireEvent.click(screen.getAllByText('Править')[1]);
    fireEvent.change(screen.getByLabelText('Текст страницы 2'), {
      target: { value: 'Черновик' },
    });
    store.set(gameDataAtom, {
      ...book,
      revision: 2,
      pages: [book.pages[0], { text: 'Правка второго автора' }, book.pages[2]],
    });
    rerender(<IllustratedBook />);
    fireEvent.click(screen.getByText('Сохранить'));
    expect(
      (screen.getByLabelText('Текст страницы 2') as HTMLTextAreaElement).value,
    ).toBe('Черновик');
    expect(send).not.toHaveBeenCalled();
    send.mockRestore();
  });
});
