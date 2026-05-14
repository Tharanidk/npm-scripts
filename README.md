# Dependency check scripts

Two scripts for inspecting npm dependency versions across portals (`admin`, `publisher`, `devportal`).

- **`check-deps.sh`** — versions in your **current local branch** (uses installed `node_modules`)
- **`check-deps-branches.sh`** — versions across **multiple APIM versions** (reads lockfiles from upstream)

Run both from the repo root.

---

## check-deps.sh

Find the installed versions of npm dependencies across all portals in the current branch.

### Check a single dependency

```bash
./check-deps.sh <pkg>
```

Example:

```bash
./check-deps.sh ajv
```

```
┌────────────┬────────────────┬────────────────┬────────────────┬────────────────┐
│ dependency │ admin          │ publisher      │ devportal      │ all installed  │
├────────────┼────────────────┼────────────────┼────────────────┼────────────────┤
│ ajv        │ 6.15.0, 8.20.0 │ 6.15.0, 8.20.0 │ 6.15.0, 8.20.0 │ 6.15.0, 8.20.0 │
└────────────┴────────────────┴────────────────┴────────────────┴────────────────┘
```

### Check multiple dependencies

Pass them space-separated:

```bash
./check-deps.sh <pkg1> <pkg2> <pkg3> ...
```

Example:

```bash
./check-deps.sh ajv follow-redirects semver
```

```
┌──────────────────┬─────────────────────┬─────────────────────┬─────────────────────┬─────────────────────┐
│ dependency       │ admin               │ publisher           │ devportal           │ all installed       │
├──────────────────┼─────────────────────┼─────────────────────┼─────────────────────┼─────────────────────┤
│ ajv              │ 6.15.0, 8.20.0      │ 6.15.0, 8.20.0      │ 6.15.0, 8.20.0      │ 6.15.0, 8.20.0      │
│ follow-redirects │ 1.16.0              │ 1.16.0              │ 1.15.11             │ 1.15.11, 1.16.0     │
│ semver           │ 5.7.2, 6.3.1, 7.8.0 │ 5.7.2, 6.3.1, 7.8.0 │ 5.7.2, 6.3.1, 7.8.0 │ 5.7.2, 6.3.1, 7.8.0 │
└──────────────────┴─────────────────────┴─────────────────────┴─────────────────────┴─────────────────────┘
```

---

## check-deps-branches.sh

Find npm dependency versions across multiple APIM versions in one command. Reads each branch's `package-lock.json` directly from `upstream` (`wso2-support/apim-apps`) — no `npm install` needed, no working-tree changes, runs in under a minute.

### Check a single dependency

```bash
./check-deps-branches.sh <pkg>
```

Example:

```bash
./check-deps-branches.sh axios
```

```
### axios

┌──────────────┬────────┬───────────┬────────────────┐
│ APIM version │ Admin  │ Publisher │ Devportal      │
├──────────────┼────────┼───────────┼────────────────┤
│ 4.1.0        │ N/A    │ N/A       │ 0.30.0         │
│ 4.2.0        │ N/A    │ N/A       │ 0.30.2         │
│ 4.3.0        │ 1.13.2 │ 1.13.2    │ 0.30.2, 1.13.2 │
│ 4.4.0        │ 1.13.6 │ 1.13.6    │ 0.30.0, 1.13.6 │
│ 4.5.0        │ 1.15.2 │ 1.15.2    │ 1.15.2         │
│ 4.6.0        │ 1.15.2 │ 1.15.2    │ 1.15.2         │
└──────────────┴────────┴───────────┴────────────────┘
```

### Check multiple dependencies

Pass them space-separated:

```bash
./check-deps-branches.sh <pkg1> <pkg2> <pkg3> ...
```

Example:

```bash
./check-deps-branches.sh axios lodash
```

```
### axios

┌──────────────┬────────┬───────────┬────────────────┐
│ APIM version │ Admin  │ Publisher │ Devportal      │
├──────────────┼────────┼───────────┼────────────────┤
│ 4.1.0        │ N/A    │ N/A       │ 0.30.0         │
│ 4.2.0        │ N/A    │ N/A       │ 0.30.2         │
│ 4.3.0        │ 1.13.2 │ 1.13.2    │ 0.30.2, 1.13.2 │
│ 4.4.0        │ 1.13.6 │ 1.13.6    │ 0.30.0, 1.13.6 │
│ 4.5.0        │ 1.15.2 │ 1.15.2    │ 1.15.2         │
│ 4.6.0        │ 1.15.2 │ 1.15.2    │ 1.15.2         │
└──────────────┴────────┴───────────┴────────────────┘

### lodash

┌──────────────┬─────────┬───────────┬──────────────────┐
│ APIM version │ Admin   │ Publisher │ Devportal        │
├──────────────┼─────────┼───────────┼──────────────────┤
│ 4.1.0        │ 4.17.21 │ 4.17.21   │ 4.17.21          │
│ 4.2.0        │ 4.17.21 │ 4.17.21   │ 4.17.21          │
│ 4.3.0        │ 4.17.21 │ 4.17.21   │ 4.17.21          │
│ 4.4.0        │ 4.17.21 │ 4.17.21   │ 4.17.21, 4.17.23 │
│ 4.5.0        │ 4.18.1  │ 4.18.1    │ 4.18.1           │
│ 4.6.0        │ 4.18.1  │ 4.18.1    │ 4.18.1           │
└──────────────┴─────────┴───────────┴──────────────────┘
```

### APIM versions checked

| APIM version | Branch |
|---|---|
| 4.1.0 | `support-9.0.311.x-full` |
| 4.2.0 | `support-9.0.432.x-full` |
| 4.3.0 | `support-9.1.74.x-full` |
| 4.4.0 | `support-9.1.166.x-full` |
| 4.5.0 | `support-9.2.76.x-full` |
| 4.6.0 | `support-9.3.111.x-full` |

To add or remove versions, edit the `BRANCH_MAP` at the top of the script.

`N/A` means the package is not present in that portal's lockfile.
