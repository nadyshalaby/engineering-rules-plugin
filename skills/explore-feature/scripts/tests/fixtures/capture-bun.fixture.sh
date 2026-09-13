#!/bin/bash
# capture-bun.fixture.sh: a small Bun project the capture is run over, and a v2 trace over
# its lib.ts, for capture-run.test.sh. lib.ts holds three functions (an async one with a
# branch, one that throws on a negative, an arrow handing back a promise); main.ts calls all three, once with an
# email and once past the throw; leak.ts hands the runner an AWS-shaped key assembled at
# runtime, so no literal sits in this file; lib.test.ts is a bun:test case; server.ts serves
# on port 0 and writes the port it got to $PORT_FILE, never into the repo. The repo carries
# its own `typescript`, from bun's cache, and is committed, so a test can prove the runner
# leaves it untouched. `write_capture_trace <dir> <trace.json>` writes the trace with root
# pointing at the directory.

write_capture_lib() {
  cat > "$1/lib.ts" <<'EOF'
export async function greet(name: string, extra: { n: number }): Promise<string> {
  if (extra.n > 1) return `hi ${name} x${extra.n}`
  return `hi ${name}`
}
export function check(n: number): number {
  if (n < 0) throw new RangeError('negative')
  return n * 2
}
export const arrow = (a: number) => Promise.resolve(a + 1)
EOF
}

write_capture_main() {
  cat > "$1/main.ts" <<'EOF'
import { greet, check, arrow } from './lib.ts'
console.log(await greet('nady', { n: 2 }), await greet('x@y.io', { n: 1 }), check(2), await arrow(1))
try { check(-1) } catch (err) { console.log('caught', (err as Error).message) }
EOF
  cat > "$1/leak.ts" <<'EOF'
import { greet } from './lib.ts'
// The AWS documentation example key, assembled at runtime so no literal sits here.
console.log(await greet(['AKIA', 'IOSFODNN', '7EXAMPLE'].join(''), { n: 1 }))
EOF
}

write_capture_bun_only() {
  cat > "$1/lib.test.ts" <<'EOF'
import { test, expect } from 'bun:test'
import { greet } from './lib.ts'
test('greets', async () => { expect(await greet('t', { n: 1 })).toBe('hi t') })
EOF
  cat > "$1/server.ts" <<'EOF'
import { greet } from './lib.ts'
const server = Bun.serve({
  port: 0,
  async fetch(req) {
    const url = new URL(req.url)
    return new Response(await greet(url.searchParams.get('name') || 'anon', { n: 1 }))
  },
})
await Bun.write(String(process.env.PORT_FILE), String(server.port))
EOF
}

# write_capture_sources <dir>: the sources both fixtures share, and typescript 5 from bun's
# cache (typescript 7 ships the Go compiler only, no API for the rewriter to call).
write_capture_sources() {
  mkdir -p "$1"
  write_capture_lib "$1"
  write_capture_main "$1"
  printf 'node_modules\n' > "$1/.gitignore"
  (cd "$1" && bun add -d typescript@5 > /dev/null 2>&1)
}

# commit_capture_repo <dir>: explicit paths, so `git status --porcelain` afterwards is the claim.
commit_capture_repo() {
  git -C "$1" init -q
  git -C "$1" add .gitignore package.json lib.ts main.ts leak.ts
  [ -f "$1/bun.lock" ] && git -C "$1" add bun.lock
  [ -f "$1/lib.test.ts" ] && git -C "$1" add lib.test.ts server.ts
  git -C "$1" -c user.name=fixture -c user.email=fixture@example.test commit -q -m 'capture fixture'
}

# build_capture_bun_repo <dir>: the Bun project, committed.
build_capture_bun_repo() {
  mkdir -p "$1"
  printf '{ "name": "capture-bun-fixture", "private": true, "type": "module", "scripts": { "t": "bun test lib.test.ts" } }\n' > "$1/package.json"
  write_capture_sources "$1" || return 1
  write_capture_bun_only "$1"
  commit_capture_repo "$1"
}

# write_capture_trace <dir> <trace.json>: one hop over the whole of lib.ts.
write_capture_trace() {
  mkdir -p "$(dirname "$2")"
  jq -n --arg root "$(cd "$1" && pwd -P)" '{ version: 2, root: $root, hops: [ { id: "h0", file: "lib.ts", line: 1, range: [1, 9] } ] }' > "$2"
}
