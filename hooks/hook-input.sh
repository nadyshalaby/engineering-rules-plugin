#!/bin/bash
# Shared by every hook script here: the JSON Claude Code writes on stdin, read once and
# validated before any field is used. A hook with no jq, no input or input that is not JSON
# has nothing to judge, so read_hook_input returns 1 and the caller exits 0 with no output.

# read_hook_input: reads stdin into $input; returns 1 when it cannot be used.
read_hook_input() {
  command -v jq >/dev/null 2>&1 || return 1
  input=$(cat)
  printf '%s' "$input" | jq -e . >/dev/null 2>&1
}

# hook_field <jq expression>: one field of the input, raw, empty when absent.
hook_field() {
  printf '%s' "$input" | jq -r "$1"
}
