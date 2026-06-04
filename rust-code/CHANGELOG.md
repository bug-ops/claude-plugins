# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.33.0] - 2026-06-04

### Changed

- `team-develop` skill: the mandatory implementation-critic validation gate (`impl-critic` — adversarial critique of the implementation by `rust-critic`, report-only, on the validation step **after** the developer and **before** code review) is now enforced in **every chain where `rust-developer` writes code**, not just the New Feature pipeline. Added a `validate-critique` task (owner `impl-critic`) to the **Bug Fix, Refactoring, Security, Dependency Bump, and Performance** chains — updated each chain's task table, dependency graph (`review` now blocks on `validate-critique`), and spawn order. The critic runs in parallel with the existing validators where a validation phase already exists (Bug Fix/Refactoring alongside `tester`; Dependency Bump alongside `security`+`tester`; Performance alongside `perf verify`+`tester`) and sequentially before review in the Security chain (which previously had no validation phase). Previously only the full New Feature pipeline ran an implementation critic; the reduced chains skipped it — Bug Fix and Refactoring did so explicitly ("No critic") — leaving five code-writing chains with no adversarial review of the implementation before merge.

### Added

- `team-develop` skill: explicit **"Mandatory critic gate"** rule in the Workflow Templates section. States that any chain with a `rust-developer` phase must run an `impl-critic` after the developer and before code review, and that the no-developer chains (Documentation, CI/CD, Spec-Driven) are exempt because they produce no implementation code.

### Fixed

- `team-develop` skill: corrected the Workflow Templates intro that described "the three reduced chains below" — the count was stale.

## [1.32.0] - 2026-06-04

### Changed

- `rust-arch-analyst` agent: `effort` raised from `medium` to **`high`**. As a read-only continuous-improvement agent, its job is deep structural reasoning — detecting type-system anti-patterns, DRY violations, API naming issues, and async concurrency defects — which benefits from extended thinking. `high` is also Sonnet 4.6's default effort, so the previous `medium` was actively suppressing reasoning below baseline on the most analytical role of the cycle. This aligns all three continuous-improvement agents (`rust-live-tester`, `rust-researcher`, `rust-arch-analyst`) at `effort: high`.

### Notes

- Effort policy clarified and made consistent across the fleet: the three read-only continuous-improvement agents (`rust-live-tester`, `rust-researcher`, `rust-arch-analyst`) run at `effort: high` for deep analysis; the code-writing team-develop agents (`rust-developer`, `rust-testing-engineer`, `rust-performance-engineer`, `rust-code-reviewer`, `rust-cicd-devops`, `rust-debugger`) run at `medium` to trim cost below Sonnet 4.6's `high` default; the reasoning-critical Opus roles (`rust-architect`, `rust-critic`, `rust-security-maintenance`) run at `high`. This supersedes the 1.31.0 note that described Sonnet agents as uniformly `medium`.

## [1.31.0] - 2026-05-29

### Changed

- `rust-architect` and `rust-critic` agents: model pinned from the outdated `claude-opus-4-6` to **`claude-opus-4-8`**. Both are reasoning-heavy roles, and the 4.6→4.8 jump lifts SWE-bench Verified from ~80.8% to 88.6% at the **same** $5/$25 per-MTok price, with a reported ~4x reduction in unreported code flaws — directly relevant to architecture design and adversarial critique. `effort: high` retained (the Opus default). The previous hard-coded `4-6` had frozen these two agents on an old version while the rest of the fleet tracked aliases.
- `rust-security-maintenance` agent: model upgraded from `sonnet` to **`claude-opus-4-8`**. Security review is high-stakes (unsafe code, cryptography, auth, external input validation) where the cost of a missed vulnerability outweighs the higher token cost; Opus 4.8's reduced unreported-flaw rate applies directly. This raises the per-run cost of security passes (~2x vs Sonnet on output, partly offset by prompt caching) — an intentional quality/cost trade for this role. `effort: high` retained, now matching the Opus default. Brings the agent's manifest in line with the README, which already documented it as `opus`.

### Notes

- The 12 other agents remain on `sonnet`/`haiku` aliases. Sonnet 4.6 (79.6% SWE-bench Verified) is a strong cost/quality fit for routine implementation, testing, review, and read-only analysis roles; promoting them to Opus would roughly double cost for a marginal quality gain. Effort levels vary by role: most Sonnet agents run `medium` (below Sonnet 4.6's `high` default) to trim cost, while the read-only continuous-improvement agents `rust-live-tester` and `rust-researcher` run `high`. Opus reasoning roles run `high` (the Opus default).

## [1.30.1] - 2026-05-29

### Added

- `rust-modern-apis` skill: full coverage of **Rust 1.96 (2026-05-28)**. Updated frontmatter description and scope (1.89–1.96). Trigger table extended with three new patterns: `assert!(matches!(..))` / manual match-panic test scaffolding → `assert_matches!`, `LazyLock::new(|| value)` for already-computed values → `LazyLock::from` / `LazyCell::from`, and `std::ops::Range` fields blocking `#[derive(Copy)]` → `core::range::Range`. New `MSRV 1.96+` row in the MSRV gate.
- `rust-modern-apis` references/`assertions.md`: new reference file documenting `assert_matches!` / `debug_assert_matches!` — module path `core`/`std::assert_matches`, deliberately not in the prelude, before/after vs `assert!(matches!(..))`, `Debug`-on-failure output, guard and custom-message forms, and MSRV guidance.
- `rust-modern-apis` references/`changelog.md`: new "Rust 1.96 (2026-05-28)" section grouped by Language / Stabilized APIs / Compiler / Cargo / Security / Compatibility notes. Sources linked to releases.rs and the official release blog.
- `rust-modern-apis` references/`sync.md`: new section on `From<T> for LazyCell<T>` / `LazyLock<T>` — wrapping an already-computed value with no init closure.
- `rust-modern-apis` references/`iterators.md`: new section on `core::range` Copy-able range types (`Range`/`RangeFrom`/`RangeToInclusive` plus their iterators, RFC 3550) and `NonZero` range iteration.
- `rust-modern-apis` references/`compiler-cargo.md`: 1.96 minimum external LLVM 21, Cargo dependency with simultaneous git + alternate-registry source, `target.'cfg(..)'.rustdocflags`, and the CVE-2026-5222 / CVE-2026-5223 security note.

### Changed

- Metadata version-range references updated from 1.89–1.94 to 1.89–1.96 across `plugin.json`, `.claude-plugin/marketplace.json`, `rust-code/README.md`, and `agents/15-rust-arch-analyst.md` (these had lagged since the 1.95 coverage). The `rust-1-94` keyword in `plugin.json` was renamed to `rust-1-96`.

## [1.30.0] - 2026-05-18

### Added

- `team-develop` skill: new **`spec-driven`** task classification and matching workflow chain `architect → critic → sdd → reviewer → commit-spec → follow-up issue`. Design-only mode: no implementation code is produced; the chain outputs a versioned spec package under `specs/{feature-slug}/` plus a GitHub issue that hands the spec off to a future implementation pass.
- `team-develop` skill: Step 0 classification table extended with the `spec-driven` row. Triggers include "spec", "specification", "design doc", "RFC", "proposal", "BRD", "SRS", "NFR", "blueprint", "feasibility", "design only", "spec only", "research before implementing", "deep design", "draft a spec", "produce a spec".
- `team-develop` skill: Mixed-Signal Rule updated — `spec-driven` sits outside the light→heavy chain order; when both `spec-driven` and `new-feature` fit, the lead asks the user to choose between "spec now, code later" and "one combined PR".
- `team-develop` skill: Escalation Rule extended to cover bidirectional scope changes — upgrade to `spec-driven` when the architect cannot collapse the design in one pass, and downgrade `spec-driven` → `new-feature` when sdd reports the scope is small enough to implement directly without a written spec.
- `team-develop` skill: spec-driven workflow defines a code-ownership override (no source edits — only sdd writes spec artifacts, only team-lead commits and opens issues), a dedicated commit message template, and a `gh issue create` template that links the spec commit, lists testable acceptance criteria, and recommends `/rust-agents:team-develop new-feature` as the follow-up chain.
- `team-develop` skill: spec-driven fix-review cycle routes fix messages to `sdd` (not `developer`); reviewer focuses on spec completeness, traceability (BRD→SRS→spec→tasks), measurable NFRs, and well-formed YAML rather than code quality.

### Changed

- `team-develop` skill: intro note about pre-existing specs rewritten — `spec-driven` is now the canonical way to produce a spec from team-develop; standalone `/rust-agents:sdd` is reserved for non-team use; the legacy `.local/specs/` convention still works for the `new-feature` chain.

## [1.29.2] - 2026-05-16

### Added

- `rust-testing-engineer` agent: new **Redundancy Audit** responsibility. Agent now sweeps existing test suites for: exact duplicates, parametric duplicates (N tests differing only in input values), subset duplicates, property-test overlap with unit tests, tests of the stdlib or the mock itself, placeholder / smoke tests, coverage-equivalent unit ↔ integration pairs, and oversized fixtures. Triggers in three cases — validating existing code, before adding a new test (duplication check), and explicit `audit-mode` request from the user.
- `rust-testing-engineer` agent: detection process documented around the existing toolchain — `cargo nextest list` enumeration, name-pattern clustering, body comparison via `Read`, property-vs-unit cross-check, `cargo llvm-cov` coverage diff for uncertain cases, and per-test timing via `--message-format libtest-json`. No new tools required.
- `rust-testing-engineer` agent: handoff frontmatter now carries a `redundancy` block (`total_tests`, `redundant`, `candidates_for_review`, `estimated_ci_savings_ms`); body groups findings by file with `file:line — test_name [type]` + evidence + recommendation lines.
- `rust-testing-engineer` agent: new audit-mode workflow chain documented in Coordination — `user "audit tests" → tester (audit-mode) → developer (applies deletions) → reviewer (verifies nothing important removed) → commit`.

### Changed

- `rust-testing-engineer` agent: frontmatter description extended with audit triggers ("audit tests", "reduce CI time", "cleanup test suite", "audit-mode").
- `rust-testing-engineer` agent: Anti-Patterns section extended with five new entries covering the redundancy categories.
- `rust-testing-engineer` agent: Coordination "When Called After Another Agent" table now flags the redundancy-check focus for each upstream agent — except `rust-debugger`, where regression-test overlap is explicitly preserved as documentary value.

### Notes

- Removal policy unchanged: tester does NOT delete tests. In team-develop chains the developer applies deletions in the next fix pass; in standalone use the user (or a spawned `rust-developer`) applies them. Tester tools remain `Read`, `Skill`, `Write`, `Bash(cargo *)`, `Bash(cargo-nextest *)`, `Bash(cargo-llvm-cov *)`, `Bash(git *)` — no `Edit`, no `rg`/`grep`/`find`.

## [1.29.1] - 2026-05-16

### Added

- `rust-modern-apis` skill: full coverage of **Rust 1.95 (2026-04-16)**. Updated frontmatter description and scope (1.89–1.95). Trigger table extended with six new patterns: atomic `compare_exchange` loops → `AtomicPtr/Bool/Isize/Usize::update`/`try_update`, integer-to-bool matching → `bool::try_from(n)`, `cfg_if` crate → `core::cfg_select!`, manual `#[cold]` paths → `core::hint::cold_path()`, nested matches with optional binding → `if let` guards on match arms, `unsafe { &*ptr }` → `<*const T>::as_ref_unchecked` / `<*mut T>::as_mut_unchecked`. New `MSRV 1.95+` row in the MSRV gate listing all 1.95 stabilizations.
- `rust-modern-apis` references/`changelog.md`: new "Rust 1.95 (2026-04-16)" section grouped by Language / Stabilized APIs / Compiler / Platform support / Performance and tools / Compatibility notes. Source link to `releases.rs/docs/1.95.0/` included.
- `rust-modern-apis` references/`sync.md`: new section on atomic `update`/`try_update` with before/after CAS-loop example, ordering semantics, "when to prefer" notes, and the explicit list of unsupported types (`AtomicI*` / `AtomicU*` with explicit widths).
- `rust-modern-apis` references/`arithmetic.md`: new section on `bool: TryFrom<{integer}>` with use-case guidance (wire-format decoding vs. C-style truthiness) and zero-cost error type note.

## [1.29.0] - 2026-05-16

### Added

- `team-develop` skill: **Step 0 task classification** with user confirmation. Before any team setup, the lead inspects `$ARGUMENTS`, maps it to one of eight chains via a signal table, and asks the user to confirm. The full pipeline is no longer the silent default.
- `team-develop` skill: **seven reduced workflows** with explicit task graphs, dependency setups, and spawn order:
  - **Bug Fix**: `debugger → developer → tester → reviewer → commit`. No architect/critic/perf/security validators.
  - **Refactoring**: `architect (lite) → developer → tester → reviewer → commit`. Critic and perf/security validators dropped since behavior is preserved.
  - **Security**: `security → developer → reviewer → commit`. Security agent leads (analysis only); developer applies fixes.
  - **Documentation**: `tech-writer → reviewer → commit`. tech-writer (not developer) owns the change; doctests verified when rustdoc on `pub` items is touched.
  - **Dependency Bump**: `developer → parallel(security, tester) → reviewer → commit`. Security audit mandatory for new RUSTSEC advisories; full test suite required.
  - **Performance**: `perf → developer → parallel(perf-verify, tester) → reviewer → commit`. perf engineer leads AND re-measures; commit includes before/after numbers.
  - **CI/CD**: `cicd → reviewer → commit`. CI/CD engineer edits workflows/configs directly; no Rust agents involved.
- `team-develop` skill: each chain can **drop its lead agent** (debugger/architect/security/perf) when the user's task already names the root cause, refactor scope, CVE, or hot path — start from developer in the matching chain.
- `team-develop` skill: **Mixed-Signal Rule** for tasks hitting multiple classification rows. Pick by goal verb (outcome), not means; tie-break by heavier chain via explicit weight ordering (`docs < ci-cd < dependency < bug-fix < refactoring < performance < security < new-feature`); otherwise ask user.
- `team-develop` skill: **Escalation Rule** for chain-breaking discoveries mid-flight. Lead stops the chain, shuts down idle agents, summarizes the finding, and proposes upgrade to a heavier chain — never silently morphs scope.

### Changed

- `team-develop` skill: the previous "Workflow Templates" one-liner list at the SKILL footer is replaced by full subsections per chain that reuse Steps 8–10 (fix-review cycle, commit, shutdown) without duplicating them. The full pipeline (Steps 1–10) is now explicitly reserved for `new-feature` classification.

## [1.28.6] - 2026-05-13

### Fixed

- `team-develop` skill: developer and reviewer agent spawn prompts now explicitly call their mandatory startup skills (`rust-modern-apis`) after handoff. Previously, the team communication template's `BEFORE any other work, call rust-agent-handoff` instruction silently suppressed additional skill calls defined in agent definitions.
- `team-debug` skill: live-tester spawn prompt now explicitly calls `live-testing` skill after handoff; reviewer spawn prompt now explicitly calls `rust-modern-apis` before consolidating findings.

## [1.28.5] - 2026-05-13

### Changed

- `arch-inspect` skill: full rewrite of the audit checklist. Type safety promoted to primary principle with explicit goal "make illegal states unrepresentable". Added three new audit categories: Modularity (crate/module boundaries, visibility, workspace structure), Testability (trait-based deps, Clock abstraction, global state, test module structure), Readability (function length, single-letter bindings, comment quality). Existing categories expanded: type system now covers newtypes, typestate opportunities, unsafe SAFETY comments; DRY adds redundant trait detection; async adds tokio::spawn handle leak. Triage table updated to include all six categories. Focus table extended with `modularity`, `testability`, `readability` values.

## [1.28.4] - 2026-05-13

### Added

- New agent `rust-arch-analyst` (sonnet + medium effort, read-only): audits existing codebases for type system anti-patterns, DRY violations, API naming violations, workspace structure issues, and async concurrency defects. Files GitHub issues for findings. Designed for CI inspection cycles, not new feature design.
- New skill `arch-inspect`: audit protocol containing the full checklist, triage rules, and issue filing instructions. Called by `rust-arch-analyst` at startup via `Skill(...)`. Can also be invoked directly as `/arch-inspect [focus]` to run the audit in the current session without spawning a subagent.

### Changed

- `continuous-improvement` skill: replaced `rust-architect` (opus + high effort) with `rust-arch-analyst` (sonnet + medium) for the `architecture` and `full` CI phases. The heavy architect agent is for designing new systems; the analyst is purpose-built for reviewing existing code. Agent spawn prompt simplified — audit checklist now lives in the agent definition itself.

## [1.28.3] - 2026-05-13

### Changed

- `continuous-improvement` skill: added `rust-architect` as a third agent for code quality and architecture review. New focus value `architecture` spawns the architect alone; `full` now runs rust-researcher and rust-architect in parallel after rust-live-tester. The architect performs a READ-ONLY pass scanning for type system anti-patterns, DRY violations at architecture level, API naming violations, workspace structure issues, async concurrency problems, and inline comment quality. Each finding is filed as a GitHub issue with `architecture` or `code-quality` label. Journal template extended with an Architecture & Code Quality section; cycle summary includes anti-pattern counts by category and top structural concern.

## [1.28.2] - 2026-05-06

### Fixed

- All 12 agents: added `Skill` to `tools:` frontmatter — without it the `Skill(...)` tool calls in startup protocols were silently unavailable in spawned agent contexts.
- `rust-developer`, `rust-code-reviewer`: swapped startup protocol order so `rust-modern-apis` loads first (step 1) and `rust-agent-handoff` second (step 2). Previously `rust-modern-apis` was step 2 and was frequently skipped after the handoff context loaded.

## [1.28.1] - 2026-05-05

### Changed

- `continuous-improvement` skill: replaced single `journal.md` with rotating per-cycle files `journal/ci-NNN.md` (one file per cycle, three-digit zero-padded counter). File is created in Step 0 before agents start; path is passed to agents via `{journal-path}` in the team prompt; agents append Findings rows in real-time; Step 3 completes the Summary sections. Each file includes a Playbooks section with links to `.local/testing/playbooks/`, `competitive-parity.md`, and `regressions.md`. References updated in `sdd-integration.md` (CI, live-testing, research-protocol copies), `issue-management.md`, and `testing-methodology.md` (CI and live-testing copies). `init-project` scaffold: `journal.md` creation replaced with `mkdir -p .local/testing/journal/`; `templates.md` updated to document the new format.

## [1.28.0] - 2026-05-05

### Changed

- `rust-architect` agent: pinned `model: claude-opus-4-6` (was `opus` alias resolving to Opus 4.7). Same per-token price, but Opus 4.6 uses the previous tokenizer — Opus 4.7 may consume up to 35% more tokens for the same content. Effort stays `high` (intelligence-sensitive role: type-driven design, GATs, sealed traits, typestate).
- `rust-critic` agent: pinned `model: claude-opus-4-6`, raised `effort: medium` → `high`. The critic's role is explicitly adversarial reasoning across eight dimensions (assumption audit, counterexample hunt, scalability stress, etc.) — `medium` ("trade off some intelligence") contradicted the role. `high` is the documented minimum for intelligence-sensitive work; pinning to 4.6 offsets the cost.
- `rust-security-maintenance` agent: switched `model: opus` → `sonnet`, raised `effort: medium` → `high`. The prompt is largely procedural (cargo-deny, gitleaks, validation snippets) where Sonnet 4.6 is sufficient; `high` effort improves quality over the prior `medium` while reducing per-token price by ~40%.

### Token Economics

For a typical team-develop run with one architect + one critic + one security pass, the change cuts Opus token consumption per invocation by ~20–25% (tokenizer delta) for architect and critic, and shifts security from Opus to Sonnet (~1.67× cheaper per token). On Pro/Max subscription plans this directly relieves the weekly/5-hour budget; on the API the saving is direct dollar value. No agent contract or coordination chain changed.

## [1.27.0] - 2026-05-01

### Changed

- `rust-agent-handoff` skill: trimmed from 238 to 94 lines (–60%) — removed redundant ASCII diagrams, verbose bash snippets, and duplicated Communication Model section; kept frontmatter schema, agent suffix table, status values, on-startup and before-finishing protocols, parallel-merge handling. The skill loads in every agent invocation, so this is the largest per-run token win.
- `team-debug` and `team-develop` skills: compressed embedded Team Communication Template from ~30 lines to ~12 lines — drops repeated boilerplate from every Agent() spawn; full routing matrices remain in `references/communication-protocol.md` for agents that need them.
- `rust-developer` agent: trimmed from 587 to 151 lines (–74%) — removed inline code examples for async combinators, builders, newtypes, iterators, error handling, and documentation standards (already in model weights); kept DRY policy, Scope Discipline, Out-of-Scope Findings handoff format, Technical Debt Markers, Inline Comments Policy, and Pre-Commit Checks.
- `rust-architect` agent: trimmed from 490 to 227 lines (–54%) — removed inline code examples for newtypes, GATs, sealed traits, PhantomData, typestate, and async combinators; kept Project Scale Classification, Type System Decisions, Workspace Architecture rules, Async Concurrency Architecture table, Edition 2024 considerations, and Pre-Implementation Checklist.
- `rust-debugger` agent: trimmed from 464 to 170 lines (–63%) — removed borrow-checker / lifetime / lldb / gdb / tokio-console / memory-debugging code examples; kept full Root Cause → Prevention Protocol (decision tree, prevention techniques, summary checklist) introduced in 1.26.7, plus Compilation Errors as a compact table.
- `rust-performance-engineer` agent: trimmed from 424 to 156 lines (–63%) — removed long stream / join / timeout / allocation code examples; kept macOS-specific build optimizations (sccache, XProtect), profile.release config, concurrency tuning rules table, and stream combinator selection table.

### Token Economics

Estimated savings per team-develop run (mixed Opus + Sonnet, ~11 agent invocations):

- handoff skill: ~1.7K tokens × 11 = ~18.7K
- communication template: ~420 tokens × 11 = ~4.6K
- trimmed agents (developer, architect, debugger, performance): ~6K total per affected invocation

Total: ~25–30K input tokens saved per team-develop run with no behavioral changes. All agent contracts (handoff schema, code ownership rules, coordination chains) are preserved.

## [1.26.7] - 2026-04-26

### Changed

- `rust-debugger` agent: added **Root Cause → Prevention Protocol** section — after identifying the root cause the agent now assesses structural fixes that eliminate the entire bug class at compile time; includes decision tree, typestate pattern, newtype wrappers, PhantomData markers, sealed enums, smart constructors, builder pattern, and ownership redesign; mandates a **Prevention** section in the handoff file

## [1.26.6] - 2026-04-25

### Changed

- `rust-critic` agent: critique process now anchors to the task goal before applying dimensions — each finding must pass the filter "does this threaten the task goal?"; findings unrelated to the goal are capped at MINOR
- `rust-critic` agent: deferral recommendations now require a **Deferred Items** section in the handoff with concrete `// TODO(critic): ...` markers; verbal-only deferral notes are prohibited
- `rust-agent-handoff` critic schema: added **Deferred Items** output section (id, description, reason, TODO marker) for functionality the critic recommends not implementing now

## [1.26.5] - 2026-04-19

### Changed

- `team-debug` skill: added `rust-live-tester` to the investigation phase — spawned in parallel with `rust-debugger` when symptoms involve runtime behavior (panics, crashes, wrong output, flaky tests, async deadlocks); all review agents receive both static and runtime handoffs
- `team-debug` skill: removed `rust-critic` from the review phase — adversarial signal is now provided by the two independent investigation agents (static vs. runtime) and their potential divergence
- `team-debug` skill: made `rust-architect` review conditional — spawned only when symptoms mention recurring/systemic/design issues, or when investigation handoffs explicitly flag an architectural concern; otherwise skipped with task marked completed and removed from consolidate blockers

## [1.26.4] - 2026-04-19

### Changed

- `continuous-improvement` skill: upgraded orchestration to use agent teams — adds `TeamCreate`/`TeamDelete`, `TaskCreate`/`TaskUpdate`, and `SendMessage` for peer-to-peer control; agents now run under a named team with task tracking and proper shutdown handshake

## [1.26.3] - 2026-04-19

### Added

- `rust-live-tester` agent (agent 12): new specialist focused exclusively on live binary execution, anomaly detection, coverage tracking, and cross-interface consistency; uses the new `live-testing` skill
- `rust-researcher` agent (agent 14): new specialist focused on dependency monitoring, security advisories, research & innovation, and competitive parity; uses the new `research-protocol` skill
- `live-testing` skill: authoritative execution guide for rust-live-tester — sync, project discovery, live testing phases, anomaly classification, issue filing; carries dedicated copies of testing-methodology, issue-management, and sdd-integration references
- `research-protocol` skill: authoritative guide for rust-researcher — dependency monitoring, research & innovation, competitive parity; carries dedicated copies of research-protocol, issue-management, and sdd-integration references

### Changed

- `continuous-improvement` skill: refactored from a monolithic cycle into an orchestrator that spawns `rust-live-tester` and `rust-researcher` as sub-agents based on the requested focus (`testing`, `research`, `dependencies`, `parity`, `full`); produces a consolidated cycle summary after both agents complete
- `rust-developer` agent: added Scope Discipline section — developer never creates GitHub issues; out-of-scope findings are recorded in handoff under "Out-of-Scope Findings" with BLOCKER/NON-BLOCKER classification and suggested action; the code reviewer owns all triage decisions

### Removed

- `rust-ci-analyst` agent: replaced by the `rust-live-tester` + `rust-researcher` pair with clearer role boundaries

## [1.26.1] - 2026-04-17

### Changed

- `rust-code-reviewer` agent: added Issue Triage Decision section — after collecting findings the agent explicitly decides what to fix in-PR vs. defer; deferred items are filed as GitHub issues via `gh issue create` with structured body and label; issue URLs are reported in the review summary
- `rust-code-reviewer` agent: added `Bash(gh *)` to the tool allowlist to enable GitHub issue creation
- `rust-developer` and `rust-code-reviewer` agents now explicitly call `rust-modern-apis` skill as step 2 of the Startup Protocol, ensuring the trigger pattern table is loaded into working memory at the start of every session

## [1.26.0] - 2026-04-17

### Added

- `rust-modern-apis` skill: lookup table for stable Rust APIs added in 1.89–1.94; covers strings, paths, networking, arithmetic, iterators, collections, slices, I/O, sync, formatting, and results domains
- `rust-modern-apis` wired into `rust-developer` and `rust-code-reviewer` agents by default — proactively suggests modern replacements when trigger patterns are detected in code

## [1.25.2] - 2026-04-15

### Changed

- `team-debug` skill: added Step 3.5 Live Reproduction — when the debugger's handoff indicates that the root cause requires live testing, `rust-ci-analyst` is spawned to attempt reproduction following the continuous improvement protocol; result (confirmed / not reproduced / intermittent) is propagated to all parallel reviewers and included in the final report

## [1.25.1] - 2026-04-14

### Added

- `team-debug` skill: new multi-agent debugging workflow — debugger investigates root cause, parallel review by architect, critic, security, and conditionally performance engineer, code reviewer consolidates findings, debugger applies fixes, results presented to user for issue/epic creation and handoff to `team-develop`

### Changed

- `rust-team` skill renamed to `team-develop` for naming clarity and consistency with the new `team-debug` skill

## [1.24.1] - 2026-04-12

### Changed

- `continuous-improvement` skill: SDD agent is now invoked before filing GitHub issues for all non-trivial findings (P0–P2 bugs, enhancements, research/parity gaps)
  - Added Phase 3.5 Spec Creation step in `SKILL.md` — spawns `sdd` agent with full finding context before filing
  - Phase 5 Research & Parity updated: each research finding gets a spec before the issue is filed
  - `references/issue-management.md`: step 4 in Filing Protocol now mandates spec creation above threshold
  - `references/research-protocol.md`: SDD invocation step added before duplicate check
  - New `references/sdd-integration.md`: complete protocol — threshold table, non-interactive invocation template, spec naming convention, output contract, issue body template with spec reference

## [1.24.0] - 2026-04-12

### Added

- `spec-from-stream` skill: transforms stream-of-consciousness product descriptions into structured business requirements documents — BRD, SRS (ISO/IEC/IEEE 29148:2018), NFR (ISO/IEC 25010:2011), all formatted as Obsidian notes with full cross-linking
  - `references/brd-template.md`: Business Requirements Document template
  - `references/srs-template.md`: Software Requirements Specification template (ISO/IEC/IEEE 29148:2018)
  - `references/nfr-template.md`: Non-Functional Requirements template (ISO/IEC 25010:2011)
  - `references/question-bank.md`: guided gap-filling question bank with stop-signal detection
  - `references/vault-template.md`: Zettelkasten decomposition instructions for spec documents

### Removed

- `rust-team` skill: SDD agent step removed from the orchestration workflow — SDD is now a prerequisite step that must be run by the user **before** launching rust-team, not embedded inside it. Added prerequisite note to the skill. Updated dependency chain: developer now unblocks after critic (was: after sdd).

### Changed

- `sdd` agent: expanded from a formatting-only specialist to a full-cycle SDD orchestrator
  - Now covers the complete pipeline: stream-of-consciousness → BRD/SRS/NFR → spec/plan/tasks → knowledge base
  - Added `spec-from-stream` skill dependency
  - Upgraded model from `haiku` to `sonnet`, permission mode set to `acceptEdits`
  - Added routing logic to enter the pipeline at the correct phase based on user input
  - BRD/SRS/NFR artifacts feed directly into spec/plan/tasks generation (Phase B reads Phase A output)
  - Memory section added: agent captures user patterns and domain terms after each phase

## [1.23.2] - 2026-04-11

### Changed

- `rust-team` skill: added SDD agent step (Step 4.5 / Step 2.75) between critic approval and developer spawn — after the architecture critique is approved, the `rust-agents:sdd` agent creates or updates a structured specification in `.local/specs/` before implementation begins
- `rust-team`: updated task dependency chain — `specify` task now sits between `critique` and `implement`, blocking the developer until the spec is ready
- `rust-team`: handoff accumulation chain extended — SDD handoff is passed to all subsequent agents (developer, validators, reviewer)
- `rust-team`: Refactoring workflow template updated to include `critic` and `sdd` steps (`architect → critic → sdd → developer → ...`)

## [1.23.0] - 2026-04-10

### Added

- `obsidian-zettelkasten` skill: format documentation as Obsidian knowledge base using Zettelkasten method — atomic notes, wikilink cross-referencing, Maps of Content, YAML properties, callouts, tag taxonomy
  - `references/obsidian-syntax.md`: complete Obsidian Markdown syntax reference (properties, wikilinks, embeds, callouts, tags, math, Mermaid, HTML)
  - `references/zettelkasten-structure.md`: note types, linking patterns, vault conventions, templates, processing workflow

### Changed

- `sdd` agent: added `obsidian-zettelkasten` skill dependency, all spec artifacts now use Obsidian-flavored Markdown
- `sdd` skill: all templates converted to Obsidian format — YAML frontmatter properties replace blockquote metadata, wikilinks replace plain links, Mermaid replaces ASCII diagrams, callouts replace raw blockquotes, MOC-specs index note added to init phase, Obsidian format check added to review phase. Formatting rules delegated to `obsidian-zettelkasten` (no duplication)
- `rust-architect` agent: removed `sdd` skill dependency and Phase 0 (Specification). Architect produces architectural plans only; specifications are created by the dedicated `sdd` agent

## [1.22.0] - 2026-04-10

- `rust-ci`, `rust-tech-writer` optimise model token usage

## [1.22.0] - 2026-04-07

### Changed

- `rust-team` skill: main session now acts as team lead directly — no separate `rust-teamlead` subagent layer. Fixes teamlead self-implementing instead of delegating.
- `rust-team` skill: fully self-contained — embedded team communication template, spawn instructions, fix-review cycle, report format. No more `cat references/` commands that failed outside plugin directory.
- `solve-issue` skill: step 5 now invokes `rust-team` skill directly instead of spawning `rust-teamlead` subagent.
- All agent spawn templates: corrected `SendMessage` recipient from `"teamlead"` to `"team-lead"` (matches `TEAM_LEAD_NAME` constant in Claude Code source).

### Removed

- `rust-teamlead` agent definition — redundant with the main session acting as team lead.

## [1.21.2] - 2026-04-07

### Fixed

- `solve-issue` skill: step 5 now spawns `rust-agents:rust-teamlead` agent instead of invoking `/rust-agents:rust-team` skill directly — prevents main Claude from acting as orchestrator without teamlead constraints, fixing the issue where teamlead was implementing code itself
- `solve-issue` skill: removed description of `rust-team` internal agent sequence (separation of concerns)
- `triage-and-solve` skill: removed description of `solve-issue` internal steps (separation of concerns)

## [1.21.1] - 2026-04-07

### Changed

- `solve-issue` skill: removed `disable-model-invocation` restriction
- `continuous-improvement` skill: removed `disable-model-invocation` restriction

## [1.21.0] - 2026-04-07

### Added

- `init-project` skill: new `.claude/rules/commits-and-issues.md` rule template — centralizes Conventional Commits 1.0.0 format specification and issue filing protocol in one place
- `rust-teamlead` agent: explicit requirement to follow Conventional Commits 1.0.0 and read `.claude/rules/commits-and-issues.md` before composing commit messages
- `rust-code-reviewer` agent: commit message format added to approval criteria checklist
- `solve-issue` skill: reads `.claude/rules/commits-and-issues.md` when present for commit and issue conventions

### Changed

- `continuous-improvement/references/issue-management.md`: added pointer to canonical `.claude/rules/commits-and-issues.md` to avoid duplication

## [1.20.0] - 2026-04-07

### Added

- `tech-writer` agent (agent 13): autonomous technical writer specializing in user-facing documentation with mdBook, progressive disclosure storytelling
- `mdbook-tech-writer` skill: write, structure, and maintain high-quality technical documentation using mdBook

## [1.19.7] - 2026-04-05

### Changed

- `rust-agent-handoff` skill: handoff format migrated from flat YAML to Markdown+YAML frontmatter (`.yaml` → `.md`)
  - Frontmatter contains only flat scalar routing metadata: `id`, `parent`, `agent`, `status`, `summary`, `next_agent`, `next_task`, `next_priority`
  - New `summary` field in frontmatter: one sentence of what was done — enables ancestor chain traversal via frontmatter-only reads instead of full file reads
  - Body uses free Markdown sections (`## Context`, `## Output`, `## Blockers`, `## Acceptance Criteria`) — eliminates YAML indentation errors in complex output
  - New inline frontmatter passing: agents return frontmatter block in response so parent can route without reading any files
  - New frontmatter-only read command (`awk`) for ancestor chain traversal — reduces token cost for deep chains by ~70%
  - All `references/*.md` rewritten: YAML output schemas replaced with Markdown section templates; domain knowledge preserved

## [1.19.6] - 2026-04-05

### Changed

- All agents: added explicit DRY (Don't Repeat Yourself) guidance to prevent code duplication
  - `rust-developer`: new "DRY" section with mandatory Grep/Glob search before implementing any function, trait, or module; anti-patterns updated
  - `rust-code-reviewer`: DRY violations added as 🟡 IMPORTANT review criterion; new DRY checklist in Code Quality Checklist
  - `rust-architect`: new "DRY at Architecture Level" section — scan for existing abstractions before designing new ones; shared logic must go to core/domain crate
  - `rust-testing-engineer`: new "DRY in Tests" section — shared fixtures in `tests/common/`, reuse mocks, extract repeated setup to helpers
  - `rust-critic`: DRY violations (duplicated logic, copy-pasted error variants) added to "Alternative Hypotheses" red flags

## [1.19.5] - 2026-04-05

### Fixed

- `rust-team` skill: added mandatory reading step at startup — model now explicitly reads `references/team-workflow.md`, `references/communication-protocol.md`, and `references/result-aggregation.md` before proceeding

## [1.19.4] - 2026-04-05

### Fixed

- `rust-teamlead` agent: spawn prompt template in agent definition used ambiguous `run /rust-agent-handoff` — replaced with explicit `Skill(skill: "rust-agents:rust-agent-handoff")` call and step-by-step handoff instructions (timestamp capture, schema reading, YAML write before finishing)
- `rust-teamlead` agent: teamlead's own handoff chain section also used `run /rust-agent-handoff` — replaced with `Skill(...)` call
- All 9 specialist agents (architect, developer, testing, performance, security, reviewer, cicd, debugger, critic): added `# Startup Protocol (MANDATORY)` section with explicit `Skill(skill: "rust-agents:rust-agent-handoff")` call, timestamp capture, schema read, and handoff write instructions — agents previously had the skill listed in frontmatter but no instruction to invoke it

## [1.19.3] - 2026-04-05

### Fixed

- `rust-team` skill: replaced ambiguous `run /rust-agent-handoff` in agent spawn prompts with explicit `Skill(skill: "rust-agents:rust-agent-handoff")` call — agents now correctly load and follow the handoff protocol
- `rust-team` skill: communication-protocol template now includes step-by-step handoff instructions with timestamp capture, schema reading, and mandatory YAML write before finishing

## [1.19.2] - 2026-04-05

### Fixed

- `rust-agent-handoff` skill: corrected `reference/` path typo to `references/` in startup instructions — agents now correctly read agent-specific output schemas
- `rust-agent-handoff` skill: consolidated duplicate `## On Startup` sections into a single ordered sequence to prevent agents from missing timestamp capture or schema reading steps

## [1.19.1] - 2026-04-04

### Changed

- `rust-architect` agent: added Phase 0 (Specification) — create/update spec via `/sdd` skill after analysis when developing new functionality
- `rust-architect` agent: added Specification section to Pre-Implementation Checklist
- `rust-agent-handoff` skill: added `spec` field to architect output schema for propagating spec path through handoff chain
- `rust-agent-handoff` skill: agents now check `output.spec` in handoff chain and read spec before starting work

## [1.19.0] - 2026-04-03

### Added
- `rust-teamlead` agent — team orchestrator for multi-agent collaborative development (merged from rust-team plugin)
- `rust-team` skill — full team workflow with communication protocol, task structure, and result aggregation (merged from rust-team plugin)

## [1.18.0] - 2026-04-03

### Removed
- `rust-lifecycle` skill — use `rust-team` skill instead for full development workflow orchestration

## [1.17.2] - 2026-03-27

### Fixed
- Add `ToolSearch("select:TaskCreate,TaskUpdate,TaskList,TaskGet")` as first step in `rust-lifecycle` workflow-steps.md — task tools are deferred and must be loaded before use; without schema load the LLM emits wrong parameter names (e.g. `id` instead of `taskId`)

## [1.17.1] - 2026-03-26

### Changed
- Replace deprecated `TaskOutput` references with `Read` on task output file path in `rust-lifecycle` skill

## [1.17.0] - 2026-03-21

### Added
- `effort` frontmatter for all agents: `high` for architect (deep architectural reasoning), `medium` for all others (security, critic, developer, testing, performance, cicd, debugger, code-reviewer, sdd)
- `effort` frontmatter for skills: `medium` for sdd, `low` for fast-yaml
- `maxTurns` frontmatter for critic (15) and code-reviewer (20) to prevent unbounded iterations
- `maxTurns` prevents unbounded iterations in review-only agents

## [1.16.0] - 2026-03-17

### Added
- `sdd` agent: Spec-Driven Development specialist for creating structured specifications, technical plans, and implementation task breakdowns
- `sdd` skill: Self-contained SDD workflow with embedded constitution, spec, plan, and tasks templates; supports `init`, `specify`, `plan`, `tasks`, and `review` phases

### Changed
- `rust-architect`: added `sdd` skill to enable structured spec output in SDD format when planning features

## [1.15.4] - 2026-03-13

### Changed
- `rust-architect`: added `ultrathink` directive before the Architecture Decision Framework to trigger extended thinking on architectural decisions
- `rust-critic`: added `ultrathink` step in the Critique Process before applying the eight dimensions to surface non-obvious failure modes
- `rust-debugger`: downgraded model from `opus` to `sonnet` — debugging is iterative tool use, not deep reasoning; sonnet's speed is an advantage

## [1.15.2] - 2026-03-10

### Changed
- `rust-code-reviewer`: downgraded model from `opus` to `sonnet` — review tasks are pattern-based and do not require deep reasoning

## [1.15.1] - 2026-03-04

### Fixed
- `readme-generator` skill: added warning that GitHub callouts (`[!NOTE]`, `[!TIP]`, etc.) render
  as plain blockquotes on PyPI and npm — avoid using them for Python and TypeScript/JavaScript packages

## [1.15.0] - 2026-03-04

### Changed
- `rust-lifecycle` skill: `rust-critic` now runs a second time in the parallel validation phase
  after implementation, alongside `rust-performance-engineer`, `rust-security-maintenance`, and
  `rust-testing-engineer`
- Added `phase-N-validate-critique` task that blocks on `phase-N-implement` and unblocks
  `phase-N-review`, matching the dependency pattern of other validation tasks
- `rust-code-reviewer` now receives the critic's implementation handoff alongside performance,
  security, and testing handoffs for a more complete review context
- Updated workflow diagram and task structure table in `SKILL.md` to reflect the new step

## [1.14.1] - 2026-03-04

### Fixed
- `rust-critic` workflow diagrams: removed square brackets that implied optional invocation; added explicit `(MANDATORY)` marker and `[!IMPORTANT]` callout to enforce mandatory critic step

## [1.14.0] - 2026-03-01

### Changed
- `rust-lifecycle` skill: `rust-critic` is now a mandatory step in the workflow, running after
  every `rust-architect` phase before implementation begins
- Workflow diagram and task table updated to include `phase-N-critique` task between plan and implement
- `phase-N-implement` now blocks on `phase-N-critique`, not on `phase-N-plan` directly
- Added verdict-based branching logic: `critical` and `significant` verdicts force architect redesign
  and critic re-run before implementation can proceed; only `approved` or `minor` unblock implementation
- `workflow-steps.md` updated with full execution guide for the critique phase including verdict handling

## [1.11.0] - 2026-02-09

### Added
- New `rust-release` skill for automated release preparation workflow
  - Supports patch/minor/major semver version bumps
  - Creates release branch, updates all Cargo.toml manifests
  - Finalizes CHANGELOG.md with versioned section and comparison links
  - Refreshes README via `/readme-generator` skill integration
  - Runs pre-release quality checks (fmt, nextest, clippy, build)
  - Creates commit, pushes branch, and opens PR via `gh`
  - Handles both single-crate and workspace projects
  - Reference documentation for changelog format conventions

## [1.10.2] - 2026-02-07

### Added
- JSON → YAML conversion documentation in `fast-yaml` skill
  - Added `fy convert yaml` CLI command documentation
  - Python API examples for JSON → YAML conversion with helper functions
  - Node.js/TypeScript API examples including batch conversion and CLI script
  - Bidirectional conversion patterns for both YAML ↔ JSON directions

### Changed
- Updated `fast-yaml` skill description to include JSON → YAML triggers
- Enhanced Quick Reference table with both conversion directions
- Updated CLI commands reference with comprehensive bidirectional conversion examples

## [1.10.1] - 2026-02-07

### Fixed
- Changed memory scope from `project`/`local` to `user` for all agents to resolve access issues with ~/.claude/ directory

## [1.10.0] - 2026-02-07

### Added
- New `fast-yaml` skill for YAML validation, formatting, and conversion
  - Complete CLI reference with batch processing and parallel execution support
  - Python API documentation with linting and parallel processing capabilities
  - Node.js/TypeScript API reference for modern JavaScript projects
  - YAML 1.2.2 specification guide with migration examples from YAML 1.1
  - Supports validation, formatting, linting, and YAML-to-JSON conversion
  - Triggers on keywords: validate yaml, format yaml, lint yaml, check yaml syntax, convert yaml to json

## [1.9.6] - 2026-02-07

### Added
- Added `memory` frontmatter field to all 8 agents for persistent memory support (introduced in Claude Code v2.1.33)
  - `project` scope for 6 agents: rust-architect, rust-developer, rust-testing-engineer, rust-performance-engineer, rust-security-maintenance, rust-cicd-devops
  - `local` scope for 2 agents: rust-code-reviewer, rust-debugger

### Changed
- Agent frontmatter now includes memory configuration to enable context persistence across sessions

## [1.9.5] - 2026-02-07

### Added
- Feature flags testing strategy in rust-cicd-devops agent
- Comprehensive CI/CD workflow examples for testing with different feature combinations

## Earlier versions

See git history for changes in versions 1.9.4 and earlier.
