#!/usr/bin/env bash
# Verify that a baseliner release archive was built by a given workflow of
# baselinerhq/baseliner, from a given tag, on a GitHub-hosted runner.
#
#   verify-provenance.sh <archive> <tag> <workflow path in the repo>
#
# The attestation bundle is fetched from the GitHub API and checked offline,
# so gh needs no login. Env: GITHUB_TOKEN, sent only when this runner belongs
# to github.com (on GitHub Enterprise Server it is that server's token).
set -euo pipefail

REPO="baselinerhq/baseliner"
archive=$1 tag=$2 workflow=$3

fail() {
  echo "::error::$1" >&2
  exit 1
}

for tool in gh jq curl; do
  command -v "$tool" >/dev/null 2>&1 ||
    fail "$tool is needed to verify baseliner's build provenance; install it on this runner"
done
# Older gh releases lack --source-ref, which pins the tag.
help=$(gh attestation verify --help 2>&1 || true)
[[ "$help" == *--source-ref* ]] ||
  fail "this runner's gh cannot pin an attestation to a tag (no 'attestation verify --source-ref'); update gh"

auth=()
case "${GITHUB_SERVER_URL:-https://github.com}" in
  https://github.com | https://github.com/)
    [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}") ;;
esac

if command -v sha256sum >/dev/null 2>&1; then
  digest=$(sha256sum "$archive" | cut -d' ' -f1)
else
  digest=$(shasum -a 256 "$archive" | cut -d' ' -f1)
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=$(curl -sSL --retry 3 -o "$tmp/attestations.json" -w '%{http_code}' \
  -H "Accept: application/vnd.github+json" ${auth[@]+"${auth[@]}"} \
  "https://api.github.com/repos/${REPO}/attestations/sha256:${digest}") ||
  fail "could not reach the GitHub API to fetch the build provenance of $(basename "$archive")"
case "$status" in
  200) ;;
  404) fail "$(basename "$archive") from ${tag} has no build provenance attestation (releases before v0.3.0 have none); not installing" ;;
  *) fail "the GitHub API answered HTTP ${status} when fetching the build provenance of $(basename "$archive"); not installing" ;;
esac
jq -ce '.attestations[].bundle' "$tmp/attestations.json" >"$tmp/bundle.jsonl" ||
  fail "the build provenance response for $(basename "$archive") held no attestation bundle; not installing"

if ! env -u GH_TOKEN -u GITHUB_TOKEN GH_HOST=github.com gh attestation verify "$archive" \
  --bundle "$tmp/bundle.jsonl" \
  --repo "$REPO" \
  --signer-workflow "${REPO}/${workflow}" \
  --source-ref "refs/tags/${tag}" \
  --deny-self-hosted-runners; then
  fail "$(basename "$archive") is not attested as built by ${REPO}/${workflow} at ${tag} on a GitHub-hosted runner; not installing"
fi
