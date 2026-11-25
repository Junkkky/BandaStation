import { useEffect, useRef, useState } from 'react';
import { Button } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { type BindingColor, BookCover } from './IllustratedBook/BookCover';
import { FormattingToolbar } from './IllustratedBook/FormattingToolbar';
import {
  IllustrationLink,
  useIllustrationLink,
} from './IllustratedBook/IllustrationLink';
import { useBookBookmark } from './IllustratedBook/useBookBookmark';
import { MarkdownRenderer } from './MarkdownViewer';

type Page = {
  text: string;
  image?: string | null;
  caption?: string | null;
};

export type Book = {
  title: string;
  author: string;
  pages: Page[];
  revision: number;
  canEdit: BooleanLike;
  canIllustrate: BooleanLike;
  canReadAloud?: BooleanLike;
  readAloudVoiceEnabled?: BooleanLike;
  readingPage?: number;
  canImportIllustration?: BooleanLike;
  hasBookCover?: BooleanLike;
  coverImage?: string | null;
  bindingColor?: BindingColor | null;
  maxPages: number;
  maxTextLength: number;
  maxCaptionLength: number;
  illustrationPreview?: {
    requestId: string;
    image?: string;
    error?: string;
  } | null;
};

type Draft = {
  page: Page;
  number: number;
  revision: number;
};

function PageContent({ text, image, caption }: Page) {
  return (
    <div className="IllustratedBook__prose">
      {!!image && (
        <figure className="IllustratedBook__figure">
          <img
            className="IllustratedBook__illustration"
            alt={caption || 'Иллюстрация к странице'}
            src={`data:image/png;base64,${image}`}
          />
          {!!caption && <figcaption>{caption}</figcaption>}
        </figure>
      )}
      <MarkdownRenderer content={text} sanitize />
    </div>
  );
}

function PageEditor(props: { draft: Draft; close: () => void }) {
  const { draft, close } = props;
  const { data, act } = useBackend<Book>();
  const [text, setText] = useState(draft.page.text);
  const field = useRef<HTMLTextAreaElement>(null);
  const [caption, setCaption] = useState(draft.page.caption || '');
  const link = useIllustrationLink();
  const { url, requestId, preview } = link;
  const [submitted, setSubmitted] = useState<
    Page & { requestId?: string; url?: string }
  >();
  const image = preview?.image || draft.page.image;
  const dirty =
    text !== draft.page.text ||
    caption !== (draft.page.caption || '') ||
    image !== draft.page.image;
  const stale = data.revision !== draft.revision;
  const length = Array.from(text).length;
  const saved = data.pages[draft.number - 1];

  // Keep the manuscript on screen until the server echoes this exact revision's edit.
  useEffect(() => {
    if (
      submitted !== undefined &&
      submitted.requestId === requestId &&
      submitted.url === url &&
      submitted.text === text &&
      submitted.caption === caption &&
      saved?.text === text &&
      (saved.caption || '') === caption &&
      (saved.image || null) === (submitted.image || null) &&
      data.revision === draft.revision + 1
    ) {
      close();
    }
  }, [
    submitted,
    url,
    requestId,
    text,
    caption,
    saved,
    data.revision,
    draft.revision,
    close,
  ]);

  return (
    <>
      <section className="IllustratedBook__leaf IllustratedBook__leaf--editor">
        <div className="IllustratedBook__running">
          Рукопись · Страница {draft.number}
        </div>
        <FormattingToolbar field={field} onChange={setText} />
        <textarea
          ref={field}
          aria-label={`Текст страницы ${draft.number}`}
          className="IllustratedBook__input"
          value={text}
          onChange={(event) => setText(event.currentTarget.value)}
          placeholder="Начните писать здесь…"
        />
        <div className="IllustratedBook__count">
          {length} / {data.maxTextLength}
        </div>
        {!!data.canImportIllustration && (
          <IllustrationLink
            link={link}
            page={draft.number}
            revision={draft.revision}
            disabled={stale || !data.canEdit}
            onCancel={() => {
              if (!draft.page.image) setCaption('');
            }}
          />
        )}
        {!!image && (
          <label className="IllustratedBook__caption">
            Подпись к иллюстрации
            <input
              value={caption}
              onChange={(event) => setCaption(event.currentTarget.value)}
              placeholder="Что изображено на рисунке?"
            />
          </label>
        )}
        {stale ? (
          <p className="IllustratedBook__notice" role="status">
            Книгу уже изменили. Скопируйте нужный текст и откройте страницу
            заново.
          </p>
        ) : !data.canEdit ? (
          <p className="IllustratedBook__notice" role="status">
            Чтобы записать правку, возьмите ручку.
          </p>
        ) : null}
        <div className="IllustratedBook__tools">
          <Button
            icon="check"
            disabled={
              !dirty ||
              stale ||
              !data.canEdit ||
              (url !== undefined && !preview?.image) ||
              length > data.maxTextLength ||
              Array.from(caption).length > data.maxCaptionLength
            }
            onClick={() => {
              setSubmitted({ text, caption, image, url, requestId });
              act('save_page', {
                page: draft.number,
                revision: draft.revision,
                text,
                caption,
                ...(preview?.image && { illustrationRequestId: requestId }),
              });
            }}
          >
            Сохранить
          </Button>
          {dirty ? (
            <Button.Confirm
              confirmContent="Закрыть без сохранения?"
              onClick={close}
            >
              Отмена
            </Button.Confirm>
          ) : (
            <Button onClick={close}>К чтению</Button>
          )}
        </div>
      </section>
      <section className="IllustratedBook__leaf">
        <div className="IllustratedBook__running">Предпросмотр</div>
        <PageContent image={image} text={text} caption={caption} />
        <div className="IllustratedBook__number">{draft.number}</div>
      </section>
    </>
  );
}

export function IllustratedBook() {
  const { data, act } = useBackend<Book>();
  const { pages, revision, canEdit, canIllustrate } = data;
  const [spread, setSpread] = useState(-1);
  const [draft, setDraft] = useState<Draft>();
  const bookmark = useBookBookmark();
  const lastSpread = Math.max(0, Math.ceil(pages.length / 2) - 1);
  const current = Math.min(Math.max(spread, 0), lastSpread);
  const bookmarkedSpread = Math.min(
    Math.ceil(bookmark.page / 2) - 1,
    lastSpread,
  );
  const pinnedHere = bookmark.pinned && bookmarkedSpread === current;
  const readLabel = data.readAloudVoiceEnabled
    ? 'Читать вслух'
    : 'Зачитать в чат';

  function turn(next: number) {
    setSpread(next);
    act('play_flip_sound');
    if (data.hasBookCover && next >= 0 && !bookmark.pinned) {
      bookmark.remember(next * 2 + 1);
    }
  }

  function insertAfter(page: number) {
    act('insert_page', { page, revision });
    setSpread(Math.floor(page / 2));
  }

  return (
    <Window title={data.title} width={860} height={600}>
      <Window.Content fitted className="IllustratedBook__window">
        {!!data.readingPage && (
          <div className="IllustratedBook__reading">
            <span role="status">Вы читаете страницу {data.readingPage}</span>
            <Button icon="stop" onClick={() => act('stop_reading')}>
              Остановить чтение
            </Button>
          </div>
        )}
        {data.hasBookCover && spread < 0 ? (
          <BookCover
            open={turn}
            bookmarkedSpread={bookmarkedSpread}
            pinned={bookmark.pinned}
          />
        ) : (
          <div
            className="IllustratedBook"
            data-book-binding={data.bindingColor}
          >
            <header className="IllustratedBook__binding">
              <div className="IllustratedBook__title">{data.title}</div>
              <div className="IllustratedBook__author">{data.author}</div>
              {!!canEdit && !draft && (
                <div className="IllustratedBook__metadata">
                  <Button
                    icon="feather"
                    onClick={() => act('edit_title', { revision })}
                  >
                    Название
                  </Button>
                  <Button
                    icon="signature"
                    onClick={() => act('edit_author', { revision })}
                  >
                    Автор
                  </Button>
                </div>
              )}
            </header>
            <div className="IllustratedBook__spread">
              {draft ? (
                <PageEditor draft={draft} close={() => setDraft(undefined)} />
              ) : (
                [current * 2, current * 2 + 1].map((index) => {
                  const page = pages[index];
                  const number = index + 1;
                  const target = { page: number, revision };
                  return (
                    <section
                      className={
                        pinnedHere && index === current * 2
                          ? 'IllustratedBook__leaf IllustratedBook__leaf--bookmarked'
                          : 'IllustratedBook__leaf'
                      }
                      key={number}
                    >
                      {page ? (
                        <>
                          <PageContent {...page} />
                          <div className="IllustratedBook__tools">
                            {!!data.canReadAloud &&
                              !data.readingPage &&
                              !!(page.text.trim() || page.caption?.trim()) && (
                                <Button
                                  icon={
                                    data.readAloudVoiceEnabled
                                      ? 'volume-high'
                                      : 'comment'
                                  }
                                  aria-label={`${readLabel} · страница ${number}`}
                                  tooltip={
                                    data.readAloudVoiceEnabled
                                      ? `Прочитать страницу ${number} окружающим`
                                      : 'Синтез голоса выключен. Реплики увидят персонажи рядом.'
                                  }
                                  onClick={() => act('read_aloud', target)}
                                >
                                  {readLabel}
                                </Button>
                              )}
                            {!!canEdit && (
                              <>
                                <Button
                                  icon="pen-nib"
                                  onClick={() =>
                                    setDraft({ page, number, revision })
                                  }
                                >
                                  Править
                                </Button>
                                <Button
                                  icon="file-circle-plus"
                                  tooltip="Вставить пустую страницу следом"
                                  disabled={pages.length >= data.maxPages}
                                  onClick={() => insertAfter(number)}
                                />
                                {pages.length > 1 && (
                                  <Button.Confirm
                                    icon="trash"
                                    tooltip="Удалить эту страницу"
                                    confirmContent="Удалить лист?"
                                    onClick={() => act('delete_page', target)}
                                  />
                                )}
                              </>
                            )}
                            {!!canIllustrate && (
                              <Button
                                icon="image"
                                tooltip="Использовать снимок или картину из руки"
                                onClick={() => act('attach_image', target)}
                              >
                                {page.image ? 'Заменить' : 'Вклеить'}
                              </Button>
                            )}
                            {!!canEdit && !!page.image && (
                              <Button.Confirm
                                icon="eraser"
                                tooltip="Убрать иллюстрацию"
                                confirmContent="Убрать рисунок?"
                                onClick={() => act('remove_image', target)}
                              />
                            )}
                          </div>
                          <div className="IllustratedBook__number">
                            {number}
                          </div>
                        </>
                      ) : canEdit && pages.length < data.maxPages ? (
                        <div className="IllustratedBook__newPage">
                          <Button
                            icon="plus"
                            onClick={() => insertAfter(pages.length)}
                          >
                            Добавить страницу
                          </Button>
                        </div>
                      ) : null}
                    </section>
                  );
                })
              )}
            </div>
            <nav
              className="IllustratedBook__navigation"
              aria-label="Перелистывание"
            >
              <Button
                icon="chevron-left"
                disabled={!!draft || (!data.hasBookCover && current === 0)}
                onClick={() => turn(current - 1)}
              >
                {data.hasBookCover && current === 0 ? 'К обложке' : 'Назад'}
              </Button>
              <span>
                Разворот {current + 1} из {lastSpread + 1}
              </span>
              {!!data.hasBookCover && !draft && (
                <Button
                  icon="bookmark"
                  selected={pinnedHere}
                  disabled={!bookmark.ready}
                  onClick={() =>
                    pinnedHere
                      ? bookmark.unpin(current * 2 + 1)
                      : bookmark.pin(current * 2 + 1)
                  }
                >
                  {pinnedHere
                    ? 'Снять закладку'
                    : bookmark.pinned
                      ? 'Перенести закладку сюда'
                      : 'Заложить страницу'}
                </Button>
              )}
              <Button
                icon="chevron-right"
                iconPosition="right"
                disabled={!!draft || current === lastSpread}
                onClick={() => turn(current + 1)}
              >
                Вперёд
              </Button>
            </nav>
          </div>
        )}
      </Window.Content>
    </Window>
  );
}
