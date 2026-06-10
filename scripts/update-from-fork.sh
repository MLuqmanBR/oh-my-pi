#!/usr/bin/env bash
set -euo pipefail

# ── update-from-fork ───────────────────────────────────────────
# Replaces "omp update" for fork users.
# Pulls the latest fork code (kept current by the sync workflow),
# builds from source, and atomically replaces the installed binary.
# On failure the existing binary is left untouched.
#
# Usage:
#   ./update-from-fork.sh            # use repo at $OMP_REPO_PATH or default
#   OMP_REPO_PATH=~/my-omp ./update-from-fork.sh
#
# To intercept "omp update", add to your shell rc:
#   alias omp-update='path/to/update-from-fork.sh'
# ────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

REPO_PATH="${OMP_REPO_PATH:-$HOME/oh-my-pi}"
BUN="${BUN:-bun}"

# ── helpers ────────────────────────────────────────────────────
log()  { echo -e "${DIM}$*${NC}"; }
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
die()  { echo -e "${RED}✗${NC} $*" >&2; exit 1; }

# ── step 1: ensure repo exists and is current ──────────────────
log "Step 1/5: Updating repository…"

if [[ ! -d "$REPO_PATH/.git" ]]; then
    die "No git repo at $REPO_PATH. Set OMP_REPO_PATH or clone your fork:
    git clone https://github.com/MLuqmanBR/oh-my-pi.git $REPO_PATH"
fi

cd "$REPO_PATH"

# Stash any local modifications so pull is clean
if ! git diff --quiet 2>/dev/null; then
    warn "Uncommitted changes detected — stashing temporarily"
    git stash push -m "update-from-fork auto-stash" --include-untracked
    STASHED=1
else
    STASHED=0
fi

# Pull latest from fork
if ! git pull --ff-only origin main 2>&1; then
    if [[ "${STASHED:-0}" -eq 1 ]]; then
        git stash pop 2>/dev/null || true
    fi
    die "git pull failed — fix conflicts manually and re-run"
fi

# Restore stashed changes (your api-gateway provider is committed, so this is for WIP)
if [[ "${STASHED:-0}" -eq 1 ]]; then
    git stash pop 2>/dev/null || warn "Could not re-apply stash (your changes may be in conflict)"
fi

# ── step 2: install dependencies ───────────────────────────────
log "Step 2/5: Installing dependencies…"
if ! $BUN install --frozen-lockfile 2>&1; then
    die "bun install failed"
fi

# ── step 3: build the binary ───────────────────────────────────
log "Step 3/5: Building binary…"
if ! $BUN run build 2>&1; then
    die "Build failed"
fi

BUILT_BINARY="$REPO_PATH/packages/coding-agent/dist/omp"
if [[ ! -f "$BUILT_BINARY" ]]; then
    die "Build succeeded but binary not found at $BUILT_BINARY"
fi
ok "Built $(cat "$BUILT_BINARY" | wc -c | tr -d ' ') bytes → $BUILT_BINARY"

# ── step 4: verify the built binary ────────────────────────────
log "Step 4/5: Verifying built binary…"
BUILT_VERSION=$("$BUILT_BINARY" --version 2>/dev/null || true)
if [[ -z "$BUILT_VERSION" ]]; then
    die "Built binary failed to report version (may be broken)"
fi
ok "Built binary reports: $BUILT_VERSION"

# ── step 5: find and replace installed binary ──────────────────
log "Step 5/5: Installing…"

INSTALLED=$(which omp 2>/dev/null || true)
if [[ -z "$INSTALLED" ]]; then
    die "Cannot find 'omp' in PATH — is it installed?"
fi

# Resolve symlinks to the real file
if [[ -L "$INSTALLED" ]]; then
    REAL_INSTALLED=$(readlink -f "$INSTALLED")
    IS_SYMLINK=1
else
    REAL_INSTALLED="$INSTALLED"
    IS_SYMLINK=0
fi

ok "Current omp: $INSTALLED → $REAL_INSTALLED"

BACKUP="${REAL_INSTALLED}.bak"

# Remove stale backup if present
rm -f "$BACKUP"

# Atomic replace: backup → copy new → verify → cleanup
if ! cp "$REAL_INSTALLED" "$BACKUP" 2>/dev/null; then
    die "Failed to create backup at $BACKUP (permissions?)"
fi

if ! cp "$BUILT_BINARY" "$REAL_INSTALLED" 2>/dev/null; then
    # Restore backup
    cp "$BACKUP" "$REAL_INSTALLED" 2>/dev/null || true
    rm -f "$BACKUP"
    die "Failed to copy new binary to $REAL_INSTALLED (permissions?)"
fi

# Verify the replaced binary works
NEW_VERSION=$("$REAL_INSTALLED" --version 2>/dev/null || true)
if [[ -z "$NEW_VERSION" ]]; then
    warn "Replaced binary failed — rolling back"
    cp "$BACKUP" "$REAL_INSTALLED" 2>/dev/null || true
    rm -f "$BACKUP"
    die "New binary is broken; previous version restored"
fi

rm -f "$BACKUP"
ok "Installed: $NEW_VERSION"
ok "Update complete. Restart omp to use the new version."
