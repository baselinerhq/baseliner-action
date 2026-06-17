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
| `version` | `v0.2.0` | baseliner version to install (or `latest`). |
| `config` | `baseliner.yaml` | Path to the config file. |
| `format` | `both` | `json`, `table`, or `both`. |
| `output-file` | — | Write JSON results here. |
| `sarif-file` | — | Write SARIF 2.1.0 here (for code scanning). |
| `fail-under` | — | Exit 1 if any repo scores below this (`0.0`–`1.0`). |
| `open-issues` | `false` | Open/update a findings issue per repo. |
| `extra-args` | — | Extra arguments appended to `baseliner scan`. |
| `working-directory` | `.` | Directory to run from. |
| `github-token` | `${{ github.token }}` | Token for GitHub scanning / `--open-issues`. |

## Exit behavior

The action fails the step when baseliner exits non-zero — exit 1 on findings (or
below `--fail-under`), exit 2 on a config/auth/runtime error. See the
[baseliner docs](https://baselinerhq.github.io).

## License

MIT.
