import type { CSSProperties } from 'react';
import { useBackend } from 'tgui/backend';
import { Icon, Section, Stack } from 'tgui-core/components';

import type { PreferencesMenuData } from '../types';
import { JobSlotDropdown } from './JobSlotDropdown';
import { PriorityButtons } from './JobsPage';

const slotPluralRules = new Intl.PluralRules('ru');
const slotLabels: Record<Intl.LDMLPluralRule, string> = {
  zero: 'мест',
  one: 'место',
  two: 'места',
  few: 'места',
  many: 'мест',
  other: 'места',
};

export function AwayMissionsPage() {
  const { act, data } = useBackend<PreferencesMenuData>();
  const priorities = data.character_preferences.misc.away_mission_role;

  return (
    <Stack vertical className="PreferencesMenu__AwayMissions">
      {data.away_missions?.map((mission) => (
        <Stack.Item key={mission.name}>
          <Section
            fitted
            title={mission.name}
            className="PreferencesMenu__AwayMission"
            style={{ '--mission-color': mission.color } as CSSProperties}
          >
            <ul className="PreferencesMenu__AwayRoleList">
              {mission.roles.map((role) => (
                <li
                  key={role.title}
                  className="PreferencesMenu__Department PreferencesMenu__AwayRole"
                >
                  <div className="PreferencesMenu__AwayRoleDetails">
                    <strong>{role.title}</strong>
                    <p>{role.description}</p>
                  </div>
                  <span className="PreferencesMenu__AwayRoleSlots">
                    {role.slots} {slotLabels[slotPluralRules.select(role.slots)]}
                  </span>
                  <div className="options">
                    {data.job_bans?.includes(role.title) ? (
                      <span className="PreferencesMenu__AwayRoleRestricted">
                        <Icon name="lock" /> Забанен
                      </span>
                    ) : (
                      <>
                        <PriorityButtons
                          jobTitle={role.title}
                          priority={priorities?.[role.title] ?? null}
                          createSetPriority={(level) => () =>
                            act('set_away_job_preference', {
                              job: role.title,
                              level,
                            })
                          }
                        />
                        <JobSlotDropdown name={role.title} />
                      </>
                    )}
                  </div>
                </li>
              ))}
            </ul>
          </Section>
        </Stack.Item>
      ))}
      <Stack.Item className="PreferencesMenu__AwayHint">
        Высокий приоритет можно дать одной выездной роли. Если в экипаже нет
        места, сработают настройки «На&nbsp;станции».
      </Stack.Item>
    </Stack>
  );
}
