---
id: running-users-and-roles
title: Users and roles
description: Let people in, give each the smallest role that lets them work, build roles of your own, and keep a way
  in for when something goes wrong.
order: 2
---

# Users and roles

Tidewater's Control Plane has several kinds of people in it, and each needs something different: you administer
the site, marketing runs the blog and landing pages, a freelance writer drafts posts, and the founders only look.
Roles are how that is expressed.

After reading this guide, you will know:

- How to add someone, from the Control Plane or a terminal.
- What each built-in role can do.
- How to build a role of your own.
- The rule that keeps a site from locking itself out.

## 1. Adding someone

**From the Control Plane.** Open **Users**, choose to invite someone, and give their name, email address and role.
They get an email with a link and set their own password, so nobody ever sends a password to anyone.

![Users in the Control Plane](../../images/cp/users.png)

**From a terminal** — for the very first account, or a server where mail is not set up yet:

```sh
bin/rails nibble:admin:create
```

It asks for a role, then a name, an email address and a password. On a deployed server, run it in the container:

```sh
bin/kamal app exec -i 'bin/rails nibble:admin:create'
```

> [!IMPORTANT]
> Passwords need at least 12 characters, with a lowercase letter, an uppercase letter, a number and a symbol. The rule
> is the same everywhere — invitations, resets, and people changing their own.

## 2. The roles that ship

| Role | Can |
|---|---|
| **Administrator** | everything, including users, roles and settings |
| **Editor** | all content, globals, menus, assets and forms; redirects, the trash, utilities, and approving reviews |
| **Author** | create entries and edit their own; see terms; upload assets |
| **Contributor** | create entries and edit their own; see terms and assets |
| **Viewer** | look, not touch |

At Tidewater, marketing are **Editors**, the freelance writer is an **Author** — able to upload the images a post
needs, but not to publish — and the founders are **Viewers**.

> [!TIP]
> Give people the smallest role that lets them do their job. It is not about distrust: a smaller role means fewer
> ways to break something by accident on a busy afternoon.

A person can hold more than one role; they can do whatever any of them allows.

## 3. Roles of your own

Open **Roles** and every ability is a checkbox, grouped by what it touches — each collection, each taxonomy, assets,
forms, users, settings. Create a role, tick what it allows, and assign it.

![Roles in the Control Plane](../../images/cp/roles.png)

Abilities are fine-grained on purpose. "Can write blog posts but not touch landing pages", "can publish but not
delete", "can read demo requests but not export them" are all expressible without code. For Tidewater, you
might make a **Sales** role that can only read the Book a demo form's submissions.

Two permissions concern AI apps: **Connect apps** lets someone connect Claude, the `nibble` command and the like to
act as them, and **Manage agent access** opens [Agent access](agent-access.md). Only administrators have either until
you grant them.

**Administrator is the exception.** It grants everything rather than listing abilities, which is why a new feature is
immediately available to administrators, and has to be granted to everyone else on purpose.

## 4. The last way in

**At least one role must grant full access, and someone must hold it.** Nibble refuses to delete the last one or to
strip what makes it complete.

> [!CAUTION]
> A site with no administrator cannot be repaired from the Control Plane. It needs someone at a terminal with
> `bin/rails nibble:admin:create` — on a server, through `bin/kamal app exec`. Keep two administrators, so one
> person's lost phone is not the site's problem.

## 5. Signing in, and staying safe

Each person manages their own password, their signed-in devices and two-factor authentication from their account.

- **Sensitive screens ask for the password again** before they open: users, roles, API tokens, agent access,
  approvals, imports.
- **A session ends after two hours without activity**, on the server, so reloading the page doesn't bring it back.
  A minute before, a warning offers to extend it. Once it has ended, a dialog asks for the password (and the code, with
  two-factor on) and carries on where the page left off, unsaved changes included. `session.idle_minutes` in
  `config/nibble.yml` sets how long.
- **Guessing is slowed down.** Ten wrong passwords for one email address within fifteen minutes, or twenty wrong
  two-factor codes, locks that address out of signing in for the rest of the fifteen minutes: the sign-in page
  answers "Too many attempts. Try again in 15 minutes." A wrong password typed into the "confirm your password" prompt
  counts too. Failures older than fifteen minutes are forgotten, a successful sign-in clears the count, and a lockout
  is written to the [audit log](utilities.md#9-audit-log) as `auth.locked_out`. Within one sign-in, five wrong codes
  end the attempt and the person starts again.
- **Recovery codes** are the way in when the phone is lost. Turning on two-factor with an authenticator app makes
  eight single-use codes and shows them once; the person should save them somewhere safe. Typing one in place of the
  six-digit code signs them in and uses it up. **New recovery codes**, on the account page, makes a fresh set after asking
  for the password, and the old ones stop working.
- **Passkeys** are an alternative second step that needs no codes. They are added from the same account page.

### 5.1 Someone cannot get in

| Their problem | What to do |
|---|---|
| Forgot the password | They choose **Forgot password?** on the sign-in page and follow the email. Or open them under **Users** and choose **Send password reset**. Both need mail to be set up ([Configuration](configuration.md#6-environment-and-credentials)). |
| Locked out after too many tries | Wait fifteen minutes. Nothing needs undoing. |
| Lost the phone, still has recovery codes | Sign in with a recovery code, then set up two-factor again from their account. |
| Lost the phone and the codes | Another administrator switches two-factor off for them in a console (below); they sign in with their password and set it up again. |
| Signed in on a device they no longer have | Open them under **Users** and revoke the session. |

There is no button for switching off someone else's two-factor. On the server, as an administrator:

```sh
bin/kamal console
Nibble::User.find_by!(email_address: "mina@tidewater.example").disable_two_factor!
```

If the person's role requires two-factor, they are sent to set it up again as soon as they sign in. Only a superuser
may edit or reset another superuser.

## 6. Removing someone

Deleting a person under **Users** ends their access and their sessions at once. What they wrote stays where it is:
entries record who created and last changed them, and that history survives the account.
