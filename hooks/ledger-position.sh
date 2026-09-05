#!/bin/bash
# Shared by progress-notify.sh and statusline.sh: the phase-ledger heading Claude prints,
# "## 0. Phase ledger  (3 of 6, Phase 4)", and how to read the position out of it.
LEDGER_HEADING='## 0\. Phase ledger +\([^)]*\)'
LEDGER_PREFIX='## 0. Phase ledger'

# read_ledger_position: text on stdin, the last "(N of M, Phase X)" on stdout, empty when none.
read_ledger_position() {
  heading=$(grep -E -o "$LEDGER_HEADING" | tail -n 1)
  position="${heading#"$LEDGER_PREFIX"}"
  printf '%s' "${position#"${position%%[![:space:]]*}"}"
}
