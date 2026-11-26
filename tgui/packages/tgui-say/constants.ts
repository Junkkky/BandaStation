/** Window sizes in pixels */
export enum WindowSize {
  Small = 30,
  Medium = 50,
  Large = 68,
  Width = 325,
}

/** Line lengths for autoexpand */
export enum LineLength {
  Small = 30,
  Medium = 60,
  Large = 90,
}

/**
 * Radio prefixes.
 * Displays the name in the left button, tags a css class.
 */
export const RADIO_PREFIXES = {
  ':a ': 'Рой',
  ':b ': 'Бин',
  ':c ': 'Ком',
  ':e ': 'Инж',
  ':g ': 'Генка',
  ':m ': 'Мед',
  ':n ': 'Иссл',
  ':o ': 'ИИ',
  ':p ': 'Развл',
  ':q ': 'Патр',
  ':s ': 'Безоп',
  ':l ': 'Юр',
  ':t ': 'Синд',
  ':u ': 'Снаб',
  ':v ': 'Обсл',
  ':h ': 'Эксп',
  ':y ': 'ЦК',

  ':ф ': 'Рой',
  ':и ': 'Бин',
  ':с ': 'Ком',
  ':у ': 'Инж',
  ':п ': 'Генка',
  ':ь ': 'Мед',
  ':т ': 'Иссл',
  ':щ ': 'ИИ',
  ':з ': 'Развл',
  ':й ': 'Патр',
  ':ы ': 'Безоп',
  ':д ': 'Юр',
  ':е ': 'Синд',
  ':г ': 'Снаб',
  ':м ': 'Обсл',
  ':р ': 'Эксп',
  ':н ': 'ЦК',
} as const;
