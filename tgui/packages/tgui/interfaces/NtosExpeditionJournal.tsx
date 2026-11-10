import { useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Input,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Tabs,
  TextArea,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { NtosWindow } from '../layouts';

type JournalRecord = {
  id: string;
  origin: string;
  observations: string[];
};

type Goal = {
  id: string;
  text: string;
  author: string;
  created: string;
  personal: boolean;
  editable: boolean;
  status: string;
  conclusion: string;
  records: string[];
};

type Data = {
  records: JournalRecord[];
  goals: Goal[];
};

const STATUSES = {
  open: 'Открыта',
  done: 'Выполнена',
  failed: 'Не выполнена',
};

export const NtosExpeditionJournal = () => {
  const [tab, setTab] = useState(1);

  return (
    <NtosWindow width={600} height={640}>
      <NtosWindow.Content scrollable>
        <Tabs>
          <Tabs.Tab
            icon="bullseye"
            selected={tab === 1}
            onClick={() => setTab(1)}
          >
            Цели
          </Tabs.Tab>
          <Tabs.Tab
            icon="book"
            selected={tab === 2}
            onClick={() => setTab(2)}
          >
            Протоколы находок
          </Tabs.Tab>
        </Tabs>
        {tab === 1 ? <Goals /> : <Records />}
      </NtosWindow.Content>
    </NtosWindow>
  );
};

const Goals = () => {
  const { act, data } = useBackend<Data>();
  const [text, setText] = useState('');

  const add = (personal: boolean) => {
    if (!text.trim()) {
      return;
    }
    act('add_goal', { text, personal });
    setText('');
  };

  return (
    <>
      <Section title="Новая цель">
        <Stack>
          <Stack.Item grow>
            <Input
              fluid
              maxLength={256}
              placeholder="Формулировка цели..."
              value={text}
              onChange={setText}
            />
          </Stack.Item>
          <Stack.Item>
            <Button onClick={() => add(false)}>Цель экспедиции</Button>
          </Stack.Item>
          <Stack.Item>
            <Button onClick={() => add(true)}>Личная цель</Button>
          </Stack.Item>
        </Stack>
      </Section>
      {data.goals.length === 0 && <NoticeBox>Целей пока нет.</NoticeBox>}
      {data.goals.map((goal) => (
        <GoalSection key={goal.id} goal={goal} />
      ))}
    </>
  );
};

const GoalSection = (props: { goal: Goal }) => {
  const { act, data } = useBackend<Data>();
  const { goal } = props;
  const unlinked = data.records
    .map((record) => record.id)
    .filter((id) => !goal.records.includes(id));

  return (
    <Section
      title={`${goal.id}: ${goal.text}`}
      buttons={
        <Button icon="print" onClick={() => act('print', { goal: goal.id })}>
          Печать отчёта
        </Button>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Тип">
          {goal.personal ? 'Личная цель' : 'Цель экспедиции'}
        </LabeledList.Item>
        <LabeledList.Item label="Поставлена">
          {goal.created} — {goal.author}
        </LabeledList.Item>
        <LabeledList.Item label="Статус">
          {Object.entries(STATUSES).map(([key, label]) => (
            <Button
              key={key}
              selected={goal.status === key}
              disabled={!goal.editable}
              onClick={() =>
                act('set_status', { goal: goal.id, status: key })
              }
            >
              {label}
            </Button>
          ))}
        </LabeledList.Item>
        <LabeledList.Item label="Протоколы">
          {goal.records.map((id) => (
            <Button
              key={id}
              icon={goal.editable ? 'times' : undefined}
              disabled={!goal.editable}
              onClick={() =>
                act('unlink_record', { goal: goal.id, record: id })
              }
            >
              {id}
            </Button>
          ))}
          {goal.editable && unlinked.length > 0 && (
            <Dropdown
              placeholder="Привязать протокол..."
              selected=""
              options={unlinked}
              onSelected={(id) =>
                act('link_record', { goal: goal.id, record: id })
              }
            />
          )}
        </LabeledList.Item>
      </LabeledList>
      <Box mt={1}>
        {goal.editable ? (
          <TextArea
            fluid
            height="80px"
            maxLength={1024}
            placeholder="Гипотезы и выводы..."
            value={goal.conclusion}
            onBlur={(value) =>
              value !== goal.conclusion &&
              act('set_conclusion', { goal: goal.id, text: value })
            }
          />
        ) : (
          <Box preserveWhitespace>{goal.conclusion || 'Выводы не записаны.'}</Box>
        )}
      </Box>
    </Section>
  );
};

const Records = () => {
  const { data } = useBackend<Data>();

  if (data.records.length === 0) {
    return <NoticeBox>Протоколов пока нет.</NoticeBox>;
  }
  return (
    <>
      {data.records.map((record) => (
        <Section key={record.id} title={`Протокол ${record.id}`}>
          <Box color="label">Место обнаружения: {record.origin}</Box>
          {record.observations.map((line, index) => (
            <Box key={index}>{line}</Box>
          ))}
        </Section>
      ))}
    </>
  );
};
