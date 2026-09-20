---
title: Users and roles
description: Adding people, and deciding what they can do.
order: 3
---

# Users and roles

## Adding someone

```sh
bin/rails nibble:admin:create
```

It asks which role, then a name, email address and password, and refuses a password the rules reject — at least
12 characters with lower case, upper case, a number and a symbol. The same rule applies everywhere a password is
set: the control panel, resets and invitations.

People can also be invited from **Users** in the control panel, which sends them a link to set their own password.

## The roles

| Role | Can |
|---|---|
| Administrator | everything, including users, roles and settings |
| Editor | all content, assets and forms; redirects, trash and utilities |
| Author | create entries and edit their own; view terms; upload assets |
| Contributor | create entries and edit their own; view terms and assets |
| Viewer | look, not touch |

Roles are rows, not code: **Roles** in the control panel shows each ability as a checkbox, and you can add roles of
your own. Only an Administrator's role grants everything; the others list their abilities explicitly.

At least one role must grant full access at all times — Nibble refuses to remove the last one, because a site
with no way in cannot be fixed from inside.

## Signing in

Sessions, password resets and two-factor authentication are in the control panel under the user menu. Screens that
change users, roles, API tokens or imported content ask for the password again before they open, and the site
locks itself after a period of inactivity with a warning first.
