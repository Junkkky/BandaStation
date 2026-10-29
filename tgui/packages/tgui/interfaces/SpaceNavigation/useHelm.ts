// AI EDIT START - Server-retained manual lateral thrust and bounded throttle input
import { useEffect, useRef } from 'react';

import { useBackend } from '../../backend';
import type { NavigationData } from './types';

export function useHelm(data: NavigationData) {
  const { act } = useBackend();
  const current = useRef(data);
  current.current = data;
  const held = useRef(new Set<string>());
  const send = useRef<() => void>(() => {});
  const throttleOrder = useRef({ value: data.throttle, at: 0 });
  const blocked = !!(
    !data.engines_running ||
    data.coupled ||
    data.preparing ||
    data.relocating ||
    data.jumping
  );
  const lateralBlocked =
    blocked || !!(data.docked || data.autopilot || data.braking);

  const setThrottle = (value: number) => {
    throttleOrder.current = { value, at: Date.now() };
    act('throttle', { value });
  };

  const changeThrottle = (delta: number) => {
    const state = current.current;
    if (
      !state.engines_running ||
      state.coupled ||
      state.preparing ||
      state.relocating ||
      state.jumping
    )
      return;
    const prior = throttleOrder.current;
    const value = Math.max(
      -100,
      Math.min(
        100,
        (Date.now() - prior.at < 1000 ? prior.value : state.throttle) + delta,
      ),
    );
    setThrottle(value);
  };
  const throttleStep = useRef(changeThrottle);
  throttleStep.current = changeThrottle;

  useEffect(() => {
    const transmit = () => {
      const state = current.current;
      const left =
        held.current.has('ArrowLeft') || held.current.has('mouse-left');
      const right =
        held.current.has('ArrowRight') || held.current.has('mouse-right');
      if (
        !state.engines_running ||
        state.preparing ||
        state.relocating ||
        state.jumping ||
        state.coupled ||
        state.docked ||
        state.autopilot ||
        state.braking
      ) {
        held.current.clear();
      }
      act('maneuver', {
        value: held.current.size ? (left === right ? 0 : left ? 8 : 4) : 0,
      });
    };
    send.current = transmit;
    const release = () => {
      if (!held.current.size) return;
      held.current.clear();
      transmit();
    };
    let lastKey = 0;
    const down = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement;
      if (
        event.defaultPrevented ||
        event.altKey ||
        event.ctrlKey ||
        event.metaKey ||
        target.isContentEditable ||
        /INPUT|TEXTAREA|SELECT/.test(target.tagName)
      )
        return;
      if (
        !['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', ' '].includes(
          event.key,
        )
      )
        return;
      event.preventDefault();
      if (event.key === ' ') {
        if (!event.repeat) {
          release();
          throttleOrder.current = { value: 0, at: Date.now() };
          act('stop');
        }
      } else if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
        if (held.current.has(event.key)) return;
        held.current.add(event.key);
        transmit();
      } else if (Date.now() - lastKey >= 150) {
        lastKey = Date.now();
        throttleStep.current(event.key === 'ArrowUp' ? 5 : -5);
      }
    };
    const up = (event: KeyboardEvent) => {
      if (held.current.delete(event.key)) transmit();
    };
    const mouseUp = (event: MouseEvent) => {
      if (event.button !== 0) return;
      const left = held.current.delete('mouse-left');
      const right = held.current.delete('mouse-right');
      if (left || right) transmit();
    };
    document.addEventListener('keydown', down);
    document.addEventListener('keyup', up);
    document.addEventListener('mouseup', mouseUp);
    return () => {
      document.removeEventListener('keydown', down);
      document.removeEventListener('keyup', up);
      document.removeEventListener('mouseup', mouseUp);
    };
  }, [act]);

  useEffect(() => {
    if (lateralBlocked && held.current.size) {
      held.current.clear();
      send.current();
    }
    if (blocked || (!data.helm && data.throttle === 0 && data.speed <= 0.05)) {
      throttleOrder.current = { value: data.throttle, at: 0 };
    }
  }, [blocked, lateralBlocked, data.helm, data.throttle, data.speed]);

  return {
    blocked,
    lateralBlocked,
    changeThrottle,
    setThrottle,
    hold: (side: string) => {
      if (lateralBlocked) return;
      held.current.add(`mouse-${side}`);
      send.current();
    },
  };
}
// AI EDIT END
