import { Lexer } from 'marked';
import type { RefObject } from 'react';
import { Icon } from 'tgui-core/components';

const tools = [
  { format: 'bold', label: 'Жирный', icon: 'bold' },
  { format: 'italic', label: 'Курсив', icon: 'italic' },
  { format: 'heading', label: 'Заголовок', text: 'H2' },
  { format: 'subheading', label: 'Подзаголовок', text: 'H3' },
  { format: 'bullet', label: 'Маркированный список', icon: 'list-ul' },
  { format: 'number', label: 'Нумерованный список', icon: 'list-ol' },
] as const;

type Format = (typeof tools)[number]['format'];
type BlockFormat = Exclude<Format, 'bold' | 'italic'>;
type Edit = {
  from: number;
  to: number;
  replacement: string;
  selectFrom: number;
  selectTo: number;
};

function splitLine(line: string) {
  const [, indent, marker = ''] =
    /^([ \t]*)((?:#{1,6}|[-+*]|\d+[.)])[ \t]+)?/.exec(line)!;
  return { indent, marker, body: line.slice(indent.length + marker.length) };
}

function emphasisMarkers(body: string, atCaret: boolean): string[] {
  if (!/^[*_]/.test(body)) return [];
  // Empty pairs are still being typed and Markdown reads them as literal punctuation.
  if (atCaret && /^\*{2}$|^\*{4}$|^\*{6}$/.test(body)) {
    return body.length === 6 ? ['*', '**'] : ['*'.repeat(body.length / 2)];
  }
  const markers: string[] = [];
  let tokens = Lexer.lexInline(body);
  while (tokens.length === 1) {
    const [token] = tokens;
    if (token.type !== 'strong' && token.type !== 'em') break;
    markers.push(token.raw[0].repeat(token.type === 'strong' ? 2 : 1));
    tokens = token.tokens ?? [];
  }
  return markers;
}

function inlineEdit(
  value: string,
  start: number,
  end: number,
  marker: string,
): Edit {
  // Markdown emphasis must sit directly against the first and last non-space character.
  const selected = value.slice(start, end);
  if (selected.trim()) {
    start += selected.length - selected.trimStart().length;
    end -= selected.length - selected.trimEnd().length;
  }
  let around = 0;
  while (around < 3 && start > around && end + around < value.length) {
    const left = value[start - around - 1];
    if (!'*_'.includes(left) || left !== value[end + around]) break;
    around++;
  }
  const from = start - around;
  const to = end + around;
  const lines = value
    .slice(from, to)
    .split('\n')
    .map((line, index) => {
      const atLineStart = index > 0 || from === 0 || value[from - 1] === '\n';
      const {
        indent,
        marker: blockMarker,
        body: content,
      } = atLineStart
        ? splitLine(line)
        : { indent: '', marker: '', body: line };
      const body = content.trimEnd();
      const suffix = content.slice(body.length);
      const markers = emphasisMarkers(body, start === end);
      const active = markers.some((part) => part.length === marker.length);
      return { prefix: indent + blockMarker, body, suffix, markers, active };
    });
  const remove = lines.every((line) => !line.body || line.active);
  const parts = lines.map(({ prefix, body, suffix, markers, active }) => {
    const depth = markers.join('').length;
    const inner = body.slice(depth, body.length - depth);
    if (remove && active) {
      markers.splice(
        markers.findIndex((part) => part.length === marker.length),
        1,
      );
    } else if (!active && (body || start === end)) {
      // Adjacent single asterisks would turn separate italic spans into bold delimiters.
      const alternate =
        marker === '*' &&
        !depth &&
        (body.startsWith('*') || body.endsWith('*'));
      markers.unshift(alternate ? '_' : marker);
    }
    const opening = markers.join('');
    const closing = markers.reverse().join('');
    return {
      text: prefix + opening + inner + closing + suffix,
      left: prefix.length + opening.length,
      right: suffix.length + closing.length,
    };
  });
  const replacement = parts.map((part) => part.text).join('\n');
  return {
    from,
    to,
    replacement,
    selectFrom: from + parts[0].left,
    selectTo: from + replacement.length - parts[parts.length - 1].right,
  };
}

function blockEdit(
  value: string,
  start: number,
  end: number,
  format: BlockFormat,
): Edit {
  const from = value.slice(0, start).lastIndexOf('\n') + 1;
  const last = end > start && value[end - 1] === '\n' ? end - 1 : end;
  const nextBreak = value.indexOf('\n', last);
  const to = nextBreak === -1 ? value.length : nextBreak;
  const lines = value.slice(from, to).split('\n').map(splitLine);
  const prefix = {
    heading: '## ',
    subheading: '### ',
    bullet: '- ',
    number: '1. ',
  }[format];
  const remove =
    lines.every(({ marker, body }) => {
      if (!marker && !body) return true;
      if (format === 'number') return /^\d+[.)]/.test(marker);
      if (format === 'bullet') return /^[-+*]/.test(marker);
      return marker.trim() === prefix.trim();
    }) && lines.some((line) => line.marker);
  let number = 0;
  let caret = start;
  const replacement = lines
    .map(({ indent, marker, body }) => {
      if (lines.length > 1 && !marker && !body) return indent;
      const newMarker = remove
        ? ''
        : format === 'number'
          ? `${++number}. `
          : prefix;
      if (start === end) {
        caret =
          from +
          indent.length +
          newMarker.length +
          Math.max(0, start - from - indent.length - marker.length);
      }
      return indent + newMarker + body;
    })
    .join('\n');
  return {
    from,
    to,
    replacement,
    selectFrom: start === end ? caret : from,
    selectTo: start === end ? caret : from + replacement.length,
  };
}

export function FormattingToolbar(props: {
  field: RefObject<HTMLTextAreaElement | null>;
  onChange: (text: string) => void;
}) {
  function apply(format: Format) {
    const area = props.field.current;
    if (!area) return;
    const { value, selectionStart, selectionEnd, selectionDirection } = area;
    const edit =
      format === 'bold' || format === 'italic'
        ? inlineEdit(
            value,
            selectionStart,
            selectionEnd,
            format === 'bold' ? '**' : '*',
          )
        : blockEdit(value, selectionStart, selectionEnd, format);
    area.focus();
    area.setSelectionRange(edit.from, edit.to);
    // Chromium records insertText in the textarea's native undo history.
    if (!document.execCommand?.('insertText', false, edit.replacement)) {
      area.setRangeText(edit.replacement, edit.from, edit.to, 'end');
    }
    props.onChange(area.value);
    area.setSelectionRange(edit.selectFrom, edit.selectTo, selectionDirection);
  }

  return (
    <div
      className="IllustratedBook__formatting"
      role="group"
      aria-label="Оформление страницы"
    >
      {tools.map((tool) => (
        <button
          key={tool.format}
          type="button"
          title={tool.label}
          aria-label={tool.label}
          onMouseDown={(event) => event.preventDefault()}
          onClick={() => apply(tool.format)}
        >
          {'icon' in tool ? <Icon name={tool.icon} /> : tool.text}
        </button>
      ))}
    </div>
  );
}
