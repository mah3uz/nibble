// In development only, errors on a page are sent to the Vite dev server, which adds them to the developer tools' log.
export function reportBrowserErrors() {
  const hot = import.meta.hot
  if (!hot) return

  const send = (source: string, message: unknown, stack?: string) =>
    hot.send('nibble:browser-error', {
      source,
      message: String(message),
      url: location.href,
      stack: stack?.split('\n').slice(0, 15),
    })

  window.addEventListener('error', (event) => send('error', event.message, event.error?.stack))
  window.addEventListener('unhandledrejection', (event) =>
    send('unhandled promise', event.reason?.message ?? event.reason, event.reason?.stack),
  )
  const original = console.error.bind(console)
  console.error = (...args: unknown[]) => {
    send('console', args.map((arg) => (arg instanceof Error ? arg.message : String(arg))).join(' '))
    original(...args)
  }
}
