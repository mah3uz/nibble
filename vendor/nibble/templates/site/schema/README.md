# Your schema

This directory is yours. Nibble never ships a file here, so nothing you put in it is touched by an upgrade.

It holds collections, taxonomies, blueprints, fieldsets, globals, navigation and forms, in the same layout Nibble
uses internally:

```
site/schema/
  collections/<handle>.yml
  taxonomies/<handle>.yml
  blueprints/collections/<collection>/<handle>.yml
  blueprints/taxonomies/<taxonomy>/<handle>.yml
  fieldsets/<handle>.yml
  globals/<handle>.yml
  navigation/<handle>.yml
  forms/<handle>.yml
```

Schema is read in three layers — Nibble's own, then your theme's, then this one — and the last one to define a
handle wins. So a file here named after one of Nibble's replaces it.

**An override replaces the whole file.** Copying `collections/posts.yml` here and deleting a key removes that key;
it is not merged with Nibble's version. Start from a copy of the file you are replacing.

To remove one of Nibble's collections rather than replace it, list it under `disable:` in `config/nibble.yml`
instead.

Run `bin/rails nibble:check` after editing anything here.
