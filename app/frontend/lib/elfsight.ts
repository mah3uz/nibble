import { onMounted } from 'vue'

export function useElfsight() {
  onMounted(() => {
    if (document.querySelector('script[data-elfsight-platform]')) return
    const script = document.createElement('script')
    script.src = 'https://static.elfsight.com/platform/platform.js'
    script.defer = true
    script.dataset.useServiceCore = ''
    script.dataset.elfsightPlatform = ''
    document.body.appendChild(script)
  })
}
