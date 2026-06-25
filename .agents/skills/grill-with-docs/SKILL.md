---
name: grill-with-docs
description: Explicit-only dotfiles design interview that stress-tests a plan while maintaining domain docs. Use only when the user explicitly invokes grill-with-docs or asks to stress-test a dotfiles design with docs.
---

# Grill With Docs

This repo-local wrapper expects `dotfiles.codex.mattPocockSkills.enable`
to stay enabled for `homePC`; that global skill subset provides the
`$grilling` dependency used by this workflow.

Run `$grilling` to stress-test the user's dotfiles design one question
at a time. Keep `$domain-modeling` active as decisions settle:

- Update `CONTEXT.md` when a durable dotfiles domain term is introduced
  or sharpened.
- Offer an ADR only when the decision is hard to reverse, surprising
  without context, and the result of a real tradeoff.
- Keep implementation work out of the grilling loop unless the user
  explicitly asks to proceed.
