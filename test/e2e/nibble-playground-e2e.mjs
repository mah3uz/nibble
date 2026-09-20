#!/usr/bin/env node
import { chromium } from 'playwright'
import { readFileSync } from 'node:fs'
const [base = 'http://localhost:3100', email = 'you@example.com', passwordFile = 'tmp/dev-admin-password'] =
  process.argv.slice(2)
const password = readFileSync(passwordFile, 'utf8').trim()
const b = await chromium.launch()
const page = await b.newPage({ viewport: { width: 1440, height: 1000 } })
const errors = []
page.on('pageerror', (e) => errors.push(e.message))
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))
const failures = []
const check = (label, ok, detail) => {
  console.log(ok ? '✓' : '✗', label, detail ?? '')
  if (!ok) failures.push(label)
}
const field = (path) => page.locator(`[data-field-path="${path}"]`)
const settle = (ms = 400) => page.waitForTimeout(ms)
const json = async (testid) => JSON.parse(await page.getByTestId(testid).textContent())

await page.goto(`${base}/admin`)
await page.waitForLoadState('networkidle')
await page.getByLabel('Email').fill(email)
await page.getByLabel('Password').fill(password)
await page.getByRole('button', { name: 'Sign in' }).click()
await page.waitForURL(`${base}/admin`)

await page.goto(`${base}/admin/nibble/playground?blueprint=kitchen_sink`)
await page.getByTestId('validate').waitFor()
await settle(1500)
await page.screenshot({ path: 'tmp/nibble-playground-initial.png', fullPage: true })

const unsupported = await page.getByText('Unsupported fieldtype component').count()
check('every kitchen-sink field has a registered component', unsupported === 0, `${unsupported} unsupported`)
for (const path of [
  'title',
  'slug',
  'excerpt',
  'count',
  'featured',
  'category',
  'tags',
  'layout',
  'channels',
  'published_on',
  'event_starts',
  'show_cta',
  'hours',
  'links',
  'blocks',
  'body',
]) {
  check(`field "${path}" renders`, (await field(path).count()) === 1)
}
check('conditional field starts hidden', (await field('cta_label').count()) === 0)

await page.getByTestId('validate').click()
await page.getByTestId('status').waitFor()
check('empty submission is invalid', (await page.getByTestId('status').textContent()).includes('error'))
check('title shows its required error', (await field('title').getByText('The Title field is required.').count()) === 1)

await field('title').locator('input').fill('Hello Nibble World')
await settle()
check('slug generates from title', (await field('slug').locator('input').inputValue()) === 'hello-nibble-world')

await field('show_cta').getByRole('switch').click()
await settle()
check('toggle reveals the conditional field', (await field('cta_label').count()) === 1)
await field('cta_label').locator('input').fill('Buy now')

await field('category').getByRole('combobox').click()
await page.getByRole('option', { name: 'News' }).click()
await field('layout').getByRole('radio').nth(1).click()
await field('channels').getByRole('checkbox').first().click()
await field('count').locator('input').fill('3')

await field('hours').getByRole('button', { name: 'Add hours' }).click()
await field('hours').locator('input').first().fill('Mon 9-5')
await field('links').getByRole('button', { name: 'Add link' }).click()
await settle()
await field('links.0.label').locator('input').fill('Docs')

await field('blocks').getByRole('button', { name: 'Add block' }).click()
await page.getByRole('option', { name: 'Quote' }).click()
await settle()
check('adding a set renders its fields', (await field('blocks.0.quote').count()) === 1)
check('nested conditional field starts hidden', (await field('blocks.0.attribution').count()) === 0)
await field('blocks.0.quote').locator('textarea').fill('Stay curious')
await settle()
check('nested condition reveals a sibling in the same set', (await field('blocks.0.attribution').count()) === 1)

const editor = field('body').locator('.ProseMirror')
await editor.click()
await page.keyboard.type('Intro paragraph')
await field('body').getByRole('button', { name: 'Add set' }).first().click()
await page.getByRole('option', { name: 'Callout' }).click()
await settle(800)
const calloutPath = await field('body')
  .locator('[data-field-path$=".attrs.values.message"]')
  .first()
  .getAttribute('data-field-path')
check('rich text set renders its fields', !!calloutPath, calloutPath)
if (calloutPath) {
  await field(calloutPath).locator('textarea').fill('Remember this')
  await settle()
}

await page.screenshot({ path: 'tmp/nibble-playground-filled.png', fullPage: true })

await page.getByRole('tab', { name: 'Relations' }).click()
await field('related').getByRole('combobox').click()
await page.getByRole('option', { name: /About us/ }).click()
await settle()
check('picked entry shows by title', (await field('related').getByText('About us').count()) >= 1)
await field('gallery').getByRole('combobox').click()
await page.getByRole('option', { name: /Forest/ }).click()
await settle()
await field('gallery').getByLabel('Alt text for Forest').fill('Tall trees')
await page.getByRole('tab', { name: 'Main' }).click()

await page.getByTestId('validate').click()
await page.getByTestId('status').waitFor()
await settle()
const status = await page.getByTestId('status').textContent()
check('filled submission is valid', status.includes('Valid'), status)

if (status.includes('Valid')) {
  const processed = await json('processed')
  const augmented = await json('augmented')
  check('stored slug', processed.slug === 'hello-nibble-world', processed.slug)
  check('stored integer is a number', processed.count === 3, processed.count)
  check(
    'stored replicator row keeps type and id',
    processed.blocks?.[0]?.type === 'quote' && !!processed.blocks?.[0]?.id,
  )
  check('stored grid row', processed.links?.[0]?.label === 'Docs')
  check('stored relationship ids', JSON.stringify(processed.related) === '["e1"]', JSON.stringify(processed.related))
  check(
    'stored asset keeps per-use alt',
    processed.gallery?.[0]?.alt === 'Tall trees',
    JSON.stringify(processed.gallery),
  )
  check('stored rich text keeps the set', JSON.stringify(processed.body ?? []).includes('Remember this'))
  check('public select carries its label', augmented.category?.label === 'News')
  check('public relationship is a summary', augmented.related?.[0]?.url === '/about')
  check(
    'public rich text splits into text and set blocks',
    augmented.body?.some?.((block) => block.type === 'callout'),
  )
}

check('no console or page errors', errors.length === 0, errors.slice(0, 5).join(' | '))
await b.close()
if (failures.length) {
  console.error(`\n${failures.length} check(s) failed`)
  process.exit(1)
}
console.log('\nAll playground checks passed')
