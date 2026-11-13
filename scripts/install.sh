#!/usr/bin/env bash
# Install the baseliner binary for this action, verified before it runs.
#
# This script ships with the action, so the code that installs baseliner is
# pinned by the action ref the workflow uses, not fetched from a branch. The
# archive must match its release's checksums.txt and carry a build provenance
# attestation from baseliner's release workflow at the requested tag; an
# archive that fails either check is not installed.
#
# Env:
#   VERSION       version to install, vX.Y.Z (v0.3.0 or later) or 'latest'
#   GITHUB_TOKEN  optional; authenticates the github.com API calls when this
#                 runner belongs to github.com (anonymous calls are
#                 rate-limited on shared IPs)
#   BINDIR        install dir (default: $HOME/.local/bin)
set -euo pipefail

REPO="baselinerhq/baseliner"
WORKFLOW="${REPO}/.github/workflows/release.yml"
BINDIR="${BINDIR:-$HOME/.local/bin}"

fail() {
  echo "::error::$1" >&2
  exit 1
}

for tool in gh jq curl; do
  command -v "$tool" >/dev/null 2>&1 ||
    fail "$tool is needed to verify baseliner's build provenance; install it on this runner"
done

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$arch" in
  x86_64 | amd64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *) fail "unsupported architecture: $arch" ;;
esac
case "$os" in
  linux | darwin) ;;
  *) fail "unsupported OS: $os" ;;
esac

# The release and its attestations live on github.com. Send the token there
# only when this runner belongs to github.com: on GitHub Enterprise Server it
# is that server's token, so the calls go anonymous.
auth=()
case "${GITHUB_SERVER_URL:-https://github.com}" in
  https://github.com | https://github.com/)
    [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}") ;;
esac
api() {
  curl -fsSL --retry 3 -H "Accept: application/vnd.github+json" ${auth[@]+"${auth[@]}"} \
    "https://api.github.com/$1"
}

ver="${VERSION:-latest}"
if [ "$ver" = "latest" ]; then
  ver=$(api "repos/${REPO}/releases/latest" | jq -r .tag_name) ||
    fail "could not resolve the latest baseliner release; pin a version with the 'version' input"
fi
[[ "$ver" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "version must be vX.Y.Z or 'latest', got '${ver}'"

archive="baseliner_${os}_${arch}.tar.gz"
base="https://github.com/${REPO}/releases/download/${ver}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "downloading ${base}/${archive}"
curl -fsSL --retry 3 -o "$tmp/$archive" "${base}/${archive}"
curl -fsSL --retry 3 -o "$tmp/checksums.txt" "${base}/checksums.txt"

want=$(awk -v f="$archive" '$2 == f { print $1 }' "$tmp/checksums.txt")
if command -v sha256sum >/dev/null 2>&1; then
  got=$(sha256sum "$tmp/$archive" | cut -d' ' -f1)
else
  got=$(shasum -a 256 "$tmp/$archive" | cut -d' ' -f1)
fi
if [ -z "$want" ] || [ "$got" != "$want" ]; then
  fail "${archive} does not match the ${ver} release's checksums.txt; not installing"
fi

# Built by baseliner's release workflow, from the tag asked for, on a
# GitHub-hosted runner. Releases before v0.3.0 carry no attestation. The
# bundle is fetched here and checked offline, so gh needs no login.
if ! api "repos/${REPO}/attestations/sha256:${got}" 2>/dev/null |
  jq -ce '.attestations[].bundle' >"$tmp/bundle.jsonl"; then
  fail "${archive} from ${ver} has no build provenance attestation (releases before v0.3.0 have none); not installing"
fi
if ! env -u GH_TOKEN -u GITHUB_TOKEN GH_HOST=github.com gh attestation verify "$tmp/$archive" \
  --bundle "$tmp/bundle.jsonl" \
  --repo "$REPO" \
  --signer-workflow "$WORKFLOW" \
  --source-ref "refs/tags/${ver}" \
  --deny-self-hosted-runners >"$tmp/verify.log" 2>&1; then
  cat "$tmp/verify.log" >&2
  fail "${archive} from ${ver} has no valid build provenance from ${WORKFLOW} at ${ver} (releases before v0.3.0 have none); not installing"
fi
echo "verified ${archive} ${ver}: SHA-256 ${got}, built by ${WORKFLOW}"

tar -xzf "$tmp/$archive" -C "$tmp" baseliner
mkdir -p "$BINDIR"
install -m 0755 "$tmp/baseliner" "$BINDIR/baseliner"
"$BINDIR/baseliner" --version
