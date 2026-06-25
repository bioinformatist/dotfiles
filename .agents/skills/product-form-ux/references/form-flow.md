# Form Flow

Use this reference when checking ordering, grouping, progressive disclosure, and
how the user moves through the form.

## Order Fields By User Decision Flow

The visible order should follow how the user thinks:

1. Identify what is being created or configured.
2. Choose authentication or access method.
3. Choose target, scope, or destination.
4. Choose optional capabilities.
5. Preview generated output.
6. Run, copy, download, submit, or install.

Optional metadata should not interrupt required setup unless it changes the
generated result in a critical way.

## Progressive Disclosure

When a mode is selected, show only the fields and guidance for that mode:

- Selecting SSH key should reveal SSH key input and key guidance.
- Selecting password should reveal password input and password guidance.
- Mode-specific validation should update with the mode.

Keep hidden-mode errors out of the user's path unless they affect persisted
data or a final action.

## Sequential Blockers

When one prerequisite blocks a later confirmation, show the current actionable
blocker first. Do not show every downstream error before the upstream input is
valid.

For example, if a URL, credential, target, or mode choice is required before an
option-specific check can make sense, first ask the user to fix that input. Show
the downstream confirmation only after the prerequisite is usable.

## Preview And Output Responsiveness

If a checkbox, mode, or option changes generated output, the preview or output
area should visibly reflect that change. If the generated output does not
change, explain why.

Otherwise a valid option can look broken because the user sees no visible
response from the preview, command, file list, or generated artifact.

## Required Versus Optional

Users should be able to tell what blocks progress:

- Required fields need visible labels and field-local errors.
- Optional fields need short "optional" language only when ambiguity is likely.
- Disabled actions need an immediate reason: near the action, near the missing
  field, or both.

Avoid making the user infer blockers from disabled buttons alone.

## High-Risk Or Irreversible Choices

For destructive or high-risk flows, such as wiping a disk, replacing a system,
deleting data, or irreversible submission:

- Put the warning near the target field.
- Use a stable identifier, not a transient path, when the user must pick a
  device or resource.
- Repeat the destructive consequence near the final action if the action can
  execute it.

Use stronger treatment than ordinary help text while keeping the warning close
to the field or action that can cause the result. Do not bury destructive
consequences in a generic help tooltip only.

## Copy Discipline

Use standard UI copy for standard actions:

- "Download", "Copy command", "Install", "Continue", "Back", "Save".
- Avoid themed labels that make actions less clear.

Keep visible text specific and useful. Remove filler labels, decorative status
phrases, and repeated explanatory paragraphs that do not change user action.

## Successful Path Discipline

The successful path ends after the final action's side effect is verified, not
after the button becomes enabled:

- Copy actions should produce the expected clipboard value.
- Download actions should produce the expected file or archive.
- Generate and export actions should produce artifacts that match the current
  fields and options.

Do not let a toast, optimistic state update, or lack of console errors stand in
for the action result.
