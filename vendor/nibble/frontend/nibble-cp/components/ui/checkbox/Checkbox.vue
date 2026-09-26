<script setup lang="ts">
import type { CheckboxRootEmits, CheckboxRootProps } from 'reka-ui'

import type { HTMLAttributes } from 'vue'
import { CheckIcon } from '@lucide/vue'
import { reactiveOmit } from '@vueuse/core'
import { CheckboxIndicator, CheckboxRoot, useForwardPropsEmits } from 'reka-ui'
import { cn } from '@/lib/utils'

const props = defineProps<CheckboxRootProps & { class?: HTMLAttributes['class'] }>()
const emits = defineEmits<CheckboxRootEmits>()

const delegatedProps = reactiveOmit(props, 'class')

const forwarded = useForwardPropsEmits(delegatedProps, emits)
</script>

<template>
  <CheckboxRoot
    v-slot="slotProps"
    data-slot="checkbox"
    v-bind="forwarded"
    :class="cn('peer relative flex size-4 shrink-0 cursor-default items-center justify-center rounded-sm border border-gray-400/75 bg-white text-white shadow-ui-xs outline-none focus-visible:focus-outline data-checked:border-ui-accent-bg data-checked:bg-ui-accent-bg data-[state=indeterminate]:border-ui-accent-bg data-[state=indeterminate]:bg-ui-accent-bg aria-invalid:border-destructive disabled:cursor-not-allowed disabled:opacity-50 group-has-disabled/field:opacity-50 after:absolute after:-inset-x-3 after:-inset-y-2 dark:border-none dark:bg-gray-500', props.class)"
  >
    <CheckboxIndicator
      data-slot="checkbox-indicator"
      class="[&>svg]:size-2.5 [&>svg]:stroke-3 grid place-content-center text-current transition-none"
    >
      <slot v-bind="slotProps">
        <CheckIcon />
      </slot>
    </CheckboxIndicator>
  </CheckboxRoot>
</template>
