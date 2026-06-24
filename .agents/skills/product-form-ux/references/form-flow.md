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

## Required Versus Optional

Users should be able to tell what blocks progress:

- Required fields need visible labels and field-local errors.
- Optional fields need short "optional" language only when ambiguity is likely.
- Disabled actions need an immediate reason: near the action, near the missing
  field, or both.

Avoid making the user infer blockers from disabled buttons alone.

## Destructive Or Irreversible Choices

For destructive setup flows, such as wiping a disk or replacing a system:

- Put the warning near the target field.
- Use a stable identifier, not a transient path, when the user must pick a
  device or resource.
- Repeat the destructive consequence near the final action if the action can
  execute it.

Do not bury destructive consequences in a generic help tooltip only.

## Copy Discipline

Use standard UI copy for standard actions:

- "Download", "Copy command", "Install", "Continue", "Back", "Save".
- Avoid themed labels that make actions less clear.

Keep visible text specific and useful. Remove filler labels, decorative status
phrases, and repeated explanatory paragraphs that do not change user action.
