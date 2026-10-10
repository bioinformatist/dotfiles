## Engineering scope and verification

These preferences narrow the shared defaults for scope and verification.
Explicit user instructions and explicit project requirements take precedence.

- Implement the requested behavior and its current contracts. Add the
  smallest tests needed to establish correctness of this change. Additional
  regression coverage, compatibility layers, fallbacks, hardening,
  compliance processes, and abstractions require an explicit request or a
  concrete requirement of current supported behavior. Hypothetical future
  needs do not expand the task.

- Before running verification commands, inspect the relevant CI workflows
  and invoked scripts, including their triggers, filters, commands,
  platforms, and coverage. Leave checks that applicable CI will run to CI;
  do not repeat equivalent checks locally as routine preflight.

- Run the smallest necessary local checks for behavior CI does not cover.
  An explicit request for local verification or an explicit project
  requirement to run locally is an exception; identify that requirement
  and keep execution within its scope.

- For a CI failure, inspect the failed job and use a local reproducer only
  when needed to diagnose or verify the correction. Expand or repeat
  verification only for a changed input, an observed failure, or a concrete
  unresolved question.

- Report completed local checks and pending or unavailable CI separately.
  Pending CI does not justify duplicating its work locally or claiming
  verification passed. CI-first verification does not authorize a push,
  workflow dispatch, merge, or deployment.

## Community reuse and upstream contribution

- Before implementing any new feature, research existing community
  solutions. Start with the project's dependencies, then inspect relevant
  alternatives, current documentation, releases, and upstream discussions.
  Reuse existing research after checking that it still applies. Research
  is sufficient when evidence supports a reuse choice or explains the
  remaining need for custom implementation; summarize that decision with
  source links.

- Prefer suitable existing work, considering fit and integration cost.
  When a dependency lacks a capability or appears buggy, inspect its
  documented scope, extension points, contribution guidance, and existing
  issues and pull requests. Distinguish a general upstream improvement
  from product-specific composition. Prefer contributions that improve
  the shared dependency, and build on existing community work.

- When an upstream contribution is appropriate, create or update a
  tracking issue in the product repository that needs the capability,
  before introducing a local workaround. Search for an existing issue
  first. Creating this product issue is part of the normal implementation
  workflow; publishing an upstream issue or pull request is a separate task.

- Preserve the product need and impact, dependency and affected versions,
  relevant documentation and upstream links, observed behavior and any
  available reproduction, confirmed findings and remaining uncertainty,
  why the change belongs upstream, and the proposed contribution.
  Document any temporary implementation, its limits and code location,
  and the condition for replacing it with upstream support. Keep the
  account concise but complete enough to resume without chat history.

- Continue the requested product work with the smallest necessary
  temporary solution and link the tracking issue in the handoff.
  Product-specific glue does not require an upstream-contribution issue.
  Respect explicit read-only or publication limits. If the issue cannot
  be posted, provide the complete draft and mark publication pending.
