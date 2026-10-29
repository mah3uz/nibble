---
id: reference
title: Reference
description: Every field option, validation rule and condition a blueprint can use, looked up by name.
order: 7
---

# Reference

The guides explain how to build a site; these pages are for looking something up. Each lists everything Nibble accepts
under one heading, with its type, its default and what it does.

| Page | Look here for |
|---|---|
| [Fieldtypes and field options](fieldtypes.md) | every fieldtype, what it stores, each of its options, and the options every field takes |
| [Validation rules](validation.md) | every rule a field's `validate` accepts, its arguments, its message and how to reword it |
| [Conditions](conditions.md) | the syntax behind `if`, `unless`, `required` and `read_only` conditions, and what a hidden field keeps |

`bin/rails nibble:check` reads a blueprint against these pages and refuses an option a fieldtype doesn't have, so a
typo in an option name is reported rather than ignored.

The guides that use these: [Blueprints and fields](../modelling/blueprints.md) and [Forms](../modelling/forms.md).
