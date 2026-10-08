#!/usr/bin/env bash
# Normalise the public-context input: print "true", "false", or "" (auto-detect).
# Surrounding whitespace and case are ignored; anything else is an error rather
# than a silent "off", since "True" or "yes" means the author wanted it on.
set -euo pipefail

in="${1-}"
v="${in#"${in%%[![:space:]]*}"}"
v="${v%"${v##*[![:space:]]}"}"
v="${v,,}"

case "$v" in
  "" | true | false) printf '%s\n' "$v" ;;
  *)
    # Escape so a newline in the value can't start a new workflow command.
    esc=${in//'%'/'%25'}
    esc=${esc//$'\r'/'%0D'}
    esc=${esc//$'\n'/'%0A'}
    echo "::error::public-context must be true, false, or empty to auto-detect; got '$esc'"
    exit 1
    ;;
esac
