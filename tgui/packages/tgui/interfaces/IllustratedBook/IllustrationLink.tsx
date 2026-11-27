import { useState } from 'react';
import { Button } from 'tgui-core/components';
import { useBackend } from '../../backend';
import type { Book } from '../IllustratedBook';

let requestSequence = 0;

export function useIllustrationLink() {
  const { data } = useBackend<Book>();
  const [url, setUrl] = useState<string>();
  const [requestId, setRequestId] = useState<string>();
  const preview =
    requestId && data.illustrationPreview?.requestId === requestId
      ? data.illustrationPreview
      : undefined;

  function changeUrl(value?: string) {
    setUrl(value);
    setRequestId(undefined);
  }

  return { url, requestId, preview, changeUrl, setRequestId };
}

export function IllustrationLink(props: {
  link: ReturnType<typeof useIllustrationLink>;
  page: number | 'cover';
  revision: number;
  disabled: boolean;
  onCancel?: () => void;
}) {
  const { act } = useBackend();
  const { link, page, revision, disabled, onCancel } = props;
  const { url, requestId, preview } = link;
  if (url === undefined) {
    return (
      <div className="IllustratedBook__tools">
        <Button
          icon="link"
          disabled={disabled}
          onClick={() => link.changeUrl('')}
        >
          Иллюстрация по ссылке
        </Button>
      </div>
    );
  }
  return (
    <div>
      <label className="IllustratedBook__caption">
        Ссылка на PNG или JPEG
        <input
          type="url"
          value={url}
          placeholder="https://…"
          onChange={(event) => link.changeUrl(event.currentTarget.value)}
        />
      </label>
      <div className="IllustratedBook__tools">
        <Button
          icon="image"
          disabled={disabled || !url.trim() || (!!requestId && !preview?.error)}
          onClick={() => {
            const id = `${Date.now()}-${++requestSequence}`;
            link.setRequestId(id);
            act('preview_illustration', {
              page,
              revision,
              url: url.trim(),
              requestId: id,
            });
          }}
        >
          {requestId && !preview?.image && !preview?.error
            ? 'Загрузка…'
            : page === 'cover'
              ? 'Показать на обложке'
              : 'Показать на странице'}
        </Button>
        <Button
          onClick={() => {
            link.changeUrl();
            onCancel?.();
          }}
        >
          Отменить вставку
        </Button>
      </div>
      {!!preview?.error && (
        <p className="IllustratedBook__notice" role="alert">
          {preview.error}
        </p>
      )}
    </div>
  );
}
