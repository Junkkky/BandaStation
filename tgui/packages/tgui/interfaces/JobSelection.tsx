import { useEffect } from 'react';
import { Color } from 'tgui-core/color';
import {
  Box,
  Button,
  Icon,
  NoticeBox,
  Section,
  Stack,
  StyleableSection,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import {
  DEPARTMENTS_RU,
  JOBS_RU,
  ReverseJobsRu,
} from '../bandastation/ru_jobs'; // BANDASTATION EDIT
import { Window } from '../layouts';
import { JOB2ICON } from './common/JobToIcon';

type Job = {
  unavailable_reason: string | null;
  open_slots: number | '∞';
  used_slots: number;
  prioritized: BooleanLike;
  jobIcon: string;
  character_profile?: string;
  public_title?: string;
};

type JobDetails = {
  command: BooleanLike;
  description: string;
  job_icon?: string;
};

type Department = {
  jobs: Record<string, Job>;
  open_slots: number | '∞';
};

type DepartmentDetails = {
  color: string;
  jobs: Record<string, JobDetails>;
};

type Data = {
  departments_static: Record<string, DepartmentDetails>;
  departments: Record<string, Department>;
  alert_state: string;
  shuttle_status: string;
  disable_jobs_for_non_observers: BooleanLike;
  edit_slot: number;
  priority: BooleanLike;
  round_duration: string;
};

type JobEntryProps = {
  jobName: string;
  job: Job;
  details?: JobDetails;
  color: string;
  disabled: boolean;
  onClick: () => void;
};

function JobEntry(props: JobEntryProps) {
  const { jobName, job, details, color, disabled, onClick } = props;
  const jobIcon = job.jobIcon || JOB2ICON[ReverseJobsRu(jobName)];
  const title = job.public_title || JOBS_RU[jobName] || jobName;
  const unavailable = disabled || !!job.unavailable_reason;

  return (
    <Button
      fluid
      disabled={unavailable}
      style={{
        backgroundColor: unavailable
          ? '#949494' // Grey background
          : job.prioritized
            ? '#16fc0f' // Bright green background
            : Color.fromHex(color).darken(10).toString(),
        color: unavailable
          ? '#616161' // Dark grey font
          : Color.fromHex(color).darken(90).toString(),
        fontSize: '1.1rem',
        cursor: unavailable ? 'initial' : 'pointer',
      }}
      tooltip={
        job.unavailable_reason ||
        (job.prioritized ? (
          <>
            <p style={{ marginTop: '0px' }}>
              <b>The HoP wants more people in this job!</b>
            </p>
            {details?.description}
          </>
        ) : (
          details?.description
        ))
      }
      tooltipPosition="top"
      onClick={onClick}
    >
      <Stack fill>
        {(details?.job_icon || jobIcon) && (
          <Stack.Item>
            {details?.job_icon ? (
              <img
                src={`data:image/png;base64,${details.job_icon}`}
                alt=""
                width={16}
                height={16}
                style={{ imageRendering: 'pixelated', marginRight: '0.1em' }}
              />
            ) : (
              <Icon style={{ marginRight: '0.1em' }} name={jobIcon} />
            )}
          </Stack.Item>
        )}
        <Stack.Item grow>
          {details?.command ? <b>{title}</b> : title}
          {job.character_profile && (
            <Box fontSize={0.8} opacity={0.75}>
              {job.character_profile}
            </Box>
          )}
        </Stack.Item>
        <Stack.Item>
          <span
            style={{
              whiteSpace: 'nowrap',
            }}
          >
            {job.used_slots} / {job.open_slots}
          </span>
        </Stack.Item>
      </Stack>
    </Button>
  );
}

type DepartmentEntryProps = {
  name: string;
  department: Department;
  details: DepartmentDetails;
};

function DepartmentEntry(props: DepartmentEntryProps) {
  const { name, department, details } = props;
  const { act, data } = useBackend<Data>();
  const { color } = details;

  return (
    <Box minWidth="30%">
      <StyleableSection
        title={
          <>
            {name}
            <span
              style={{
                fontSize: '1rem',
                whiteSpace: 'nowrap',
                position: 'absolute',
                right: '1em',
                color: Color.fromHex(color).darken(60).toString(),
              }}
            >
              {`позиций доступно: ${department.open_slots}`}
            </span>
          </>
        }
        style={{
          backgroundColor: color,
          marginBottom: '1em',
          breakInside: 'avoid-column',
        }}
        titleStyle={{
          borderBottomColor: Color.fromHex(color).darken(50).toString(),
        }}
        textStyle={{
          color: Color.fromHex(color).darken(80).toString(),
        }}
      >
        <Stack vertical>
          {Object.entries(department.jobs).map(([name, job]) => (
            <Stack.Item key={name}>
              <JobEntry
                key={name}
                jobName={name}
                job={job}
                details={details.jobs[name]}
                color={color}
                disabled={!!data.disable_jobs_for_non_observers}
                onClick={() =>
                  act('select_job', { job: name, edit_slot: data.edit_slot })
                }
              />
            </Stack.Item>
          ))}
        </Stack>
      </StyleableSection>
    </Box>
  );
}

export function JobSelection(props) {
  const { act, data } = useBackend<Data>();
  const ready = !!data?.departments_static && !!data.departments;
  useEffect(() => {
    if (ready) {
      act('ui_mounted_with_no_bluescreen');
    }
  }, [act, ready]);

  if (!ready) {
    return null; // Stop TGUI whitescreens with TGUI-dev!
  }

  const { departments, edit_slot, shuttle_status, round_duration } = data;
  const disabled = !!data.disable_jobs_for_non_observers;

  return (
    <Window width={1012} height={shuttle_status ? 690 : 666 /* Hahahahahaha */}>
      <Window.Content>
        <Section
          buttons={
            <Button
              disabled={disabled}
              onClick={() => act('select_job', { job: 'Random', edit_slot })}
              tooltip="Случайно выбрать профессию. Вы можете повторно выбирать случайную профессию или отказаться от этого."
            >
              Случайная профессия!
            </Button>
          }
          fill
          scrollable
          title={
            <>
              {shuttle_status && <NoticeBox info>{shuttle_status}</NoticeBox>}
              {disabled && (
                <NoticeBox danger>
                  Вход в раунд временно отключён администрацией.
                </NoticeBox>
              )}
              <Box as="span" color="label">
                It is currently {round_duration} into the shift.
              </Box>
            </>
          }
        >
          <Box style={{ columns: '20em' }}>
            {Object.entries(departments).map(([name, department]) => {
              const details = data.departments_static[name];
              return (
                details &&
                Object.keys(department.jobs).length > 0 && (
                  <DepartmentEntry
                    key={name}
                    name={DEPARTMENTS_RU[name] || name}
                    department={department}
                    details={details}
                  />
                )
              );
            })}
          </Box>
        </Section>
      </Window.Content>
    </Window>
  );
}
