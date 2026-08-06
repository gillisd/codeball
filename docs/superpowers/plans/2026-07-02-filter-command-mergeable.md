# Filter Command — Branch-to-Mergeable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Get the `feature/expand-ball-public-api` branch into a clean, tested, mergeable state — fix the `filter` command's broken FILE-argument handling, add the missing test coverage, and drive `bundle exec rake` (test + spec + RuboCop) fully green — then open a PR into `master`.

**Architecture:** `codeball` is a `command_kit`-based CLI. Each subcommand is a class under `lib/codeball/commands/`. The parsing model (`Ball` → `Entry` → `Header`/`Body`/`Footer`) is filesystem-free. The established idiom for reading "a FILE argument or stdin" is `ARGV.replace(...)` + `ARGF.read` (see `master`'s `unpack`). This plan makes `filter` adopt that idiom, which simultaneously fixes its stdin/FILE bug and removes the `Security/Open` RuboCop offense.

**Tech Stack:** Ruby 3.4+, command_kit ~> 0.6, zeitwerk, RSpec (integration specs), Minitest (unit), RuboCop (rubocop-claude/-minitest/-performance/-rake/-md).

---

## Background & Current State (read before starting)

- We are on branch `feature/expand-ball-public-api`, already **rebased onto current `master`** (tip `Draft of filter`). The rebase is **local only**; `origin/feature/expand-ball-public-api` still holds the pre-rebase commits, so the final push must be `--force-with-lease`.
- `bundle install` succeeds on this branch (it still uses the git-sourced `minitest-reporters`, inherited from `master`; that is fine and out of scope here — see "Sequencing" at the end).
- **Tests currently pass**: Minitest 8/8, RSpec 222/222.
- **RuboCop currently fails** with **13 offenses**:
  - `lib/codeball/commands/filter.rb`: `Style/TrailingCommaInArrayLiteral` (:29), `Metrics/AbcSize` (:32), `Metrics/MethodLength` (:32), `Layout/IndentationWidth` (:34), `Security/Open` (:42)
  - `lib/codeball/commands/unpack.rb`: `Metrics/AbcSize` (:36), `Security/Open` (:61)
  - `tar2ball.rb`: `Style/FileOpen` (:5), `Lint/EmptyClass` (:8), `Layout/BlockAlignment` (:18), `Lint/Debugger` (:22)
  - `tarscript.rb`: `Style/MixinUsage` (:3), `Style/ItBlockParameter` (:9)
- **The `filter` command has a real bug and zero tests.** In `run`, the FILE-vs-stdin decision keys on `stdin.tty?`. When stdin is not a TTY (pipes, scripts, CI — i.e. always in practice), the FILE argument is ignored, swallowed as an extra pattern, and the command reads empty stdin → dies with `no input`. **3 of the 4 examples in its own `--help` use the broken `PATTERN FILE` form.**
- `tar2ball.rb` and `tarscript.rb` are tracked throwaway experiments (contain `binding.irb`, reference an undeclared `Ronin::Support`). They are not required anywhere. They must be deleted for RuboCop to pass and to keep them out of the packaged gem.
- The `warning` gem (added on this branch) is legitimately wired in `lib/codeball.rb` (`require "warning"`, `Warning.ignore(/FileMagic/)`) and the `ruby-filemagic` gemspec dependency was added. **Leave both as-is.**

### File Structure (what this plan touches)

- **Delete:** `tar2ball.rb`, `tarscript.rb` (root-level scratch scripts)
- **Modify:** `lib/codeball/commands/filter.rb` (fix bug + lint), `lib/codeball/commands/unpack.rb` (lint + tidy `-O`)
- **Create:** `spec/integration/filter_spec.rb` (new coverage for `filter`)
- **Modify:** `spec/integration/unpack_spec.rb` (add `-O` coverage)

No other files change.

### Commands you will use repeatedly

- Full suite: `bundle exec rake`
- Just RSpec: `bundle exec rspec`
- One spec file: `bundle exec rspec spec/integration/filter_spec.rb`
- Just RuboCop: `bundle exec rubocop`
- RuboCop on one file: `bundle exec rubocop lib/codeball/commands/filter.rb`

---

## Task 1: Remove throwaway tarball scripts

Deleting these removes 6 of the 13 RuboCop offenses and keeps experiment scripts out of the gem. They are not referenced by any code.

**Files:**
- Delete: `tar2ball.rb`
- Delete: `tarscript.rb`

- [ ] **Step 1: Confirm nothing references the scripts or their symbols**

Run:
```bash
git grep -nE "tar2ball|tarscript|LazyEntry|Ronin" -- '*.rb' Rakefile exe
```
Expected: no matches (empty output). If there are matches, STOP and investigate before deleting.

- [ ] **Step 2: Delete both files**

Run:
```bash
git rm tar2ball.rb tarscript.rb
```
Expected: `rm 'tar2ball.rb'` and `rm 'tarscript.rb'`.

- [ ] **Step 3: Verify their RuboCop offenses are gone**

Run:
```bash
bundle exec rubocop --format simple 2>/dev/null | tail -5
```
Expected: offense count dropped to **7** (the remaining `filter.rb` + `unpack.rb` offenses). No `tar2ball.rb` / `tarscript.rb` lines.

- [ ] **Step 4: Confirm the test suite is unaffected**

Run:
```bash
bundle exec rspec 2>&1 | tail -3
```
Expected: `222 examples, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Remove throwaway tarball experiment scripts

tar2ball.rb and tarscript.rb were scratch experiments (left-in
binding.irb, undeclared Ronin::Support). They are not required by any
code and were being packaged into the gem. Delete them."
```

---

## Task 2: Fix the `filter` FILE/stdin bug and add specs

The bug: `filter PATTERN FILE` ignores `FILE` whenever stdin is not a TTY. The fix: adopt the codebase's `ARGV`/`ARGF` idiom and decide "is the trailing arg a FILE?" by whether it names a readable file on disk — behaving identically interactively and in pipes. This also removes the `Security/Open`, `AbcSize`, `MethodLength`, `IndentationWidth`, and `TrailingCommaInArrayLiteral` offenses in this file.

**Files:**
- Create: `spec/integration/filter_spec.rb`
- Modify: `lib/codeball/commands/filter.rb`

- [ ] **Step 1: Write the failing spec**

Create `spec/integration/filter_spec.rb` with exactly:

```ruby
require_relative "../spec_helper"

RSpec.describe "codeball filter", type: :integration do
  include CLIHelper

  # A ball with entries at several depths so glob semantics are observable.
  let(:bundle) do
    pack_bundle(
      ["lib/app.rb", "puts :app\n"],
      ["lib/nested/helper.rb", "puts :helper\n"],
      ["test/app_test.rb", "puts :test\n"],
      ["README.md", "# readme\n"],
    )
  end
  let(:bundle_path) { create_file("bundle.txt", bundle) }

  # Extract the entry paths from a serialized ball (BEGIN "path" lines).
  def entries_in(ball_text)
    ball_text.scan(/^BEGIN "(.+)"$/).flatten
  end

  describe "with a FILE argument and non-interactive stdin" do
    # Regression: the FILE argument must be honored even when stdin is not a
    # TTY (pipes, scripts, CI). Previously the file was ignored and treated
    # as another pattern, so this errored with "no input".
    let(:result) { run_codeball("filter", "lib/**/*.rb", bundle_path) }

    it "reads the ball from the file and keeps only matching entries" do
      expect(entries_in(result.stdout)).to contain_exactly("lib/app.rb", "lib/nested/helper.rb")
    end

    it "exits 0" do
      expect(result.exit_code).to eq(0)
    end
  end

  describe "reading from stdin" do
    let(:result) { run_codeball("filter", "lib/**/*.rb", stdin: bundle) }

    it "keeps only matching entries" do
      expect(entries_in(result.stdout)).to contain_exactly("lib/app.rb", "lib/nested/helper.rb")
    end
  end

  describe "glob semantics" do
    it "treats '*' as non-recursive (stops at '/')" do
      result = run_codeball("filter", "*.md", stdin: bundle)
      expect(entries_in(result.stdout)).to contain_exactly("README.md")
    end

    it "ORs multiple patterns together" do
      result = run_codeball("filter", "README.md", "test/**", stdin: bundle)
      expect(entries_in(result.stdout)).to contain_exactly("README.md", "test/app_test.rb")
    end
  end

  describe "with --inverse (-v)" do
    let(:result) { run_codeball("filter", "-v", "test/**", stdin: bundle) }

    it "keeps entries that do NOT match" do
      expect(entries_in(result.stdout)).to contain_exactly(
        "lib/app.rb", "lib/nested/helper.rb", "README.md"
      )
    end
  end

  describe "with empty input" do
    let(:result) { run_codeball("filter", "*.rb", stdin: "") }

    it "prints an error to stderr" do
      expect(result.stderr).to include("no input")
    end

    it "exits non-zero" do
      expect(result.exit_code).not_to eq(0)
    end
  end
end
```

- [ ] **Step 2: Run the spec and watch the FILE-argument tests fail**

Run:
```bash
bundle exec rspec spec/integration/filter_spec.rb
```
Expected: FAILURES. Specifically the two examples under "with a FILE argument and non-interactive stdin" fail — `result.exit_code` is `1` and `result.stdout` is empty (`stderr` contains `no input`), because the current code ignores the FILE arg when stdin is not a TTY. (The stdin-based examples will already pass.)

- [ ] **Step 3: Rewrite `filter.rb` to fix the bug and satisfy RuboCop**

Replace the entire contents of `lib/codeball/commands/filter.rb` with:

```ruby
require "command_kit/command"
require "command_kit/colors"

module Codeball
  module Commands
    # Filter entries in a codeball by glob pattern.
    class Filter < CommandKit::Command
      include CommandKit::Colors

      usage "[options] [FILE]"
      description "Filter entries in a codeball"

      option :inverse, short: "-v", desc: "Reverse direction of filtering"

      # Flags chosen so glob semantics match what users expect from shell
      # globs: FNM_PATHNAME makes '*' stop at '/' and enables '**/' for
      # recursive matching; FNM_EXTGLOB enables '{rb,py}' brace expansion.
      FNMATCH_FLAGS = File::FNM_PATHNAME | File::FNM_EXTGLOB

      argument :patterns, required: true, repeats: true, desc: "Patterns to filter on"
      argument :file, required: false, desc: "Codeball file (or stdin if omitted)"

      examples [
        "'*.rb' bundle.txt",
        "'*.rb' < bundle.txt",
        "'lib/**/*.rb' bundle.txt",
        "-v 'test/**' bundle.txt",
      ]

      def run(*args)
        patterns, file = split_source(args)
        ball = Ball.parse(read_input(file))
        report_warnings(ball)
        drop_unmatched(ball, patterns)
        stdout.puts ball.serialize
      end

      private

      # The trailing argument is the codeball file when it names a readable
      # file on disk; otherwise every argument is a pattern and the ball is
      # read from stdin. This behaves the same interactively and in pipes.
      def split_source(args)
        *leading, last = args
        last && File.file?(last) ? [leading, last] : [args, nil]
      end

      def read_input(file)
        ARGV.replace(file ? [file] : [])
        input = ARGF.read
        abort_if_empty(input)
        input
      end

      def report_warnings(ball)
        ball.each_warning { |msg| stderr.puts colors(stderr).yellow("warning: #{msg}") }
      end

      def drop_unmatched(ball, patterns)
        ball.each_entry.reject { match?(patterns, it) }.each { ball.remove_entry(it) }
      end

      def match?(patterns, entry)
        verb = options[:inverse] ? :none? : :any?
        patterns.public_send(verb) { |pattern| File.fnmatch?(pattern, entry.path, FNMATCH_FLAGS) }
      end

      def abort_if_empty(input)
        return unless input.nil? || input.strip.empty?

        print_error "no input"
        exit 1
      end
    end
  end
end
```

Key changes vs. the old file: dropped `require "command_kit/open"` and `include CommandKit::Open` (no longer using `open`); `split_source` replaces the `stdin.tty?` heuristic; `read_input` uses the `ARGV`/`ARGF` idiom; `run` delegates to small helpers to stay under AbcSize/MethodLength; trailing comma added to the `examples` array.

- [ ] **Step 4: Run the spec and confirm it passes**

Run:
```bash
bundle exec rspec spec/integration/filter_spec.rb
```
Expected: all examples pass (0 failures).

- [ ] **Step 5: Confirm RuboCop is clean for this file**

Run:
```bash
bundle exec rubocop lib/codeball/commands/filter.rb
```
Expected: `no offenses detected`.

- [ ] **Step 6: Commit**

```bash
git add lib/codeball/commands/filter.rb spec/integration/filter_spec.rb
git commit -m "Fix filter FILE argument handling and add specs

filter decided FILE-vs-stdin from stdin.tty?, so the documented
'filter PATTERN FILE' form silently failed in any non-interactive
context (pipes, scripts, CI): the file was swallowed as a pattern and
empty stdin was read. Adopt the ARGV/ARGF idiom used by unpack and pick
the source by whether the trailing arg names a file on disk. Add
integration coverage for file/stdin, glob semantics, -v, and empty
input. Also clears the AbcSize/MethodLength/Security/Open offenses."
```

---

## Task 3: Clean up `unpack` RuboCop offenses and cover `-O`

`unpack` gained a `-O` (dump-to-stdout) option on this branch, which introduced an `open`-based read (`Security/Open` at :61) and pushed `run` over `AbcSize` (:36). Revert the read to the `ARGV`/`ARGF` idiom (as on `master`) and extract helpers. The `-O` feature currently has no test — add one first as a safety net, then refactor.

**Files:**
- Modify: `spec/integration/unpack_spec.rb`
- Modify: `lib/codeball/commands/unpack.rb`

- [ ] **Step 1: Add `-O` coverage to the unpack spec**

In `spec/integration/unpack_spec.rb`, insert this `describe` block immediately after the opening `include CLIHelper` line's block — i.e. as the first `describe` inside `RSpec.describe "codeball unpack" ...`, before `describe "extracting from a file argument" do`:

```ruby
  describe "with --stdout (-O)" do
    let(:bundle) do
      pack_bundle(
        ["a.txt", "alpha\n"],
        ["b.txt", "beta\n"],
      )
    end
    let(:result) { run_codeball("unpack", "-O", stdin: bundle) }

    it "writes file contents to stdout" do
      expect(result.stdout).to include("alpha")
      expect(result.stdout).to include("beta")
    end

    it "does not write any files to disk" do
      result
      expect(output_path("a.txt")).not_to exist
      expect(output_path("b.txt")).not_to exist
    end

    it "exits 0" do
      expect(result.exit_code).to eq(0)
    end
  end
```

- [ ] **Step 2: Run the new tests and confirm they PASS against current code**

Run:
```bash
bundle exec rspec spec/integration/unpack_spec.rb -e "with --stdout"
```
Expected: 3 examples, 0 failures. (This characterizes the existing `-O` behavior so the upcoming refactor is guarded.)

- [ ] **Step 3: Rewrite `unpack.rb` to remove `open` and reduce `run`**

Replace the entire contents of `lib/codeball/commands/unpack.rb` with:

```ruby
require "command_kit/command"
require "command_kit/colors"

module Codeball
  module Commands
    # Extract files from a codeball.
    #
    class Unpack < CommandKit::Command
      include CommandKit::Colors

      usage "[options] [FILE]"
      description "Extract files from a codeball"

      option :output_dir, short: "-o",
                          value: { type: String, default: "." },
                          desc: "Output directory"

      option :stdout, short: "-O", desc: "Write file contents to stdout instead of to files. (Analagous to tar -Ox)"
      option :dry_run, short: "-n",
                       desc: "Preview extraction without writing files"

      option :quiet, short: "-q", long: "--quiet", desc: "Suppress non-error output"

      argument :file, required: false,
                      desc: "Codeball file (or stdin if omitted)"

      examples [
        "bundle.txt",
        "-n bundle.txt",
        "-o extracted/ bundle.txt",
        "< bundle.txt",
      ]

      def run(file = nil)
        ball = Ball.parse(read_input(file))
        report_warnings(ball)
        return dump_to_stdout(ball) if options[:stdout]

        extract_to_disk(ball)
      end

      private

      def report_warnings(ball)
        ball.each_warning { |msg| warn colors.yellow("warning: #{msg}") }
      end

      def dump_to_stdout(ball)
        ball.each_entry { |entry| stdout.puts entry.contents }
      end

      def extract_to_disk(ball)
        dest = build_destination
        ball.each_entry { |entry| dest.write(entry) { |outcome| print_outcome(outcome) } }
        print_summary(dest.summary(malformed: ball.warning_count))
      end

      def build_destination
        Destination.new(options[:output_dir], dry_run: options[:dry_run])
      end

      def read_input(file)
        ARGV.replace(file ? [file] : [])
        input = ARGF.read
        abort_on_empty(input)
        input
      end

      def abort_on_empty(input)
        return unless input.nil? || input.strip.empty?

        print_error "no input"
        exit 1
      end

      def puts(...)
        return if options[:quiet]

        stdout.puts(...)
      end

      def warn(...)
        return if options[:quiet]

        stderr.puts(...)
      end

      def print_outcome(outcome)
        case outcome.status
        when :written then print_written(outcome)
        when :dry_run then print_dry_run(outcome)
        when :unsafe  then print_unsafe(outcome)
        when :failed  then print_failed(outcome)
        end
      end

      def print_written(outcome)
        puts "#{colors.green("wrote")}: #{outcome.path} (#{outcome.line_count} lines)"
      end

      def print_dry_run(outcome)
        puts "#{colors.cyan("[dry-run]")} would write: #{outcome.path} (#{outcome.line_count} lines)"
      end

      def print_unsafe(outcome)
        warn colors.yellow("warning: skipping unsafe path #{outcome.path.inspect}")
      end

      def print_failed(outcome)
        warn colors.red("error: #{outcome.path}: #{outcome.error}")
      end

      def print_summary(summary)
        prefix = summary.dry_run? ? "#{colors.cyan("[dry-run]")} " : ""
        puts "---"
        puts "#{prefix}#{summary_parts(summary).join(", ")}"
      end

      def summary_parts(summary)
        parts = [colors.green("extracted: #{summary.extracted}").to_s]
        parts << skipped_part(summary)
        parts << colors.yellow("malformed: #{summary.malformed}") if summary.malformed.positive?
        parts
      end

      def skipped_part(summary)
        if summary.skipped.positive?
          colors.yellow("skipped: #{summary.skipped}")
        else
          "skipped: 0"
        end
      end
    end
  end
end
```

Key changes vs. the old file: dropped `require "command_kit/open"` and `include CommandKit::Open`; `read_input` uses `ARGV`/`ARGF` (no `open`); `run` shrinks by extracting `report_warnings`, `dump_to_stdout`, and `extract_to_disk`; `-O` now emits `entry.contents` (nil-safe String) instead of the raw `Body` object.

- [ ] **Step 4: Run the full unpack spec and confirm green**

Run:
```bash
bundle exec rspec spec/integration/unpack_spec.rb
```
Expected: 0 failures (all pre-existing unpack examples plus the 3 new `-O` examples).

- [ ] **Step 5: Confirm RuboCop is clean for this file**

Run:
```bash
bundle exec rubocop lib/codeball/commands/unpack.rb
```
Expected: `no offenses detected`.

- [ ] **Step 6: Commit**

```bash
git add lib/codeball/commands/unpack.rb spec/integration/unpack_spec.rb
git commit -m "Read unpack input via ARGF, add -O coverage

The -O option introduced an open-based read (Security/Open) and pushed
run over AbcSize. Reuse the ARGV/ARGF idiom for input, extract
report_warnings/dump_to_stdout/extract_to_disk, and emit entry.contents
for -O. Add integration tests for the -O dump-to-stdout path."
```

---

## Task 4: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Run the complete suite exactly as CI does**

Run:
```bash
bundle exec rake
```
Expected, in order:
- Minitest: `8 tests, 14 assertions, 0 failures, 0 errors, 0 skips`
- RSpec: `X examples, 0 failures` where `X` = 222 + 8 new (6 filter + wait, count is informational; the requirement is **0 failures**)
- RuboCop: `NN files inspected, no offenses detected` (file count drops by 2 after the deletions)

If anything is red, STOP and fix before proceeding — do not push a red branch.

- [ ] **Step 2: Sanity-check the branch history**

Run:
```bash
git log --oneline master..HEAD | head -20
git status
```
Expected: your 3 new commits sit on top of the rebased feature commits; working tree clean.

---

## Task 5: Integration — force-push and open the PR

**Files:** none (git/GitHub only)

- [ ] **Step 1: Force-push the rebased + fixed branch**

The branch was rebased locally, so a plain push is rejected; use lease protection:
```bash
git push --force-with-lease origin feature/expand-ball-public-api
```
Expected: `+ <old>...<new> feature/expand-ball-public-api -> feature/expand-ball-public-api (forced update)`.

- [ ] **Step 2: Check whether a PR already exists**

Run:
```bash
gh pr list --head feature/expand-ball-public-api --state open
```
If a PR is listed, skip Step 3 and instead note the URL (the force-push already updated it).

- [ ] **Step 3: Open the PR into master**

Run:
```bash
gh pr create --base master --head feature/expand-ball-public-api \
  --title "Add filter command and expand Ball public API" \
  --body "$(cat <<'BODY'
## Summary

Adds a `codeball filter` subcommand (glob-filter entries in a ball) plus
supporting `Ball` API additions and an `unpack -O` (dump-to-stdout)
option. This PR also makes the branch mergeable: fixes a filter bug,
adds test coverage, and gets RuboCop to zero offenses.

## Highlights

- **`codeball filter PATTERNS... [FILE]`** — keep/drop entries by shell-style
  glob (`FNM_PATHNAME` + `FNM_EXTGLOB`); `-v` inverts. Reads a FILE arg or stdin.
- **Bug fix:** `filter` previously decided FILE-vs-stdin from `stdin.tty?`, so the
  documented `filter PATTERN FILE` form failed in any non-interactive context.
  Now uses the `ARGV`/`ARGF` idiom and picks the source by whether the trailing
  arg names a file on disk.
- **`unpack -O`** — write extracted contents to stdout (analogous to `tar -O`).
- Removed throwaway `tar2ball.rb` / `tarscript.rb` experiments.

## Verification

`bundle exec rake` is green: Minitest 0 failures, RSpec 0 failures, RuboCop
0 offenses. New integration specs cover `filter` (file/stdin, glob semantics,
`-v`, empty input) and `unpack -O`.
BODY
)"
```
Expected: prints the new PR URL.

- [ ] **Step 4: Report the PR URL back to the user.**

---

## Sequencing note (not a task)

PR #5 (`use-released-minitest-reporters`) also edits the `Gemfile`. Whichever PR merges second will need a quick rebase and may hit a trivial `minitest-reporters` line conflict in the `Gemfile`; resolve by keeping the released-gem line from PR #5. This does not block the work above — CI on this branch installs the git-sourced reporter fine.

The `stash@{0}` ("On feature/expand-ball-public-api: stream_to") is an unrelated unfinished `Ball#stream_to` stub. It is **out of scope** and left untouched.

---

## Self-Review

**1. Spec coverage vs. the goal.**
- Fix filter FILE/stdin bug → Task 2 (Step 3, `split_source` + `read_input`), driven by the failing test in Steps 1–2. ✓
- Add missing filter coverage → Task 2 Step 1 (`filter_spec.rb`). ✓
- RuboCop to zero → Task 1 (6 offenses via deletion) + Task 2 (5 filter offenses) + Task 3 (2 unpack offenses) = all 13. ✓
- Cover new `unpack -O` behavior → Task 3 Steps 1–2. ✓
- Green `rake` + PR → Task 4 and Task 5. ✓

**2. Placeholder scan.** No `TODO`/`TBD`/"handle edge cases"/"similar to". Every code step contains full file contents or exact insertions; every command has expected output. ✓

**3. Type/name consistency.**
- `split_source(args)` returns `[patterns, file]`; `run` destructures `patterns, file =` and passes `patterns` to `drop_unmatched`/`match?`. ✓
- `read_input(file)` defined and called in both `filter.rb` and `unpack.rb`; both `filter` (`abort_if_empty`) and `unpack` (`abort_on_empty`) keep their original private guard names. ✓
- Ball API used exists on this branch: `Ball.parse`, `#each_warning`, `#each_entry`, `#remove_entry`, `#serialize`, `#warning_count` (verified in `lib/codeball/ball.rb`); `Entry#contents`, `#path` (verified in `lib/codeball/entry.rb`). ✓
- Spec helpers used exist in `spec/spec_helper.rb`: `run_codeball`, `pack_bundle`, `create_file`, `output_path`. ✓
- `entries_in` regex matches `Entry#serialize` output (`BEGIN "path"`). ✓

No issues found beyond those already fixed inline.
