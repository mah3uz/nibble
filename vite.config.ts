import { defineConfig, mergeConfig, type UserConfigFnObject } from 'vite'
import vueDevTools from 'vite-plugin-vue-devtools'
import nibble from './vendor/nibble/vite.config'

// Rails serves no index.html for the plugin to transform, so it is injected into the entry module instead.
export default defineConfig((env) =>
  mergeConfig(
    (nibble as UserConfigFnObject)(env),
    env.command === 'serve' ? { plugins: [
        vueDevTools({
          appendTo: /entrypoints\/inertia\.ts$/,
          launchEditor: 'rubymine'
        })
      ] } : {},
  ),
)
