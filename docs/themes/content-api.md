---
title: The Content API
description: Reading the same content from somewhere else.
order: 6
---

# The Content API

Everything a theme renders is also readable over HTTP, for a front end you host elsewhere or a job that needs the
content.

```
GET /api/v1/collections/guides/entries
GET /api/v1/collections/guides/entries/<id>
GET /api/v1/taxonomies/regions/terms
GET /api/v1/globals/contact
```

Requests are authorised with an API token, created under **API tokens** in the control panel, each with its own
scopes and expiry. Send it as a bearer token:

```sh
curl -H "Authorization: Bearer $TOKEN" https://example.com/api/v1/collections/guides/entries
```

Responses hold published content in the same shape a view receives, so a field is the same thing in both places.
Drafts and unpublished entries are not served.
