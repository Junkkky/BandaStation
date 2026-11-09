import { type Feature, FeatureShortTextInput, FeatureTextInput } from '../base';

export const flavor_text: Feature<string> = {
  name: 'Описание внешности',
  description: 'Опишите вашего персонажа!',
  component: FeatureTextInput,
};

export const silicon_flavor_text: Feature<string> = {
  name: 'Описание внешности (Синтетик)',
  description: 'Опишите вашего синтетика!',
  component: FeatureTextInput,
};

export const character_portrait_url: Feature<string> = {
  name: 'Ссылка на портрет 1',
  description:
    'Прямая HTTPS-ссылка на PNG или JPEG с Gyazo, Lensdump, Imgbox, Catbox или File Garden. Очистите поле, чтобы убрать портрет.',
  component: FeatureShortTextInput,
};

export const character_portrait_url_2: Feature<string> = {
  ...character_portrait_url,
  name: 'Ссылка на портрет 2',
};

export const character_portrait_url_3: Feature<string> = {
  ...character_portrait_url,
  name: 'Ссылка на портрет 3',
};
