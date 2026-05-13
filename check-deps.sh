#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORTALS_DIR="$ROOT_DIR/portals"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <pkg> [<pkg> ...]" >&2
    exit 1
fi

node - "$PORTALS_DIR" "$@" <<'NODE'
const path = require('path');
const { spawnSync } = require('child_process');

const portalsDir = process.argv[2];
const packageNames = process.argv.slice(3);
const portals = ['admin', 'publisher', 'devportal'];

function sortedValues(set) {
    return Array.from(set).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
}

function buildPortalVersionMap(portalDir) {
    const result = spawnSync('npm', ['ls', '--json', '--all'], {
        cwd: portalDir,
        encoding: 'utf8',
        maxBuffer: 30 * 1024 * 1024,
    });

    if (result.error) {
        console.error(`warning: failed to run npm ls in ${portalDir}: ${result.error.message}`);
        return new Map();
    }

    let tree = {};
    try {
        tree = JSON.parse((result.stdout || '').trim() || '{}');
    } catch (e) {
        console.error(`warning: failed to parse npm ls output for ${portalDir}: ${e.message}`);
        return new Map();
    }

    const map = new Map();

    function walk(node) {
        if (!node || typeof node !== 'object') return;
        const deps = node.dependencies;
        if (!deps || typeof deps !== 'object') return;

        for (const [name, meta] of Object.entries(deps)) {
            if (!meta || typeof meta !== 'object' || !meta.version) continue;
            if (!map.has(name)) map.set(name, new Set());
            map.get(name).add(meta.version.trim());
            walk(meta);
        }
    }

    walk(tree);
    return map;
}

const portalMaps = {};
for (const portal of portals) {
    portalMaps[portal] = buildPortalVersionMap(path.join(portalsDir, portal, 'src/main/webapp'));
}

function resolveRow(name) {
    const perPortal = {};
    const allVersions = new Set();

    for (const portal of portals) {
        const versions = portalMaps[portal].get(name);
        const ordered = versions ? sortedValues(versions) : [];
        for (const v of ordered) allVersions.add(v);
        perPortal[portal] = ordered.length ? ordered.join(', ') : 'N/A';
    }

    const allInstalled = sortedValues(allVersions);
    return [
        name,
        perPortal.admin,
        perPortal.publisher,
        perPortal.devportal,
        allInstalled.length ? allInstalled.join(', ') : 'N/A',
    ];
}

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

const headers = ['dependency', 'admin', 'publisher', 'devportal', 'all installed'];
const rows = packageNames.map(resolveRow);
console.log(renderTable(headers, rows));
NODE
