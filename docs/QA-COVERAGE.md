# Taskboard automated QA coverage

The current count and named results come from `python tests/run.py --report-json dist/qa-results.json` and the GitHub Actions artifact, rather than a number maintained by hand. CI runs the Lua 5.1 suite on Windows and Linux for every push and pull request, builds three ZIP layouts, and tests the packaged CurseForge addon. This establishes simulated behavior, not real-client certification.

## Historical 1.2.1 audit

Audit date: 2026-11-08. **219 automated tests passed, 0 failed** under Lua 5.1 with the WoW API mock and Forever client API fixture. The baseline had 190 passing tests. This audit added 29 cases; the first regression run reproduced nine failing scenarios before fixes.

These are unit tests plus simulated integration/UI-handler tests. They do not establish real-client rendering, event delivery, sound playback, server reset timing, or multiplayer delivery. There is not yet a two-to-three-test guarantee for every individual manual checklist case. Multiple assertions inside one test are not counted as separate tests, and the table below is a feature-level coverage map, not line/branch coverage.

## Reproduce and inspect individual results

```text
python tests/run.py --report-json dist/qa-results.json
python tests/run.py qa_audit_spec
python tests/tools/package.py --curseforge
python tests/tools/package.py
python tests/tools/package.py --legacy-loader
python tests/tools/check_package.py
```

Install the test dependency `lupa` into the Python environment first. The JSON report lists each executed test's spec, full scenario name, pass/fail result, and failure traceback when present. The process exits unsuccessfully on a failing test. Generated reports and packages belong in `dist/` and are not runtime addon files.

## Fixes found by this audit

| Area | Reproduced issue and corrected behavior |
| --- | --- |
| Mail proximity | Leaving a mailbox now clears nearby state even with reminder popups disabled. |
| Mail proximity | A newly added mail task can remind during the current visit; remaining nearby does not repeat alerts after cooldown. Closing the mail window does not immediately duplicate the opening reminder. |
| Mail completion | Supported check-mail titles accept punctuation. Opening mail cannot finish an unrelated goal or subtask, and respects the automatic completion setting. |
| Location parsing | Mixed quoted and unquoted destinations now follow textual order; the last destination wins. |
| Character boards | Ambiguous slash-command board names are rejected with guidance. Use a board ID or `Name (Character-Realm)`. |
| Character boards | Tasks created while viewing another character's board default to that board's owner. |
| Import | If the board limit prevents creating a personal board, import reports the failure without dereferencing a missing board. |

## Coverage map

Paths below are relative to `tests/spec/`. Each row identifies automated evidence and the client-only work still required. A passing offline test does not check off its corresponding in-game interaction automatically.

| Checklist area | Automated evidence | Remaining in-game verification |
| --- | --- | --- |
| SET / IN: load, upgrade, branding | `static_spec`, `db_spec`, `persistence_spec`, `personalization_spec`, `coverage_regression_spec`: compile/API checks; clean/corrupt saves; rich board consolidation, legacy copy, post-upgrade edits and repeated login | Actual addon load, old installation upgrade, key bindings and saved files |
| UI: windows, controls, combat | `ui_spec`, `regression_spec`, `personalization_spec`: handler invocation, close behavior, drag lifecycle, resizing, focused edits | Real mouse/keyboard focus, Escape, combat restrictions, clipping and reachability |
| BD: one board per character | `db_spec`, `qa_audit_spec`, `regression_spec`, `coverage_regression_spec`: creation, rich consolidation with column overflow and shared-board isolation, status preservation, ambiguous names, cross-character ownership and read-only guards | Actual A/B login sequence, owner labels, existing-save consolidation |
| QA: Quick Add | `parser_spec`, `ui_spec`, `util_spec`: quantities, links, plain tasks, modifiers, subtasks, unknown names and sanitization | Real shift-click links, typing cadence and input focus |
| LC: destinations | `parser_spec`, `ui_spec`, `qa_audit_spec`: quoted locations, token order, suggestion filtering, acceptance, dismissal and surrounding-text preservation | Client area names and real keyboard/mouse selection |
| ED: editor/cards/columns | `ui_spec`, `regression_spec`, `db_spec`: edits, invalid updates, selection switches, stale cards, core-column guards, horizontal scroll and drag state | Visual layout, scrolling/dragging at different resolutions and UI scales |
| GL: live goals | `goals_spec`, `engine_spec`, `parser_spec`, `qa_audit_spec`: item, money, level, skill, reputation and quest lifecycles; auto-completion disabled; foreign-character event isolation | Actual loot, money, XP, skill, faction and turn-in events; server-specific item identities |
| BK: bank inventory | `items_spec`, `engine_spec`, `regression_spec`: count modes, item verification, new recurring baseline after mode changes | Cached bank counts after closing bank, transfers and reloads on the real client |
| RM: zone/NPC reminders | `reminders_spec`, `personalization_spec`, `ui_spec`: matching, cooldown, disabled state, smart reminder quantities, nearby tracker state | Zone boundaries and real vendor/bank/AH/trainer events |
| MB: mailbox | `reminders_spec`, `qa_audit_spec`, `coverage_regression_spec`: learning, persistence, two distinct maps, missing coordinates and recovery, entry/exit hysteresis, cooldown, newly added tasks, supported completion and exclusions | Actual 35/50-yard behavior, map boundaries, indoors/stacked floors and client coordinates |
| TR: tracker | `ui_spec`, `personalization_spec`, `coverage_regression_spec`: default/pinned/all-open/nearby visibility, progress, pulse state, drag/lock handlers and saved position/settings | Real mouse placement, visual separation, scrolling, pulse appearance and combat behavior |
| MP: map pins | `ui_spec`, `qa_audit_spec`: waypoint creation, pin replacement/clear/reload, absent position handling and unsupported-map fallback | Real waypoint placement, map artwork and tracking arrow |
| AP: appearance | `personalization_spec`, `ui_spec`, `layout_style_spec`: nine theme choices, accents, opacity, opaque dialogs, persistence and resize state | Artwork availability, contrast, text readability and scale on the actual client |
| FB: feedback | `personalization_spec`, `ui_spec`, `qa_audit_spec`: event selection, Off/master controls, no duplicate completion, batching and stale-toast clicks | Audible sound choices/volume/channels and toast appearance/click targets |
| RC: recurrence | `recurring_spec`, `regression_spec`, `persistence_spec`, `coverage_regression_spec`: daily/weekly, offline catch-up, baselines, stock rearming, missed streaks, archive exclusions and check-mail completion across two periods | Real daily/weekly server boundary and alternate-character login timing |
| SH: sharing | `sync_spec`, `regression_spec`, `conformance_spec`: simulated two-client exchange, read-only guards, malformed messages, channel permissions, retry/timeout/queue limits | Two real clients in party/raid/guild, throttling and other-addon interference |
| EX: export/import | `serialize_spec`, `ui_spec`, `regression_spec`, `qa_audit_spec`: round-trip, corrupt/fuzzed data, bounds, sanitization, reassignment and board-limit failure | Real clipboard use and practical export sizes |
| DG / SG: diagnostics/release | `static_spec`, `conformance_spec`, `ui_spec`, `regression_spec`, `qa_audit_spec`, `tests/tools/check_package.py`: API fixture, self-test failures, caught errors, 200-card filtering and tests against exact release ZIP contents | Real FPS/memory, long sessions, addon conflicts, install through the client and release sign-off |

## High-risk checklist traceability

| Manual case IDs | Automated evidence | What still needs the game |
| --- | --- | --- |
| IN03/04, BD11–16; partial IN06 | `coverage_regression_spec` checks rich older Taskboard board consolidation, column overflow, shared-board isolation, an edit and two reloads. `personalization_spec` separately checks copying `QuestboardDB` without changing the old save. | Upgrade an actual Questboard save, disable its legacy loader after verification, and confirm the edited card still persists in WoW (IN06). |
| TR11/17 | `coverage_regression_spec` invokes drag/lock handlers and checks saved coordinates and visibility after reload. | Drag with a real mouse and check the displayed location. |
| RC16 | `coverage_regression_spec` completes a daily mail task, resets it and completes it again without duplicate statistics. | Observe a real server reset and mailbox visit. |
| MB08/19 | `coverage_regression_spec` checks two maps, absent coordinates and recovery. | Approach real mailboxes on different maps and test indoor positioning. |
| DG10 | `qa_audit_spec` lays out 200 varied cards in eight columns and verifies search keeps one correct match, then restores all 200. | Judge real scrolling, dragging and typing responsiveness. |
| SG08 | `check_package.py` verifies all three ZIP layouts and runs every Lua test against the extracted CurseForge ZIP. | Fresh install through CurseForge once the project is published. |

## Testing standard going forward

For each distinct logic behavior, aim for a normal path, a boundary/negative path, and recovery/persistence where meaningful. Add a failing regression test before fixing a defect. Shared assertions can be parameterized across task types, but must assert user-visible behavior. A raw count of two or three tests is not proof of coverage.

The historical 29 new cases covered mailbox state/completion, destination ordering, board ownership/selection, import failure and stale-toast handling, plus disabled-completion and foreign-character tests for five live goal types. Map-pin boundary/persistence tests were also included. The manual checklist remains the source of truth for real-client acceptance; a passing mock test does not check off a live case.

## CI merge gate

`.github/workflows/tests.yml` runs on pushes and pull requests. Its single `required-tests` job succeeds only after both Windows and Linux test/package jobs succeed. When GitHub branch protection is available, target `main`, require a pull request, and require the `required-tests` status check before merging. The current private repository's GitHub account returned `403: Upgrade to GitHub Pro or make this repository public to enable this feature` for rulesets. The GitHub App connection also cannot edit branch protection. Until the account supports it and the owner enables the rule, CI reports failures but GitHub does not block a merge. See [GitHub's protected-branch availability](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).

## Prioritized in-game pass

The 1.3.0 update adds automated coverage in `tests/spec/layout_style_spec.lua` for Simple mode, completed-column visibility, saved column ordering, archived-task pagination, parchment/custom styling, opaque dialogs, Help search, dependent-window closing and repeating nearby sounds. These mock-client checks do not replace the in-game cases in `docs/TESTING.md` or the dated manual QA record. The 1.2.1 audit above is historical.

1. Reload, verify the version shown in `Taskboard.toc`, run `/tb selftest` and `/tb diag`; preserve the earlier diagnostic record for comparison.
2. Create a plain task and a real linked `get 17 Silverleaf`; loot, move, edit, reload and check persistence.
3. Test learned mailbox approach/exit, a new task while already nearby, reminder-off exit, and check-mail completion with/without subtasks and auto-completion enabled/disabled.
4. Check window closing in combat, all classic skins, opacity exceptions, editor scaling, dropdowns, drag/scroll and tracker spacing.
5. Exercise actual zone/NPC reminders, bank-cache behavior, map pins and sound playback.
6. Log into another character to verify board selection and task ownership; test legacy consolidation only in an isolated setup.
7. Observe one real daily and weekly reset; exercise two-client sharing in the channels you use.
8. Run a populated-board session with your usual addons, then capture diagnostics and any visual/input issues before release sign-off.
