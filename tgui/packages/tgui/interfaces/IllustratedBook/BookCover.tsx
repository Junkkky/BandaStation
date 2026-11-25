import { useEffect, useState } from 'react';
import { Button, Icon } from 'tgui-core/components';
import { useBackend } from '../../backend';
import type { Book } from '../IllustratedBook';
import { IllustrationLink, useIllustrationLink } from './IllustrationLink';

const bindingColors = [
  ['green', 'Зелёный'],
  ['red', 'Красный'],
  ['amber', 'Янтарный'],
  ['blue', 'Синий'],
  ['purple', 'Фиолетовый'],
  ['black', 'Чёрный'],
] as const;

export type BindingColor = (typeof bindingColors)[number][0];

function CoverFace(props: {
  title: string;
  author: string;
  image?: string | null;
}) {
  return (
    <span className="IllustratedBook__coverFace">
      <span className="IllustratedBook__coverFrame">
        <span className="IllustratedBook__coverTitle">{props.title}</span>
        {props.image ? (
          <img
            className="IllustratedBook__coverImage"
            alt="Иллюстрация на обложке"
            src={`data:image/png;base64,${props.image}`}
          />
        ) : (
          <span className="IllustratedBook__coverStamp" aria-hidden="true">
            <Icon name="feather-pointed" />
          </span>
        )}
        <span className="IllustratedBook__coverAuthor">{props.author}</span>
      </span>
    </span>
  );
}

export function BookCover(props: {
  open: (spread: number) => void;
  bookmarkedSpread: number;
  pinned: boolean;
}) {
  const { open, bookmarkedSpread, pinned } = props;
  const { data, act } = useBackend<Book>();
  const [revision, setRevision] = useState<number>();
  const [draftColor, setDraftColor] = useState<BindingColor>();
  const [submitted, setSubmitted] = useState<
    | 'held'
    | 'remove'
    | {
        image?: string | null;
        requestId?: string;
        color?: BindingColor | null;
      }
  >();
  const link = useIllustrationLink();
  const editing = revision !== undefined;
  const stale = editing && revision !== data.revision;
  const color = draftColor ?? data.bindingColor;
  const colorChanged = color !== data.bindingColor;

  function closeEditor() {
    setRevision(undefined);
    setDraftColor(undefined);
    setSubmitted(undefined);
    link.changeUrl();
  }

  // Wait for the acknowledged cover before dismissing the author's preview.
  useEffect(() => {
    if (revision === undefined || data.revision !== revision + 1) return;
    const matches =
      typeof submitted === 'object'
        ? submitted.image === data.coverImage &&
          submitted.color === data.bindingColor &&
          submitted.color === color &&
          submitted.requestId === link.requestId
        : link.url === undefined &&
          ((submitted === 'held' && !!data.coverImage) ||
            (submitted === 'remove' && !data.coverImage));
    if (matches) {
      closeEditor();
    }
  }, [
    data.revision,
    revision,
    data.coverImage,
    data.bindingColor,
    color,
    submitted,
    link.requestId,
    link.url,
  ]);

  const face = (
    <CoverFace
      title={data.title}
      author={data.author}
      image={link.preview?.image || data.coverImage}
    />
  );

  return (
    <div
      className="IllustratedBook IllustratedBook--closed"
      data-book-binding={color}
    >
      <div className="IllustratedBook__coverLayout">
        {editing ? (
          <>
            {face}
            <section
              className="IllustratedBook__coverEditor"
              aria-label="Оформление обложки"
            >
              <h2>Оформление обложки</h2>
              {!!data.canEdit && data.bindingColor !== undefined && (
                <fieldset className="IllustratedBook__palette" disabled={stale}>
                  <legend>Цвет переплёта</legend>
                  <div>
                    {bindingColors.map(([value, label]) => (
                      <label key={value}>
                        <input
                          type="radio"
                          name="book-binding"
                          data-book-binding={value}
                          checked={color === value}
                          onChange={() => setDraftColor(value)}
                        />
                        {label}
                      </label>
                    ))}
                  </div>
                </fieldset>
              )}
              {link.url === undefined && (
                <>
                  {data.canIllustrate ? (
                    <Button
                      icon="image"
                      disabled={stale || colorChanged}
                      tooltip={
                        colorChanged && 'Сначала сохраните цвет переплёта'
                      }
                      onClick={() => {
                        setSubmitted('held');
                        act('attach_cover', { revision });
                      }}
                    >
                      Взять изображение из руки
                    </Button>
                  ) : (
                    <p>
                      Для картинки из руки возьмите снимок или завершённый
                      холст.
                    </p>
                  )}
                  {!!data.coverImage && !!data.canEdit && (
                    <Button.Confirm
                      icon="eraser"
                      disabled={stale || colorChanged}
                      tooltip={
                        colorChanged && 'Сначала сохраните цвет переплёта'
                      }
                      confirmContent="Убрать изображение?"
                      onClick={() => {
                        setSubmitted('remove');
                        act('remove_cover', { revision });
                      }}
                    >
                      Убрать изображение
                    </Button.Confirm>
                  )}
                </>
              )}
              {!!data.canImportIllustration &&
                (!!data.canEdit || link.url !== undefined) && (
                  <IllustrationLink
                    link={link}
                    page="cover"
                    revision={revision}
                    disabled={stale || !data.canEdit}
                  />
                )}
              {stale && (
                <p className="IllustratedBook__notice" role="status">
                  Книгу уже изменили. Откройте оформление заново.
                </p>
              )}
              {(colorChanged || link.url !== undefined) && (
                <Button
                  icon="check"
                  disabled={
                    (link.url !== undefined && !link.preview?.image) ||
                    stale ||
                    !data.canEdit
                  }
                  onClick={() => {
                    setSubmitted({
                      image: link.preview?.image || data.coverImage,
                      requestId: link.requestId,
                      color,
                    });
                    act('save_cover', {
                      revision,
                      ...(link.requestId && {
                        illustrationRequestId: link.requestId,
                      }),
                      ...(colorChanged && { bindingColor: color }),
                    });
                  }}
                >
                  Сохранить обложку
                </Button>
              )}
              <Button icon="arrow-left" onClick={closeEditor}>
                К обложке
              </Button>
            </section>
          </>
        ) : (
          <div className="IllustratedBook__coverShelf">
            <button
              type="button"
              className="IllustratedBook__openBook"
              onClick={() => open(0)}
              onKeyDown={(event) => {
                if (event.key !== 'Enter' && event.key !== ' ') return;
                event.preventDefault();
                event.stopPropagation();
                if (!event.repeat) open(0);
              }}
              aria-label={`Открыть книгу «${data.title}»`}
            >
              {face}
              <span className="IllustratedBook__openHint">
                Открыть книгу <Icon name="arrow-right" />
              </span>
            </button>
            <div className="IllustratedBook__tools">
              {(bookmarkedSpread > 0 || (bookmarkedSpread === 0 && pinned)) && (
                <Button icon="bookmark" onClick={() => open(bookmarkedSpread)}>
                  {pinned ? 'К закладке' : 'Продолжить чтение'}
                  {' · разворот '}
                  {bookmarkedSpread + 1}
                </Button>
              )}
              {(!!data.canEdit || !!data.canIllustrate) && (
                <Button
                  icon="pen-nib"
                  onClick={() => setRevision(data.revision)}
                >
                  Оформить обложку
                </Button>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
