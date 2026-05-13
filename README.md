# check-deps

Find the installed versions of npm dependencies across all portals (`admin`, `publisher`, `devportal`) in one command.

- Run the script from the repo root

## Usage

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
