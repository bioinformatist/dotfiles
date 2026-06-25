# Inline Feedback

Use this reference when checking validation, help text, warnings, and field
semantics.

## Field-Local Validation

Validation belongs where the user can fix it:

- A malformed hostname error belongs below the hostname field.
- A short password error belongs below the password field.
- A disk path format error belongs below the disk path field.
- A missing required login method belongs inside the login method group.

Avoid routing those messages only to a global status panel. A summary can exist,
but the field still needs its own visible and programmatic error.

## Context-Aware Copy

Error text should match the current UI mode:

- If the user selected "password", say the password is missing or too short.
- If the user selected "SSH key", say the key is missing or malformed.
- Do not mention inactive alternatives unless the user can act on them right
  there.

Schema-level messages are often too broad for the screen. Rewrite them into
field-level language at the UI boundary.

## Help And Warnings

Help text should sit next to the relevant field or option:

- Stable disk path guidance belongs near the disk path input.
- Proxy or regional network warnings belong near the selected network mode.
- Irreversible data-loss warnings belong near the destructive target field and
  again near the final destructive action.

Do not mix ordinary hints, blocking errors, and non-blocking notices in one
undifferentiated status list.

High-risk or irreversible warnings should be visually stronger than ordinary
help text, but still local to the field, option, or final action that can cause
the result.

## Tooltips And Interactive Help

Simple tooltips are for short explanatory text only. If the content includes
selectable text, commands, links, buttons, or other actions, treat it as
interactive help or popover-like content.

Interactive help should:

- remain open across hover and focus transitions;
- avoid pointer gaps between trigger and panel;
- be reachable by keyboard;
- not disappear while the user selects text, copies commands, or clicks controls.

## Accessible Semantics

When a field is invalid:

- Set the invalid state with the framework's native form API or
  `aria-invalid="true"`.
- Connect the field to its error text with `aria-describedby`.
- Keep labels programmatically associated with controls.
- Ensure icon-only help has an accessible name or use visible text.
- Do not rely on color alone; use text and, when useful, an icon from the
  project's existing icon system.

Source-only checks can find missing attributes, but browser snapshots provide
better evidence for labels, names, roles, and focus order.
