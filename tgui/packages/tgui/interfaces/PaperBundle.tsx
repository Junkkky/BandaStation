import { useRef } from 'react';
import { Box, Button, Section, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { PreviewView } from './PaperSheet/Preview';
import type { PaperContext, PaperReplacement } from './PaperSheet/types';

type Data = {
  bundle_name: string;
  page: number;
  page_count: number;
  page_name: string;
  page_ref: string;
  paper?: PaperContext;
  photo?: string;
  photo_caption?: string;
  can_remove: BooleanLike;
};

const noop = () => {};

export function PaperBundle() {
  const { act, data } = useBackend<Data>();
  const {
    bundle_name,
    page,
    page_count,
    page_name,
    page_ref,
    paper,
    photo,
    photo_caption,
    can_remove,
  } = data;
  const pageParams = { page, ref: page_ref };
  const scrollableRef = useRef<HTMLDivElement>(null);
  const usedReplacementsRef = useRef<PaperReplacement[]>([]);

  return (
    <Window title={bundle_name} theme="paper220" width={600} height={530}>
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item>
                <Button
                  icon="chevron-left"
                  tooltip="Предыдущая страница"
                  disabled={page <= 1}
                  onClick={() => act('previous', pageParams)}
                />
              </Stack.Item>
              <Stack.Item>
                {page} / {page_count}
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="chevron-right"
                  tooltip="Следующая страница"
                  disabled={page >= page_count}
                  onClick={() => act('next', pageParams)}
                />
              </Stack.Item>
              <Stack.Item grow>{page_name}</Stack.Item>
              <Stack.Item>
                <Button
                  icon="eye"
                  disabled={!page_ref}
                  onClick={() => act('open', pageParams)}
                >
                  Открыть отдельно
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="eject"
                  disabled={!can_remove}
                  onClick={() => act('remove', pageParams)}
                >
                  Вынуть
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item grow basis={0}>
            {paper ? (
              <PreviewView
                key={page_ref}
                paperContext={paper}
                scrollableRef={scrollableRef}
                activeWriteButtonId=""
                textAreaTextForPreview=""
                usedReplacementsRef={usedReplacementsRef}
                handleOnScroll={noop}
                setActiveWriteButtonId={noop}
                setTextAreaActive={noop}
              />
            ) : (
              <Section key={page_ref} fill scrollable>
                <Box textAlign="center">
                  {photo && (
                    <img
                      src={`data:image/png;base64,${photo}`}
                      alt={page_name}
                      style={{ maxWidth: '100%', imageRendering: 'pixelated' }}
                    />
                  )}
                  {photo_caption && <Box>{photo_caption}</Box>}
                </Box>
              </Section>
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
}
