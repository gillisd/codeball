# Code-Review Follow-ups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the five sub-threshold findings from the code review of PR #6 on `feature/expand-ball-public-api`: a `filter` argument-parsing edge case (A), two stale doc comments (C, D), an encapsulation regression (B), and an unhandled unreadable-file error (E).

**Architecture:** Small, surgical fixes to `codeball`, a command_kit-based Ruby CLI (`Ball` aggregate → `Entry`; commands under `lib/codeball/commands/`). No new abstractions. Each finding gets its own task and commit. Two findings are real behavior fixes (A, E) driven by failing tests; one is an encapsulation change (B) with an assertion test; two are dead-code / doc corrections (C, D) verified by the suite staying green.

**Tech Stack:** Ruby 3.4+, command_kit, RSpec (integration + unit specs), RuboCop (`rubocop-claude` etc.).

---

## Background (read before starting)

We are on branch `feature/expand-ball-public-api` (a feature branch — committing is expected). PR #6 is open from it into `master`. The suite is currently green (`bundle exec rake` → Minitest 0 failures, RSpec 239 examples 0 failures, RuboCop 52 files 0 offenses). Run Ruby tooling via `bundle exec`. **The planning doc directory `docs/superpowers/` is gitignored — never `git add` it.**

The five findings, from the review:

- **A** — `lib/codeball/commands/filter.rb` `split_source` only inspects the *last* argument via `File.file?`. A lone argument that names an existing file (e.g. `codeball filter lib/app.rb < ball.txt` when `lib/app.rb` exists) is consumed as the ball *file*, leaving `patterns` empty; `drop_unmatched` then removes **every** entry (`[].any?` is false for all), silently. It also reads the wrong input (the on-disk file instead of stdin).
- **B** — `lib/codeball/ball.rb` exposes `attr_reader :entries, :warnings` publicly (they were `private` on `master`), leaking the live mutable internal arrays so callers can bypass `add_entry`'s warning bookkeeping.
- **C** — the `Ball` class doc comment says "It does not touch the filesystem," but the new `Ball.load_file` reads a file from disk. The comment is now false.
- **D** — the `Entry` class doc comment describes a write-once Header→Body→Footer state machine with "Two construction paths, same invariants," but the new `Entry#name=` setter (unused anywhere) sets header+footer with no body — a third, invariant-violating path.
- **E** — `filter`'s `split_source` comment says the trailing arg is used "when it names a **readable** file," but the code only checks `File.file?`, not `File.readable?`. An existing-but-unreadable file is passed to `File.read`, raising an unrescued `Errno::EACCES`.

### File Structure (what this plan touches)

- **Modify:** `lib/codeball/commands/filter.rb` (Task 1: A + E — `split_source` guard + `File.readable?` + comment)
- **Modify:** `spec/integration/filter_spec.rb` (Task 1: two new tests)
- **Modify:** `lib/codeball/ball.rb` (Task 2: privatize readers; Task 3: fix class comment)
- **Modify:** `spec/codeball/ball_spec.rb` (Task 2: encapsulation assertion test)
- **Modify:** `lib/codeball/entry.rb` (Task 4: remove `name=`)

### Commands you'll reuse

- One spec file: `bundle exec rspec spec/integration/filter_spec.rb`
- Unit spec: `bundle exec rspec spec/codeball/ball_spec.rb`
- One file's RuboCop: `bundle exec rubocop lib/codeball/commands/filter.rb`
- Full suite (as CI): `bundle exec rake`

---

## Task 1: Harden `filter` argument parsing (findings A + E)

Both findings live in `split_source`. Fix: only treat the trailing argument as the ball file when (1) there is at least one *preceding* pattern (so a lone argument is always a pattern — never leaving zero patterns), and (2) it is a **readable** regular file (so an unreadable file falls through to being treated as a pattern / stdin rather than raising `Errno::EACCES`). Update the comment to match.

**Files:**
- Modify: `lib/codeball/commands/filter.rb` (the `split_source` method + its comment)
- Test: `spec/integration/filter_spec.rb`

- [ ] **Step 1: Write the failing tests**

In `spec/integration/filter_spec.rb`, add these two `describe` blocks immediately before the final `end` of the top-level `RSpec.describe "codeball filter" ...` block. They rely on the file's existing `bundle` let (which packs `lib/app.rb`, `lib/nested/helper.rb`, `test/app_test.rb`, `README.md` — and, as a side effect, writes those files into the working dir) and the `entries_in` helper.

```ruby
  describe "when the sole argument also names a file on disk (finding A)" do
    # pack_bundle wrote lib/app.rb into the working dir, so that name is now
    # both a valid glob pattern AND an existing file. A lone argument must
    # stay a pattern -- it must never be consumed as the ball file, which
    # would leave zero patterns and silently drop every entry.
    let(:result) { run_codeball("filter", "lib/app.rb", stdin: bundle) }

    it "treats it as a pattern and filters stdin" do
      expect(entries_in(result.stdout)).to contain_exactly("lib/app.rb")
    end

    it "exits 0" do
      expect(result.exit_code).to eq(0)
    end
  end

  describe "when the trailing argument is an unreadable file (finding E)" do
    before { skip "chmod has no effect when running as root" if Process.uid.zero? }

    let(:result) do
      path = create_file("locked.ball", "secret\n")
      File.chmod(0o000, path)
      run_codeball("filter", "lib/**/*.rb", "locked.ball", stdin: bundle)
    end

    it "treats the unreadable file as a pattern and filters stdin instead of crashing" do
      expect(result.exit_code).to eq(0)
      expect(entries_in(result.stdout)).to contain_exactly("lib/app.rb", "lib/nested/helper.rb")
    end
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec rspec spec/integration/filter_spec.rb -e "finding A" -e "finding E"`
Expected: FAILURES.
- Finding A: with the current code, `lib/app.rb` (a real file) is taken as the ball file, `File.read` gets `"puts :app\n"`, `Ball.parse` raises `MalformedBallError`, so `result.exit_code` is non-zero and `result.stdout` is empty.
- Finding E: the current code takes `locked.ball` as the file and `File.read` raises `Errno::EACCES`, so `result.exit_code` is non-zero (uncaught crash).

- [ ] **Step 3: Fix `split_source` and its comment**

In `lib/codeball/commands/filter.rb`, replace this exact block:

```ruby
      # The trailing argument is the codeball file when it names a readable
      # file on disk; otherwise every argument is a pattern and the ball is
      # read from stdin. This behaves the same interactively and in pipes.
      def split_source(args)
        *leading, last = args
        last && File.file?(last) ? [leading, last] : [args, nil]
      end
```

with:

```ruby
      # The trailing argument is the codeball file only when there is at
      # least one preceding pattern and it names a readable file on disk;
      # otherwise every argument is a pattern and the ball is read from
      # stdin. Requiring a preceding pattern keeps a lone argument a pattern
      # (so `filter '*.rb'` filters stdin instead of trying to open '*.rb')
      # and guarantees patterns is never empty.
      def split_source(args)
        *leading, last = args
        leading.any? && File.file?(last) && File.readable?(last) ? [leading, last] : [args, nil]
      end
```

(`leading.any?` guarantees `last` is present before `File.file?` is evaluated, so no nil-guard on `last` is needed.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bundle exec rspec spec/integration/filter_spec.rb`
Expected: PASS — all filter examples green (the existing file-argument, stdin, glob, `-v`, empty-input, and nonexistent-trailing-arg examples still pass, plus the two new ones).

- [ ] **Step 5: Confirm RuboCop is clean for this file**

Run: `bundle exec rubocop lib/codeball/commands/filter.rb`
Expected: `no offenses detected`.

- [ ] **Step 6: Commit**

```bash
git add lib/codeball/commands/filter.rb spec/integration/filter_spec.rb
git commit -m "Harden filter argument parsing

split_source consumed a lone argument as the ball file whenever it named
an existing file, leaving zero patterns so every entry was silently
dropped; and it treated an unreadable file as the source, raising an
uncaught Errno::EACCES. Only take the trailing arg as the file when a
preceding pattern exists and the file is readable; otherwise treat it as
a pattern and read stdin. Add regression specs for both."
```

---

## Task 2: Privatize `Ball#entries` / `Ball#warnings` (finding B)

Restore `master`'s encapsulation: these readers must be private so the only way to add entries/warnings is through `add_entry` (which maintains the warning bookkeeping). Nothing outside `ball.rb` reads them with an explicit receiver, so this breaks no callers; all internal uses call them via implicit `self`, which works for private methods.

**Files:**
- Modify: `lib/codeball/ball.rb`
- Test: `spec/codeball/ball_spec.rb`

- [ ] **Step 1: Write the failing test**

In `spec/codeball/ball_spec.rb`, add this `describe` block inside the top-level `RSpec.describe Codeball::Ball do` (e.g. immediately after the `let(:ball_text)` definition, before the first `describe ".parse"`):

```ruby
  describe "encapsulation" do
    it "keeps entries a private reader" do
      expect(described_class.public_method_defined?(:entries)).to be false
      expect(described_class.private_method_defined?(:entries)).to be true
    end

    it "keeps warnings a private reader" do
      expect(described_class.public_method_defined?(:warnings)).to be false
      expect(described_class.private_method_defined?(:warnings)).to be true
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec rspec spec/codeball/ball_spec.rb -e "encapsulation"`
Expected: FAIL — `entries`/`warnings` are currently public, so `public_method_defined?(:entries)` returns `true` (expected `false`).

- [ ] **Step 3: Move the readers under `private`**

In `lib/codeball/ball.rb`, delete the public reader near the top of the class. Change:

```ruby
  class Ball
    attr_reader :entries, :warnings

    def self.parse(text)
```

to:

```ruby
  class Ball
    def self.parse(text)
```

Then add the private reader at the end of the class. Change the tail:

```ruby
    def serialize
      each_text_entry.map(&:serialize).join
    end
  end
end
```

to:

```ruby
    def serialize
      each_text_entry.map(&:serialize).join
    end

    private

    attr_reader :entries, :warnings
  end
end
```

(`add_entry` mutates via the `@entries` / `@warnings` instance variables, and every other method reads via implicit `self`, so all of them keep working with the readers now private.)

- [ ] **Step 4: Run the test and the full unit spec to verify green**

Run: `bundle exec rspec spec/codeball/ball_spec.rb`
Expected: PASS — the new encapsulation examples pass and every pre-existing `ball_spec` example still passes (they use public methods: `parse`, `each_entry`, `each_warning`, `warning_count`, `serialize`, `remove_entry`, `files`, `entry_count`).

- [ ] **Step 5: Confirm RuboCop is clean for this file**

Run: `bundle exec rubocop lib/codeball/ball.rb`
Expected: `no offenses detected`.

- [ ] **Step 6: Commit**

```bash
git add lib/codeball/ball.rb spec/codeball/ball_spec.rb
git commit -m "Make Ball#entries and #warnings private again

These readers were public, exposing the live internal arrays so callers
could push entries/warnings directly and bypass add_entry's warning
bookkeeping. Restore them to private (as on master); nothing reads them
externally. Add a spec locking the encapsulation."
```

---

## Task 3: Correct the `Ball` class doc comment (finding C)

`Ball.load_file` is intentional public API (a factory that reads a ball from a path), but the class comment claims the class "does not touch the filesystem." Update the comment so it accurately distinguishes the I/O-free instance from the `load_file` factory. This is a documentation-only change (comments need no test); it is verified by the suite staying green.

**Files:**
- Modify: `lib/codeball/ball.rb` (class doc comment only)

- [ ] **Step 1: Update the comment**

In `lib/codeball/ball.rb`, replace this exact comment block:

```ruby
  # A codeball -- the aggregate root.
  #
  # Ball starts empty and grows as entries are added, like a snowball.
  # It does not touch the filesystem. Parse is a thin factory that
  # wires Cursor -> Stream -> Ball.
  #
  class Ball
```

with:

```ruby
  # A codeball -- the aggregate root.
  #
  # Ball starts empty and grows as entries are added, like a snowball.
  # An instance holds parsed entries in memory and does no I/O itself.
  # Two class factories build one from source: parse (from an in-memory
  # string, wiring Cursor -> Stream -> Ball) and load_file (which reads
  # the source file from disk, then parses it).
  #
  class Ball
```

- [ ] **Step 2: Verify the suite is still green**

Run: `bundle exec rake`
Expected: Minitest 0 failures, RSpec 0 failures, RuboCop `no offenses detected`. (A comment change must not alter any behavior.)

- [ ] **Step 3: Commit**

```bash
git add lib/codeball/ball.rb
git commit -m "Fix Ball doc comment about filesystem access

The class comment claimed Ball does not touch the filesystem, but the
load_file factory reads from disk. Reword to say an instance does no I/O
while the load_file factory reads the source file."
```

---

## Task 4: Remove the unused `Entry#name=` setter (finding D)

`Entry#name=` has no callers anywhere in `lib`, `exe`, `spec`, or `test`. It sets header and footer but no body, producing an entry that is simultaneously `invalid?` and `truncated?` — a third construction path that contradicts the class's documented write-once Header→Body→Footer invariant. Removing this dead code resolves the contradiction and leaves the class comment accurate. This is a dead-code removal (no test to write); verified by the suite staying green.

**Files:**
- Modify: `lib/codeball/entry.rb` (delete the `name=` method)

- [ ] **Step 1: Confirm it is genuinely unused**

Run: `git grep -nE '\.name\s*=|\bname=' -- lib exe spec test | grep -v 'spec\.name\|spec\.email'`
Expected: exactly one line — the definition `lib/codeball/entry.rb:...:    def name=(name)` — and no callers. If any caller appears, STOP and report (do not delete).

- [ ] **Step 2: Delete the method**

In `lib/codeball/entry.rb`, remove this exact method (including the blank line after it):

```ruby
    def name=(name)
      stringified_name = name.to_s
      self.header = stringified_name
      self.footer = stringified_name
    end

```

- [ ] **Step 3: Verify the suite is still green**

Run: `bundle exec rake`
Expected: Minitest 0 failures, RSpec 0 failures, RuboCop `no offenses detected`. (No spec exercised `name=`, so nothing should break.)

- [ ] **Step 4: Commit**

```bash
git add lib/codeball/entry.rb
git commit -m "Remove unused Entry#name= setter

name= had no callers and set header+footer without a body, yielding an
entry that was both invalid? and truncated? -- a third construction path
that violated the documented Header -> Body -> Footer state machine.
Delete it; entries are built via the Stream and Entry.from_file paths."
```

---

## Task 5: Full verification and push

**Files:** none (verification + git)

- [ ] **Step 1: Run the complete suite as CI does**

Run: `bundle exec rake`
Expected: Minitest `0 failures, 0 errors`; RSpec `0 failures` (243 examples: 239 prior + 2 filter + 2 encapsulation); RuboCop `no offenses detected`. If anything is red, STOP and fix before pushing.

- [ ] **Step 2: Confirm the working tree and commits**

Run:
```bash
git status --short
git log --oneline -5
```
Expected: clean tree; the four new commits (filter hardening, private readers, Ball comment, remove name=) on top of `7aaec25`.

- [ ] **Step 3: Push (updates PR #6)**

These are new commits on top of the already-pushed branch, so a normal push fast-forwards — no force needed:
```bash
git push origin feature/expand-ball-public-api
```
Expected: the push succeeds and PR #6 updates automatically.

- [ ] **Step 4: Report the updated PR URL** (https://github.com/gillisd/codeball/pull/6).

---

## Self-Review

**1. Finding coverage.**
- A (empty-patterns data loss) → Task 1 (`leading.any?` guard) + failing test "finding A". ✓
- E (unreadable file → EACCES) → Task 1 (`File.readable?`) + failing test "finding E" + comment now accurate. ✓
- B (public mutable readers) → Task 2 (private) + encapsulation test. ✓
- C (stale "no filesystem" comment) → Task 3 (comment reworded). ✓
- D (`name=` violates Entry invariant) → Task 4 (method removed). ✓

**2. Placeholder scan.** No TBD/TODO/"handle edge cases"/"similar to". Every code step shows exact before/after; every command has an expected result. ✓

**3. Type/name consistency.**
- `split_source` still returns `[patterns, file]`; `run` (unchanged) destructures `patterns, file =` and `read_input(file)` handles `nil` → stdin. The new guard only changes *which* branch is taken, not the return shape. ✓
- Tests use helpers that exist: `run_codeball`, `create_file`, `entries_in`, `bundle` (filter_spec), and `described_class`, `public_method_defined?`/`private_method_defined?` (ball_spec). ✓
- `File.chmod(0o000, path)` + `Process.uid.zero?` skip guard keeps the E test robust across root/non-root. ✓
- Task 4's deletion matches the exact method body confirmed by `git grep` (single definition, no callers). ✓

**4. Interaction check.** Task 1's `leading.any?` guard does not break existing filter specs: the two-arg file case (`lib/**/*.rb bundle_path`) keeps `leading = ["lib/**/*.rb"]` (non-empty) so the file is still used; all single-arg and multi-pattern-with-non-file-last cases already read stdin. ✓

No gaps found.
