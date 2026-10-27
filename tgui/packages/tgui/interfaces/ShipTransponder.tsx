// BANDASTATION ADDITION - Ship transponder controls.
import { Button, LabeledList, Section } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  enabled: BooleanLike;
  transmitting: BooleanLike;
  callsign: string | null;
  faction: string | null;
};

export const ShipTransponder = () => {
  const { act, data } = useBackend<Data>();
  return (
    <Window width={350} height={220}>
      <Window.Content>
        <Section title="Опознавание">
          <LabeledList>
            <LabeledList.Item label="Позывной">
              {data.callsign || 'Не запрограммирован'}
            </LabeledList.Item>
            <LabeledList.Item label="Принадлежность">
              {data.faction || 'Не заявлена'}
            </LabeledList.Item>
            <LabeledList.Item label="Ответчик">
              {data.transmitting ? 'Передача опознавания' : 'Нет передачи'}
            </LabeledList.Item>
          </LabeledList>
          <Button
            mt={2}
            icon="power-off"
            selected={!!data.enabled}
            onClick={() => act('toggle')}
          >
            {data.enabled ? 'Отключить передачу' : 'Включить передачу'}
          </Button>
        </Section>
      </Window.Content>
    </Window>
  );
};
