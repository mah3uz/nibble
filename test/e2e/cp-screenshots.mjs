#!/usr/bin/env node
import { readFileSync, mkdirSync } from 'node:fs'
import { chromium } from 'playwright'

const [base = 'http://localhost:3100', email, passwordFile, outDir = 'tmp/cp-screens'] = process.argv.slice(2)
const password = readFileSync(passwordFile, 'utf8').trim()
mkdirSync(outDir, { recursive: true })

const browser = await chromium.launch()
const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } })
const page = await context.newPage()
const errors = []
page.on('console', (message) => message.type() === 'error' && errors.push(`${page.url()}: ${message.text()}`))
page.on('pageerror', (error) => errors.push(`${page.url()}: ${error.message}`))

await page.goto(`${base}/cp`, { waitUntil: 'networkidle' })
await page.waitForTimeout(1000)
await page.locator('#email').fill(email)
await page.locator('#password').fill(password)
await page.getByRole('button', { name: 'Sign in' }).click()
await page.waitForURL(`${base}/cp`)

const shots = process.argv.includes('--paths')
  ? process.argv[process.argv.indexOf('--paths') + 1].split(',')
  : [
      '/cp',
      '/cp/collections/pages',
      '/cp/collections/posts',
      '/cp/globals',
      '/cp/utilities',
      '/cp/trash',
    ]

for (const path of shots) {
  await page.goto(`${base}${path}`, { waitUntil: 'networkidle' })
  const name = path.replace(/[^a-z0-9]+/gi, '-').replace(/^-|-$/g, '') || 'root'
  await page.screenshot({ path: `${outDir}/${name}.png`, fullPage: true })
  console.log(`${path} -> ${outDir}/${name}.png`)
}

await page.goto(`${base}/cp/collections/pages`, { waitUntil: 'networkidle' })
const firstRow = page.locator('tbody tr a, tbody tr [role=link]').first()
if (await firstRow.count()) {
  await firstRow.click()
  await page.waitForLoadState('networkidle')
  await page.screenshot({ path: `${outDir}/editor.png`, fullPage: true })
  console.log(`editor -> ${outDir}/editor.png`)
}

if (errors.length) console.log(`\nconsole errors:\n${errors.join('\n')}`)
await browser.close()
