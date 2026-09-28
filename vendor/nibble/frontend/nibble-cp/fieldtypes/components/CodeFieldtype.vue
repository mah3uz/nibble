<script setup lang="ts">
import type { EditorView } from '@codemirror/view'
import { onBeforeUnmount, onMounted, useTemplateRef, watch } from 'vue'
import { fieldtypeEmits, fieldtypeProps, useFieldtype } from '../useFieldtype'

const props = defineProps(fieldtypeProps)
const emit = defineEmits(fieldtypeEmits)
const { updateDebounced, isReadOnly, expose } = useFieldtype(emit, props)
defineExpose(expose)

const host = useTemplateRef<HTMLElement>('host')
const text = () => (props.value == null ? '' : String(props.value))
let view: EditorView | null = null

const theme = {
  '&': {
    backgroundColor: 'var(--color-gray-900)',
    color: 'var(--color-gray-100)',
    borderRadius: 'var(--radius-md)',
    fontSize: '0.8125rem',
  },
  '&.cm-focused': { outline: '2px solid var(--color-ring, var(--color-blue-500))', outlineOffset: '1px' },
  '.cm-scroller': { fontFamily: 'var(--default-mono-font-family, ui-monospace, SFMono-Regular, Menlo, monospace)' },
  '.cm-content': {
    minHeight: `${(Number(props.config.rows) || 8) * 1.4}em`,
    padding: '0.625rem 0',
    caretColor: 'var(--color-gray-100)',
  },
  '.cm-gutters': { backgroundColor: 'transparent', color: 'var(--color-gray-500)', border: 'none' },
  '.cm-activeLine, .cm-activeLineGutter': {
    backgroundColor: 'color-mix(in oklab, var(--color-gray-700) 35%, transparent)',
  },
  '&.cm-focused .cm-selectionBackground, .cm-selectionBackground, ::selection': {
    backgroundColor: 'color-mix(in oklab, var(--color-sky-500) 35%, transparent)',
  },
  '.tok-typeName, .tok-className, .tok-heading': { color: 'var(--color-pink-400)' },
  '.tok-keyword, .tok-propertyName': { color: 'var(--color-slate-300)' },
  '.tok-string, .tok-string2, .tok-number, .tok-atom, .tok-bool, .tok-variableName, .tok-literal, .tok-url': {
    color: 'var(--color-sky-300)',
  },
  '.tok-comment, .tok-punctuation, .tok-operator, .tok-meta': { color: 'var(--color-slate-400)' },
}

// CodeMirror reads the DOM as it loads, so it's imported only once the field is on screen.
onMounted(async () => {
  const [codemirror, state, commands, language, lang, highlight] = await Promise.all([
    import('@codemirror/view'),
    import('@codemirror/state'),
    import('@codemirror/commands'),
    import('@codemirror/language'),
    import('@codemirror/lang-html'),
    import('@lezer/highlight'),
  ])
  if (!host.value) return

  const editable = new state.Compartment()
  view = new codemirror.EditorView({
    parent: host.value,
    state: state.EditorState.create({
      doc: text(),
      extensions: [
        codemirror.lineNumbers(),
        codemirror.highlightActiveLine(),
        codemirror.highlightActiveLineGutter(),
        codemirror.drawSelection(),
        commands.history(),
        language.indentOnInput(),
        language.bracketMatching(),
        language.syntaxHighlighting(highlight.classHighlighter),
        lang.html(),
        codemirror.keymap.of([...commands.defaultKeymap, ...commands.historyKeymap]),
        codemirror.EditorView.lineWrapping,
        codemirror.EditorView.theme(theme, { dark: true }),
        codemirror.EditorView.contentAttributes.of({
          id: props.id ?? '',
          'aria-multiline': 'true',
          spellcheck: 'false',
        }),
        codemirror.placeholder((props.config.placeholder as string) || ''),
        editable.of(codemirror.EditorView.editable.of(!isReadOnly.value)),
        codemirror.EditorView.updateListener.of((update) => {
          if (update.docChanged) updateDebounced(update.state.doc.toString())
          if (update.focusChanged) emit(update.view.hasFocus ? 'focus' : 'blur')
        }),
      ],
    }),
  })

  watch(isReadOnly, (readOnly) =>
    view?.dispatch({ effects: editable.reconfigure(codemirror.EditorView.editable.of(!readOnly)) }),
  )
})

watch(
  () => props.value,
  () => {
    const next = text()
    if (view && next !== view.state.doc.toString())
      view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: next } })
  },
)

onBeforeUnmount(() => view?.destroy())
</script>

<template>
  <div ref="host" class="min-w-0" :data-field="handle" />
</template>
