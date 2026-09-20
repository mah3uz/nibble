<script setup lang="ts">
import { router, usePage } from '@inertiajs/vue3'
import { Trash2 } from '@lucide/vue'
import { useMediaQuery } from '@vueuse/core'
import { computed, ref, useTemplateRef } from 'vue'
import PageHeader from '@/components/admin/page/PageHeader.vue'
import StatusIndicator from '@/components/admin/page/StatusIndicator.vue'
import LivePreview from '@/components/admin/preview/LivePreview.vue'
import RevisionHistory from '@/components/admin/revisions/RevisionHistory.vue'
import { Button } from '@/components/ui/button'
import type { Breadcrumb } from '@/lib/breadcrumbs'
import { useConfirm } from '@/lib/confirm'
import { registerCoreFieldtypes } from '@/nibble-admin/fieldtypes/core'
import PublishContainer from '@/nibble-admin/publish/PublishContainer.vue'
import PublishSections from '@/nibble-admin/publish/PublishSections.vue'
import PublishTabs from '@/nibble-admin/publish/PublishTabs.vue'
import type { Can, DraftMeta, EditMeta, EditUrls, PublishBlueprint } from './context'
import CommentsPanel from './CommentsPanel.vue'
import ErrorSummary from './ErrorSummary.vue'
import LocalBackupBanner from './LocalBackupBanner.vue'
import PreviewActions from './PreviewActions.vue'
import SaveButton from './SaveButton.vue'
import { usePublishForm } from './usePublishForm'
import WorkingCopyBanner from './WorkingCopyBanner.vue'

// The sidebar tab renders as the aside or as a tab, never both, or field ids would repeat.
const SIDEBAR_TAB = 'sidebar'

const props = defineProps<{
  title: string
  icon?: string
  breadcrumbs: Breadcrumb[]
  resourceKey: string
  blueprint: PublishBlueprint
  values: Record<string, unknown>
  meta: EditMeta
  fieldMeta: Record<string, unknown>
  draft: DraftMeta
  can: Can
  urls: EditUrls
}>()

registerCoreFieldtypes()

const {
  form,
  values,
  meta: currentMeta,
  draft: currentDraft,
  save,
  backup,
} = usePublishForm({
  resourceKey: props.resourceKey,
  urls: props.urls,
  values: props.values,
  meta: props.meta,
  draft: props.draft,
  canPublish: props.can.publish,
})

const viewportIsWide = useMediaQuery('(min-width: 1280px)')
const livePreview = useTemplateRef<{ popIn: () => void }>('livePreview')
const livePreviewOpen = ref(false)
const livePreviewPoppedOut = ref(false)
const visitUrl = computed(() => (currentMeta.value.live ? currentMeta.value.permalink : null))
const isWide = computed(() => (livePreviewOpen.value ? livePreviewPoppedOut.value : viewportIsWide.value))

const sidebarTab = computed(() => props.blueprint.tabs.find((tab) => tab.handle === SIDEBAR_TAB) ?? null)
const mainTabs = computed(() => props.blueprint.tabs.filter((tab) => tab.handle !== SIDEBAR_TAB))
const tabs = computed(() => (isWide.value && sidebarTab.value ? mainTabs.value : props.blueprint.tabs))

const publishAt = computed(() => (values.published_at as string | null) ?? null)
const errors = computed(() => form.errors as unknown as Record<string, string>)
const fieldErrors = computed(() =>
  Object.fromEntries(Object.entries(errors.value).map(([path, message]) => [path, [message]])),
)

function onJump(tabHandle: string | null, fieldHandle: string) {
  requestAnimationFrame(() => document.getElementById(fieldHandle)?.focus())
  if (tabHandle) document.querySelector<HTMLButtonElement>(`[data-state][value="${tabHandle}"]`)?.click()
}

const historyOpen = ref(new URLSearchParams(usePage().url.split('?')[1] ?? '').has('history'))

const confirm = useConfirm()
async function destroy() {
  const ok = await confirm({
    title: `Move this ${props.blueprint.title.toLowerCase()} to the trash?`,
    description: 'You can restore it from the trash later.',
    confirmText: 'Move to trash',
    dangerous: true,
  })
  if (ok && props.urls.trash) router.post(props.urls.trash)
}
</script>

<template>
  <form class="space-y-4" @submit.prevent="save('save')">
    <!-- v-model would replace the Inertia form: the container emits a new object on every edit. -->
    <PublishContainer
      :model-value="values"
      :blueprint="blueprint"
      :meta="fieldMeta"
      :errors="fieldErrors"
      :read-only="!can.edit"
      @update:model-value="(next) => Object.assign(values, next)"
    >
      <PageHeader :title="title" :icon="icon" :breadcrumbs="breadcrumbs">
        <template #meta>
          <StatusIndicator
            :status="currentMeta.workflow_status ?? currentMeta.status"
            :live="currentMeta.live"
            :has-changes="!!currentDraft || form.isDirty"
          />
        </template>
        <template #actions>
          <Button v-if="urls.versions" type="button" variant="ghost" size="sm" @click="historyOpen = true">
            History
          </Button>
          <RevisionHistory v-if="urls.versions" v-model:open="historyOpen" :url="urls.versions" />
          <SaveButton
            v-if="can.edit"
            :status="currentMeta.workflow_status ?? currentMeta.status"
            :workflow="currentMeta.workflow"
            :publish-at="publishAt"
            :dirty="form.isDirty"
            :has-working-copy="!!currentDraft"
            :processing="form.processing"
            :can-publish="can.publish"
            :can-review="can.review"
            @save="save('save')"
            @publish="(message) => save('publish', { message })"
            @unpublish="save('unpublish')"
            @discard="save('discard')"
            @submit="save('submit')"
            @approve="save('approve')"
            @reject="save('reject')"
          />
          <Button v-if="can.delete && currentMeta.id" type="button" variant="destructive" @click="destroy">
            <Trash2 /> Trash
          </Button>
        </template>
      </PageHeader>

      <ErrorSummary :errors="errors" :blueprint="blueprint" @jump="onJump" />

      <LocalBackupBanner
        v-if="backup.available.value"
        :backup="backup.available.value"
        :saved-since="backup.available.value.base !== currentMeta.updated_at"
        @restore="backup.restore"
        @discard="backup.discard"
      />

      <WorkingCopyBanner
        v-if="currentDraft"
        :working-copy="currentDraft"
        :processing="form.processing"
        @preview="livePreviewOpen = true"
        @discard="save('discard')"
        @publish="save('publish')"
        @view-history="historyOpen = true"
      />

      <div
        v-if="!livePreviewOpen || livePreviewPoppedOut"
        class="grid gap-8"
        :class="{ 'xl:grid-cols-[1fr_320px]': isWide && sidebarTab }"
      >
        <div class="min-w-0">
          <PreviewActions
            v-if="!isWide"
            class="mb-6"
            :can-preview="!!urls.preview"
            :visit-url="visitUrl"
            :popped-out="livePreviewPoppedOut"
            @live-preview="livePreviewOpen = true"
            @pop-in="livePreview?.popIn()"
          />
          <PublishTabs :tabs="tabs" />
        </div>
        <aside v-if="isWide && sidebarTab" class="space-y-6 self-start">
          <PreviewActions
            :can-preview="!!urls.preview"
            :visit-url="visitUrl"
            :popped-out="livePreviewPoppedOut"
            @live-preview="livePreviewOpen = true"
            @pop-in="livePreview?.popIn()"
          />
          <PublishSections :sections="sidebarTab.sections" />
          <CommentsPanel v-if="urls.comments" :url="urls.comments" />
        </aside>
      </div>

      <LivePreview
        v-if="urls.preview"
        ref="livePreview"
        v-model:open="livePreviewOpen"
        :url="urls.preview"
        :values="values"
        @update:popped-out="livePreviewPoppedOut = $event"
      >
        <template #fields>
          <PublishTabs :tabs="tabs" />
        </template>
        <template #actions>
          <SaveButton
            v-if="can.edit"
            :status="currentMeta.workflow_status ?? currentMeta.status"
            :workflow="currentMeta.workflow"
            :publish-at="publishAt"
            :dirty="form.isDirty"
            :has-working-copy="!!currentDraft"
            :processing="form.processing"
            :can-publish="can.publish"
            :can-review="can.review"
            @save="save('save')"
            @publish="(message) => save('publish', { message })"
            @unpublish="save('unpublish')"
            @discard="save('discard')"
            @submit="save('submit')"
            @approve="save('approve')"
            @reject="save('reject')"
          />
        </template>
      </LivePreview>
    </PublishContainer>
  </form>
</template>
