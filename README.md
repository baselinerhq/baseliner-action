# baseliner-action

GitHub Action for [baseliner](https://github.com/baselinerhq/baseliner) — scan a
fleet of repositories against a configurable baseline policy. One step instead of
the install-script boilerplate.

## Usage

```yaml
- uses: actions/checkout@v4

- uses: baselinerhq/baseliner-action@v1
  with:
    config: baseliner.yaml
    fail-under: "0.8"
  env:
    GITHUB_TOKEN: ${{ secrets.BASELINER_TOKEN }}
```

### Upload findings to code scanning (SARIF)

```yaml
- uses: baselinerhq/baseliner-action@v1
  with:
    config: baseliner.yaml
    sarif-file: results.sarif
  env:
    GITHUB_TOKEN: ${{ secrets.BASELINER_TOKEN }}

- uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: results.sarif
```

(The job needs `permissions: security-events: write` for the upload.)

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `version` | `v0.2.7` | baseliner version to install (or `latest`). |
| `config` | `baseliner.yaml` | Path to the config file. |
| `format` | `both` | `json`, `table`, or `both`. |
| `output-file` | — | Write JSON results here. |
| `sarif-file` | — | Write SARIF 2.1.0 here (for code scanning). |
| `fail-under` | — | Exit 1 if any repo scores below this (`0.0`–`1.0`). |
| `open-issues` | `false` | Open/update a findings issue per repo. |
| `public-context` | auto | Protect private/internal repos when the output is public. Empty auto-detects from this repo's visibility (on when public, off when private); set `true` to force it on, or `false` to leave it to `privacy.public_context` in your config (case-insensitive). Any other value fails the step rather than leaving the guard off. Needs baseliner v0.2.1 or later. |
| `extra-args` | — | Extra arguments appended to `baseliner scan`. |
| `working-directory` | `.` | Directory to run from. |
| `github-token` | `${{ github.token }}` | Token for GitHub scanning / `--open-issues`. The default only reaches the repo the workflow runs in; see [Token](#token). |
| `api-url` | — | GitHub API root for the scan. Empty uses the runner's `GITHUB_API_URL`. |

baseliner (v0.2.5+) takes its API root from `GITHUB_API_URL`, which Actions sets
on every runner — on GitHub Enterprise Server, to that server's API — and which
`env:` can't override. To scan a github.com org from a GHES runner, set
`api-url: https://api.github.com`, or the token is sent to the GHES API.

## Token

The default `github-token` is the workflow's own `GITHUB_TOKEN`. Its
permissions are limited to the repo the workflow runs in: elsewhere it can read
public repos only, and it cannot write issues. With it, an org scan silently
covers only the public repos, and `open-issues: true` cannot write findings
issues into other repos, so the run exits 2.

For a fleet scan, pass a PAT or GitHub App token that can read every scanned
repo and, for `open-issues`, has Issues read and write on each of them. Either
form works; a token set in the step's `env:` (as in the examples above) takes
precedence over the input's default:

```yaml
- uses: baselinerhq/baseliner-action@v1
  with:
    github-token: ${{ secrets.BASELINER_TOKEN }}
    open-issues: true
```

Scanning only this repo with the default token works, but `open-issues` then
needs `permissions: issues: write` on the job.

## Upgrading to baseliner v0.2.7

This version of the action installs baseliner v0.2.7 by default. For a workflow
using this action:

- **Evidence that could not be read is `unknown`, not a failure.** A file check
  whose directory listing or README could not be read (for example a token
  without Contents read) reports `unknown`, which lowers coverage. With
  `--min-coverage 1.0` (through `extra-args`), such a run is now red, where it
  used to be green with the checks failing as if the files were missing.
- **A findings issue isn't closed on evidence that could not be read.** With
  `open-issues`, a check the issue lists as failing that is `unknown` this run
  stays in the issue as "last seen failing".
- **The privacy guard is stricter.** Private repo names are redacted in any
  letter case, and `exclude` mode leaves no trace of excluded repos in the log.
  A private control repo's guard is still left to its config: the action passes
  no flag for it and hides `GITHUB_ACTIONS`, under which baseliner v0.2.7 would
  otherwise turn the guard on.

To stay on the previous release, set `version: v0.2.6`.
See the [v0.2.7 release notes](https://github.com/baselinerhq/baseliner/releases/tag/v0.2.7).

## Privacy in public control repos

If this control repo is **public** but its token can read **private** repos, the
action enables baseliner's privacy guard automatically (detected from the repo's
visibility), so private repo names and findings are not leaked into the public
Actions log or artifacts. Private/internal repos are redacted by default; choose
the treatment with `privacy.private_repos` in `baseliner.yaml`
(`redact` | `exclude` | `fail` | `allow`). Per-repo findings issues
(`open-issues`) still open inside each private repo. See the
[privacy guard docs](https://baselinerhq.github.io/control-repo#privacy-scanning-private-repos-from-a-public-control-repo).

## Exit behavior

The action fails the step when baseliner exits non-zero — exit 1 on findings (or
below `--fail-under`), exit 2 on a config/auth/runtime error or, with
`open-issues`, when a findings issue could not be searched for or written
(archived repos and repos with Issues disabled are skipped). See the
[baseliner docs](https://baselinerhq.github.io).

## License

MIT.
