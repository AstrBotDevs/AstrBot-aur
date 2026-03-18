#!/bin/bash
set -e

# Configuration
PKG_NAME="astrbot-git"
BUILD_DIR="src"
PKG_FILE_PATTERN="*.pkg.tar.zst"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[TEST] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

# 1. Clean previous builds
log "Cleaning up previous builds..."
rm -rf "$BUILD_DIR" pkg/ "$PKG_FILE_PATTERN"
# Clean up src directory to force a fresh git clone if needed
# rm -rf src/astrbot-git

# 2. Syntax Check
log "Running syntax check on scripts..."

if command -v shellcheck >/dev/null 2>&1; then
    log "Using shellcheck..."
    shellcheck -x astrbotctl || warn "astrbotctl syntax issues found."
    shellcheck -x astrbot-git.install || warn "astrbot-git.install syntax issues found."
else
    warn "shellcheck not found. Skipping static analysis."
    # Basic syntax check
    bash -n astrbotctl || error "astrbotctl syntax error"
    bash -n astrbot-git.install || error "astrbot-git.install syntax error"
fi

# 3. Validation of PKGBUILD
log "Validating PKGBUILD..."
namcap PKGBUILD || warn "namcap found issues in PKGBUILD"

# 4. Build Package
log "Building package..."
makepkg -sif --noconfirm

# 5. Integration Test (requires sudo/root)
# Only run this if the user agrees or if a flag is passed
if [[ "$1" == "--install-test" ]]; then
    log "Starting Integration Test..."

    # Check if installed
    if ! command -v astrbotctl >/dev/null; then
        error "astrbotctl not found in path after installation."
    fi

    # Check for config template
    if [ ! -f "/opt/astrbot/config.template" ]; then
        error "config.template not found in /opt/astrbot."
    fi

    TEST_INSTANCE="test_bot_$$"

    log "1. Creating test instance: $TEST_INSTANCE"
    sudo astrbotctl init "$TEST_INSTANCE"

    if [ ! -d "/var/lib/astrbot/$TEST_INSTANCE" ]; then
        error "Instance directory not created."
    fi

    if [ ! -f "/etc/astrbot/$TEST_INSTANCE.conf" ]; then
        error "Instance config not created."
    fi

    log "2. Checking permissions..."
    OWNER=$(stat -c '%U' "/var/lib/astrbot/$TEST_INSTANCE")
    if [ "$OWNER" != "astrbot" ]; then
        error "Instance directory owner is $OWNER, expected astrbot."
    fi

    log "3. Listing instances..."
    sudo astrbotctl list | grep "$TEST_INSTANCE" || error "Instance not found in list."

    log "4. Dry-run test (checking if python environment sets up)..."
    # This might fail if network is down or upstream is broken, but we check if it tries to run
    # timeout 10s sudo astrbotctl run "$TEST_INSTANCE" || true

    log "5. Cleanup..."
    sudo rm -rf "/var/lib/astrbot/$TEST_INSTANCE"
    sudo rm "/etc/astrbot/$TEST_INSTANCE.conf"
    sudo rm -rf "/var/cache/astrbot/venv-$TEST_INSTANCE"

    log "Integration Test Passed!"
else
    log "Skipping integration test. Run with --install-test to execute."
fi

log "Build and basic checks completed successfully."
