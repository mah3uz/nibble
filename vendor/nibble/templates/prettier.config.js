/** @type {import('prettier').Config} */
export default {
  singleQuote: true,
  semi: false,
  trailingComma: 'all',
  tabWidth: 2,
  printWidth: 120,
  plugins: ['prettier-plugin-tailwindcss'],
  tailwindStylesheet: './vendor/nibble/frontend/entrypoints/admin.css',
}
