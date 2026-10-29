export type DisplayConfig = Record<string, unknown>

export const offersFullscreen = (config: DisplayConfig) => config.fullscreen !== false

export const showsPreviews = (config: DisplayConfig) => config.previews !== false

export const dateWidthClass = (config: DisplayConfig) =>
  config.full_width === true || (config.time_enabled === true && !!config.time_zone) ? 'w-full' : 'w-full max-w-xs'
