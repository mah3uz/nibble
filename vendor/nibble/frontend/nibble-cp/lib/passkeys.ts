const csrf = () => document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')?.content ?? ''

export class ConfirmationLapsed extends Error {}

const post = async (url: string, body?: unknown) => {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-CSRF-Token': csrf() },
    body: JSON.stringify(body ?? {}),
  })
  if (!response.headers.get('content-type')?.includes('application/json'))
    throw new Error('Something went wrong. Reload the page and try again.')
  const data = await response.json()
  if (response.status === 403) throw new ConfirmationLapsed(data.error)
  if (!response.ok) throw new Error(data.error ?? 'That passkey was refused.')
  return data
}

const decode = (value: string) =>
  Uint8Array.from(atob(value.replace(/-/g, '+').replace(/_/g, '/')), (char) => char.charCodeAt(0))

const encode = (buffer: ArrayBuffer) =>
  btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')

export const supported = () => typeof window !== 'undefined' && !!window.PublicKeyCredential

export async function registerPasskey(name: string) {
  const options = await post('/cp/account/passkeys/options')
  const credential = (await navigator.credentials.create({
    publicKey: {
      ...options,
      challenge: decode(options.challenge),
      user: { ...options.user, id: decode(options.user.id) },
      excludeCredentials: (options.excludeCredentials ?? []).map((item: { id: string; type: string }) => ({
        ...item,
        id: decode(item.id),
      })),
    },
  })) as PublicKeyCredential

  const response = credential.response as AuthenticatorAttestationResponse
  await post('/cp/account/passkeys', {
    name,
    credential: {
      id: credential.id,
      rawId: encode(credential.rawId),
      type: credential.type,
      response: {
        clientDataJSON: encode(response.clientDataJSON),
        attestationObject: encode(response.attestationObject),
      },
    },
  })
}

export async function signInWithPasskey() {
  const options = await post('/cp/session/passkey/options')
  const credential = (await navigator.credentials.get({
    publicKey: { ...options, challenge: decode(options.challenge), allowCredentials: [] },
  })) as PublicKeyCredential

  const response = credential.response as AuthenticatorAssertionResponse
  const { redirect } = await post('/cp/session/passkey', {
    credential: {
      id: credential.id,
      rawId: encode(credential.rawId),
      type: credential.type,
      response: {
        clientDataJSON: encode(response.clientDataJSON),
        authenticatorData: encode(response.authenticatorData),
        signature: encode(response.signature),
        userHandle: response.userHandle ? encode(response.userHandle) : null,
      },
    },
  })
  window.location.href = redirect ?? '/cp'
}
