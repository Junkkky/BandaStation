import { storage } from 'common/storage';
import { useEffect, useRef, useState } from 'react';
import { useBackend } from '../../backend';
import { sharedAtom, store } from '../../events/store';
import { createLogger } from '../../logging';

type Bookmark = { marker: string; page: number; pinned: boolean };
type ReadingState = { key: string; bookmark?: Bookmark };
const logger = createLogger('BookBookmark');

function save(
  key: string,
  previous: Bookmark | undefined,
  page: number,
  pinned: boolean,
) {
  // BYOND can reuse an object's ref. Only the opaque marker lives on the book.
  const marker =
    previous?.marker ??
    `book-mark-${crypto.getRandomValues(new Uint32Array(4)).join('-')}`;
  if (!previous) {
    Byond.sendMessage({ type: 'setSharedState', key: marker, value: 'true' });
  }
  const bookmark = { marker, page, pinned };
  storage
    .set(key, bookmark)
    .catch(() => logger.warn('Could not save reading position'));
  return bookmark;
}

export function useBookBookmark() {
  const { config } = useBackend();
  const reader = config.client?.ckey;
  const book = config.window?.key;
  const key = reader && book ? `book-bookmark:${reader}:${book}` : '';
  const [state, setState] = useState<ReadingState>();
  const earlyTurn = useRef<{ key: string; page: number } | null>(null);
  const ready = !!key && state?.key === key;
  const bookmark = ready ? state.bookmark : undefined;

  useEffect(() => {
    if (!key) return;
    let open = true;
    storage
      .get(key)
      .catch(() => undefined)
      .then((saved: Bookmark | undefined) => {
        if (!open) return;
        let mark =
          saved &&
          store.get(sharedAtom)[saved.marker] === true &&
          Number.isSafeInteger(saved.page) &&
          saved.page > 0 &&
          typeof saved.pinned === 'boolean'
            ? saved
            : undefined;
        const turn = earlyTurn.current;
        if (
          turn?.key === key &&
          !mark?.pinned &&
          turn.page !== (mark?.page ?? 1)
        ) {
          mark = save(key, mark, turn.page, false);
        }
        earlyTurn.current = null;
        setState({ key, bookmark: mark });
      });
    return () => {
      open = false;
    };
  }, [key]);

  function update(page: number, pinned: boolean) {
    if (ready && (bookmark?.page !== page || bookmark.pinned !== pinned)) {
      setState({ key, bookmark: save(key, bookmark, page, pinned) });
    }
  }

  return {
    ready,
    page: bookmark?.page ?? 0,
    pinned: bookmark?.pinned ?? false,
    remember(page: number) {
      if (!ready) {
        earlyTurn.current = { key, page };
      } else if (!bookmark?.pinned && page !== (bookmark?.page ?? 1)) {
        update(page, false);
      }
    },
    pin: (page: number) => update(page, true),
    unpin: (page: number) => update(page, false),
  };
}
