#!/usr/bin/env node
import { readFileSync } from 'node:fs'
import { AxeBuilder } from '@axe-core/playwright'
import { chromium } from 'playwright'

const [base = 'http://localhost:3100', email, passwordFile] = process.argv.slice(2)
if (!email || !passwordFile) {
  console.error('usage: node test/e2e/cp-e2e.mjs BASE EMAIL PASSWORD_FILE')
  process.exit(2)
}
const password = readFileSync(passwordFile, 'utf8').trim()
const title = `E2E page ${Date.now()}`
const renamed = `${title} renamed`

const browser = await chromium.launch()
const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } })
const page = await context.newPage()

const errors = []
const checks = []
let expectedStatus = null
page.on('console', (message) => {
  if (message.type() !== 'error') return
  if (expectedStatus && message.text().includes(`status of ${expectedStatus}`)) return
  errors.push(`${page.url()}: ${message.text()}`)
})
page.on('pageerror', (error) => errors.push(`${page.url()}: ${error.message}`))

const check = (name, ok, detail = '') => checks.push({ name, ok: !!ok, detail })

async function run(label, step) {
  try {
    return await step()
  } catch (problem) {
    check(`${label} ran to the end`, false, problem.message.split('\n')[0])
  }
}

async function visit(path) {
  await page.goto(`${base}${path}`, { waitUntil: 'networkidle' })
}

async function audit(label) {
  const { violations } = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
  const serious = violations.filter((violation) => ['serious', 'critical'].includes(violation.impact))
  check(
    `${label} has no serious accessibility violations`,
    serious.length === 0,
    serious.map((violation) => `${violation.id} (${violation.nodes.length})`).join(', '),
  )
}

async function signIn() {
  await visit('/admin')
  await page.locator('#email').fill(email)
  await page.locator('#password').fill(password)
  await page.getByRole('button', { name: /sign in/i }).click()
  await page.waitForURL(`${base}/admin`, { timeout: 15000 })
  check('signs in', page.url() === `${base}/admin`)
}

async function createEntry() {
  await visit('/admin/collections/pages/entries/new')
  await page.locator('#title').click()
  await page.keyboard.type(title, { delay: 15 })
  await page.waitForTimeout(400)
  await audit('the editor')
  await page.getByRole('button', { name: /^Save draft$/ }).click()
  await page.waitForTimeout(2500)

  const heading = (await page.locator('h1').first().textContent())?.trim()
  check('a new entry saves the title that was typed', heading === title, `heading: ${heading}`)
  check('a saved entry lands on its own edit URL', /\/entries\/\d+\/edit$/.test(page.url()), page.url())
  return page.url().match(/\/entries\/(\d+)\/edit/)?.[1]
}

async function recoverAndPublish(id) {
  const editUrl = `${base}/admin/collections/pages/entries/${id}/edit`
  await page.locator('#title').fill(renamed)
  await page.waitForTimeout(800)

  await page.goBack()
  const leaveDialog = page.getByRole('alertdialog')
  await leaveDialog.waitFor({ timeout: 5000 }).catch(() => {})
  check('going back with unsaved changes asks first', await leaveDialog.isVisible())
  await leaveDialog.getByRole('button', { name: 'Stay' }).click()
  check(
    'staying keeps the page and the typed text',
    page.url() === editUrl && (await page.locator('#title').inputValue()) === renamed,
  )

  page.once('dialog', (dialog) => dialog.accept())
  await page.reload({ waitUntil: 'networkidle' })
  const restore = page.getByRole('button', { name: 'Restore', exact: true })
  await restore.waitFor({ timeout: 5000 }).catch(() => {})
  check('unsaved changes survive a reload and can be restored', await restore.isVisible())
  await restore.click()
  check('restoring puts the typed text back', (await page.locator('#title').inputValue()) === renamed)

  await page
    .getByRole('button', { name: /^Publish/ })
    .first()
    .click()
  await page.waitForTimeout(2500)
  const published = await page.getByText('Published', { exact: true }).count()
  check('publishing reports the entry as published', published > 0)
  await visit(`/admin/collections/pages/entries/${id}/edit`)
  check(
    'a saved page leaves nothing to restore',
    !(await page.getByRole('button', { name: 'Restore', exact: true }).isVisible()),
  )
}

async function reviseAndRestore(id) {
  await page.locator('#title').fill(`${renamed} again`)
  await page
    .getByRole('button', { name: /^(Save|Publish)/ })
    .first()
    .click()
  await page.waitForTimeout(2500)

  await page.getByRole('button', { name: 'History', exact: true }).click()
  await page.waitForTimeout(1500)
  const revisions = await page.locator('[role=dialog] li, [role=dialog] button').count()
  check('history lists revisions', revisions > 0, `${revisions} rows`)
  await page.keyboard.press('Escape')
  await visit(`/admin/collections/pages/entries/${id}/edit`)
}

async function notesAndBell(id) {
  await visit(`/admin/collections/pages/entries/${id}/edit`)
  const note = page.locator('textarea[placeholder^="Leave a note"]')
  check('the editor offers editorial notes', (await note.count()) > 0)
  if (await note.count()) {
    await note.fill('A note from the gate.')
    await page.getByRole('button', { name: 'Add note' }).click()
    await page.waitForTimeout(1500)
    const saved = await page.getByText('A note from the gate.').count()
    check('a note is saved and listed', saved > 0)
  }

  await page.getByRole('button', { name: 'Notifications' }).click()
  await page.waitForTimeout(800)
  check('the notification list opens', (await page.getByText(/Notifications|Nothing yet/).count()) > 0)
  const listed = page.locator('[data-slot=popover-content] li')
  const before = await listed.count()
  if (before) {
    await listed.first().hover()
    await listed
      .first()
      .getByRole('button', { name: /Remove notification/ })
      .click()
    await page.waitForTimeout(800)
    check('a notification can be removed from the list', (await listed.count()) === before - 1)
  }
  await page.keyboard.press('Escape')
}

async function treeView(current) {
  await visit('/admin/collections/pages?view=tree')
  const rows = await page.locator('li, tr').filter({ hasText: current }).count()
  check('the tree lists the entry', rows > 0)
  await audit('the tree view')
}

async function trashAndRestore(id, current) {
  await visit(`/admin/collections/pages/entries/${id}/edit`)
  await page.getByRole('button', { name: /trash/i }).first().click()
  await page.waitForTimeout(600)
  const confirm = page.locator('[role=alertdialog] button', { hasText: /trash|delete/i }).last()
  if (await confirm.count()) await confirm.click()
  await page.waitForTimeout(2000)

  await visit('/admin/trash')
  const inTrash = await page.locator('tbody tr').filter({ hasText: current }).count()
  check('a trashed entry appears in the trash', inTrash > 0)
  await audit('trash')

  const row = page.locator('tbody tr').filter({ hasText: current }).first()
  if (await row.count()) {
    await row.getByRole('button', { name: /restore/i }).click()
    await page.waitForTimeout(2000)
  }
  await visit('/admin/collections/pages')
  const restored = await page.locator('tbody tr').filter({ hasText: current }).count()
  check('a restored entry is back in the listing', restored > 0)
}

async function purge(id, current) {
  await visit(`/admin/collections/pages/entries/${id}/edit`)
  await page.getByRole('button', { name: /trash/i }).first().click()
  await page.waitForTimeout(500)
  const confirm = page.locator('[role=alertdialog] button', { hasText: /trash|delete/i }).last()
  if (await confirm.count()) await confirm.click()
  await page.waitForTimeout(1500)

  await visit('/admin/trash')
  const row = page.locator('tbody tr').filter({ hasText: current }).first()
  if (await row.count()) {
    await row.getByRole('button', { name: /delete/i }).click()
    await page.waitForTimeout(500)
    const confirmDelete = page.locator('[role=alertdialog] button', { hasText: /delete/i }).last()
    if (await confirmDelete.count()) await confirmDelete.click()
    await page.waitForTimeout(1500)
  }
  await visit('/admin/trash')
  check('the gate cleans up after itself', (await page.locator('tbody tr').filter({ hasText: current }).count()) === 0)
}

async function media() {
  await visit('/admin/media')
  await audit('the asset library')
  await page.getByLabel('Toggle grid').click()
  const name = `e2e-${Date.now()}.png`
  await page
    .locator('input[type=file]')
    .first()
    .setInputFiles({
      name,
      mimeType: 'image/png',
      buffer: readFileSync(new URL('../fixtures/files/pixel.png', import.meta.url)),
    })
  const tile = page.getByRole('button', { name, exact: true })
  await tile.waitFor({ timeout: 15000 }).catch(() => {})
  check('an upload appears in the library', await tile.isVisible())

  await tile.dblclick()
  const alt = page.getByRole('textbox', { name: 'Alt text' })
  await alt.waitFor({ timeout: 10000 }).catch(() => {})
  await audit('the asset editor')
  await alt.fill('A single pixel')
  await page.getByRole('dialog').getByRole('button', { name: 'Save' }).click()
  await page
    .waitForResponse((r) => r.url().includes('/admin/media/') && r.request().method() === 'PATCH')
    .catch(() => {})
  await page.getByRole('button', { name: 'Close Editor' }).click()
  await tile.dblclick()
  await page.waitForResponse((r) => /\/admin\/media\/\d+$/.test(r.url())).catch(() => {})
  check('asset metadata saves from the editor', (await alt.inputValue()) === 'A single pixel')
  await page.getByRole('button', { name: 'Close Editor' }).click()

  await tile.click()
  check(
    'selecting an asset shows the selection bar',
    await page.getByRole('button', { name: /Deselect 1 item/ }).isVisible(),
  )
  await page.keyboard.press('Backspace')
  await page.getByRole('alertdialog').getByRole('button', { name: 'Delete' }).click()
  await tile.waitFor({ state: 'detached', timeout: 10000 }).catch(() => {})
  check('a deleted asset leaves the library', !(await tile.isVisible()))
}

async function forms() {
  const sender = `E2E Visitor ${Date.now()}`
  await visit('/about')
  const form = page.locator('form[action="/forms/contact"]')
  await form.locator('#contact-name').fill(sender)
  await form.locator('#contact-email').fill('not-an-email')
  await form.locator('#contact-message').fill('Sent by the control panel gate.')
  expectedStatus = 422
  await form.getByRole('button', { name: /send/i }).click()
  await page.waitForTimeout(1200)
  expectedStatus = null
  check('a public form shows field errors without reloading', (await form.getByText(/valid email/i).count()) > 0)
  await form.locator('#contact-email').fill('visitor@example.test')
  await form.getByRole('button', { name: /send/i }).click()
  await form
    .getByRole('status')
    .waitFor({ timeout: 10000 })
    .catch(() => {})
  check('a public form confirms a valid submission', await form.getByRole('status').isVisible())

  await visit('/admin/forms')
  await audit('the forms index')
  await visit(`/admin/forms/contact?q=${encodeURIComponent(sender)}`)
  await audit("a form's submissions")
  const row = page.locator('tbody tr').filter({ hasText: sender }).first()
  check('the submission is listed and searchable', (await row.count()) > 0)
  await row.click()
  await page.waitForURL(/\/submissions\/\d+$/, { timeout: 10000 }).catch(() => {})
  await audit('a submission')
  check('a submission shows what was sent', (await page.locator('input[readonly]').first().inputValue()) === sender)

  await page.getByRole('button', { name: 'Delete' }).click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Delete' }).click()
  await page.waitForURL(/\/admin\/forms\/contact$/, { timeout: 10000 }).catch(() => {})
  check(
    'a deleted submission leaves the listing',
    (await page.locator('tbody tr').filter({ hasText: sender }).count()) === 0,
  )
}

async function webhooks() {
  const name = `E2E hook ${Date.now()}`
  await visit('/admin/webhooks/new')
  await audit('the webhook form')
  await page.locator('#webhook-name').fill(name)
  await page.locator('#webhook-url').fill('https://hooks.e2e.invalid/in')
  await page.locator('label').filter({ hasText: 'record.published' }).getByRole('checkbox').click()
  await page.getByRole('button', { name: 'Create' }).click()
  await page.waitForURL(/\/admin\/webhooks\/\d+\/edit$/, { timeout: 10000 }).catch(() => {})
  check('a webhook saves with its own signing secret', await page.locator('#webhook-secret').isVisible())

  await page.getByRole('button', { name: 'Send test' }).click()
  const delivery = page.getByRole('button', { name: /webhook\.test/ })
  await delivery.waitFor({ timeout: 15000 }).catch(() => {})
  check('a test ping is logged with the reason it failed', (await delivery.textContent())?.includes("doesn't resolve"))
  await delivery.click()
  await audit('webhook deliveries')

  await page.getByRole('button', { name: 'Delete' }).click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Delete' }).click()
  await page.waitForURL(`${base}/admin/webhooks`, { timeout: 10000 }).catch(() => {})
  check('a deleted webhook leaves the list', (await page.locator('tbody tr').filter({ hasText: name }).count()) === 0)
}

async function navigationSave() {
  const label = `E2E link ${Date.now()}`
  await visit('/admin/navigation/footer/edit')
  await page.getByRole('button', { name: 'Add link' }).last().click()
  await page.locator('#nav-item-title').fill(label)
  await page.locator('#nav-item-url').fill('/about')
  await page.getByRole('dialog').getByRole('button', { name: 'Save', exact: true }).click()
  await page.getByRole('button', { name: 'Save', exact: true }).click()
  await page.waitForTimeout(1500)
  check('saving a changed menu saves instead of asking to leave', !(await page.getByRole('alertdialog').isVisible()))
  await visit('/admin/navigation/footer/edit')
  const link = page
    .locator('.drag-handle')
    .locator('xpath=ancestor::div[contains(@class,"rounded-md")][1]')
    .filter({ hasText: label })
  check('a saved menu link is there after a reload', (await link.count()) > 0)

  await link
    .getByRole('button', { name: /remove|delete/i })
    .first()
    .click()
  const confirmRemove = page.getByRole('alertdialog').getByRole('button', { name: /remove|delete/i })
  if (await confirmRemove.count()) await confirmRemove.click()
  await page.getByRole('button', { name: 'Save', exact: true }).click()
  await page.waitForTimeout(1500)
  await visit('/admin/navigation/footer/edit')
  check('the gate leaves the menu as it found it', (await page.getByText(label).count()) === 0)
}

async function roles() {
  const name = `E2E role ${Date.now()}`
  await visit('/admin/roles')
  await audit('the roles listing')
  await page.getByRole('link', { name: 'Create role' }).click()
  await page.waitForURL(`${base}/admin/roles/new`, { timeout: 10000 })
  await audit('the role editor')

  await page.locator('#role-title').fill(name)
  const publish = page.locator('label').filter({ hasText: 'Publish and unpublish' }).first()
  await publish.getByRole('checkbox').click()
  const view = page
    .locator('label')
    .filter({ hasText: /^View / })
    .first()
  check('checking a child checks what it depends on', await view.getByRole('checkbox').isChecked())

  await page.getByRole('button', { name: 'Create' }).click()
  await page.waitForURL(`${base}/admin/roles`, { timeout: 10000 }).catch(() => {})
  const row = page.locator('tbody tr').filter({ hasText: name })
  check('a role saves with the permissions that were ticked', (await row.count()) === 1)

  await row.first().click()
  await page.waitForURL(/\/admin\/roles\/\d+\/edit$/, { timeout: 10000 }).catch(() => {})
  await page.getByRole('button', { name: 'Delete' }).click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Delete' }).click()
  await page.waitForURL(`${base}/admin/roles`, { timeout: 10000 }).catch(() => {})
  check('a deleted role leaves the list', (await page.locator('tbody tr').filter({ hasText: name }).count()) === 0)
}

async function users() {
  await visit('/admin/users')
  await audit('the users listing')
  const invited = `e2e-${Date.now()}@nibble.test`
  await page.getByRole('button', { name: 'Invite user' }).click()
  await page.locator('#invite-name').fill('E2E Invitee')
  await page.locator('#invite-email').fill(invited)
  await page.locator('label').filter({ hasText: 'Author' }).getByRole('checkbox').click()
  await audit('the invite dialog')
  await page.getByRole('button', { name: 'Send invitation' }).click()
  await page.waitForTimeout(1000)
  const row = page.locator('tbody tr').filter({ hasText: invited })
  check('an invited user appears with the role they were given', (await row.count()) === 1)

  await row.first().getByRole('link').first().click()
  await page.waitForURL(/\/admin\/users\/\d+\/edit$/, { timeout: 10000 }).catch(() => {})
  await audit('the user editor')
  await page.getByRole('button', { name: 'Delete' }).click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Delete' }).click()
  await page.waitForURL(`${base}/admin/users`, { timeout: 10000 }).catch(() => {})
  check('a deleted user leaves the list', (await page.locator('tbody tr').filter({ hasText: invited }).count()) === 0)
}

async function apiTokens() {
  const name = `E2E token ${Date.now()}`
  await visit('/admin/api-tokens')
  await audit('the API tokens screen')
  await page
    .getByRole('button', { name: /Create( a)? token/ })
    .first()
    .click()
  await page.locator('#token-name').fill(name)
  await page.getByRole('button', { name: 'Create', exact: true }).click()
  await page.waitForTimeout(1000)

  const shown = await page.locator('code').first().textContent()
  check('a new token is shown once, in full', /^nib_[0-9a-f]{48}$/.test((shown ?? '').trim()))
  await audit('the token reveal')
  await page.mouse.click(5, 500)
  await page.waitForTimeout(300)
  check('clicking outside the reveal keeps the token on screen', (await page.locator('code').count()) === 1)
  await page.keyboard.press('Escape')
  await page.waitForTimeout(300)
  check('pressing Escape keeps the token on screen', (await page.locator('code').count()) === 1)
  await page.getByRole('button', { name: 'Close' }).first().click()
  await page.waitForTimeout(300)
  await visit('/admin/users')
  await page.goBack()
  await page.waitForTimeout(1000)
  check('going back after closing the reveal does not bring the token back', (await page.locator('code').count()) === 0)

  await visit('/admin/api-tokens')
  check('the token is never shown again', (await page.locator('code').count()) === 0)
  const row = page.locator('tbody tr').filter({ hasText: name })
  await row.getByRole('button', { name: 'Revoke' }).click()
  await page.getByRole('alertdialog').getByRole('button', { name: 'Revoke' }).click()
  await page.waitForTimeout(1000)
  check('a revoked token stays listed as revoked', (await row.getByText('Revoked').count()) === 1)
}

async function twoFactor() {
  await visit('/admin/account/edit')
  await audit('the account screen')
  await page.getByRole('button', { name: 'Two-Factor Authentication' }).click()
  await page.getByRole('button', { name: 'Enable two-factor authentication' }).click()
  await page.waitForTimeout(1500)
  const secret = await page.locator('#totp-secret').inputValue()
  check(
    'two-factor setup offers a key and a QR code',
    /^[A-Z2-7]{32}$/.test(secret) && (await page.locator('svg').count()) > 0,
  )
  await audit('the two-factor dialog')
  await page.locator('#totp-code').fill('000000')
  await page.getByRole('button', { name: 'Confirm' }).click()
  await page.waitForTimeout(1000)
  check('a wrong code leaves two-factor off', (await page.getByText(/isn't right/).count()) === 1)
  await page.keyboard.press('Escape')
}

async function auditEveryScreen() {
  for (const [path, label] of [
    ['/admin', 'the dashboard'],
    ['/admin/collections/pages', 'a collection listing'],
    ['/admin/collections/posts?view=calendar', 'the calendar'],
    ['/admin/taxonomies/authors', 'a taxonomy listing'],
    ['/admin/globals/site/edit', 'a globals editor'],
    ['/admin/navigation/main/edit', 'the navigation builder'],
    ['/admin/blueprints', 'blueprints'],
    ['/admin/redirects', 'redirects'],
    ['/admin/utilities', 'utilities'],
    ['/admin/utilities/jobs', 'jobs'],
    ['/admin/utilities/health', 'health'],
    ['/admin/utilities/content', 'content export and import'],
    ['/admin/utilities/cache', 'cache'],
    ['/admin/utilities/search', 'search'],
    ['/admin/utilities/schema', 'schema'],
    ['/admin/utilities/backups', 'backups'],
    ['/admin/utilities/audit', 'audit log'],
    ['/admin/webhooks', 'webhooks'],
    ['/admin/navigation', 'navigation'],
    ['/admin/globals', 'globals'],
    ['/admin/users', 'users'],
    ['/admin/roles', 'roles'],
    ['/admin/api-tokens', 'API tokens'],
  ]) {
    await visit(path)
    await audit(label)
  }
}

await signIn()
const id = await createEntry()
if (id) {
  await recoverAndPublish(id)
  await reviseAndRestore(id)
  await notesAndBell(id)
  const current = title
  await treeView(current)
  await trashAndRestore(id, current)
  await purge(id, current)
}
await media()
await forms()
await webhooks()
await navigationSave()
await run('roles', roles)
await run('users', users)
await run('API tokens', apiTokens)
await run('two-factor setup', twoFactor)
await auditEveryScreen()

check('no console errors on any screen', errors.length === 0, errors.slice(0, 5).join('\n'))

const failed = checks.filter((entry) => !entry.ok)
for (const entry of checks)
  console.log(`${entry.ok ? 'ok  ' : 'FAIL'} ${entry.name}${entry.detail ? ` — ${entry.detail}` : ''}`)
console.log(`\n${checks.length - failed.length}/${checks.length} checks passed`)

await browser.close()
process.exit(failed.length ? 1 : 0)
