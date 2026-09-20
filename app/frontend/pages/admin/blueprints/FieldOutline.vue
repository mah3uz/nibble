<script setup lang="ts">
import type { PublishField } from '@/nibble-admin/fieldtypes/types'

type SetGroup = {
  handle: string
  display: string | null
  sets: { handle: string; display: string; instructions: string | null; fields: PublishField[] }[]
}

const props = defineProps<{ field: PublishField }>()

const nestedFields = () => (props.field.config.fields as PublishField[] | undefined) ?? []
const setGroups = () => (props.field.config.sets as SetGroup[] | undefined) ?? []
const conditions = () =>
  Object.fromEntries(
    (['if', 'if_any', 'unless', 'unless_any'] as const)
      .filter((key) => props.field[key])
      .map((key) => [key, props.field[key]]),
  )
</script>

<template>
  <div class="rounded-md border p-2">
    <div class="flex flex-wrap items-center gap-2 text-sm">
      <code class="font-medium">{{ field.handle }}</code>
      <span class="text-muted-foreground">{{ field.type }}</span>
      <span v-if="field.required" class="text-xs text-destructive">required</span>
      <span v-if="field.read_only" class="text-xs text-muted-foreground">read-only</span>
      <span v-if="field.localizable" class="text-xs text-muted-foreground">localizable</span>
      <span class="text-xs text-muted-foreground">{{ field.width }}%</span>
      <code v-if="Object.keys(conditions()).length" class="rounded bg-muted px-1 text-xs">
        {{ JSON.stringify(conditions()) }}
      </code>
    </div>
    <div v-if="nestedFields().length" class="mt-2 ml-4 space-y-2">
      <FieldOutline v-for="child in nestedFields()" :key="child.handle" :field="child" />
    </div>
    <div v-for="group in setGroups()" :key="group.handle" class="mt-2 ml-4 space-y-2">
      <div v-for="set in group.sets" :key="set.handle" class="rounded-md border p-2">
        <div class="text-sm font-medium">
          {{ set.display }} <span class="text-xs text-muted-foreground">({{ set.handle }})</span>
        </div>
        <p v-if="set.instructions" class="text-xs text-muted-foreground">{{ set.instructions }}</p>
        <div class="mt-2 space-y-2">
          <FieldOutline v-for="child in set.fields" :key="child.handle" :field="child" />
        </div>
      </div>
    </div>
  </div>
</template>
