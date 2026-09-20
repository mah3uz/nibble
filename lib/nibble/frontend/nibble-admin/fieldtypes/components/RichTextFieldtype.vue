<script setup lang="ts">
import { posToDOMRect, type Editor, type JSONContent } from '@tiptap/core'
import { FindAndReplace } from '@tiptap/extension-find-and-replace'
import { Markdown } from '@tiptap/markdown'
import { AllSelection, NodeSelection, type EditorState } from '@tiptap/pm/state'
import { EditorContent, VueNodeViewRenderer, useEditor } from '@tiptap/vue-3'
import { BubbleMenu, FloatingMenu } from '@tiptap/vue-3/menus'
import { computed, nextTick, onBeforeUnmount, ref, useId, watch } from 'vue'
import AdminIcon from '@/components/admin/icons/AdminIcon.vue'
import type { AssetRow } from '@/components/admin/assets/api'
import AssetSelector from '@/components/admin/assets/AssetSelector.vue'
import ImageNodeView from '@/components/admin/rich-text/ImageNodeView.vue'
import FindReplaceBar from '../../components/FindReplaceBar.vue'
import LinkUrlInput from '../../components/LinkUrlInput.vue'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Popover, PopoverAnchor, PopoverContent } from '@/components/ui/popover'
import { Switch } from '@/components/ui/switch'
import { MarkdownPaste } from '@/lib/tiptap/markdownPaste'
import { readingTime } from '@/lib/tiptap/readingTime'
import { clone } from '../../lib/clone'
import { rowId } from '../../lib/rowId'
import { RichTextImage, baseExtensions, setNode } from '../rich-text/extensions'
import SetNodeView, { type SetNodeStorage } from '../rich-text/SetNodeView.vue'
import type { PublishSetGroup } from '../types'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'
import SetPicker from './SetPicker.vue'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { update, updateMeta, isReadOnly, defineFieldActions, expose } = useFieldtype(emit, props)
defineExpose(expose)

const groups = computed(() => (props.config.sets as PublishSetGroup[]) ?? [])
const hasSets = computed(() => groups.value.some((group) => group.sets.length))
const nodes = () => (Array.isArray(props.value) ? (props.value as JSONContent[]) : [])
const doc = (content: JSONContent[]): JSONContent => ({
  type: 'doc',
  content: content.length ? content : [{ type: 'paragraph' }],
})

const readTime = ref('00:00')
const storage: SetNodeStorage = {
  groups: groups.value,
  fieldPathPrefix: props.fieldPathPrefix ?? props.handle,
  metaPathPrefix: props.metaPathPrefix ?? props.fieldPathPrefix ?? props.handle,
  readOnly: isReadOnly.value,
  canAdd: () => !isReadOnly.value,
  duplicate: (id) => duplicateSet(id),
  insertAfter: (pos, handle) => insertSet(handle, pos),
}

const editor = useEditor({
  content: doc(nodes()),
  editable: !isReadOnly.value,
  extensions: [
    ...baseExtensions.map((extension) =>
      extension === RichTextImage
        ? RichTextImage.extend({ addNodeView: () => VueNodeViewRenderer(ImageNodeView) })
        : extension,
    ),
    setNode(SetNodeView).extend({ addStorage: () => storage, name: 'set' }),
    Markdown,
    MarkdownPaste,
    FindAndReplace.configure({ injectCSS: false, searchDebounceMs: 150 }),
  ],
  editorProps: {
    attributes: { class: 'nib-content prose prose-nibble dark:prose-invert' },
    scrollMargin: { top: 160, bottom: 48, left: 0, right: 0 },
    scrollThreshold: { top: 160, bottom: 48, left: 0, right: 0 },
    handleKeyDown: (view, event) => {
      if (!(event.metaKey || event.ctrlKey) || event.altKey || event.key.toLowerCase() !== 'f') return false
      const { from, to } = view.state.selection
      const selected = view.state.doc.textBetween(from, to, ' ')
      openFind(selected.includes('\n') ? '' : selected)
      return true
    },
    handleClick: (_view, pos, event) => {
      const link = (event.target as HTMLElement).closest('a')
      if (!link || event.shiftKey) return false
      setTimeout(() => {
        openLink(link)
        editor.value?.chain().setTextSelection(pos).extendMarkRange('link').run()
      })
      return false
    },
  },
  onCreate: ({ editor }) => (readTime.value = readingTime(editor.state.doc)),
  onUpdate: ({ editor }) => {
    const content = editor.getJSON().content ?? []
    if (JSON.stringify(content) !== JSON.stringify(nodes())) update(content)
    readTime.value = readingTime(editor.state.doc)
  },
  onFocus: ({ editor }) => {
    if (editor.state.selection instanceof AllSelection) editor.commands.setTextSelection(editor.state.doc.content.size)
  },
})
storage.readOnly = isReadOnly.value
watch(isReadOnly, (readOnly) => {
  storage.readOnly = readOnly
  editor.value?.setEditable(!readOnly)
})

// Set fields write straight to the container; patch just those nodes so the caret and node views survive.
watch(
  () => props.value,
  (value) => {
    const instance = editor.value
    if (!instance) return
    const incoming = Array.isArray(value) ? (value as JSONContent[]) : []
    const current = instance.getJSON().content ?? []
    if (JSON.stringify(incoming) === JSON.stringify(current)) return

    const sameShape =
      incoming.length === current.length && incoming.every((node, index) => node.type === current[index]?.type)
    if (!sameShape) {
      instance.commands.setContent(doc(incoming), { emitUpdate: false })
      return
    }
    const tr = instance.state.tr
    instance.state.doc.forEach((node, offset, index) => {
      const next = incoming[index]
      if (node.type.name === 'set' && JSON.stringify(node.attrs) !== JSON.stringify(next?.attrs))
        tr.setNodeMarkup(offset, undefined, next?.attrs)
      else if (node.type.name !== 'set' && JSON.stringify(node.toJSON()) !== JSON.stringify(next))
        tr.replaceWith(offset, offset + node.nodeSize, instance.schema.nodeFromJSON(next!))
    })
    if (tr.docChanged) instance.view.dispatch(tr.setMeta('addToHistory', false))
  },
)

function insertSet(handle: string, pos?: number) {
  const instance = editor.value
  if (!instance) return
  const id = rowId()
  const defaults = ((props.meta.defaults as Record<string, object>) ?? {})[handle] ?? {}
  updateMeta({
    ...props.meta,
    existing: {
      ...((props.meta.existing as object) ?? {}),
      [id]: ((props.meta.new as Record<string, unknown>) ?? {})[handle] ?? {},
    },
  })
  const content = { type: 'set', attrs: { id, enabled: true, values: { ...clone(defaults), type: handle } } }
  const chain = instance.chain().focus()
  ;(pos === undefined ? chain.insertContent(content) : chain.insertContentAt(pos, content)).run()
}

function duplicateSet(id: string) {
  const instance = editor.value
  if (!instance) return
  instance.state.doc.forEach((node, offset) => {
    if (node.type.name !== 'set' || node.attrs.id !== id) return
    const copy = rowId()
    updateMeta({
      ...props.meta,
      existing: {
        ...((props.meta.existing as object) ?? {}),
        [copy]: clone(((props.meta.existing as Record<string, unknown>) ?? {})[id] ?? {}),
      },
    })
    instance
      .chain()
      .insertContentAt(offset + node.nodeSize, { type: 'set', attrs: { ...clone(node.attrs), id: copy } })
      .run()
  })
}

const fullscreen = ref(false)
const findOpen = ref(false)
const findBar = ref<InstanceType<typeof FindReplaceBar> | null>(null)
async function openFind(prefill = '') {
  findOpen.value = true
  await nextTick()
  findBar.value?.focus(prefill)
}
function closeFind() {
  findOpen.value = false
  editor.value?.commands.focus()
}
function toggleFullscreen() {
  fullscreen.value = !fullscreen.value
  nextTick(() => editor.value?.commands.focus())
}
function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape' && fullscreen.value && !linkOpen.value && !pickerOpen.value && !findOpen.value)
    fullscreen.value = false
}
watch(fullscreen, (on) =>
  on ? window.addEventListener('keydown', onKeydown) : window.removeEventListener('keydown', onKeydown),
)
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKeydown)
  editor.value?.destroy()
})

defineFieldActions(
  props.config.fullscreen === false
    ? []
    : [
        {
          title: 'Toggle Fullscreen Mode',
          icon: () => (fullscreen.value ? 'fullscreen-close' : 'fullscreen-open'),
          run: toggleFullscreen,
          visibleWhenReadOnly: true,
        },
      ],
)

const toolbarTarget = `nib-${useId()}`
const linkButton = ref<HTMLElement>()
type LinkAnchor = HTMLElement | { getBoundingClientRect: () => DOMRect }
const linkAnchor = ref<LinkAnchor | null>(null)
const linkOpen = ref(false)
const linkHref = ref('')
const linkNewWindow = ref(false)
function openLink(anchor: LinkAnchor | null = null) {
  linkAnchor.value = anchor
  const attrs = editor.value?.getAttributes('link') ?? {}
  linkHref.value = attrs.href ?? ''
  linkNewWindow.value = attrs.target === '_blank' || props.config.target_blank === true
  linkOpen.value = true
}
function applyLink() {
  const chain = editor.value?.chain().focus().extendMarkRange('link')
  if (!linkHref.value) chain?.unsetLink().run()
  else chain?.setLink({ href: linkHref.value, target: linkNewWindow.value ? '_blank' : null }).run()
  linkOpen.value = false
}
function removeLink() {
  editor.value?.chain().focus().extendMarkRange('link').unsetLink().run()
  linkOpen.value = false
}

const pickerOpen = ref(false)
const IMAGE_TYPES = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'avif', 'svg']
function insertImage([asset]: AssetRow[]) {
  if (!asset) return
  editor.value
    ?.chain()
    .focus()
    .insertContent({
      type: 'image',
      attrs: {
        src: asset.url,
        alt: asset.alt ?? '',
        asset: String(asset.id),
        width: asset.width,
        height: asset.height,
      },
    })
    .run()
}

type ToolbarButton = {
  name: string
  text: string
  svg: string
  command: (e: Editor) => void
  active?: string | [string, object]
  whenActive?: string
}
const allButtons: ToolbarButton[] = [
  {
    name: 'h2',
    text: 'Heading 2',
    svg: 'h2',
    command: (e) => e.chain().focus().toggleHeading({ level: 2 }).run(),
    active: ['heading', { level: 2 }],
  },
  {
    name: 'h3',
    text: 'Heading 3',
    svg: 'h3',
    command: (e) => e.chain().focus().toggleHeading({ level: 3 }).run(),
    active: ['heading', { level: 3 }],
  },
  {
    name: 'h4',
    text: 'Heading 4',
    svg: 'h4',
    command: (e) => e.chain().focus().toggleHeading({ level: 4 }).run(),
    active: ['heading', { level: 4 }],
  },
  {
    name: 'bold',
    text: 'Bold',
    svg: 'text-bold',
    command: (e) => e.chain().focus().toggleBold().run(),
    active: 'bold',
  },
  {
    name: 'italic',
    text: 'Italic',
    svg: 'text-italic',
    command: (e) => e.chain().focus().toggleItalic().run(),
    active: 'italic',
  },
  {
    name: 'underline',
    text: 'Underline',
    svg: 'text-underline',
    command: (e) => e.chain().focus().toggleUnderline().run(),
    active: 'underline',
  },
  {
    name: 'unorderedlist',
    text: 'Unordered List',
    svg: 'list-ul',
    command: (e) => e.chain().focus().toggleBulletList().run(),
    active: 'bulletList',
  },
  {
    name: 'orderedlist',
    text: 'Ordered List',
    svg: 'list-ol',
    command: (e) => e.chain().focus().toggleOrderedList().run(),
    active: 'orderedList',
  },
  {
    name: 'removeformat',
    text: 'Remove Formatting',
    svg: 'eraser',
    command: (e) => e.chain().focus().clearNodes().unsetAllMarks().run(),
  },
  {
    name: 'quote',
    text: 'Blockquote',
    svg: 'quote',
    command: (e) => e.chain().focus().toggleBlockquote().run(),
    active: 'blockquote',
  },
  { name: 'anchor', text: 'Link', svg: 'insert-link', command: () => openLink(), active: 'link' },
  { name: 'image', text: 'Image', svg: 'insert-image', command: () => (pickerOpen.value = true) },
  {
    name: 'table',
    text: 'Table',
    svg: 'add-table',
    command: (e) => e.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run(),
  },
  {
    name: 'strikethrough',
    text: 'Strikethrough',
    svg: 'text-strike-through',
    command: (e) => e.chain().focus().toggleStrike().run(),
    active: 'strike',
  },
  {
    name: 'code',
    text: 'Inline Code',
    svg: 'code-inline',
    command: (e) => e.chain().focus().toggleCode().run(),
    active: 'code',
  },
  {
    name: 'codeblock',
    text: 'Code Block',
    svg: 'code-block',
    command: (e) => e.chain().focus().toggleCodeBlock().run(),
    active: 'codeBlock',
  },
  {
    name: 'horizontalrule',
    text: 'Horizontal Rule',
    svg: 'hr',
    command: (e) => e.chain().focus().setHorizontalRule().run(),
  },
  {
    name: 'deletetable',
    text: 'Delete Table',
    svg: 'delete-table',
    command: (e) => e.chain().focus().deleteTable().run(),
    whenActive: 'table',
  },
  {
    name: 'addcolumnbefore',
    text: 'Add Column Before',
    svg: 'add-col-before',
    command: (e) => e.chain().focus().addColumnBefore().run(),
    whenActive: 'table',
  },
  {
    name: 'addcolumnafter',
    text: 'Add Column After',
    svg: 'add-col-after',
    command: (e) => e.chain().focus().addColumnAfter().run(),
    whenActive: 'table',
  },
  {
    name: 'deletecolumn',
    text: 'Delete Column',
    svg: 'delete-col',
    command: (e) => e.chain().focus().deleteColumn().run(),
    whenActive: 'table',
  },
  {
    name: 'addrowbefore',
    text: 'Add Row Before',
    svg: 'add-row-before',
    command: (e) => e.chain().focus().addRowBefore().run(),
    whenActive: 'table',
  },
  {
    name: 'addrowafter',
    text: 'Add Row After',
    svg: 'add-row-after',
    command: (e) => e.chain().focus().addRowAfter().run(),
    whenActive: 'table',
  },
  {
    name: 'deleterow',
    text: 'Delete Row',
    svg: 'delete-row',
    command: (e) => e.chain().focus().deleteRow().run(),
    whenActive: 'table',
  },
  {
    name: 'toggleheadercell',
    text: 'Toggle Header Cell',
    svg: 'flip-vertical',
    command: (e) => e.chain().focus().toggleHeaderCell().run(),
    whenActive: 'table',
  },
  {
    name: 'togglecellmerge',
    text: 'Merge Cells',
    svg: 'combine-cells',
    command: (e) => e.chain().focus().mergeCells().run(),
    whenActive: 'table',
  },
]
const configured = computed(() => {
  const names = Array.isArray(props.config.buttons) ? (props.config.buttons as string[]) : null
  return names
    ? allButtons.filter(
        (button) => names.includes(button.name) || (button.whenActive === 'table' && names.includes('table')),
      )
    : allButtons
})
function isActive(button: ToolbarButton) {
  if (!editor.value || !button.active) return false
  return Array.isArray(button.active) ? editor.value.isActive(...button.active) : editor.value.isActive(button.active)
}
const visibleButtons = () => configured.value.filter((b) => !b.whenActive || editor.value?.isActive(b.whenActive))
const bubbleButtons = computed(() =>
  configured.value.filter((b) =>
    ['bold', 'italic', 'underline', 'strikethrough', 'code', 'anchor', 'removeformat'].includes(b.name),
  ),
)
const floatingButtons = computed(() =>
  configured.value.filter((b) =>
    ['h2', 'h3', 'unorderedlist', 'orderedlist', 'quote', 'codeblock', 'table', 'horizontalrule'].includes(b.name),
  ),
)

function runBubbleButton(e: Editor, button: ToolbarButton) {
  if (button.name !== 'anchor') return button.command(e)
  const { from, to } = e.state.selection
  openLink({ getBoundingClientRect: () => posToDOMRect(e.view, from, to) })
}
function showBubbleMenu({
  editor: e,
  state,
  from,
  to,
}: {
  editor: Editor
  state: EditorState
  from: number
  to: number
}) {
  return (
    e.isEditable &&
    e.view.hasFocus() &&
    from !== to &&
    !linkOpen.value &&
    !(state.selection instanceof NodeSelection) &&
    !e.isActive('codeBlock')
  )
}
</script>

<template>
  <Teleport to="body" :disabled="!fullscreen">
    <div :id="id" :class="['nib antialiased', { 'nib-fullscreen': fullscreen }]">
      <header
        v-show="fullscreen"
        class="fixed inset-x-0 top-0 z-45 flex h-12 items-center justify-between bg-gray-50 px-4 shadow-ui-lg dark:border-b dark:border-white/10 dark:bg-gray-925 dark:shadow-none"
      >
        <h2 class="shrink-0 text-[0.9375rem] font-medium text-gray-925 dark:text-white">{{ config.display }}</h2>
        <div :id="toolbarTarget" class="flex min-w-max items-center gap-4" />
        <div :id="`${toolbarTarget}-find`" class="absolute inset-x-0 top-full flex justify-center px-4" />
        <div class="flex items-center justify-end gap-2 py-2.5">
          <Button
            type="button"
            variant="outline"
            size="sm"
            class="px-2.5"
            aria-label="Toggle Fullscreen Mode"
            tabindex="-1"
            @click="toggleFullscreen"
          >
            <AdminIcon name="fullscreen-close" class="size-3.5" />
          </Button>
        </div>
      </header>

      <Teleport defer :to="`#${toolbarTarget}`" :disabled="!fullscreen">
        <div
          v-if="!isReadOnly"
          :class="['nib-toolbar', { 'border-0': fullscreen }]"
          role="toolbar"
          aria-label="Formatting"
        >
          <div class="flex flex-1 flex-wrap items-center gap-1">
            <Button
              v-for="button in visibleButtons()"
              :key="button.name"
              :ref="(el) => button.name === 'anchor' && (linkButton = (el as { $el?: HTMLElement } | null)?.$el)"
              type="button"
              variant="ghost"
              size="sm"
              :class="['nib-toolbar-button px-2!', { active: isActive(button) }]"
              :aria-label="button.text"
              :title="button.text"
              @mousedown.prevent
              @click="editor && button.command(editor)"
            >
              <AdminIcon :name="button.svg" class="size-3.5!" />
            </Button>
            <SetPicker
              v-if="hasSets"
              :groups="groups"
              icon-only
              label="Add set"
              @pick="(handle) => insertSet(handle)"
            />
          </div>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            :class="['nib-toolbar-button px-2!', { active: findOpen }]"
            aria-label="Find and replace"
            title="Find and replace (Ctrl+F)"
            :aria-expanded="findOpen"
            @mousedown.prevent
            @click="findOpen ? closeFind() : openFind()"
          >
            <AdminIcon name="search-magnifying-glass" class="size-3.5!" />
          </Button>
          <Teleport defer :to="`#${toolbarTarget}-find`" :disabled="!fullscreen">
            <FindReplaceBar
              v-if="findOpen && editor"
              ref="findBar"
              :editor="editor"
              :class="{ 'nib-find-floating': fullscreen }"
              @close="closeFind"
            />
          </Teleport>
        </div>
      </Teleport>

      <div :class="['nib-editor', { 'focus-within:focus-outline': !fullscreen }]">
        <BubbleMenu
          v-if="editor"
          :editor="editor"
          :should-show="showBubbleMenu"
          class="z-25"
          :options="{ placement: 'top', offset: 10 }"
        >
          <div v-show="!linkOpen" class="nib-bubble-menu" role="toolbar" aria-label="Text formatting">
            <Button
              v-for="button in bubbleButtons"
              :key="button.name"
              type="button"
              variant="ghost"
              size="sm"
              :class="[
                'px-2! hover:bg-white/15 [&_svg]:opacity-100',
                isActive(button) ? '[&_svg]:text-yellow-300' : '[&_svg]:text-white',
              ]"
              :aria-label="button.text"
              :aria-pressed="isActive(button)"
              :title="button.text"
              @mousedown.prevent
              @click="runBubbleButton(editor, button)"
            >
              <AdminIcon :name="button.svg" class="size-3.5!" />
            </Button>
          </div>
        </BubbleMenu>
        <FloatingMenu v-if="editor && !isReadOnly" :editor="editor" :options="{ placement: 'right', offset: 8 }">
          <div class="nib-floating-menu" role="toolbar" aria-label="Insert block">
            <Button
              v-for="button in floatingButtons"
              :key="button.name"
              type="button"
              variant="ghost"
              size="sm"
              class="nib-toolbar-button px-2!"
              :aria-label="button.text"
              :title="button.text"
              @mousedown.prevent
              @click="button.command(editor)"
            >
              <AdminIcon :name="button.svg" class="size-3.5!" />
            </Button>
            <SetPicker
              v-if="hasSets"
              :groups="groups"
              icon-only
              label="Add set"
              @pick="(handle) => insertSet(handle)"
            />
          </div>
        </FloatingMenu>
        <EditorContent :editor="editor" />
      </div>

      <div v-if="config.reading_time || config.word_count" class="nib-footer">
        <div v-if="config.reading_time">{{ readTime }} Reading Time</div>
      </div>
    </div>
  </Teleport>

  <Popover v-model:open="linkOpen">
    <PopoverAnchor :reference="linkAnchor ?? linkButton" />
    <PopoverContent class="z-50 w-96 space-y-4" @open-auto-focus.prevent>
      <div class="space-y-2">
        <Label :for="`${toolbarTarget}-href`">URL</Label>
        <LinkUrlInput :id="`${toolbarTarget}-href`" v-model="linkHref" @submit="applyLink" />
      </div>
      <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-300">
        <Switch v-model="linkNewWindow" size="sm" />Open in new window
      </label>
      <div class="flex justify-end gap-2">
        <Button type="button" variant="ghost" size="sm" @click="linkOpen = false">Cancel</Button>
        <Button type="button" variant="outline" size="sm" @click="removeLink">Remove Link</Button>
        <Button type="button" size="sm" @click="applyLink">Apply Link</Button>
      </div>
    </PopoverContent>
  </Popover>

  <AssetSelector v-model:open="pickerOpen" :max-files="1" :allowed-types="IMAGE_TYPES" @select="insertImage" />
</template>
