import pluginVue from 'eslint-plugin-vue'
import { defineConfigWithVueTs, vueTsConfigs } from '@vue/eslint-config-typescript'
import skipFormatting from '@vue/eslint-config-prettier/skip-formatting'

export default defineConfigWithVueTs(
  {
    ignores: ['public/**', 'tmp/**', 'log/**', 'storage/**', 'vendor/**', '**/node_modules/**', 'site/types.d.ts'],
  },
  pluginVue.configs['flat/recommended'],
  vueTsConfigs.recommended,
  // A view is addressed by its path and receives Rails' snake_case props.
  {
    files: ['site/themes/**/*.{ts,vue}', 'site/cp/**/*.vue'],
    rules: { 'vue/multi-word-component-names': 'off', 'vue/prop-name-casing': 'off' },
  },
  // A theme stays swappable: it may import only @nibble, @theme, relative paths and its own dependencies.
  {
    files: ['site/themes/**/*.{ts,vue}'],
    rules: {
      'no-restricted-imports': [
        'error',
        {
          patterns: [
            {
              group: ['@/*', '~/*', '**/vendor/nibble/frontend/**'],
              message: 'Themes may only import @nibble, @theme, relative paths and their own dependencies.',
            },
          ],
        },
      ],
    },
  },
  skipFormatting,
)
