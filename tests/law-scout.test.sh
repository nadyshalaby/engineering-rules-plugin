#!/bin/bash
# Runs the law scout's shell block straight out of 9.5 against a throwaway git repo with one
# planted instance per construct ban and per banned equivalent, and expects every hit under its
# own rule id, every allowed line left alone, every secret redacted, and an equal coverage pair.
# Run: bash tests/law-scout.test.sh
# LAW_SCOUT_MD points the test at another copy of 9.5, for a watched failure.
# shellcheck source-path=SCRIPTDIR
# shellcheck source=harness.sh
. "$(dirname "${BASH_SOURCE[0]}")/harness.sh"
ROOT=$(repo_root) || exit 1
DOC="${LAW_SCOUT_MD:-$ROOT/skills/engineering-rules/references/09-phase-3-implement/9.5-the-law-scout.md}"

# The HOW block, with its <base>..HEAD placeholder pointed at the fixture's base commit.
extract_block() {
  awk '/^### HOW/ { h = 1 } h && /^```bash$/ { f = 1; next } f && /^```$/ { exit } f' "$DOC" \
    | sed "s/\"<base>..HEAD\"/\"$1..HEAD\"/"
}

# One instance per construct ban, a clean file, a path with a space, a path that starts with
# a dash, and a path that would run as code if it were ever spliced into shell text.
plant_bans() {
  printf 'const ok = 1\n' > src/clean.ts
  printf '// @ts-ignore\nconst a = 1\n' > 'src/my file.ts'
  printf 'try { x() } catch (e) {}\n' > src/empty-catch.ts
  printf 'throw new Error("x")\n' > src/bare.ts
  printf '// TODO fix me\n' > src/todo.ts
  printf '// @ts-ignore\n' > -dash.ts
  printf 'const quiet = 1\n' > 'src/a";echo INJECTED;".ts'
}

# One instance per banned equivalent the law names beside the literal token.
plant_equivalents() {
  printf '// oxlint-disable-next-line no-explicit-any\n' > src/sup-oxlint.ts
  printf '/* istanbul ignore next */\n' > src/sup-coverage.ts
  printf 'x = 1  # noqa\n' > src/sup-python.py
  printf 'try { x() } catch (e) { /* ignore */ }\n' > src/catch-comment.ts
  printf 'load().catch(() => {})\n' > src/catch-promise.ts
  printf 'load().catch(() => { /* ignore */ })\n' > src/catch-promise-comment.ts
  printf 'try {\n} catch (e) {\n  // ignore\n}\n' > src/catch-multiline.ts
  printf 'try {\n} catch (e) {\n\n}\n' > src/catch-blank.ts
  printf 'try:\n    x()\nexcept Exception:\n    pass\n' > src/except-pass.py
  printf 'throw Error("x")\n' > src/bare-no-new.ts
  printf 'return Promise.reject(new Error("x"))\n' > src/bare-reject.ts
  printf 'throw "broke"\n' > src/bare-string.ts
  printf 'const n = count!+1\n' > src/nn-op.ts
  printf 'debugger;\n' > src/dbg.ts
  printf '<!-- TODO fix me -->\n' > src/todo-html.html
  seq 1 501 > 'src/big file.ts'
}

# Rules whose domain is a role or a test file, planted inside and outside that domain.
plant_scoped() {
  mkdir -p src/users src/orders src/ui tests
  printf 'interface Args { a: string; b: number }\n' > src/users/users.service.ts
  printf 'export function create(input: { name: string; email: string }) {}\n' > src/users/users.controller.ts
  printf 'export interface UserDto { id: string; name: string }\n' > src/users/users.types.ts
  printf 'return { data: { user: u, token: t } }\n' > src/orders/orders.controller.ts
  printf 'console.log(order)\n' > src/orders/orders.service.ts
  printf "console.log('render')\n" > src/ui/Button.tsx
  printf "describe.only('x', () => {})\n" > tests/focus.test.ts
  printf "it.skip('flaky', () => {})\n" > tests/skip.test.ts
  printf "it.skip('PROJ-123 flaky', () => {})\n" > tests/skip-ticket.test.ts
  printf "it.skip('mails admin@example.com', () => {})\n" > tests/skip-email.test.ts
  printf "describe.only('x', () => {})\n" > src/only-outside.ts
}

# Test files named the way other languages name them, a skip token in each, one of them owned.
plant_tests_in_other_conventions() {
  mkdir -p spec pkg src/test/java
  printf "xit 'is flaky' do\nend\n" > spec/user_spec.rb
  printf 'func TestX(t *testing.T) { t.Skip("flaky") }\n' > pkg/user_test.go
  printf 'func TestY(t *testing.T) { t.Skip("PROJ-9 flaky") }\n' > pkg/owned_test.go
  printf '@pytest.mark.skip\ndef test_x(): pass\n' > test_user.py
  printf '@Disabled\nvoid userTest() {}\n' > src/test/java/UserTest.java
}

# Lines the law allows, which must stay silent, and secrets, which must come back redacted.
plant_allowed_and_secrets() {
  printf '// TODO(nady): fix me\n' > src/todo-owned.ts
  printf '// TODO: PROJ-123 fix me\n' > src/todo-ticket.ts
  printf 'class A { name!: string }\n' > src/nn-definite.ts
  printf 'if (a != b) {}\n' > src/neq.ts
  printf 'const key = "sk_live_FIXTUREnotArealKey1"\n' > src/secret-stripe.ts
  printf 'const dsn = "postgres://admin:hunter2@db.internal/app"\n' > src/secret-url.ts
  printf 'API_KEY=envsecretvalue2026xyz\n' > .env
  printf -- '-----BEGIN PGP PRIVATE KEY BLOCK-----\n' > src/secret-pgp.txt
  printf '{ "password": "hunter2hunter2hunter2" }\n' > src/secret-json.json
  printf "'password' => 'hunter2hunter2hunter2',\n" > src/secret-php.php
  printf 'smtp_password: hunter2hunter2hunter2\n' > src/secret-yaml.yml
  printf '"smtp_password": hunter2hunter2hunter2\n' > src/secret-quoted-key.yml
  printf 'const password = "P@ssw0rd-Sup3r-Secret!"\n' > src/secret-special.ts
  printf 'export STRIPE_API_KEY=envsecretvalue2026xyz\n' > .envrc
  printf 'db_password=envsecretvalue2026xyz\n' > src/secret.properties
  seq 1 500 > src/at-cap.ts
}

# A postfix `!` in a language where it is not the non-null operator (\044 is the shell's `$`),
# and one in a language where it is.
plant_bangs() {
  printf 'user.save!\n' > src/bang.rb
  printf 'let v = vec![1, 2];\n' > src/bang.rs
  printf 'kill \044!\n' > src/bang.sh
  printf 'final n = user!.name;\n' > src/nn-dart.dart
}

# One instance per cross-language analog the scout carries from 16.7, in that language's file.
plant_analogs() {
  printf 'x := f() // #nosec\n' > src/sup-go.go
  printf '@SuppressWarnings("unchecked")\n' > src/sup-java.java
  printf 'foo(); // @phpstan-ignore-line\n' > src/sup-php.php
  printf 'foo() # rubocop:disable Style/Foo\n' > src/sup-ruby.rb
  printf '#[allow(dead_code)]\n' > src/sup-rust.rs
  printf 'let x = 1 // swiftlint:disable:next force_cast\n' > src/sup-swift.swift
  printf 'x = 1  # pragma: no cover\n' > src/sup-nocover.py
  printf '@file:Suppress("UNCHECKED_CAST")\n' > src/sup-kotlin.kt
  printf '_ = err\n' > src/catch-go.go
  printf 'x rescue nil\n' > src/catch-ruby.rb
  printf 'result.ok();\n' > src/catch-rust.rs
  printf 'raise Exception("boom")\n' > src/bare-python.py
  printf '\treturn errors.New("boom")\n' > src/bare-go.go
  printf '\treturn fmt.Errorf("load: %%w", err)\n' > src/wrap-go.go
  printf 'val n = user!!.name\n' > src/nn-kotlin.kt
  printf 'let v = opt.unwrap();\n' > src/nn-rust.rs
  printf 'let d = try! decode()\n' > src/nn-swift.swift
  printf 'breakpoint()\n' > src/dbg-python.py
  printf 'binding.pry\n' > src/dbg-ruby.rb
}

build_fixture() (
  git init -q "$WORK/repo" && cd "$WORK/repo" || return 1
  git -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m base
  mkdir src
  plant_bans && plant_equivalents && plant_scoped && plant_tests_in_other_conventions \
    && plant_allowed_and_secrets && plant_bangs && plant_analogs || return 1
  git add -- src tests spec pkg test_user.py .env .envrc -dash.ts
  git -c user.name=t -c user.email=t@example.com commit -q -m planted
)

run_block() (
  cd "$WORK/repo" || return 1
  extract_block "$(git rev-parse HEAD~1)" > "$WORK/block.sh"
  SCOUT_PATHS="$WORK/paths" PROJECT_BAN_PATTERNS="$WORK/no-such-file" bash "$WORK/block.sh" 2>&1
)

test_finds_every_planted_ban() {
  assert_contains "suppression in a path with a space" "ban.suppression src/my file.ts:1:// @ts-ignore" "$out"
  assert_contains "suppression in a path that starts with a dash" "ban.suppression -dash.ts:1:// @ts-ignore" "$out"
  assert_contains "empty catch" "ban.empty-catch src/empty-catch.ts:1:" "$out"
  assert_contains "bare throw" "ban.bare-error src/bare.ts:1:" "$out"
  assert_contains "debt marker" "clean.debt-marker src/todo.ts:1:" "$out"
  assert_missing "the clean file stays silent" "src/clean.ts" "$out"
  assert_missing "no path text ever runs as code" "INJECTED" "$out"
  untagged=$(printf '%s\n' "$out" | grep -vE '^(ban|cap|sec|test|clean)\.[a-z-]+ ' | grep -vE '^[[:space:]]*[0-9]+$')
  assert_contains "every printed line carries its rule id, or is a coverage count" "<none>" "${untagged:-<none>}"
  pair=$(printf '%s\n' "$out" | tail -n 2 | tr -d ' ' | tr '\n' '/')
  assert_contains "coverage pair: every planted path handed in and readable" "$PLANTED/$PLANTED/" "$pair"
}

test_finds_every_equivalent() {
  assert_contains "oxlint suppression" "ban.suppression src/sup-oxlint.ts:1:" "$out"
  assert_contains "coverage-ignore marker" "ban.suppression src/sup-coverage.ts:1:" "$out"
  assert_contains "python noqa suppression" "ban.suppression src/sup-python.py:1:" "$out"
  assert_contains "comment-only catch body" "ban.empty-catch src/catch-comment.ts:1:" "$out"
  assert_contains "promise .catch(() => {})" "ban.empty-catch src/catch-promise.ts:1:" "$out"
  assert_contains "promise catch with a comment-only body" "ban.empty-catch src/catch-promise-comment.ts:1:" "$out"
  assert_contains "catch closed on a later line" "ban.empty-catch src/catch-multiline.ts:2:" "$out"
  assert_contains "empty catch with a blank line inside" "ban.empty-catch src/catch-blank.ts:2:" "$out"
  assert_contains "python except: pass" "ban.empty-catch src/except-pass.py:3:" "$out"
  assert_contains "throw Error without new" "ban.bare-error src/bare-no-new.ts:1:" "$out"
  assert_contains "Promise.reject(new Error)" "ban.bare-error src/bare-reject.ts:1:" "$out"
  assert_contains "thrown string literal" "ban.bare-error src/bare-string.ts:1:" "$out"
  assert_contains "non-null before an operator" "ban.non-null src/nn-op.ts:1:" "$out"
  assert_contains "debugger statement" "clean.debug-artifact src/dbg.ts:1:" "$out"
  assert_contains "html debt marker" "clean.debt-marker src/todo-html.html:1:" "$out"
  assert_contains "file cap names the whole path" "cap.file-lines src/big file.ts: 501 lines" "$out"
  assert_contains "inline interface in a service" "ban.inline-type src/users/users.service.ts:1:" "$out"
  assert_contains "inline type literal in a controller signature" "ban.inline-type src/users/users.controller.ts:1:" "$out"
  assert_contains "console in a domain role" "clean.debug-artifact src/orders/orders.service.ts:1:" "$out"
  assert_contains "focused test" "test.focused tests/focus.test.ts:1:" "$out"
  assert_contains "skipped test with no ticket" "test.skipped tests/skip.test.ts:1:" "$out"
  assert_contains "an email in a skip reason is not an owner" "test.skipped tests/skip-email.test.ts:1:" "$out"
  assert_contains "a named but missing ban file is said out loud" "ban.custom skipped:" "$out"
}

test_finds_every_test_file_convention() {
  assert_contains "rspec xit under spec/" "test.skipped spec/user_spec.rb:1:" "$out"
  assert_contains "go t.Skip in a _test.go" "test.skipped pkg/user_test.go:1:" "$out"
  assert_contains "pytest skip in a test_ module" "test.skipped test_user.py:1:" "$out"
  assert_contains "junit Disabled under src/test/" "test.skipped src/test/java/UserTest.java:1:" "$out"
  assert_missing "a go skip naming a ticket is owned" "owned_test.go" "$out"
}

test_finds_every_language_analog() {
  assert_contains "go nosec suppression" "ban.suppression src/sup-go.go:1:" "$out"
  assert_contains "java SuppressWarnings" "ban.suppression src/sup-java.java:1:" "$out"
  assert_contains "php phpstan ignore" "ban.suppression src/sup-php.php:1:" "$out"
  assert_contains "ruby rubocop disable" "ban.suppression src/sup-ruby.rb:1:" "$out"
  assert_contains "rust allow attribute" "ban.suppression src/sup-rust.rs:1:" "$out"
  assert_contains "swift swiftlint disable" "ban.suppression src/sup-swift.swift:1:" "$out"
  assert_contains "python pragma no cover" "ban.suppression src/sup-nocover.py:1:" "$out"
  assert_contains "kotlin file-level Suppress" "ban.suppression src/sup-kotlin.kt:1:" "$out"
  assert_contains "go error discarded into _" "ban.empty-catch src/catch-go.go:1:" "$out"
  assert_contains "ruby inline rescue nil" "ban.empty-catch src/catch-ruby.rb:1:" "$out"
  assert_contains "rust .ok() dropping a Result" "ban.empty-catch src/catch-rust.rs:1:" "$out"
  assert_contains "python raise Exception" "ban.bare-error src/bare-python.py:1:" "$out"
  assert_contains "go errors.New inside a function" "ban.bare-error src/bare-go.go:1:" "$out"
  assert_missing "go fmt.Errorf with %w is a wrap, not a bare error" "wrap-go.go" "$out"
  assert_contains "kotlin double bang" "ban.non-null src/nn-kotlin.kt:1:" "$out"
  assert_contains "rust unwrap" "ban.non-null src/nn-rust.rs:1:" "$out"
  assert_contains "swift try!" "ban.non-null src/nn-swift.swift:1:" "$out"
  assert_contains "dart postfix bang" "ban.non-null src/nn-dart.dart:1:" "$out"
  assert_contains "python breakpoint()" "clean.debug-artifact src/dbg-python.py:1:" "$out"
  assert_contains "ruby binding.pry" "clean.debug-artifact src/dbg-ruby.rb:1:" "$out"
}

test_leaves_the_allowed_alone_and_redacts_secrets() {
  assert_missing "interface in its own types file" "users.types.ts" "$out"
  assert_missing "a nested object literal is not an inline type" "orders.controller.ts" "$out"
  assert_missing "console outside a domain role" "Button.tsx" "$out"
  assert_missing "owned TODO" "todo-owned.ts" "$out"
  assert_missing "ticketed TODO" "todo-ticket.ts" "$out"
  assert_missing "skipped test naming a ticket" "skip-ticket.test.ts" "$out"
  assert_missing ".only outside a test file" "only-outside.ts" "$out"
  assert_missing "definite assignment is not a non-null assertion" "nn-definite.ts" "$out"
  assert_missing "!= is not a non-null assertion" "neq.ts" "$out"
  assert_missing "a ruby bang method is not a non-null assertion" "bang.rb" "$out"
  assert_missing "a rust macro bang is not a non-null assertion" "bang.rs" "$out"
  assert_missing "a shell background-pid bang is not a non-null assertion" "bang.sh" "$out"
  assert_missing "a file exactly at the cap stays silent" "at-cap.ts" "$out"
  assert_contains "stripe key found" "sec.hardcoded-secret src/secret-stripe.ts:1:" "$out"
  assert_missing "stripe key redacted" "sk_live_FIXTUREnotArealKey1" "$out"
  assert_contains "url credentials found" "sec.hardcoded-secret src/secret-url.ts:1:" "$out"
  assert_missing "url password redacted" "hunter2" "$out"
  assert_contains "env file value found" "sec.hardcoded-secret .env:1:" "$out"
  assert_missing "env file value redacted" "envsecretvalue2026xyz" "$out"
  assert_contains "pgp private key block" "sec.hardcoded-secret src/secret-pgp.txt:1:" "$out"
  assert_contains "json password found" "sec.hardcoded-secret src/secret-json.json:1:" "$out"
  assert_contains "php array password found" "sec.hardcoded-secret src/secret-php.php:1:" "$out"
  assert_contains "yaml unquoted password found" "sec.hardcoded-secret src/secret-yaml.yml:1:" "$out"
  assert_contains "yaml quoted key, unquoted password found" "sec.hardcoded-secret src/secret-quoted-key.yml:1:" "$out"
  assert_contains "password with symbols found" "sec.hardcoded-secret src/secret-special.ts:1:" "$out"
  assert_contains "exported env key found" "sec.hardcoded-secret .envrc:1:" "$out"
  assert_contains "lowercase properties key found" "sec.hardcoded-secret src/secret.properties:1:" "$out"
  assert_missing "every hunter2 value redacted" "hunter2hunter2hunter2" "$out"
  assert_missing "the symbol password redacted" "Sup3r-Secret" "$out"
}

test_refuses_a_list_without_nul() {
  printf 'src/clean.ts\nsrc/todo.ts\n' > "$WORK/newline-paths"
  guard=$(grep -F 'not NUL-separated' "$WORK/block.sh")
  out=$(SCOUT_PATHS="$WORK/newline-paths" bash -c "$guard" 2>&1; echo "exit=$?")
  assert_contains "a list built without -z is refused" "SCOUT_PATHS is not NUL-separated" "$out"
  assert_contains "and the block stops" "exit=1" "$out"
}

test_runs_under_set_u_with_no_ban_file() {
  out=$(cd "$WORK/repo" && env -u PROJECT_BAN_PATTERNS SCOUT_PATHS="$WORK/paths" bash -u "$WORK/block.sh" 2>&1)
  assert_missing "no ban-patterns file is not an unbound variable" "unbound variable" "$out"
}

build_fixture || { printf 'FAIL could not build the fixture repo\n'; exit 1; }
PLANTED=$(git -C "$WORK/repo" ls-files | wc -l | tr -d ' ')
out=$(run_block)
test_finds_every_planted_ban
test_finds_every_equivalent
test_finds_every_test_file_convention
test_finds_every_language_analog
test_leaves_the_allowed_alone_and_redacts_secrets
test_refuses_a_list_without_nul
test_runs_under_set_u_with_no_ban_file
report
