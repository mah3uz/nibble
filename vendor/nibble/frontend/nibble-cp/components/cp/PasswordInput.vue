<script setup lang="ts">
import { Eye, EyeOff } from '@lucide/vue'
import { computed, ref, useAttrs } from 'vue'
import { Input } from '@/components/ui/input'

defineOptions({ inheritAttrs: false })
const model = defineModel<string>({ default: '' })
const visible = ref(false)
const attrs = useAttrs()
const inputAttrs = computed(() => Object.fromEntries(Object.entries(attrs).filter(([key]) => key !== 'class')))
</script>

<template>
  <div class="relative" :class="attrs.class">
    <Input v-bind="inputAttrs" v-model="model" :type="visible ? 'text' : 'password'" class="pe-10" />
    <button
      type="button"
      class="absolute inset-y-0 end-0 flex w-10 cursor-pointer items-center justify-center text-gray-500 hover:text-gray-800 dark:hover:text-gray-200"
      :aria-label="visible ? 'Hide password' : 'Show password'"
      :aria-pressed="visible"
      @click="visible = !visible"
    >
      <component :is="visible ? EyeOff : Eye" class="size-4" />
    </button>
  </div>
</template>
