import type { SetBlock } from './types'

export const withoutIdentity = (block: SetBlock) => {
  const props = { ...block } as Partial<SetBlock>
  delete props.id
  delete props.type
  return props
}
