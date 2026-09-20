import { registerFieldtype } from './registry'

const components = {
  assets: () => import('./components/AssetsFieldtype.vue'),
  checkboxes: () => import('./components/CheckboxesFieldtype.vue'),
  date: () => import('./components/DateFieldtype.vue'),
  entries: () => import('./components/EntriesFieldtype.vue'),
  grid: () => import('./components/GridFieldtype.vue'),
  integer: () => import('./components/IntegerFieldtype.vue'),
  link: () => import('./components/LinkFieldtype.vue'),
  list: () => import('./components/ListFieldtype.vue'),
  radio: () => import('./components/RadioFieldtype.vue'),
  replicator: () => import('./components/ReplicatorFieldtype.vue'),
  rich_text: () => import('./components/RichTextFieldtype.vue'),
  select: () => import('./components/SelectFieldtype.vue'),
  secret: () => import('./components/SecretFieldtype.vue'),
  seo: () => import('./components/SeoFieldtype.vue'),
  slug: () => import('./components/SlugFieldtype.vue'),
  terms: () => import('./components/TermsFieldtype.vue'),
  text: () => import('./components/TextFieldtype.vue'),
  textarea: () => import('./components/TextareaFieldtype.vue'),
  toggle: () => import('./components/ToggleFieldtype.vue'),
}

export const coreFieldtypeHandles = Object.keys(components)

export function registerCoreFieldtypes() {
  for (const [handle, loader] of Object.entries(components)) registerFieldtype(handle, loader)
}
