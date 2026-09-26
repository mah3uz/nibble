export type FlashData = {
  notice?: string
  alert?: string
  form_submitted?: string
}

// Props shared with every Inertia page (none yet; see InertiaController#inertia_share).
export type SharedProps = Record<string, never>
