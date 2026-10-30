import { Link } from '@inertiajs/vue3'

export const onSite = (url: string) => /^\/(?![/\\])/.test(url)

// Inertia fetches a <Link> with XHR, which the browser blocks for another origin, so off-site addresses need a plain <a>.
export const linkTag = (url: string) => (onSite(url) ? Link : 'a')
