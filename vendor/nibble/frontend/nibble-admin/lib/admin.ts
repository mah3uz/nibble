import { usePage } from '@inertiajs/vue3'
import { computed, watch } from 'vue'
import { toast } from 'vue-sonner'

export type AdminCollection = { handle: string; title: string; create: { label: string; url: string } | null }

export type AdminUser = { id: number; name: string; email_address: string; role: string | null }

// Kept in sync with UserPreferences::DEFINITIONS (Ruby).
export type AdminPreferences = {
  theme: 'system' | 'light' | 'dark'
  sidebar_collapsed: boolean
  layout_expanded: boolean
  start_page: string
  after_save: 'continue' | 'listing' | 'create_another'
  assets: { view: 'grid' | 'table' }
}

// Kept in sync with Nibble::Cp::Navigation (Ruby).
export type NavItem = {
  title: string
  url: string
  icon: string
  active: string
  children: NavItem[] | null
  badge: number | null
  badge_tone: 'danger' | null
}
export type NavSection = { handle: string; label: string | null; items: NavItem[] }

type AdminProps = {
  admin: {
    user: AdminUser | null
    abilities: string[]
    collections: AdminCollection[]
    nav: NavSection[]
    preferences: AdminPreferences
    site_url: string
    elevated_until: string | null
    flash: { notice?: string; alert?: string }
  }
}

export function useAdmin() {
  const page = usePage<AdminProps>()
  return computed(() => page.props.admin)
}

export function useFlashToasts(flash: () => { notice?: string; alert?: string } | undefined) {
  watch(
    flash,
    (value) => {
      if (value?.notice) toast.success(value.notice)
      if (value?.alert) toast.error(value.alert)
    },
    { immediate: true },
  )
}
