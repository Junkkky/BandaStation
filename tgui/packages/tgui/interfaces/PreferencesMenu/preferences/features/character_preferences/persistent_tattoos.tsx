import { CheckboxInput, type FeatureToggle } from '../base';

export const persistent_tattoos: FeatureToggle = {
  name: 'Сохранять новые татуировки',
  description:
    'При согласовании эскиза сохранение для следующих раундов будет включено. Для каждого рисунка выбор можно изменить.',
  component: CheckboxInput,
};
