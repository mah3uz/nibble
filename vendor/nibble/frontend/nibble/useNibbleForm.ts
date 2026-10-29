import { router } from '@inertiajs/vue3'
import { computed, nextTick, onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { passes } from '../nibble-cp/conditions'
import { useLocale } from './composables'
import type { NibbleForm, NibbleFormField, NibbleFormResult, NibbleFormValue } from './types'

type Captcha = { provider: 'turnstile' | 'recaptcha'; site_key: string }

type Turnstile = {
  render: (el: HTMLElement, options: Record<string, unknown>) => string
  execute: (id: string) => void
  reset: (id: string) => void
  remove: (id: string) => void
}
type Recaptcha = {
  ready: (fn: () => void) => void
  execute: (key: string, options: { action: string }) => Promise<string>
}
type CaptchaWindow = Window & { turnstile?: Turnstile; grecaptcha?: Recaptcha }

const SCRIPTS: Record<Captcha['provider'], (key: string) => string> = {
  turnstile: () => 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit',
  recaptcha: (key) => `https://www.google.com/recaptcha/api.js?render=${encodeURIComponent(key)}`,
}

const loading = new Map<string, Promise<void>>()

function loadScript(src: string) {
  if (!loading.has(src)) {
    loading.set(
      src,
      new Promise((resolve, reject) => {
        const script = document.createElement('script')
        script.src = src
        script.async = true
        script.onload = () => resolve()
        script.onerror = () => {
          loading.delete(src)
          reject(new Error(`Couldn't load ${src}`))
        }
        document.head.appendChild(script)
      }),
    )
  }
  return loading.get(src)!
}

function many(field: NibbleFormField) {
  return field.type === 'checkboxes' || field.type === 'files' || (field.type === 'select' && field.multiple === true)
}

function initialValue(field: NibbleFormField): NibbleFormValue {
  if (field.default !== undefined && field.default !== null) return field.default as NibbleFormValue
  if (many(field)) return []
  return field.type === 'toggle' ? false : ''
}

function refilled(field: NibbleFormField, result: NibbleFormResult | null): NibbleFormValue | undefined {
  if (result?.status !== 'invalid' || field.type === 'files' || field.hidden) return undefined
  const value = result.values?.[field.handle]
  if (value === undefined || value === null) return undefined
  if (field.type === 'toggle') return !['', '0', 'false', false, 0].includes(value as string)
  if (many(field)) return Array.isArray(value) ? value : [value as string]
  return value
}

export function isFieldVisible(field: NibbleFormField, values: Record<string, unknown>) {
  const conditions = field.conditions
  if (!conditions) return true
  if (conditions.rules.some((rule) => rule.operator === 'custom' || !rule.field)) return true
  const results = conditions.rules.map((rule) => passes({ ...rule, field: rule.field! }, values))
  const passed = conditions.match === 'any' ? results.some(Boolean) : results.every(Boolean)
  return conditions.show ? passed : !passed
}

export function fileLimits(field: NibbleFormField) {
  if (field.type !== 'files') return null
  const several = (field.max_files ?? 1) > 1
  const types = field.extensions?.map((extension) => extension.toUpperCase()) ?? []
  const parts = [
    types.length > 1 ? `${types.slice(0, -1).join(', ')} or ${types.at(-1)}` : types[0],
    field.max_file_size ? `up to ${field.max_file_size} MB${several ? ' each' : ''}` : null,
    several ? `at most ${field.max_files} files` : 'one file',
  ].filter(Boolean)
  const text = parts.join(', ')
  return `${text.charAt(0).toUpperCase()}${text.slice(1)}.`
}

function append(body: FormData, name: string, value: unknown) {
  if (value === null || value === undefined || value === '') return
  if (Array.isArray(value)) value.forEach((item) => append(body, `${name}[]`, item))
  else if (value instanceof Blob) body.append(name, value)
  else body.append(name, String(value))
}

function firstMessages(errors: Record<string, string[] | string> = {}) {
  return Object.fromEntries(
    Object.entries(errors).map(([key, value]) => [key, Array.isArray(value) ? value[0] : value]),
  )
}

const FALLBACK_MESSAGES = {
  too_large: 'The files are too large to send.',
  generic: 'Something went wrong. Please try again.',
  network: 'Something went wrong. Please check your connection and try again.',
}

export function useNibbleForm(definition: NibbleForm) {
  const locale = useLocale()
  const text = (key: keyof typeof FALLBACK_MESSAGES) => definition.messages?.[key] ?? FALLBACK_MESSAGES[key]
  const values = reactive<Record<string, NibbleFormValue>>(
    Object.fromEntries(
      definition.fields.map((field) => [field.handle, refilled(field, definition.result) ?? initialValue(field)]),
    ),
  )
  const trap = ref('')
  const errors = ref<Record<string, string>>(
    definition.result?.status === 'invalid' ? (definition.result.errors ?? {}) : {},
  )
  const sent = ref(definition.result?.status === 'sent')
  const message = ref<string | null>(sent.value ? (definition.result?.message ?? null) : null)
  const processing = ref(false)
  const captchaEl = ref<HTMLElement | null>(null)
  const summaryEl = ref<HTMLElement | null>(null)
  const messageEl = ref<HTMLElement | null>(null)
  const byHandle = new Map(definition.fields.map((field) => [field.handle, field]))

  let widgetId: string | null = null
  let pendingToken: ((token: string | null) => void) | null = null

  function fieldName(field: NibbleFormField) {
    return many(field) ? `${field.handle}[]` : field.handle
  }

  const isVisible = (field: NibbleFormField) => isFieldVisible(field, values)
  const inputId = (field: NibbleFormField) => `${definition.handle}-${field.handle}`
  const helpId = (field: NibbleFormField) => `${inputId(field)}-help`
  const errorId = (field: NibbleFormField) => `${inputId(field)}-error`
  const hasHelp = (field: NibbleFormField) => Boolean(field.instructions || fileLimits(field))

  function describedBy(field: NibbleFormField) {
    const ids = [hasHelp(field) && helpId(field), errors.value[field.handle] && errorId(field)].filter(Boolean)
    return ids.length ? ids.join(' ') : undefined
  }

  const errorList = computed(() => {
    const listed = new Map<string, { handle: string; label: string; message: string; href: string }>()
    Object.entries(errors.value).forEach(([key, text]) => {
      const field = byHandle.get(key.split('.')[0]!)
      if (field && !listed.has(field.handle))
        listed.set(field.handle, {
          handle: field.handle,
          label: field.display,
          message: text,
          href: `#${inputId(field)}`,
        })
    })
    return [...listed.values()]
  })

  async function focus(el: typeof summaryEl) {
    await nextTick()
    el.value?.focus()
  }

  function accept(field: NibbleFormField) {
    return field.extensions?.map((extension) => `.${extension}`).join(',')
  }

  function setFiles(handle: string, event: Event) {
    values[handle] = Array.from((event.target as HTMLInputElement).files ?? [])
  }

  async function captchaToken(captcha: Captcha): Promise<string | null> {
    const win = window as CaptchaWindow
    await loadScript(SCRIPTS[captcha.provider](captcha.site_key))
    if (captcha.provider === 'recaptcha') {
      const recaptcha = win.grecaptcha!
      return new Promise((resolve) =>
        recaptcha.ready(() => recaptcha.execute(captcha.site_key, { action: 'submit' }).then(resolve)),
      )
    }
    if (!widgetId || !win.turnstile) return null
    const turnstile = win.turnstile
    return new Promise((resolve) => {
      pendingToken = resolve
      turnstile.execute(widgetId!)
    })
  }

  async function renderTurnstile(captcha: Captcha) {
    await loadScript(SCRIPTS.turnstile(captcha.site_key))
    const turnstile = (window as CaptchaWindow).turnstile
    if (!turnstile || !captchaEl.value) return
    widgetId = turnstile.render(captchaEl.value, {
      sitekey: captcha.site_key,
      appearance: 'interaction-only',
      execution: 'execute',
      callback: (token: string) => pendingToken?.(token),
      'error-callback': () => pendingToken?.(null),
    })
  }

  const captcha: Captcha | null =
    definition.captcha?.provider && definition.captcha.site_key
      ? { provider: definition.captcha.provider, site_key: definition.captcha.site_key }
      : null

  onMounted(() => {
    if (definition.result?.status === 'invalid') void focus(summaryEl)
    else if (sent.value) void focus(messageEl)
    if (captcha?.provider === 'turnstile') void renderTurnstile(captcha)
    else if (captcha) void loadScript(SCRIPTS.recaptcha(captcha.site_key))
  })

  onBeforeUnmount(() => {
    if (widgetId) (window as CaptchaWindow).turnstile?.remove(widgetId)
  })

  function reset() {
    definition.fields.forEach((field) => (values[field.handle] = initialValue(field)))
    trap.value = ''
  }

  async function submit(event?: Event) {
    event?.preventDefault()
    const formEl = event?.target instanceof HTMLFormElement ? event.target : null
    if (processing.value) return
    processing.value = true
    errors.value = {}
    sent.value = false
    message.value = null

    try {
      const body = new FormData()
      definition.fields.filter(isVisible).forEach((field) => append(body, field.handle, values[field.handle]))
      if (definition.honeypot) body.append(definition.honeypot, trap.value)
      body.append('_locale', locale.value)
      if (captcha) {
        const token = await captchaToken(captcha)
        if (token) body.append('_captcha', token)
      }

      const response = await fetch(definition.action, { method: 'POST', body, headers: { Accept: 'application/json' } })
      const payload = await response.json().catch(() => ({}))
      if (response.ok) {
        formEl?.reset()
        reset()
        const redirect = payload.redirect as string | undefined
        if (redirect) return redirect.startsWith('/') ? router.visit(redirect) : window.location.assign(redirect)
        sent.value = true
        message.value = payload.message ?? null
        void focus(messageEl)
      } else if (response.status === 413) {
        errors.value = { base: text('too_large') }
      } else {
        errors.value = firstMessages(payload.errors)
        if (!Object.keys(errors.value).length) errors.value = { base: text('generic') }
      }
    } catch {
      errors.value = { base: text('network') }
    } finally {
      processing.value = false
      if (Object.keys(errors.value).length) void focus(summaryEl)
      if (widgetId) (window as CaptchaWindow).turnstile?.reset(widgetId)
    }
  }

  return {
    values,
    trap,
    errors,
    errorList,
    sent,
    message,
    processing,
    captchaEl,
    summaryEl,
    messageEl,
    fieldName,
    accept,
    setFiles,
    submit,
    reset,
    isVisible,
    inputId,
    helpId,
    errorId,
    describedBy,
    fileLimits,
  }
}
