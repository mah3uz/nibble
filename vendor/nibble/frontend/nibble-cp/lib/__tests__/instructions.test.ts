import { describe, expect, it } from 'vitest'
import { instructionParts } from '../instructions'

describe('instructionParts', () => {
  it('turns a Markdown link into a link, so a card can point at the vendor page that explains the value', () => {
    expect(instructionParts('In Site settings. [Install guide](https://plausible.io/docs/plausible-script)')).toEqual([
      { text: 'In Site settings. ' },
      { text: 'Install guide', href: 'https://plausible.io/docs/plausible-script' },
    ])
  })

  it('leaves anything but an https link as text, so instructions can never carry a javascript: URL', () => {
    expect(instructionParts('[x](javascript:alert(1)) and [y](http://a.test)')).toEqual([
      { text: '[x](javascript:alert(1)) and [y](http://a.test)' },
    ])
  })
})
