import { onBeforeUnmount, onMounted, watch } from 'vue'
import type { CpPreferences } from './cp'
import { usePreference } from './preferences'

// Applies the CP's theme preference (system/light/dark) to <html>.dark. "system" follows the OS
// setting live — flipping it while the CP is open updates the theme without a reload. Reads the same
// shared preference UserMenu's theme switcher writes to (see preferences.ts's cache), so a change
// made there is visible here immediately, not just after the next full page load.
export function useTheme() {
  const theme = usePreference<CpPreferences['theme']>('theme', 'system')
  let media: MediaQueryList

  const apply = () => {
    const dark = theme.value === 'dark' || (theme.value === 'system' && media.matches)
    document.documentElement.classList.toggle('dark', dark)
  }

  // window/matchMedia don't exist during SSR, so the first apply waits for mount.
  onMounted(() => {
    media = window.matchMedia('(prefers-color-scheme: dark)')
    apply()
    media.addEventListener('change', apply)
  })
  watch(theme, () => media && apply())
  onBeforeUnmount(() => media?.removeEventListener('change', apply))
}
