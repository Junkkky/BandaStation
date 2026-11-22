import { expect, it } from 'bun:test';
import { render } from '@testing-library/react';

import { TicketMessage } from './TicketMessage';

it('preserves literal entities alongside formatted text and attachments', () => {
  const { container, getByText } = render(
    <TicketMessage
      hasStaffAccess
      messageHolder={{
        sender: 'player',
        message: '<span><b>note</b></span> Literal &amp;copy;<img src="/emoji.png">',
        time: '2026-11-22 18:00:00',
      }}
    />,
  );

  expect(container.textContent).toContain('Literal &copy;');
  expect(getByText('note').tagName).toBe('B');
  expect(container.querySelector('img')?.getAttribute('src')).toBe('/emoji.png');
});
