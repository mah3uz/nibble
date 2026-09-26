import { usePage } from '@inertiajs/vue3'
import { computed, watch } from 'vue'
import { toast } from 'vue-sonner'

export type CpCollection = { handle: string; title: string; create: { label: string; url: string } | null }

export type CpUser = { id: number; name: string; email_address: string; role: string | null }

// Kept in sync with UserPreferences::DEFINITIONS (Ruby).
export type CpPreferences = {
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

type CpProps = {
  cp: {
    user: CpUser | null
    abilities: string[]
    collections: CpCollection[]
    nav: NavSection[]
    preferences: CpPreferences
    site_url: string
    elevated_until: string | null
    flash: { notice?: string; alert?: string }
  }
}

export function useCp() {
  const page = usePage<CpProps>()
  return computed(() => page.props.cp)
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
