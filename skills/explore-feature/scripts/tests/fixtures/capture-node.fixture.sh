#!/bin/bash
# capture-node.fixture.sh: the Node twin of the Bun fixture: the same lib.ts, main.ts and
# leak.ts (Node runs them by stripping the types), a package.json that says module and
# nothing else, typescript from bun's cache, committed. `build_capture_node_repo <dir>`.
node_fixture_here=${BASH_SOURCE[0]%/*}
[ "$node_fixture_here" = "${BASH_SOURCE[0]}" ] && node_fixture_here=.
# shellcheck source=capture-bun.fixture.sh
. "$node_fixture_here/capture-bun.fixture.sh"

build_capture_node_repo() {
  mkdir -p "$1"
  printf '{ "name": "capture-node-fixture", "private": true, "type": "module" }\n' > "$1/package.json"
  write_capture_sources "$1" || return 1
  commit_capture_repo "$1"
}
