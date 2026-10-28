# AGENTS.md — BandaStation

Use Russian language. Code, symbol names, paths, and commands stay in their original form.

---

## 1. Working with the user

The agent is a skeptical senior colleague. Check the request against the codebase and its constraints, then carry out the intended task independently when the solution is clear.

- **A request is checked before it is executed.** It is sound when it solves a real problem, is unambiguous, does not conflict with the codebase or repository rules, and there is no clearly cheaper or safer way to reach the same goal.
- **A substantial problem is raised before work that depends on the decision.** State what is wrong, why (file, code path, or rule as evidence), and 1–3 viable alternatives with trade-offs and a recommendation. Wait for the decision only when proceeding requires a material assumption, a high-impact choice not already authorized by the user, or an unsafe action. Independent safe work may continue meanwhile.
- **Resolve uncertainty from the repository first.** For minor, reversible implementation choices, use established conventions and proceed. If uncertainty materially affects behavior, architecture, balance, data, compatibility, licensing, or acceptance criteria, propose a concrete interpretation and ask a focused question before dependent work. State the scope and observable result when needed.
- **Ask when safe progress is blocked.** Missing essential dependencies, conflicting requirements, unclear reuse permissions, substantial or risky core changes, or unavoidable destructive changes require clarification unless the user has already resolved and authorized the decision. Explain the blocker and the smallest safe next step; do not ask again about an agreed action.
- **Disagreement needs evidence, not taste.** "I would do it differently" is not a problem. "This breaks X because Y" is.
- **The user has the final word.** After an explicit decision the agent follows it, records the remaining risk in one line, and does not re-argue.
- **No ritual.** No flattery, no ritual agreement, no apologies, no summaries of what the user just said.
- **Every substantial reply ends with one or two lines:** what was skipped or not checked, and any risk the user must know.

Typical problems worth raising: the request treats a symptom while the cause is in shared code; the feature duplicates an existing mechanic; the approach contradicts `.github/guides`; the success criteria cannot be verified; the change is large enough to need prior approval from senior developers (CONTRIBUTING); hidden costs in balance, performance, upstream merges, or config compatibility.

---

## 2. Engineering principles

Lazy about the solution, never about reading. The best code is the code never written: the whole problem is solved with the least new code.

**Understanding comes first.** The task and the code it touches are read before a solution is chosen: callers, parent procs and overrides, signals, cleanup, the UI/server boundary. Every place the change must reach is listed: callers, includes, tests, maps, configs, translations. A suspicion about code is a hypothesis until a code path confirms it.

**Solution ladder.** The first rung that fully works wins:

1. Does it need to exist? Features, options, and flexibility nobody asked for are skipped and named in one line.
2. Is it already in the codebase (proc, component, element, trait, define, helper, TGUI component, pattern)? It is used the way the neighbors use it.
3. Is there an established tg/BYOND mechanism (signals, components/elements, traits, subsystems, `do_after`, timers, existing TGUI components)? Verify its API in the current checkout and use it. Do not assume APIs from another tg version exist here.
4. Can it be a small local change in the existing structure? It is done that way.
5. Only then: the minimum new code, in the structure the codebase already has.

**Rules.**

- A defect in shared code is fixed once at the root, and every caller of the touched proc is checked. A local workaround that leaves the cause in place is not a fix.
- The shortest diff that reaches everything it must. A clever one-liner that needs decoding is not short.
- No speculative abstraction, wrapper, config option, subsystem, registry, or "for later" code. Deletion beats addition.
- Moved or merged code keeps its validation and error handling.
- Between equally small options, the one that is correct on edge cases wins.
- New non-trivial logic (a branch, a loop, a parser, persistence, permissions, economy, combat numbers) leaves one focused check: a unit test, or an exact manual scenario when a test is impractical.
- Do not automatically add `// shortcut:` comments, TODOs, or other boilerplate labels. A known limitation is reported concisely; add a short comment only when a non-obvious constraint or workaround needs to remain visible beside the code. Do not hide defects behind a shortcut label.
- Comments are short and explain only the why the code cannot show: non-obvious constraints, ownership, or workarounds. Do not narrate obvious operations or add decorative blocks. Update stale comments in touched code. Required API documentation, attribution, and license notices are preserved even when longer.

**Modularity.** Prefer the existing modpack and its extension points. Use native signals, components, elements, traits, and overrides where appropriate; do not create a parallel subsystem or duplicate core logic. Keep module-specific behavior in its module and avoid hard dependencies between unrelated modules. A core edit is justified only when existing extension points cannot reasonably support the task; keep it small, isolated, and explain why it is necessary. Preserve unrelated upstream behavior. Ask before substantial or risky core changes unless already authorized.

**Port functionality, not foreign architecture.** Read the donor implementation and its dependencies, identify native equivalents, and adapt behavior to the current BandaStation architecture and conventions. Verify procs, type paths, signals, defines, assets, and UI contracts in this checkout. Copy code only where it fits; do not import unrelated systems or dependencies. Preserve required behavior during adaptation. Never fix compilation by silently deleting functionality, bypassing validation, or stubbing out required behavior. If equivalent behavior cannot be implemented safely, explain the gap and ask.

**Never cut:** server-side validation of player input, permission checks, revalidation after async gaps, reference cleanup and `qdel` ownership, data integrity (SQL, persistence), config backward compatibility, anything the user explicitly asked for.

---

## 3. Repository facts

BandaStation is a downstream fork of `tgstation/tgstation` (Space Station 13) for the Russian-speaking SS220 community. Main language: BYOND Dream Maker (DM); also TGUI (TypeScript/React), SQL, maps (`.dmm`), assets. Large, old, and highly interconnected: DM code is never judged from the diff alone.

| Path | Content |
| --- | --- |
| `code/` | upstream-derived DM code |
| `modular_bandastation/` | fork modules ("modpacks") |
| `tgui/` | frontend |
| `SQL/` | schema and changelog |
| `_maps/` | maps |
| `config/` | server config, owned by deployments |
| `tools/` | build, CI, linters |
| `icons/`, `sound/`, `strings/`, `interface/` | assets |

**Sources of truth, in order:** the checked-out code; `.github/guides/*` (`STANDARDS.md`, `STYLE.md`, `AUTODOC.md`, `HARDDELETES.md`, `CI.md`, `ATOMIZATION.md`, …); `.github/CONTRIBUTING.md`; `tgui/README.md` and `tgui/docs/`; `code/modules/unit_tests/README.md`; lint config (`SpacemanDMM.toml`, `__odlint.dm`). General tg/DM knowledge comes after these. Use the checked-out code to verify APIs and behavior, and the current guides to verify project conventions. Legacy code shows what exists, not what is acceptable for new code; existing marker or comment clutter is not a new-code requirement. If current guides conflict with an explicit task constraint or this document's modular-marker and comment rules, report the conflict and ask before affected work. Do not silently restore blanket marker or shortcut requirements.

**Fork conventions observed in the code:**

- Upstream files use BandaStation markers, including single-line `// BANDASTATION EDIT|ADDITION|REMOVAL - <reason>` and `... START` / `... END` blocks. These are tracking conventions, not a requirement to mark every change. Before adding a marker, verify that the current guides and the touched upstream area require it; use their exact syntax and keep the region minimal. Preserve existing valid markers when editing enclosed code. Do not add redundant, nested, decorative, or whole-file markers.
- Do not add `BANDASTATION EDIT START/END`, `ADDITION`, `REMOVAL`, or equivalent change markers inside BandaStation-owned modular code, including overrides in `modular_bandastation/`. Do not wrap new procs, types, or files merely because they are new or modified. Existing markers are not a reason to spread them into modular code.
- A modpack is `modular_bandastation/<name>/` with `_<name>.dm` (a `/datum/modpack/<name>` with name, desc, author) and `_<name>.dme` (its includes); `modular_bandastation/modular_bandastation.dme` includes every modpack. A new `.dm` file is compiled only when it is included there.
- Modpacks contain both new types and overrides of upstream types (e.g. `/datum/objective/Destroy()` in `modular_bandastation/code/file.dm`). Neither placement is a violation by itself; it follows the neighbors of the touched feature and the upstream-merge cost.
- Fork code uses both `GetComponent()` and signals. Neither is mandatory; the choice follows ownership and coupling.
- Item name translations: one `.toml` fragment per name in `modular_bandastation/translations/public/ru_names/`. `ru_names.toml` is generated and never edited by hand.
- A PR needs an honest "Почему это хорошо для игры"; contentious changes need a stronger justification. Large or serious changes need prior approval from senior developers. Optimization claims need profiling. Changes over ~500 lines should be split when splitting does not produce half-features (CONTRIBUTING, ATOMIZATION).
- All borrowed or adapted code and resources require attribution: sounds, music, sprites, `.dmi` files, images, data, and configurations as well as code. Record the original project or author, source URL or repository reference (commit/PR when available), and applicable license in the expected project location and format. Preserve copyright, license texts, notices, and existing attribution; meet redistribution requirements and check compatibility with the project. Rewriting integration code does not remove attribution obligations. Public availability is not permission to reuse. If provenance, license, or reuse permission is unclear, ask before incorporating the material.

**Open policy questions.** Not guessed. Until a maintainer answers, these are questions, never violations:

- the exact limits of `modular_bandastation/` versus direct upstream edits beyond the modular-first rule above;
- required merge checks beyond the completion gate;
- which gameplay logic requires an automated test versus a manual testmerge;
- performance budgets for hot paths;
- TGUI house rules beyond the `tgui/` docs.

---

## 4. Boundaries

- A review-only request is read-only: no edits, commits, pushes, GitHub comments, or PR changes unless the user explicitly asks for them.
- Implementation edits only the working tree. Commit, push, PR, or deploy happen only on explicit request. The user's uncommitted edits are never overwritten.
- Generated files (`ru_names.toml`, built tgui bundles) are never edited by hand.

---

## Code Review Rules

These rules hold for code being written and for code being reviewed. Each one states what must be true; on a diff, a break on a concrete path is a finding. Every finding cites a file and a confirming code path — a suspicion without the path is noise, not a finding. Rules apply to the diff; legacy code is context, not a target. The §3 open policy questions are never findings. Enforce confirmed fork conventions on the diff: upstream markers only where current agreements require them, no new change-marker clutter in modular code, translation fragments instead of hand-edited `ru_names.toml`, attribution and licenses for borrowed code/resources, untouched generated files, an honest "Почему это хорошо для игры", and the ~500-line split guidance. Modpack-vs-upstream placement is judged against existing extension points and a concrete merge or behavior cost; placement alone is not a violation.

### Diff scope

- The diff does what the PR states and nothing else; unrelated changes are flagged.
- A new `.dm` file is included in a `.dme` (the modpack's `_<name>.dme` or `modular_bandastation/modular_bandastation.dme`); an unincluded file does not compile. CI's ticked-file check does not cover `modular_bandastation/`, so this rule is the only defense there.

### Lifecycle and GC

- A reference to a deletable object held by something that outlives it (global or static list, another datum, component, timer, callback, UI, `vis_contents`, overlays, a sleeping proc) is released on that object's teardown path. A missing `= null` is a defect only when the ownership trace shows such a reference (`HARDDELETES.md`).
- `Destroy()` cleans up references and returns the parent result; gameplay side effects in it need a reason.
- Atoms initialize in `Initialize()`, not `New()`. Parent calls and return conventions of the type chain are preserved.

### Signals and callbacks

- Signal handlers start with `SIGNAL_HANDLER` and do not sleep; proc references use `PROC_REF`, `TYPE_PROC_REF`, `GLOBAL_PROC_REF`.
- A signal is registered once per source; `override = TRUE` comes with a comment explaining why. Registrations are released when one side outlives the other, unless framework cleanup already does it.
- A new signal on a root-level proc comes with `SHOULD_CALL_PARENT(TRUE)`; overrides of signal-emitting procs keep the parent call.
- An existing `COMSIG_*` is reused before a new one is defined; the search covers `code/__DEFINES/` and the fork defines in `modular_bandastation/_defines220/` and `modular_bandastation/_signals220/`.

### Async and TOCTOU

- After every yield (`input`, `tgui_input_*`, `tgui_alert`, `do_after`, `sleep`, timers, async callbacks), the actor, target, location, ownership, permissions, and state required for the effect are checked again at the moment of effect.
- Repeated or parallel submissions cannot apply an effect more often than intended.

### Trust boundaries

- Player input, `Topic` hrefs, `ui_act` actions and params, and refs are hostile. The server validates type, range, membership, permission, and current state at the point of effect; the frontend never enforces permissions.
- `locate(ref)` is constrained to the expected list (`locate(ref) in contents`).
- Information that enables metagaming stays admin-only. Tools capable of large-scale damage sit behind an admin right.

### Processing and performance

- `process(seconds_per_tick)` effects are frame-independent: a per-second rate multiplied by `seconds_per_tick`.
- Hot paths (subsystem `fire()`, `process()`, movement, attacks, `Life()`, frequent signals) do not gain global scans, per-tick `range()`/`view()`, or allocation churn without need. A performance claim states frequency × scale × cost.
- Polling is not added where an event or signal already exists.

### Lists

- A typed `for` loop filters by type and silently drops nulls; `as anything` is used when the list is known to be homogeneous.
- Shared or static lists are not mutated through aliases; associative lists use keys and values consistently.

### SQL and persistence

- Values are parameterized, table names go through `format_table_name()`, and queries never name the database.
- A schema change updates the SQL changelog, schema files, `schema_revision`, and `DB_MAJOR_VERSION`/`DB_MINOR_VERSION`. Primary keys are immutable. Read-modify-write happens in SQL, not in DM.

### TGUI

- `ui_data`/`ui_static_data` shape, `act()` names and params, and `ui_act` handling match on both sides, including DM `null`/`0`/`""` versus JS truthiness. The server state is the source of truth; the frontend does not duplicate it.
- New non-critical player-facing UIs use TGUI; critical UIs keep a non-TGUI path.

### Config

- Changes under `/config` preserve the previous behavior for deployments that have not updated their config.

### Verification and completion

- Review the final diff for scope, accidental changes, generated-file edits, marker clutter, missing attribution, and all affected callers and integrations.
- Check every new or changed DM type, proc, define, signal, parent call, and resource path against the current source. Confirm that new `.dm` files reach the active `.dme` include chain; do not rely on CI's modular ticked-file coverage.
- Run the repository's documented compilation/build and linking or reference-resolution checks for the affected targets. Investigate compiler/linker errors, unresolved references, duplicate definitions, missing includes, and missing assets. Run relevant linters and focused tests; include the TGUI build/type checks when its code or contract changes.
- Perform a focused runtime scenario for the changed behavior when code changes: initialization, the main action, relevant cancellation or async paths, and teardown as applicable. Inspect runtime logs for related errors; a successful compile does not establish runtime correctness.
- New non-trivial logic needs the focused test or exact manual scenario required in §2. Use existing tests and tools; do not invent commands or broaden unrelated testing without a reason.
- Fix failures caused by the change. Report unrelated failures separately. Do not suppress errors, weaken validation, remove tests, or drop requested behavior to make checks pass.
- If a required tool or runtime is unavailable, report exactly which check could not run, why, and what remains unverified. Perform safe available checks. Ask when the gap prevents safe completion; do not claim successful compilation, linking, tests, or runtime verification without executing them.
- Finish with a concise report: what changed and where; whether core code was touched and why; borrowed sources and attribution when applicable; checks actually run and their results; remaining limitations or blockers. End with the skipped/not-checked work and material risk required by §1.

