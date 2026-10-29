import { inject, type InjectionKey, type Ref } from 'vue'

export type DisplayConfig = Record<string, unknown>

export const offersFullscreen = (config: DisplayConfig) => config.fullscreen !== false

export const FULLSCREEN_LAYER: InjectionKey<Ref<boolean>> = Symbol('fullscreen layer')

export function useOutsideFullscreenLayer() {
  const layer = inject(FULLSCREEN_LAYER, null)
  return () => !layer?.value
}

export const showsPreviews = (config: DisplayConfig) => config.previews !== false

export const dateWidthClass = (config: DisplayConfig) =>
  config.full_width === true || (config.time_enabled === true && !!config.time_zone) ? 'w-full' : 'w-full max-w-xs'
