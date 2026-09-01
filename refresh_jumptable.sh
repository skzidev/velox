#!/usr/bin/env bash
# refresh_jumptable.sh — Re-fetch the latest velox-jumptable dependency.
#
# Removes the cached velox_jumptable package from zig-pkg/ and runs
# `zig fetch --save` to download the latest version from GitHub.

rm $(find ./zig-pkg -maxdepth 1 -name "*velox_jumptable*") -r
echo "removed old version. installing new one:"
zig fetch --save "git+https://github.com/skzidev/velox-jumptable"
