# Browser Review

Use this reference when a rendered UI can be inspected. Browser review is an
evidence path, not a required runtime mode. It may be local headed browser,
Playwright CLI, Playwright MCP, Browser Use, CI screenshots, or headless
Chromium.

## Contents

- Tooling requirements
- Reuse mature tools
- Minimum evidence set
- Final action evidence
- What to look for
- Long technical content
- Interactive help evidence
- Multilingual forms
- Source-only fallback
- Session discipline

## Tooling Requirements

Fieldcraft does not install browser automation tools. Browser evidence requires
one browser path supplied by the host agent environment:

- Playwright CLI or Playwright MCP.
- Browser Use or another browser-control integration.
- Local Chromium, Chrome, Firefox, or another browser the agent can drive.
- Existing CI screenshots, user screenshots, or saved browser traces.

If the user explicitly asks for screenshots, interaction, or browser evidence,
do not silently downgrade to source-only review. Report the missing browser path
and continue source-only only when the user accepts that fallback.

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

## Final Action Evidence

Treat final actions as successful only after verifying their side effect:

- For copy actions, read the clipboard when available or paste into a temporary
  field and compare the value.
- For download actions, verify the browser download event, downloaded file, or
  archive contents.
- For generate or export actions, confirm the artifact matches the current form
  state and changes when relevant options change.

A toast, flash message, enabled button, clean console, or click handler call is
not enough evidence that the action worked. For secure-context APIs such as the
Clipboard API, test the same origin the user will use when practical; behavior
can differ between `localhost`, LAN HTTP URLs, and HTTPS.

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
- Final action success states match the actual copy, download, generate, export,
  or submit result.

If screenshots show missing fonts, broken assets, or tofu glyphs, mark visual
judgment as lower confidence until the review environment is fixed.

## Long Technical Content

Check mobile and desktop overflow when forms render long technical content such
as URLs, commands, paths, keys, identifiers, package names, or generated
snippets. The page should not become wider than the viewport.

Useful checks include:

- Verify `document.body.scrollWidth <= window.innerWidth` after long content is
  rendered.
- Inspect code blocks, fieldsets, flex/grid children, and unbreakable inline
  text.
- Look for missing `min-width: 0`, wrapping rules, or local horizontal scrolling
  on the content container.

## Interactive Help Evidence

For interactive help or popover-like content, verify that users can move from
the trigger into the panel, select text, click controls, and use keyboard focus
without the panel disappearing.

## Multilingual Forms

For multilingual form-heavy interfaces, check that:

- the default locale is intentional;
- validation text, help text, tooltips, copy feedback, and action labels are
  translated;
- fallback behavior is acceptable;
- language switching does not reset user input unexpectedly;
- generated technical identifiers remain unchanged when they should.

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
