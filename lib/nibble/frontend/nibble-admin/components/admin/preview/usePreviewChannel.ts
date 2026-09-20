export type PreviewMessage<T = unknown> = { kind: 'page' | 'post'; payload: T }

const UPDATE = 'nibble-preview:update'
const READY = 'nibble-preview:ready'

export function usePreviewSender(target: () => Window | null | undefined) {
  function send(message: PreviewMessage) {
    target()?.postMessage({ type: UPDATE, ...message }, window.location.origin)
  }
  function onReady(handler: () => void) {
    function listener(event: MessageEvent) {
      if (event.origin === window.location.origin && event.data?.type === READY) handler()
    }
    window.addEventListener('message', listener)
    return () => window.removeEventListener('message', listener)
  }
  return { send, onReady }
}

export function announcePreviewReady() {
  const target = window.opener ?? window.parent
  if (target !== window) target.postMessage({ type: READY }, window.location.origin)
}

export function onPreviewUpdate(handler: (message: PreviewMessage) => void) {
  function listener(event: MessageEvent) {
    if (event.origin !== window.location.origin || event.data?.type !== UPDATE) return
    handler(event.data)
  }
  window.addEventListener('message', listener)
  return () => window.removeEventListener('message', listener)
}
