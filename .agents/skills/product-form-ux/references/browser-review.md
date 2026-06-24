# Browser Review

Use this reference when a rendered UI can be inspected. Browser review is an
evidence path, not a required runtime mode. It may be local headed browser,
Playwright CLI, Playwright MCP, Browser Use, CI screenshots, or headless
Chromium.

## Reuse Mature Tools

Do not reimplement browser automation or quality auditing in this skill:

- Use Playwright CLI or Playwright MCP for navigation, snapshots, screenshots,
  console logs, network requests, and responsive viewports.
- Use Lighthouse, web-quality skills, or equivalent tools for performance, SEO,
  and broad best-practice audits.
- Use axe or WCAG-focused tooling for deep accessibility audits.

This skill interprets product-form UX evidence. It does not replace those
tools.

## Minimum Evidence Set

When practical, capture:

- Desktop viewport around 1280-1440px wide.
- Mobile viewport around 375-430px wide.
- Initial empty/default state.
- One invalid path.
- One warning-but-recoverable path.
- One successful path.
- Console errors and failed network requests.
- A quick check of invalid fields for `aria-invalid` and `aria-describedby`.

If the app has multiple steps, capture the transition between steps and the
first error state after attempting to continue.

## What To Look For

Check whether:

- Errors appear near the field that caused them.
- The currently focused field and the visible error are close enough to scan
  together.
- Mobile layout preserves the relationship between fields and feedback.
- Side panels remain output-oriented instead of becoming error bins.
- Disabled actions have understandable local reasons.
- Field groups have clear accessible names.
- Tabbing follows the visible flow.
- Browser-rendered text, icons, and fonts actually load.

If screenshots show missing fonts, broken assets, or tofu glyphs, mark visual
judgment as lower confidence until the review environment is fixed.

## Source-Only Fallback

When no browser is available:

- Review source for field state, derived validation, disabled actions, and
  preview/output rendering.
- Mark visual findings as inferred.
- Prefer wording such as "likely" or "source suggests" for layout claims.
- Still report code-certain issues such as errors rendered only in a global
  array, missing accessible error attributes, or disabled buttons without local
  explanatory text.

## Session Discipline

Run browser actions against the same page sequentially. Parallel commands
against the same Playwright session can race and produce misleading state.

Close or detach browser sessions when the review is complete.
