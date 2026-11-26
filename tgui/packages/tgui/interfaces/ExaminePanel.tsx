import { type ReactNode, useState } from 'react';
import { Box, Button, Section, Stack, Tabs } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { CharacterPreview } from './common/CharacterPreview';

type Tattoo = {
  id: string;
  zone: string;
  side: string;
  image: string;
  saved?: BooleanLike;
};

type Data = {
  character_name: string;
  obscured: BooleanLike;
  assigned_map: string;
  flavor_text: string | null;
  portrait_urls?: string[] | null;
  tattoos?: Tattoo[];
};

const PORTRAIT_SIZE = 320;
// Button renders a div and forwards DOM roles, though its props omit role.
const buttonRole = { role: 'button' };

export const ExaminePanel = () => {
  const { data } = useBackend<Data>();
  const { character_name, obscured, assigned_map, flavor_text, portrait_urls } =
    data;
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [failedPortraits, setFailedPortraits] = useState(
    () => new Set<string>(),
  );
  const portraits = obscured ? [] : (portrait_urls ?? []);
  const index = selectedIndex < portraits.length ? selectedIndex : 0;
  const portraitSource = portraits[index];
  const portrait =
    portraitSource && !failedPortraits.has(portraitSource)
      ? portraitSource
      : null;
  const hasPortraits = portraits.length > 0;
  const showDescription = !hasPortraits || !!flavor_text?.trim();

  return (
    <Window
      title="Подробное описание"
      width={hasPortraits ? (showDescription ? 700 : 356) : 600}
      height={(hasPortraits ? 408 : 350) + (data.tattoos ? 36 : 0)}
      theme="ntos"
    >
      <ExamineContent tattoos={data.tattoos}>
        <Stack fill justify={showDescription ? undefined : 'center'}>
          <Stack.Item>
            <Section
              fill
              title={portrait ? 'Портрет персонажа' : 'Превью персонажа'}
              buttons={
                portraits.length > 1 && (
                  <Stack align="center" g={0.5}>
                    <Stack.Item>
                      <Button
                        compact
                        icon="chevron-left"
                        {...buttonRole}
                        aria-label="Предыдущий портрет"
                        onClick={() =>
                          setSelectedIndex(
                            (index + portraits.length - 1) % portraits.length,
                          )
                        }
                      />
                    </Stack.Item>
                    <Stack.Item aria-live="polite">
                      {index + 1} / {portraits.length}
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        compact
                        icon="chevron-right"
                        {...buttonRole}
                        aria-label="Следующий портрет"
                        onClick={() =>
                          setSelectedIndex((index + 1) % portraits.length)
                        }
                      />
                    </Stack.Item>
                  </Stack>
                )
              }
            >
              {!obscured &&
                (portrait ? (
                  <img
                    key={portrait}
                    alt="Портрет персонажа"
                    src={portrait}
                    width={PORTRAIT_SIZE}
                    height={PORTRAIT_SIZE}
                    style={{ display: 'block', objectFit: 'cover' }}
                    referrerPolicy="no-referrer"
                    onError={() =>
                      setFailedPortraits((failed) =>
                        new Set(failed).add(portrait),
                      )
                    }
                  />
                ) : (
                  <CharacterPreview id={assigned_map} height="100%" />
                ))}
            </Section>
          </Stack.Item>
          {showDescription && (
            <Stack.Item grow>
              <Section scrollable fill title={`${character_name}, описание:`}>
                <Box
                  style={{
                    whiteSpace: 'pre-wrap',
                    wordBreak: 'break-word',
                    overflowWrap: 'break-word',
                  }}
                >
                  {flavor_text}
                </Box>
              </Section>
            </Stack.Item>
          )}
        </Stack>
      </ExamineContent>
    </Window>
  );
};

function ExamineContent({
  tattoos,
  children,
}: {
  tattoos?: Tattoo[];
  children: ReactNode;
}) {
  const [showTattoos, setShowTattoos] = useState(false);
  if (!tattoos) {
    return <Window.Content>{children}</Window.Content>;
  }
  return (
    <Window.Content>
      <Stack fill vertical>
        <Stack.Item>
          <Tabs>
            <Tabs.Tab
              selected={!showTattoos}
              onClick={() => setShowTattoos(false)}
            >
              Описание
            </Tabs.Tab>
            <Tabs.Tab
              selected={showTattoos}
              onClick={() => setShowTattoos(true)}
            >
              Татуировки
            </Tabs.Tab>
          </Tabs>
        </Stack.Item>
        <Stack.Item grow minHeight={0}>
          {showTattoos ? <TattooGallery tattoos={tattoos} /> : children}
        </Stack.Item>
      </Stack>
    </Window.Content>
  );
}

function TattooGallery({ tattoos }: { tattoos: Tattoo[] }) {
  const { act } = useBackend<Data>();
  const [selectedId, setSelectedId] = useState<string>();
  const current =
    tattoos.find((tattoo) => tattoo.id === selectedId) ?? tattoos[0];
  if (!current) {
    return <Section fill>Видимых татуировок нет.</Section>;
  }

  return (
    <Stack fill>
      <Stack.Item width="38%" maxWidth={17}>
        <Section fill scrollable>
          {tattoos.map((tattoo) => (
            <Button
              key={tattoo.id}
              fluid
              {...buttonRole}
              selected={tattoo.id === current.id}
              onClick={() => setSelectedId(tattoo.id)}
            >
              {tattoo.zone}
              <Box color="label">{tattoo.side}</Box>
            </Button>
          ))}
        </Section>
      </Stack.Item>
      <Stack.Item grow minWidth={0}>
        <Stack fill vertical>
          <Stack.Item grow minHeight={0}>
            <Section fill>
              <img
                src={current.image}
                alt={`Татуировка: ${current.zone}, ${current.side}`}
                style={{
                  width: '100%',
                  height: '100%',
                  objectFit: 'contain',
                  imageRendering: 'pixelated',
                }}
              />
            </Section>
          </Stack.Item>
          {current.saved != null && (
            <Stack.Item>
              <Button
                {...buttonRole}
                onClick={() =>
                  act('set_tattoo_saved', {
                    id: current.id,
                    save: !current.saved,
                  })
                }
              >
                {current.saved
                  ? 'Убрать из сохранённых'
                  : 'Сохранить для этого персонажа'}
              </Button>
              {!!current.saved && (
                <Box color="label">
                  Если убрать, рисунок останется на теле до конца раунда.
                </Box>
              )}
            </Stack.Item>
          )}
        </Stack>
      </Stack.Item>
    </Stack>
  );
}
