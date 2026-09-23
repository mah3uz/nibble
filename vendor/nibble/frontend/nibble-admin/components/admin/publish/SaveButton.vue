<script setup lang="ts">
import { ChevronDown, MoreHorizontal } from '@lucide/vue'
import { computed, ref } from 'vue'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Label } from '@/components/ui/label'
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover'
import { Textarea } from '@/components/ui/textarea'
import { usePreference } from '@/lib/preferences'

const props = withDefaults(
  defineProps<{
    status: 'draft' | 'in_review' | 'approved' | 'scheduled' | 'published' | 'unpublished'
    dirty: boolean
    hasWorkingCopy: boolean
    processing: boolean
    canPublish: boolean
    workflow?: 'simple' | 'review'
    canReview?: boolean
    publishAt?: string | null
  }>(),
  { workflow: 'simple', canReview: false, publishAt: null },
)
const emit = defineEmits<{
  save: []
  publish: [message?: string]
  unpublish: []
  discard: []
  submit: []
  approve: []
  reject: []
}>()

const reviewed = computed(() => props.workflow === 'review')
const scheduling = computed(() => !!props.publishAt && new Date(props.publishAt).getTime() > Date.now())
const publishLabel = computed(() => (scheduling.value ? 'Schedule' : 'Publish'))

const afterSave = usePreference<'continue' | 'listing' | 'create_another'>('after_save', 'continue')

const primaryLabel = computed(() =>
  props.status === 'published' ? 'Save changes' : props.status === 'draft' ? 'Save draft' : 'Save',
)
const publishChangesEnabled = computed(() => props.hasWorkingCopy || props.dirty)

const publishPopoverOpen = ref(false)
const publishMessage = ref('')
function confirmPublish() {
  emit('publish', publishMessage.value.trim() || undefined)
  publishMessage.value = ''
  publishPopoverOpen.value = false
}
</script>

<template>
  <div class="flex items-center gap-2">
    <div class="inline-flex">
      <Button type="button" :disabled="processing" class="rounded-r-none" @click="emit('save')">{{
        primaryLabel
      }}</Button>
      <DropdownMenu>
        <DropdownMenuTrigger as-child>
          <Button
            type="button"
            size="icon"
            :disabled="processing"
            class="rounded-l-none border-l"
            aria-label="Save options"
          >
            <ChevronDown />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuLabel>After saving</DropdownMenuLabel>
          <DropdownMenuRadioGroup v-model="afterSave">
            <DropdownMenuRadioItem value="continue">Continue editing</DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="listing">Go to listing</DropdownMenuRadioItem>
            <DropdownMenuRadioItem value="create_another">Create another</DropdownMenuRadioItem>
          </DropdownMenuRadioGroup>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>

    <Button
      v-if="reviewed && ['draft', 'unpublished'].includes(status)"
      type="button"
      variant="secondary"
      :disabled="processing"
      @click="emit('submit')"
      >Submit for review</Button
    >

    <template v-else-if="reviewed && status === 'in_review' && canReview">
      <Button type="button" variant="secondary" :disabled="processing" @click="emit('approve')">Approve</Button>
      <Button type="button" variant="ghost" :disabled="processing" @click="emit('reject')">Send back</Button>
    </template>

    <Button
      v-else-if="(status === 'draft' || status === 'approved' || status === 'unpublished') && canPublish"
      type="button"
      variant="secondary"
      :disabled="processing"
      @click="emit('publish')"
      >{{ publishLabel }}</Button
    >

    <template v-else-if="status === 'scheduled' && canPublish">
      <Button type="button" variant="secondary" :disabled="processing" @click="emit('publish')">Publish now</Button>
      <Button type="button" variant="ghost" :disabled="processing" @click="emit('unpublish')">Unpublish</Button>
    </template>

    <template v-else-if="status === 'published' && canPublish">
      <Popover v-model:open="publishPopoverOpen">
        <PopoverTrigger as-child>
          <Button type="button" variant="secondary" :disabled="processing || !publishChangesEnabled"
            >Publish changes</Button
          >
        </PopoverTrigger>
        <PopoverContent align="end" class="space-y-2">
          <Label for="publish-message">Message (optional)</Label>
          <Textarea id="publish-message" v-model="publishMessage" placeholder="What changed?" rows="2" />
          <Button type="button" size="sm" class="w-full" @click="confirmPublish">Publish</Button>
        </PopoverContent>
      </Popover>
      <DropdownMenu>
        <DropdownMenuTrigger as-child>
          <Button type="button" variant="ghost" size="icon" :disabled="processing" aria-label="More actions"
            ><MoreHorizontal
          /></Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem @select="emit('unpublish')">Unpublish</DropdownMenuItem>
          <DropdownMenuItem v-if="hasWorkingCopy" variant="destructive" @select="emit('discard')"
            >Discard changes</DropdownMenuItem
          >
        </DropdownMenuContent>
      </DropdownMenu>
    </template>
  </div>
</template>
