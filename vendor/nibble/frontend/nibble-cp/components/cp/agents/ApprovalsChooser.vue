<script setup lang="ts">
const mode = defineModel<string>({ required: true })

const OPTIONS = [
  {
    value: 'ask',
    label: 'Ask before live changes',
    description:
      'Publishing, trashing, and changes to terms, site settings, navigation or assets wait for you to approve them.',
  },
  {
    value: 'off',
    label: 'Make changes without asking',
    description: 'The app makes these changes directly, still within its access.',
  },
]
</script>

<template>
  <fieldset class="space-y-2">
    <legend class="mb-1.5 text-sm font-medium">Approvals</legend>
    <label
      v-for="option in OPTIONS"
      :key="option.value"
      class="flex gap-3 rounded-lg border p-3 text-sm has-checked:border-gray-900 dark:has-checked:border-white"
    >
      <input
        v-model="mode"
        type="radio"
        name="approval_mode"
        :value="option.value"
        class="mt-0.5 accent-gray-900 dark:accent-white"
      />
      <span>
        <span class="block font-medium">{{ option.label }}</span>
        <span class="block text-muted-foreground">{{ option.description }}</span>
      </span>
    </label>
  </fieldset>
</template>
