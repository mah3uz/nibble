const YOUTUBE_HOSTS = [
  'youtube.com',
  'www.youtube.com',
  'm.youtube.com',
  'youtube-nocookie.com',
  'www.youtube-nocookie.com',
]
const VIMEO_HOSTS = ['vimeo.com', 'www.vimeo.com', 'player.vimeo.com']
const YOUTUBE_ID = /^[\w-]{6,20}$/

export function embedSrc(url: string): string | null {
  let parsed: URL
  try {
    parsed = new URL(url)
  } catch {
    return null
  }
  if (parsed.protocol !== 'https:') return null

  const host = parsed.hostname
  const parts = parsed.pathname.split('/').filter(Boolean)

  if (host === 'youtu.be') {
    return parts[0] && YOUTUBE_ID.test(parts[0]) ? `https://www.youtube-nocookie.com/embed/${parts[0]}` : null
  }
  if (YOUTUBE_HOSTS.includes(host)) {
    const id =
      parts[0] === 'watch'
        ? parsed.searchParams.get('v')
        : ['embed', 'shorts', 'live'].includes(parts[0] ?? '')
          ? parts[1]
          : null
    return id && YOUTUBE_ID.test(id) ? `https://www.youtube-nocookie.com/embed/${id}` : null
  }
  if (VIMEO_HOSTS.includes(host)) {
    const id = parts.find((part) => /^\d+$/.test(part))
    return id ? `https://player.vimeo.com/video/${id}?dnt=1` : null
  }
  return null
}

export function isLinkable(url: string) {
  return /^https?:\/\//i.test(url) || (url.startsWith('/') && !url.startsWith('//'))
}
