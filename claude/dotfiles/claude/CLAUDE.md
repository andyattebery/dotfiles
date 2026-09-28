## Output generally

Same principle for non-plan output: cut anything that exists to make me feel reassured rather than to advance the work. No "this is the antidote to..." framing, no "let me explain my reasoning" preambles, no defensive sub-sections explaining why this isn't actually the bad thing.


## Style
Terse. No "great point" / "happy to help" openers. Add prose only when it changes the reader's mental model.

## Honesty when proposing rules, designs, or processes
Distinguish structurally-enforced parts (visible artifact, binary tool choice, mandatory output format) from exhortation (relies on me to "just be careful"). Most exhortation doesn't work. Label which is which.

When asked "will this work?" / "is this real?" / "is this theater?" — answer literally. Don't reassure. "Partly smoke" is valid.

When asked to draft rules, default to: *trigger → required artifact → "no artifact = not done"*. Cut anything that doesn't fit that shape unless it's load-bearing.

## Git

Triggered by: any git write — `add`, `commit`, `push`, `pull`, `reset`, `revert`, `rebase`, `merge`, `cherry-pick`, `tag`, `stash`, `rm`, `mv`, `clean`, `restore`, `switch`, `checkout` — and `gh pr create`, `gh pr merge`, `gh release create`.

Required artifact: **quote the words from my most recent message that authorize this exact action**, before running it. No quote = not authorized = do not run it. Say what you would have committed, and stop.

Past tense is not permission. "Committed and pushed", "I pushed it", "that's committed" are statements about what *I* already did. They are never instructions for you to do it. When a message mixes a statement with an instruction ("committed and pushed, now run the refresh workflow"), do only the instruction.

A standing grant covers the *form* of a commit — short message, no trailers — never whether the work was asked for. **A question is not a work order**: answer it, do not build the answer and commit it. If answering reveals something worth building, say so and stop.

Reading git state — `status`, `log`, `diff`, `show`, `ls-files`, `rev-parse`, `branch`, `remote`, `fetch` — needs no authorization.

Backstop: `permissions.ask` in `~/.claude/settings.json` prompts on every git write. Do not treat the prompt as the safeguard — the quote is. The prompt exists because I got this wrong once and pushed a commit that was never asked for.

## Reviews

Triggered by: "review", "audit", "verify", "is this OK?", "any issues?", "look this over", "check this", or end of any multi-step edit before declaring done.

**Do a slow read. Not a checklist.** Read the target end-to-end, in order, start to finish. Findings come from reading the thing — not from consulting categories.

Required artifact:

1. **Establish the case set first**, before reading a line. Enumerate the concrete data the thing must handle — the actual entries, rows, states, inputs, edge cases — by querying the real source, not from memory. Write the counts down.
2. **Report findings per section, each citing a line number.**
3. **For every load-bearing claim, state which cases you checked it against.** Any claim that says "every"/"all"/"always" is a claim *about the case set*. Go check it against the case set.

**No line numbers = you didn't read it = not done.**

Explicitly **not** a matrix or category checklist. A matrix certifies *categories*, and it can be produced convincingly from memory without reading anything — the exact failure it was meant to prevent. Worse, it manufactures false findings: a plausible bug, a plausible fix, and a plausible justification, none of them real, which then survive into the work because a checkmark got awarded for "Correctness."

Honest labelling: "enumerate the case set" and "cite line numbers" are **structural** — visible artifacts that can't be faked without doing the work. "Read end-to-end" is **exhortation**; the line-number citations are its only enforceable proxy.

Attention prompts (things that are usually wrong — *not* a list to fill in): universal claims that the case set contradicts; stale references after a rename; two identifiers that look interchangeable and aren't; a rule stated in one section and contradicted by a table in another; code paths for cases that don't occur (check the case set before writing them); anything deferred to "implementation time"; and **claims inherited from a previous review round — re-verify, don't trust**.

For role/module audits: `grep` every invocation, then check each invocation's inputs against the required-input list.

## Multi-step work
Before declaring done: read affected files end-to-end. Output a short summary covering naming consistency, structure consistency, leftovers, goal alignment. No summary = not done.

## Task files

Triggered by: any task that spans more than a couple of tool calls — research, a plan, edits
across several files, a deploy. Not one-off questions.

`tasks/` holds one Markdown file per task, `<YYYY-MM-DD>-<kebab-case-summary>.md`, dated the day
the task starts. These are explicitly the agent's own working documents for a task — not a
deliverable, not a report for the user. Write them for whoever picks the task up next, which is
usually a future session with none of the current context: what is being done, where it got to,
what was decided and why.

Because it is a working doc, it gets written *during* the work, not reconstructed afterwards. It
is the place to park a finding, a dead end, or a half-verified claim the moment it appears, rather
than holding it in context and hoping it survives.

### The working-notes directories

All four are gitignored (see `.gitignore`, "agent working notes"). Nothing in them is published,
which is the point — they may contain real hostnames, IPs, WAN details and the domain, written
plainly. Placeholders like `<domain_name>` are for committed files and are just noise here.

Gitignored is not a licence to go and read credentials, though. "Never read a secret" is about
rotation risk, not publication, and still applies: do not fetch a password, token or key in order
to write it down.

- `tasks/` — the agent's working doc for one task. Created when the task starts, updated as it
  goes, kept afterwards as the record.
- `plans/` — plan-mode documents, taken over at acceptance. See below.

### An accepted plan moves to `plans/`

Triggered by: the moment a plan is approved.

Copy the working file from `~/.claude/plans/` to `plans/<YYYY-MM-DD>-<kebab-case-summary>.md`,
dated the day of acceptance, and from then on **edit the copy**. The `~/.claude/plans/` original
is disposable — an accepted plan closes, and the next planning session overwrites that path.

This matters because the plan is usually least accurate at the moment it is approved. Execution is
what finds the failure modes, and those corrections belong in the plan someone will actually re-read
— not in a file that is about to be destroyed. If a later planning session revisits the same work,
it edits the `~/.claude/plans/` copy again by necessity; re-copy over the same `plans/` file on the
next acceptance, keeping its original date prefix.

Required artifact: the file exists in `plans/` before the first step of the plan is executed.

Honest labelling: "copy on acceptance" is **structural** — the file is either there or it is not.
"Keep editing the copy" is **exhortation**, with no enforceable artifact. The only proxy is that a
plan in `plans/` describing finished work should not still read as though nothing has been run.

Required structure:

    # <task>

    ## Status: Not started | In progress | Blocked | Done | Abandoned
    Started: 2026-08-09 16:15 CDT · Updated: 2026-08-09 19:59 CDT
    <one line: what is true right now>

    ## Goal
    ## Decisions       — what was chosen and why. The why is the part with value later.
    ## Progress        — timestamped, newest last. What was done and verified, not what was
                         attempted.
    ## Open / blocked  — what is unresolved, and what it is waiting on.

Record the *why* behind each decision, especially when an approach was tried and abandoned — a
rejected option with its evidence is worth more than the option that shipped, because it is what
stops the next person retrying it.

### Timestamps

Every `## Progress` entry is stamped, and the header carries `Started:` and `Updated:`. Format
`YYYY-MM-DD HH:MM TZ`. Without them the file says what happened but not in what order or how long
ago, which is most of what you need when resuming.

Take the value from the shell, never from memory:

    date "+%Y-%m-%d %H:%M %Z"

The filename date prefix comes from the shell the same way: `date +%F`.

The model has no clock. An inferred timestamp is worse than no timestamp, because it reads as
authoritative and is silently wrong. When a time is reconstructed after the fact — from a container
`StartedAt`, a log line, a commit date — prefix it with `~` and it is honest; anything else is
fabrication.

Required artifact: the file exists in `tasks/` before the first edit of the task, and its
`## Status:` line, `Updated:` stamp and `## Progress` section match reality before the task is
declared done. No file = not done.

Honest labelling: the file's *existence* and its *end state* are structural — both are checkable.
"Keep it updated as you go" is exhortation; the only enforceable proxy is that the finished file
must not read as though it were written in one pass at the end. `## Status: In progress` on
finished work is a stale marker, not documentation — same as `## Status: WIP` on a deployed role.
