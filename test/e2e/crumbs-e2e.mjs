#!/usr/bin/env node
import { AxeBuilder } from '@axe-core/playwright'
import { chromium } from 'playwright'

const [base = 'http://localhost:3300'] = process.argv.slice(2)
const b = await chromium.launch()
const context = await b.newContext({ viewport: { width: 1280, height: 900 } })
const page = await context.newPage()
const errors = []
const checks = []
// The 404 page reports its own status as a failed request; every other console error is a real one.
const ignored = (text) => text.includes('status of 404')
page.on(
  'console',
  (message) =>
    message.type() === 'error' && !ignored(message.text()) && errors.push(`${page.url()}: ${message.text()}`),
)
page.on('pageerror', (error) => errors.push(`${page.url()}: ${error.message}`))

const check = (name, ok, detail = '') => checks.push({ name, ok: !!ok, detail })

async function visit(path) {
  const response = await page.goto(`${base}${path}`, { waitUntil: 'networkidle' })
  return response
}

async function audit(path) {
  const { violations } = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
  const serious = violations.filter((violation) => ['serious', 'critical'].includes(violation.impact))
  check(
    `${path} has no serious accessibility violations`,
    serious.length === 0,
    serious.map((v) => `${v.id} (${v.nodes.length})`).join(', '),
  )
}

const pages = [
  ['/', 'Crumbs left by people who make things'],
  ['/blog', 'The archive'],
  ['/blog/the-first-crumb', 'The first crumb'],
  ['/about', 'About Crumbs'],
  ['/topics', 'Topics'],
  ['/topics/slow-work', 'Slow work'],
  ['/authors/mo-ferris', 'Mo Ferris'],
  ['/search', 'Search'],
  ['/no-such-crumb', 'Nothing but crumbs here'],
]

for (const [path, expected] of pages) {
  const response = await visit(path)
  const status = response?.status()
  const html = await page.content()
  check(
    `${path} responds ${path === '/no-such-crumb' ? '404' : '200'}`,
    status === (path === '/no-such-crumb' ? 404 : 200),
    String(status),
  )
  check(`${path} renders "${expected}"`, html.includes(expected))
  check(`${path} hydrated (nav is interactive)`, (await page.locator('header nav a').count()) > 0)
  await audit(path)
}

await visit('/')
await page.getByRole('switch', { name: 'Lights' }).click()
const theme = await page.evaluate(() => document.documentElement.dataset.theme)
await page.reload({ waitUntil: 'networkidle' })
check(
  'theme switch persists across reloads',
  (await page.evaluate(() => document.documentElement.dataset.theme)) === theme,
  String(theme),
)

await visit('/search')
await page.locator('#query').fill('changelog')
await page.locator('form[role=search] button[type=submit]').last().click()
await page.waitForURL(/q=changelog/)
check('search returns the matching article', (await page.getByText('What a good changelog sounds like').count()) > 0)
check('search highlights the match', (await page.locator('mark').count()) > 0)

await visit('/blog')
check(
  'the archive lists articles by year',
  (await page.locator('section h2').first().textContent())?.trim().match(/^\d{4}$/) !== null,
)

console.log(
  checks
    .map((entry) => `${entry.ok ? '✓' : '✗'} ${entry.name}${entry.detail && !entry.ok ? ` — ${entry.detail}` : ''}`)
    .join('\n'),
)
if (errors.length) console.log(`\nconsole errors:\n${errors.join('\n')}`)
await b.close()
const failed = checks.filter((entry) => !entry.ok).length
console.log(`\n${checks.length - failed}/${checks.length} checks passed`)
process.exit(failed || errors.length ? 1 : 0)
