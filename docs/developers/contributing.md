---
title: Contributing
description: Sending a change back rather than carrying it.
order: 7
---

# Contributing

If you have changed something of Nibble's on your own site, it is worth upstreaming rather than carrying: a patch
you keep is a conflict on every upgrade, and an ejected file stops receiving fixes.

1. `bin/rails nibble:check` — see exactly which of Nibble's files you changed.
2. Clone Nibble itself and make the change there, with a test that fails without it.
3. `bin/ci` — every check, including the ones a change like yours tends to trip.
4. Send it to the repository named in `Nibble::REPOSITORY`, describing what it fixes for a site rather than how
   it works.
5. Once it is released, take the release and drop your copy: `git rm site/<path>` and its entry in
   `.nibble/ejected.yml`.

## What makes a change easy to take

- **A test that encodes why**, not just what. If the rule changes later, the test should fail.
- **The smallest change that solves it.** Touch what you must; leave adjacent code alone.
- **Comments only where the code cannot show it** — a constraint, a workaround, the reason behind something
  surprising. Never a restatement of the line below.
- **Say what it does, not where it came from.** No plan or ticket numbers in the code or the commit message.
