import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Tooltip,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import type { PreferencesMenuData } from '../types';

type SkillsData = PreferencesMenuData & {
  expedition_training_profiles: { id: string; name: string }[];
  expedition_training_levels: string[];
  expedition_training?: {
    enabled: BooleanLike;
    editable: BooleanLike;
    revision: number;
    profile: string;
    points: number;
    remaining: number;
    skills: {
      id: string;
      name: string;
      description: string;
      level: number;
      increase_error: string | null;
      decrease_error: string | null;
    }[];
  };
};

export function SkillsPage() {
  const { act, data } = useBackend<SkillsData>();
  const skillsData = data.expedition_training;
  if (!skillsData) {
    return <NoticeBox>Навыки загружаются.</NoticeBox>;
  }
  const context = {
    slot: data.active_slot,
    revision: skillsData.revision,
    profile: skillsData.profile,
  };
  return (
    <Stack fill>
      <Stack.Item basis="29%">
        <Section fill scrollable title="Профессиональный профиль">
          {data.expedition_training_profiles.map((profile) => (
            <Button
              fluid
              ellipsis
              key={profile.id}
              selected={profile.id === skillsData.profile}
              onClick={() =>
                act('select_expedition_profile', {
                  ...context,
                  profile: profile.id,
                })
              }
            >
              {profile.name}
            </Button>
          ))}
          <Box mt={2} color="label">
            При входе применяется профиль назначенной должности. Остальные
            профили может выдать ведущий. Настройки сохраняются отдельно для
            каждого персонажа.
          </Box>
        </Section>
      </Stack.Item>
      <Stack.Item grow>
        <Section
          fill
          scrollable
          title="Навыки"
          buttons={
            <Button.Confirm
              key={`${data.active_slot}:${skillsData.profile}`}
              icon="rotate-left"
              disabled={!skillsData.editable}
              confirmContent="Сбросить профиль?"
              onClick={() => act('reset_expedition_profile', context)}
            >
              Сбросить
            </Button.Confirm>
          }
        >
          {!skillsData.editable && (
            <NoticeBox>
              {skillsData.enabled
                ? 'Менять навыки можно в лобби до входа в раунд.'
                : 'Навыки отключены ведущим на этот раунд.'}
            </NoticeBox>
          )}
          <ProgressBar
            value={skillsData.remaining}
            minValue={0}
            maxValue={skillsData.points}
            mb={1}
          >
            Свободно очков: {skillsData.remaining} / {skillsData.points}
          </ProgressBar>
          <Box mb={1} color="label">
            Начальные навыки профессии бесплатны. Сервер проверяет предпосылки,
            пределы и стоимость каждого уровня.
          </Box>
          {skillsData.skills.map((skill) => (
            <Stack key={skill.id} align="center" mb={0.5}>
              <Stack.Item grow>
                <Tooltip content={skill.description}>
                  <Box>{skill.name}</Box>
                </Tooltip>
              </Stack.Item>
              <Stack.Item width="8em" textAlign="center">
                {data.expedition_training_levels[skill.level - 1]}
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="minus"
                  aria-label={`Понизить: ${skill.name}`}
                  disabled={!skillsData.editable || !!skill.decrease_error}
                  tooltip={skill.decrease_error || 'Вернуть очки за уровень'}
                  onClick={() =>
                    act('set_expedition_skill', {
                      ...context,
                      skill: skill.id,
                      from_level: skill.level,
                      level: skill.level - 1,
                    })
                  }
                />
                <Button
                  icon="plus"
                  aria-label={`Повысить: ${skill.name}`}
                  disabled={!skillsData.editable || !!skill.increase_error}
                  tooltip={skill.increase_error || 'Повысить уровень навыка'}
                  onClick={() =>
                    act('set_expedition_skill', {
                      ...context,
                      skill: skill.id,
                      from_level: skill.level,
                      level: skill.level + 1,
                    })
                  }
                />
              </Stack.Item>
            </Stack>
          ))}
          <NoticeBox mt={1}>
            Сейчас навыки влияют на экспедиционные обследования, отбор проб и
            лабораторный анализ, а также на стрельбу и ближний бой. Остальные
            дисциплины подключаются по мере переноса механик.
          </NoticeBox>
        </Section>
      </Stack.Item>
    </Stack>
  );
}
