import { Section } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import { Compartments } from './SpaceNavigation/Compartments';
import type { Compartment } from './SpaceNavigation/types';

type Data = {
  compartments: Compartment[];
};

export const ShipCompartments = () => {
  const { data } = useBackend<Data>();
  return (
    <Window width={360} height={420}>
      <Window.Content scrollable>
        <Section title="Отсеки">
          {data.compartments.length ? (
            <Compartments rooms={data.compartments} />
          ) : (
            <p>Консоль не подключена к корпусу.</p>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
