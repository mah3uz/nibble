---
title: End-to-end tests
description: The Playwright suite, and the playground it drives.
order: 4
---

# End-to-end tests

`test/e2e/` holds Playwright scripts, run from the repo root against a dev server. Install them once with
`(cd test/e2e && npm install && npx playwright install chromium)`.

```
node test/e2e/cp-e2e.mjs http://localhost:3100 EMAIL PASSWORD_FILE          # control panel round trip + axe on every screen
node test/e2e/crumbs-e2e.mjs http://localhost:3100                          # public pages, hydration and axe
node test/e2e/nibble-playground-e2e.mjs http://localhost:3100 EMAIL PASSWORD_FILE
node test/e2e/cp-screenshots.mjs http://localhost:3100 EMAIL PASSWORD_FILE  # screenshots of every CP screen
```

The playground (`/admin/nibble/playground`, development only) renders every schema blueprint plus a kitchen-sink
blueprint using all core fieldtypes, backed by in-memory demo records.
