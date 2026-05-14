#!/usr/bin/env bash

# check-deps-branches.sh
#
# Check installed versions of npm dependencies across multiple APIM versions
# by reading each branch's package-lock.json (or yarn.lock) directly.
# Does NOT modify your working tree.
#
# Fast (<1 minute for 6 branches) and immune to npm ci failures, Node version
# mismatches, or install-time errors.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORTALS_DIR_REL="portals"

# ---------- configuration: edit these ----------
# Repository slug to auto-detect among configured remotes.
# Whichever remote URL matches this (origin, upstream, support, etc.) is used.
TARGET_REPO="wso2-support/apim-apps"

BRANCH_MAP=(
    "support-9.0.311.x-full|4.1.0"
    "support-9.0.432.x-full|4.2.0"
    "support-9.1.74.x-full|4.3.0"
    "support-9.1.166.x-full|4.4.0"
    "support-9.2.76.x-full|4.5.0"
    "support-9.3.111.x-full|4.6.0"
)
# -----------------------------------------------

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <pkg> [<pkg> ...]" >&2
    echo "" >&2
    echo "Auto-detects the remote pointing to $TARGET_REPO." >&2
    echo "Override with: REMOTE=<name> $0 ..." >&2
    echo "" >&2
    echo "Checks the following APIM versions (edit the script to change):" >&2
    for entry in "${BRANCH_MAP[@]}"; do
        branch="${entry%%|*}"
        version="${entry##*|}"
        echo "  - APIM $version  ($branch)" >&2
    done
    exit 1
fi

PACKAGES=("$@")

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "error: not inside a git repository" >&2
    exit 1
fi

# --- pick the remote ---

REMOTE="${REMOTE:-}"

if [[ -z "$REMOTE" ]]; then
    # auto-detect: find any remote whose fetch URL contains TARGET_REPO
    # matches both https://github.com/<repo>(.git) and git@github.com:<repo>(.git)
    REMOTE=$(git remote -v | awk -v target="$TARGET_REPO" '
        $3 == "(fetch)" && index($2, target) > 0 { print $1; exit }
    ')
fi

if [[ -z "$REMOTE" ]]; then
    echo "error: could not find a remote pointing to $TARGET_REPO" >&2
    echo "" >&2
    echo "Your remotes:" >&2
    git remote -v | sed 's/^/  /' >&2
    echo "" >&2
    echo "Either add the remote:" >&2
    echo "  git remote add upstream https://github.com/$TARGET_REPO.git" >&2
    echo "" >&2
    echo "Or specify which one to use:" >&2
    echo "  REMOTE=<name> $0 ..." >&2
    exit 1
fi

if ! git remote | grep -qx "$REMOTE"; then
    echo "error: remote '$REMOTE' not found. Available:" >&2
    git remote -v | sed 's/^/  /' >&2
    exit 1
fi

echo "→ using remote: $REMOTE ($(git remote get-url "$REMOTE"))"
echo "→ fetching from $REMOTE..."
git fetch "$REMOTE" --quiet --prune

# auto-fetch any missing branches explicitly
for entry in "${BRANCH_MAP[@]}"; do
    branch="${entry%%|*}"
    if ! git rev-parse --verify --quiet "refs/remotes/$REMOTE/$branch" > /dev/null; then
        echo "  → branch '$branch' not yet local, fetching explicitly..."
        git fetch "$REMOTE" "$branch:refs/remotes/$REMOTE/$branch" --quiet 2>/dev/null || \
            echo "    ⚠ could not fetch — will be marked MISSING"
    fi
done

RESULTS_FILE="$(mktemp)"
PARSER_SCRIPT="$(mktemp)"
trap 'rm -f "$RESULTS_FILE" "$PARSER_SCRIPT"' EXIT

cat > "$PARSER_SCRIPT" <<'NODE'
const fs = require('fs');

const packages = JSON.parse(process.env.PKGS_JSON);
const lockType = process.env.LOCK_TYPE;
const content = fs.readFileSync(0, 'utf8');

const found = new Map();
function add(name, version) {
    if (!name || !version) return;
    if (!found.has(name)) found.set(name, new Set());
    found.get(name).add(String(version).trim());
}

if (lockType === 'npm') {
    let lock;
    try {
        lock = JSON.parse(content);
    } catch {
        process.stdout.write(packages.map(() => 'PARSE_ERROR').join('\n'));
        process.exit(0);
    }

    if (lock.packages && typeof lock.packages === 'object') {
        for (const [pkgPath, info] of Object.entries(lock.packages)) {
            if (!info || !info.version || pkgPath === '') continue;
            const m = pkgPath.match(/node_modules\/((?:@[^/]+\/)?[^/]+)$/);
            if (m) add(m[1], info.version);
        }
    }

    if (lock.dependencies && typeof lock.dependencies === 'object') {
        (function walk(deps) {
            for (const [name, info] of Object.entries(deps)) {
                if (!info || typeof info !== 'object') continue;
                if (info.version) add(name, info.version);
                if (info.dependencies) walk(info.dependencies);
            }
        })(lock.dependencies);
    }
} else if (lockType === 'yarn') {
    const lines = content.split(/\r?\n/);
    let currentNames = [];
    for (const line of lines) {
        if (/^[^\s]/.test(line) && line.includes('@')) {
            currentNames = [];
            const header = line.replace(/:\s*$/, '');
            for (const part of header.split(/,\s*/)) {
                const stripped = part.trim().replace(/^"|"$/g, '');
                const at = stripped.lastIndexOf('@');
                if (at > 0) currentNames.push(stripped.slice(0, at));
            }
        } else if (/^\s+version\s/.test(line)) {
            const m = line.match(/version\s+"([^"]+)"/);
            if (m) for (const n of currentNames) add(n, m[1]);
        }
    }
}

const out = packages.map((pkg) => {
    const versions = found.get(pkg);
    if (!versions || versions.size === 0) return 'N/A';
    return [...versions]
        .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
        .join(', ');
});
process.stdout.write(out.join('\n'));
NODE

PKGS_JSON=$(printf '%s\n' "${PACKAGES[@]}" | node -e '
    const lines = require("fs").readFileSync(0, "utf8").split("\n").filter(Boolean);
    process.stdout.write(JSON.stringify(lines));
')

for entry in "${BRANCH_MAP[@]}"; do
    branch="${entry%%|*}"
    version="${entry##*|}"
    ref="$REMOTE/$branch"

    echo ""
    echo "→ APIM $version  ($branch)"

    if ! git rev-parse --verify --quiet "refs/remotes/$ref" > /dev/null; then
        echo "    ✗ branch missing — marking MISSING for all portals"
        for portal in admin publisher devportal; do
            for pkg in "${PACKAGES[@]}"; do
                echo "$version|$pkg|$portal|MISSING" >> "$RESULTS_FILE"
            done
        done
        continue
    fi

    for portal in admin publisher devportal; do
        # Try multiple paths — newer APIM versions use src/main/webapp layout,
        # older versions (e.g. 4.1.0) use the flat layout.
        portal_paths=(
            "$PORTALS_DIR_REL/$portal/src/main/webapp"
            "$PORTALS_DIR_REL/$portal"
        )

        lock_type=""
        lock_path=""

        for portal_path in "${portal_paths[@]}"; do
            if git cat-file -e "$ref:$portal_path/package-lock.json" 2>/dev/null; then
                lock_type="npm"
                lock_path="$portal_path/package-lock.json"
                break
            elif git cat-file -e "$ref:$portal_path/yarn.lock" 2>/dev/null; then
                lock_type="yarn"
                lock_path="$portal_path/yarn.lock"
                break
            fi
        done

        if [[ -z "$lock_path" ]]; then
            echo "    ⚠ $portal: no lockfile found"
            for pkg in "${PACKAGES[@]}"; do
                echo "$version|$pkg|$portal|N/A" >> "$RESULTS_FILE"
            done
            continue
        fi

        results=$(git show "$ref:$lock_path" | \
            PKGS_JSON="$PKGS_JSON" LOCK_TYPE="$lock_type" node "$PARSER_SCRIPT")

        i=0
        while IFS= read -r line; do
            pkg="${PACKAGES[$i]}"
            echo "$version|$pkg|$portal|$line" >> "$RESULTS_FILE"
            i=$((i + 1))
        done <<< "$results"

        echo "    ✓ $portal  ($lock_type)"
    done
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Results"
echo "═══════════════════════════════════════════════════════"

node - "$RESULTS_FILE" "${PACKAGES[@]}" <<'NODE'
const fs = require('fs');

const resultsFile = process.argv[2];
const packages = process.argv.slice(3);
const portals = ['admin', 'publisher', 'devportal'];
const portalLabels = { admin: 'Admin', publisher: 'Publisher', devportal: 'Devportal' };

const records = fs.readFileSync(resultsFile, 'utf8')
    .split('\n').filter(Boolean)
    .map((line) => {
        const [version, pkg, portal, versions] = line.split('|');
        return { version, pkg, portal, versions };
    });

const versions = [...new Set(records.map((r) => r.version))];

function pad(str, width) {
    const diff = width - String(str).length;
    return diff > 0 ? str + ' '.repeat(diff) : str;
}

function renderTable(headers, rows) {
    const widths = headers.map((h, i) =>
        Math.max(String(h).length, ...rows.map((r) => String(r[i] || '').length))
    );
    const renderRow = (cells) =>
        '│ ' + cells.map((c, i) => pad(c || '', widths[i])).join(' │ ') + ' │';
    const top    = '┌' + widths.map((w) => '─'.repeat(w + 2)).join('┬') + '┐';
    const mid    = '├' + widths.map((w) => '─'.repeat(w + 2)).join('┼') + '┤';
    const bottom = '└' + widths.map((w) => '─'.repeat(w + 2)).join('┴') + '┘';
    return [top, renderRow(headers), mid, ...rows.map(renderRow), bottom].join('\n');
}

for (const pkg of packages) {
    console.log(`\n### ${pkg}\n`);
    const headers = ['APIM version', ...portals.map((p) => portalLabels[p])];
    const rows = versions.map((version) => {
        const cells = [version];
        for (const portal of portals) {
            const rec = records.find(
                (r) => r.version === version && r.pkg === pkg && r.portal === portal
            );
            cells.push(rec ? rec.versions : 'N/A');
        }
        return cells;
    });
    console.log(renderTable(headers, rows));
}
NODE
