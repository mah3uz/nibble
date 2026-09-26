// Keeps a consistent style across the frontend.
/** @type {import('prettier').Config} */
export default {
  singleQuote: true,
  semi: false,
  trailingComma: 'all',
  tabWidth: 2,
  bracketSpacing: true,
  printWidth: 120,
  plugins: ['prettier-plugin-tailwindcss'],
  tailwindStylesheet: './vendor/nibble/frontend/entrypoints/cp.css',
}
