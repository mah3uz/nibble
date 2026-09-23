import { router } from '@inertiajs/vue3'
import { onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { useLocale } from './composables'
import type { NibbleForm, NibbleFormField } from './types'

type Captcha = NonNullable<NibbleForm['captcha']>

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

function initialValue(field: NibbleFormField) {
  if (field.default !== undefined && field.default !== null) return field.default
  if (field.type === 'checkboxes' || field.type === 'files') return []
  if (field.type === 'toggle') return false
  return field.type === 'select' && field.multiple ? [] : ''
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

export function useNibbleForm(definition: NibbleForm) {
  const locale = useLocale()
  const values = reactive<Record<string, unknown>>(
    Object.fromEntries(definition.fields.map((field) => [field.handle, initialValue(field)])),
  )
  const trap = ref('')
  const errors = ref<Record<string, string>>(
    definition.result?.status === 'invalid' ? (definition.result.errors ?? {}) : {},
  )
  const sent = ref(definition.result?.status === 'sent')
  const message = ref<string | null>(sent.value ? (definition.result?.message ?? null) : null)
  const processing = ref(false)
  const captchaEl = ref<HTMLElement | null>(null)

  let widgetId: string | null = null
  let pendingToken: ((token: string | null) => void) | null = null

  function fieldName(field: NibbleFormField) {
    return field.type === 'checkboxes' || field.type === 'files' || field.multiple ? `${field.handle}[]` : field.handle
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

  onMounted(() => {
    if (definition.captcha?.provider === 'turnstile') void renderTurnstile(definition.captcha)
    else if (definition.captcha) void loadScript(SCRIPTS.recaptcha(definition.captcha.site_key))
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
      definition.fields.forEach((field) => append(body, field.handle, values[field.handle]))
      if (definition.honeypot) body.append(definition.honeypot, trap.value)
      body.append('_locale', locale.value)
      if (definition.captcha) {
        const token = await captchaToken(definition.captcha)
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
      } else if (response.status === 413) {
        errors.value = { base: 'The files are too large to send.' }
      } else {
        errors.value = firstMessages(payload.errors)
        if (!Object.keys(errors.value).length) errors.value = { base: 'Something went wrong. Please try again.' }
      }
    } catch {
      errors.value = { base: 'Something went wrong. Please check your connection and try again.' }
    } finally {
      processing.value = false
      if (widgetId) (window as CaptchaWindow).turnstile?.reset(widgetId)
    }
  }

  return { values, trap, errors, sent, message, processing, captchaEl, fieldName, accept, setFiles, submit, reset }
}
