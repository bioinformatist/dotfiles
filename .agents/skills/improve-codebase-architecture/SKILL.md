---
name: improve-codebase-architecture
description: Explicit-only dotfiles architecture review that scans for deepening opportunities and writes a temporary visual report. Use only when the user explicitly invokes improve-codebase-architecture or asks for a dotfiles architecture review.
---

# Improve Codebase Architecture

This repo-local wrapper expects `dotfiles.codex.mattPocockSkills.enable`
to stay enabled for `homePC`; that global skill subset provides the
`$codebase-design` and `$grilling` dependencies used by this workflow.

Surface architectural friction in this dotfiles repo and propose
deepening opportunities: changes that make modules smaller at the
interface and deeper in implementation.

## Process

1. Read `CONTEXT.md` and any relevant ADRs before judging the code.
   Use `$codebase-design` for the architecture vocabulary.
2. Explore with normal Codex tools. Use available multi-agent tooling
   when it is actually present; otherwise inspect the code directly and
   make distinct candidates yourself.
3. Write a self-contained HTML report under the OS temp directory:
   `$TMPDIR` when set, otherwise `/tmp`, using
   `architecture-review-<timestamp>.html`.
4. Tell the user the absolute report path. Open a GUI viewer only when
   the user explicitly asks.
5. For each candidate include files, problem, solution, benefits,
   before/after diagram, and recommendation strength.
6. End with the top recommendation, then ask which candidate the user
   wants to explore.

After the user picks a candidate, use `$grilling` to walk the design
tree with them. Use `$domain-modeling` to update `CONTEXT.md` or offer
an ADR when the conversation produces durable domain terms or decisions.

See [HTML-REPORT.md](HTML-REPORT.md) for the report scaffold, diagram
patterns, and styling guidance.
