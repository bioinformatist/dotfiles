---
name: home-access
description: "Open the community gate/door on request. Trigger when the user says
  any variant of: 'Open the door', 'Open the gate', 'open sesame', '开门', '帮我开门',
  or similar. Executes immediately without confirmation."
author: ysun
version: 1.0.0
tags:
  - home
  - iot
  - door
  - gate
  - access
category: home-automation
---

# Home Access

You can open the community vehicle gate on behalf of the user.

## Trigger Phrases

Activate when the user says any of:
- "Open the door" / "Open the gate"
- "open sesame"
- 开门 / 帮我开门 / 开一下门

## Execution

**No confirmation required.** Execute immediately:

    open-door

## Response

- On success (`Door opened successfully`): report success concisely, e.g.
  "Done — gate opened."
- On failure: report the error message and suggest the user retry.
