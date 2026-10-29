<script setup lang="ts">
import { computed, ref } from 'vue'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { NativeSelect, NativeSelectOption } from '@/components/ui/native-select'
import { createRelationship, type CreateTarget, type ItemSummary } from '../../lib/relationships'

const props = defineProps<{ type: string; targets: CreateTarget[] }>()
const emit = defineEmits<{ created: [item: ItemSummary] }>()

const open = ref(false)
const targetHandle = ref('')
const title = ref('')
const values = ref<Record<string, string>>({})
const errors = ref<Record<string, string>>({})
const saving = ref(false)

const target = computed(() => props.targets.find((item) => item.handle === targetHandle.value) ?? props.targets[0])
const noun = computed(() => target.value.label.toLowerCase())

function show() {
  targetHandle.value = props.targets[0].handle
  title.value = ''
  values.value = {}
  errors.value = {}
  open.value = true
}

async function save() {
  saving.value = true
  errors.value = {}
  try {
    const result = await createRelationship(props.type, {
      target: target.value.handle,
      title: title.value,
      values: values.value,
    })
    if (result.errors) errors.value = result.errors
    else if (result.item) {
      open.value = false
      emit('created', result.item)
    }
  } catch (error) {
    errors.value = { title: (error as Error).message }
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <Button type="button" variant="ghost" size="sm" @click="show">
    Create a new {{ (targets.length === 1 ? targets[0].label : 'item').toLowerCase() }}
  </Button>
  <Dialog v-model:open="open">
    <DialogContent>
      <form class="space-y-4" @submit.prevent="save">
        <DialogHeader>
          <DialogTitle>Create a new {{ noun }}</DialogTitle>
          <DialogDescription>It is selected for this field once it is created.</DialogDescription>
        </DialogHeader>
        <div v-if="targets.length > 1" class="space-y-1.5">
          <Label for="relationship-create-target">Type</Label>
          <NativeSelect id="relationship-create-target" v-model="targetHandle" class="w-full">
            <NativeSelectOption v-for="item in targets" :key="item.handle" :value="item.handle">{{
              item.label
            }}</NativeSelectOption>
          </NativeSelect>
        </div>
        <div class="space-y-1.5">
          <Label for="relationship-create-title">Title</Label>
          <Input id="relationship-create-title" v-model="title" autofocus autocomplete="off" />
          <p v-if="errors.title" class="text-sm text-destructive">{{ errors.title }}</p>
        </div>
        <div v-for="field in target.fields" :key="field.handle" class="space-y-1.5">
          <Label :for="`relationship-create-${field.handle}`">{{ field.display }}</Label>
          <Input
            :id="`relationship-create-${field.handle}`"
            v-model="values[field.handle]"
            :type="field.type === 'integer' ? 'number' : 'text'"
          />
          <p v-if="errors[field.handle]" class="text-sm text-destructive">{{ errors[field.handle] }}</p>
        </div>
        <DialogFooter>
          <Button type="button" variant="outline" @click="open = false">Cancel</Button>
          <Button type="submit" :disabled="saving">Create</Button>
        </DialogFooter>
      </form>
    </DialogContent>
  </Dialog>
</template>
