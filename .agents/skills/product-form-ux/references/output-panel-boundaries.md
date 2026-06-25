# Output Panel Boundaries

Use this reference when a screen has a side panel, preview panel, generated file
list, command box, log panel, or final action area.

## Separate Input From Output

Input areas answer: "What should I provide or choose?"

Output areas answer: "What will be generated, copied, downloaded, run, or
submitted?"

Do not make the output area the main place where users discover input mistakes.
Errors can be summarized there only when the corresponding field also carries
the error locally.

## Good Output Panel Content

Output panels are appropriate for:

- generated commands
- file previews
- generated configuration summaries
- downloadable artifact names
- dry-run output
- logs after an action has run
- final action buttons

They are not appropriate as the only location for:

- required-field errors
- mode-specific validation
- field format guidance
- ordinary contextual help

## Option-Owned Checks

Checks, confirmations, warnings, and preflight commands that apply only to one
option should stay with that option and its local confirmation. Do not move them
into the general output panel unless they are truly global.

Use this rule for option-owned commands, regional/network checks, permissions
checks, destructive confirmations, and other conditional prerequisites. The
output panel should remain focused on artifacts, previews, final commands,
downloads, and logs.

## Artifact Actions

Generated commands, file previews, export artifacts, and preflight snippets need
local actions:

- Put copy/download actions on or next to the exact artifact being copied or
  downloaded.
- Avoid duplicate global and local actions for the same artifact unless they
  serve distinct workflow roles.
- Keep success/failure feedback local to the action that produced it.
- Prefer short-lived local feedback that does not shift layout.

## Status Summary Rules

If a status summary exists:

- Keep it short.
- Separate blockers from warnings and notices.
- Link or visually point to the field that needs action when possible.
- Do not repeat option-specific notices that already sit next to the option.
- Do not show a "success" state while non-blocking warnings still require user
  attention.

On narrow screens, a right-side status panel often moves below the form. That
makes it even less suitable as the primary error location.

## Final Actions

Final actions should make their availability understandable:

- If download is disabled, explain the blocker near the button or field.
- If a command cannot be copied until a target is valid, say which target is
  missing or invalid.
- If a warning does not block download but blocks installation, distinguish
  those two states.

Avoid one generic "not ready" message for actions with different readiness
rules.

## Success Messages

Success messages must be tied to the real action result, not optimistic UI
state:

- "Copied" means the clipboard value was written or otherwise verified.
- "Downloaded" means the browser produced the file and, when relevant, the file
  or archive contents match the current form state.
- "Generated" or "Exported" means the artifact reflects the current fields and
  options.

Do not treat an enabled button, toast, flash message, or console-clean click as
proof that a final action succeeded.
