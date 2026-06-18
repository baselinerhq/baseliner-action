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
| `version` | `v0.2.1` | baseliner version to install (or `latest`). |
| `config` | `baseliner.yaml` | Path to the config file. |
| `format` | `both` | `json`, `table`, or `both`. |
| `output-file` | — | Write JSON results here. |
| `sarif-file` | — | Write SARIF 2.1.0 here (for code scanning). |
| `fail-under` | — | Exit 1 if any repo scores below this (`0.0`–`1.0`). |
| `open-issues` | `false` | Open/update a findings issue per repo. |
| `public-context` | auto | Protect private/internal repos when the output is public. Empty auto-detects from this repo's visibility (on when public, off when private); set `true`/`false` to override. |
| `extra-args` | — | Extra arguments appended to `baseliner scan`. |
| `working-directory` | `.` | Directory to run from. |
| `github-token` | `${{ github.token }}` | Token for GitHub scanning / `--open-issues`. |

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
below `--fail-under`), exit 2 on a config/auth/runtime error. See the
[baseliner docs](https://baselinerhq.github.io).

## License

MIT.
