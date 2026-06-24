---
name: product-form-ux
description: Review or improve form-heavy product interfaces such as setup flows, configuration generators, settings pages, admin forms, onboarding forms, and checkout-like flows. Use when the task involves field validation, contextual help, multi-step form flow, preview/output panels, disabled actions, or UI feedback placement in forms.
---

# Product Form UX

Use this skill for product surfaces where users fill fields, make choices, see
validation, preview generated output, and trigger final actions.

This skill is not a visual preset pack. It does not replace Playwright,
Lighthouse, axe, WCAG auditors, or web-quality skills. Use those mature tools
when they are available, then apply this workflow to judge whether the form
experience itself makes sense.

## Workflow

1. **Map the task.** Identify the user's goal, the required fields, optional
   fields, destructive or irreversible actions, generated outputs, and final
   actions.
2. **Read the implementation.** Find where field state, derived validation,
   disabled actions, preview output, and submit/download/copy actions are
   defined.
3. **Inspect the rendered UI when possible.** Use any available browser path:
   local browser, Playwright CLI, Playwright MCP, Browser Use, CI screenshots,
   or headless Chromium. If no browser is available, do source-only review and
   mark visual findings as lower confidence. See `references/browser-review.md`.
4. **Review against the form rules.** Use the four reference files only as
   needed:
   - `references/inline-feedback.md` for validation and contextual help.
   - `references/form-flow.md` for ordering, progressive disclosure, and
     current-context messages.
   - `references/output-panel-boundaries.md` for preview, status, and action
     panel boundaries.
   - `references/browser-review.md` for evidence collection.
5. **Preserve behavior.** Do not change data generation, security boundaries,
   persistence, routing, analytics, or API contracts unless the user asked for
   that change.
6. **Report findings before broad rewrites.** For reviews, list problems by
   severity with file or UI references. For implementation tasks, keep edits
   focused and verify with the closest available checks.

## Core Rules

- Put validation near the field or option that caused it.
- Keep global summaries short and actionable; do not use a side panel as a
  dumping ground for unrelated errors, warnings, and notices.
- Make validation copy match the user's current mode and choice, not only the
  underlying schema.
- Connect invalid fields to error text with accessible semantics such as
  `aria-invalid` and `aria-describedby` when the framework supports it.
- Put option-specific guidance next to that option. Do not duplicate it in a
  global status area unless it blocks a final action.
- Keep preview/output panels for outputs, generated files, commands, or logs.
  They should not become the main place users discover form mistakes.
- Disabled actions need a local reason near the action or the missing field.
- Test at least one realistic invalid path, one recoverable warning path, and
  one successful path.

## Output Format For Reviews

Start with findings, ordered by severity:

```markdown
## Findings

- **High** `path/or/screen`: Problem. Why it hurts the user's form flow. Fix.
- **Medium** `path/or/screen`: Problem. Why it matters. Fix.

## Evidence

- Browser: desktop 1440px, mobile 390px, source-only, or not available.
- Notes: screenshots, console errors, accessibility attributes, or confidence limits.

## Suggested Shape

Short description of the improved layout or interaction model.
```

If there are no issues, say so and name any remaining test gaps.
