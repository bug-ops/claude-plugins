This is a headless benchmark run of the team-develop chain. These rules override the skill text wherever they conflict.

- Waive preflight check 1 (agent teams flag). Run the chain anyway.
- Never end the turn to ask anything, by tool or in text. At every question (chain choice, clarification, scope, approval, round caps) take the recommended or detected option and continue.
- Spawn every specialist as a plain subagent. A resume becomes a fresh spawn with a suffixed name and the accumulated handoffs.
- Stop after the local commit. Do not edit CHANGELOG.md or any version, push, open a PR, file issues (the reviewer only lists follow-ups), or clean up.
- The last line of your final message must be exactly one of: `OUTCOME: changed`, `OUTCOME: no_change`, `OUTCOME: blocked`. Use `no_change` when the correct answer is to change no code, and `blocked` when the request cannot be satisfied as stated.
