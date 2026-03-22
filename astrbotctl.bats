#!/usr/bin/env bats
# ============================================================================
# astrbotctl - BATS Test Suite
# ============================================================================
#
# Runs all tests against the astrbotctl.functions library.
# Uses the real script source directly for maximum reliability.
#
# Prerequisites:  bats (bash automated test system)
# Running:        bats astrbotctl.bats
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
FUNCTIONS="${SCRIPT_DIR}/astrbotctl.functions"

# ─── Setup / Teardown ────────────────────────────────────────────────────────

setup() {
    TEST_ROOT="$(mktemp -d)"

    # Override constants before sourcing functions
    SYSTEM_ROOT="$TEST_ROOT/var/lib/astrbot"
    CONFIG_DIR="$TEST_ROOT/etc/astrbot"
    APP_DIR="$TEST_ROOT/opt/astrbot"
    CACHE_DIR="$TEST_ROOT/var/cache/astrbot"
    CERTBOT_INSTANCE_CERTS_DIR="$TEST_ROOT/etc/astrbot/certs"

    mkdir -p "$CONFIG_DIR" "$APP_DIR"
    TEST_INSTANCE="testinstance"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

# ─── Load functions (once per file) ────────────────────────────────────────

load_functions() {
    # shellcheck source=/dev/null
    . "$FUNCTIONS"
}

# ─── conf_file ─────────────────────────────────────────────────────────────

@test "conf_file returns correct path for instance" {
    instance="mybot"
    load_functions
    result=$(conf_file)
    [[ "$result" == "$CONFIG_DIR/mybot.conf" ]]
}

# ─── venv_dir ───────────────────────────────────────────────────────────────

@test "venv_dir returns correct path for instance" {
    instance="mybot"
    load_functions
    result=$(venv_dir)
    [[ "$result" == "$CACHE_DIR/venv-mybot" ]]
}

# ─── certbot_hook_path ──────────────────────────────────────────────────────

@test "certbot_hook_path returns correct path for instance" {
    instance="mybot"
    load_functions
    result=$(certbot_hook_path)
    [[ "$result" == *"/etc/letsencrypt/renewal-hooks/deploy/astrbot-mybot.sh" ]]
}

# ─── certbot_instance_cert_dir ─────────────────────────────────────────────

@test "certbot_instance_cert_dir returns correct path" {
    instance="mybot"
    load_functions
    result=$(certbot_instance_cert_dir)
    [[ "$result" == *"$CERTBOT_INSTANCE_CERTS_DIR/mybot" ]]
}

# ─── upsert_conf_var ────────────────────────────────────────────────────────

@test "upsert_conf_var adds new variable to empty file" {
    local conf="$TEST_ROOT/test.conf"
    touch "$conf"
    load_functions
    upsert_conf_var "$conf" "FOO" "bar"
    run cat "$conf"
    [[ "$output" == *'FOO="bar"' ]]
}

@test "upsert_conf_var updates existing variable" {
    local conf="$TEST_ROOT/test.conf"
    printf 'FOO="old"\n' >"$conf"
    load_functions
    upsert_conf_var "$conf" "FOO" "new"
    run cat "$conf"
    [[ "$output" == *'FOO="new"'* ]]
    [[ "$output" != *"old"* ]]
}

@test "upsert_conf_var preserves other variables" {
    local conf="$TEST_ROOT/test.conf"
    printf 'FOO="bar"\nBAZ="qux"\n' >"$conf"
    load_functions
    upsert_conf_var "$conf" "FOO" "updated"
    run cat "$conf"
    [[ "$output" == *'FOO="updated"'* ]]
    [[ "$output" == *'BAZ="qux"'* ]]
}

@test "upsert_conf_var escapes special characters" {
    local conf="$TEST_ROOT/test.conf"
    touch "$conf"
    load_functions
    upsert_conf_var "$conf" "URL" "https://example.com/path?foo=1&bar=2"
    run cat "$conf"
    [[ "$output" == *'URL="https:\/\/example.com\/path?foo=1\&bar=2"'* ]]
}

# ─── find_free_port ────────────────────────────────────────────────────────

@test "find_free_port returns starting port when free" {
    load_functions
    result=$(find_free_port 3000)
    [[ "$result" -eq 3000 ]]
}

@test "find_free_port increments when port is in config" {
    echo "ASTRBOT_PORT=3000" >"$CONFIG_DIR/existing.conf"
    load_functions
    result=$(find_free_port 3000)
    [[ "$result" -eq 3001 ]]
}

@test "find_free_port skips multiple occupied ports" {
    echo "ASTRBOT_PORT=3000" >"$CONFIG_DIR/a.conf"
    echo "ASTRBOT_PORT=3001" >"$CONFIG_DIR/b.conf"
    load_functions
    result=$(find_free_port 3000)
    [[ "$result" -eq 3002 ]]
}

# ─── iter_instances ─────────────────────────────────────────────────────────

@test "iter_instances returns nothing when CONFIG_DIR does not exist" {
    rmdir "$CONFIG_DIR" 2>/dev/null || true
    load_functions
    result=$(iter_instances)
    [[ -z "$result" ]]
}

@test "iter_instances returns instance names from config files" {
    mkdir -p "$CONFIG_DIR" "$SYSTEM_ROOT"
    touch "$CONFIG_DIR/instance1.conf"
    touch "$CONFIG_DIR/instance2.conf"
    mkdir -p "$SYSTEM_ROOT/instance1"
    mkdir -p "$SYSTEM_ROOT/instance2"
    load_functions
    result=$(iter_instances)
    [[ "$result" == *"instance1"* ]]
    [[ "$result" == *"instance2"* ]]
}

@test "iter_instances skips config without corresponding data directory" {
    mkdir -p "$CONFIG_DIR" "$SYSTEM_ROOT"
    touch "$CONFIG_DIR/instance1.conf"
    touch "$CONFIG_DIR/instance2.conf"
    mkdir -p "$SYSTEM_ROOT/instance1"
    load_functions
    result=$(iter_instances)
    [[ "$result" == *"instance1"* ]]
    [[ "$result" != *"instance2"* ]]
}

# ─── print_help ─────────────────────────────────────────────────────────────

@test "print_help shows usage information" {
    load_functions
    run print_help
    [[ $status -eq 0 ]]
    [[ "$output" == *"AstrBot Control Tool"* ]]
    [[ "$output" == *"init"* ]]
    [[ "$output" == *"cp"* ]]
    [[ "$output" == *"rm"* ]]
    [[ "$output" == *"list"* ]]
}

@test "print_help lists all major commands" {
    load_functions
    run print_help
    [[ "$output" == *"start"* ]]
    [[ "$output" == *"stop"* ]]
    [[ "$output" == *"status"* ]]
    [[ "$output" == *"reset"* ]]
    [[ "$output" == *"certbot"* ]]
    [[ "$output" == *"admin"* ]]
    [[ "$output" == *"export"* ]]
    [[ "$output" == *"import"* ]]
    [[ "$output" == *"git pull"* ]]
}

# ─── print_paths ─────────────────────────────────────────────────────────────

@test "print_paths prints paths for given instance" {
    instance="$TEST_INSTANCE"
    ASTRBOT_ROOT="$SYSTEM_ROOT/$instance"
    mkdir -p "$ASTRBOT_ROOT"
    load_functions
    result=$(print_paths)
    [[ "$result" == *"INSTANCE_NAME=$instance"* ]]
    [[ "$result" == *"SYSTEM_ROOT="* ]]
    [[ "$result" == *"CONFIG_FILE="* ]]
    [[ "$result" == *"VENV_DIR="* ]]
}

# ─── generate_env_file ──────────────────────────────────────────────────────

@test "generate_env_file creates .env file with required variables" {
    instance="$TEST_INSTANCE"
    ASTRBOT_ROOT="$SYSTEM_ROOT/$instance"
    mkdir -p "$ASTRBOT_ROOT/data"
    runtime_root="$ASTRBOT_ROOT/home"

    load_functions

    HOME="$runtime_root"
    XDG_CACHE_HOME="$runtime_root/.cache"
    XDG_CONFIG_HOME="$runtime_root/.config"
    XDG_DATA_HOME="$runtime_root/.local/share"
    XDG_STATE_HOME="$runtime_root/.local/state"
    UV_CACHE_DIR="$CACHE_DIR/uv"
    UV_PROJECT_ENVIRONMENT="$CACHE_DIR/venv-$instance"
    UV_PYTHON_INSTALL_DIR="$CACHE_DIR/python"
    ASTRBOT_ROOT="$ASTRBOT_ROOT"
    VIRTUAL_ENV="$UV_PROJECT_ENVIRONMENT"
    ASTRBOT_SYSTEMD=1
    ASTRBOT_DESKTOP_CLIENT=0

    generate_env_file

    local env_file="$ASTRBOT_ROOT/data/.env"
    [[ -f "$env_file" ]]
    run cat "$env_file"
    [[ "$output" == *"HOME="* ]]
    [[ "$output" == *"XDG_CACHE_HOME="* ]]
    [[ "$output" == *"ASTRBOT_ROOT="* ]]
    [[ "$output" == *"VIRTUAL_ENV="* ]]
}

# ─── ensure_runtime_dirs ─────────────────────────────────────────────────────

@test "ensure_runtime_dirs creates all required directories" {
    instance="$TEST_INSTANCE"
    ASTRBOT_ROOT="$SYSTEM_ROOT/$instance"
    HOME="$ASTRBOT_ROOT/home"
    XDG_CONFIG_HOME="$ASTRBOT_ROOT/.config"
    XDG_DATA_HOME="$ASTRBOT_ROOT/.local/share"
    XDG_STATE_HOME="$ASTRBOT_ROOT/.local/state"

    load_functions
    ensure_runtime_dirs

    [[ -d "$HOME" ]]
    [[ -d "$XDG_CONFIG_HOME" ]]
    [[ -d "$XDG_DATA_HOME" ]]
    [[ -d "$XDG_STATE_HOME" ]]
    [[ -d "$ASTRBOT_ROOT/data" ]]
    [[ -d "$ASTRBOT_ROOT/data/config" ]]
    [[ -d "$ASTRBOT_ROOT/data/plugins" ]]
    [[ -d "$ASTRBOT_ROOT/data/temp" ]]
    [[ -d "$ASTRBOT_ROOT/data/backups" ]]
}

# ─── load_instance_config ─────────────────────────────────────────────────────

@test "load_instance_config exports variables from config file" {
    instance="$TEST_INSTANCE"
    CONF_FILE="$CONFIG_DIR/$instance.conf"

    cat >"$CONF_FILE" <<'EOF'
ASTRBOT_ROOT="/test/root"
ASTRBOT_HOST="127.0.0.1"
ASTRBOT_PORT="9999"
EOF

    load_functions
    load_instance_config

    [[ "$ASTRBOT_ROOT" == "/test/root" ]]
    [[ "$ASTRBOT_HOST" == "127.0.0.1" ]]
    [[ "$ASTRBOT_PORT" == "9999" ]]
}

@test "load_instance_config is safe to call when config does not exist" {
    instance="nonexistent"
    load_functions
    run load_instance_config
    [[ $status -eq 0 ]]
}

# ─── sync_certbot_cert_for_instance ──────────────────────────────────────────

@test "sync_certbot_cert_for_instance fails when cert file missing" {
    instance="$TEST_INSTANCE"
    mkdir -p "$TEST_ROOT/etc/letsencrypt/live/testcert"
    load_functions
    run sync_certbot_cert_for_instance "testcert"
    [[ $status -ne 0 ]]
    [[ "$output" == *"Certificate file not found"* ]]
}

@test "sync_certbot_cert_for_instance fails when key file missing" {
    instance="$TEST_INSTANCE"
    mkdir -p "$TEST_ROOT/etc/letsencrypt/live/testcert"
    touch "$TEST_ROOT/etc/letsencrypt/live/testcert/fullchain.pem"
    load_functions
    run sync_certbot_cert_for_instance "testcert"
    [[ $status -ne 0 ]]
    [[ "$output" == *"Private key file not found"* ]]
}

@test "sync_certbot_cert_for_instance copies files on success" {
    instance="$TEST_INSTANCE"
    mkdir -p "$TEST_ROOT/etc/letsencrypt/live/testcert" \
             "$TEST_ROOT/etc/astrbot/certs/$TEST_INSTANCE"
    touch "$TEST_ROOT/etc/letsencrypt/live/testcert/fullchain.pem"
    touch "$TEST_ROOT/etc/letsencrypt/live/testcert/privkey.pem"
    load_functions
    run sync_certbot_cert_for_instance "testcert"
    [[ $status -eq 0 ]]
    [[ -f "$TEST_ROOT/etc/astrbot/certs/$TEST_INSTANCE/fullchain.pem" ]]
    [[ -f "$TEST_ROOT/etc/astrbot/certs/$TEST_INSTANCE/privkey.pem" ]]
}

# ─── require_instance ─────────────────────────────────────────────────────────

@test "require_instance exits with error when instance is empty" {
    instance=""
    load_functions
    run require_instance
    [[ $status -ne 0 ]]
    [[ "$output" == *"Usage:"* ]]
}

@test "require_instance succeeds when instance is set" {
    instance="someinstance"
    load_functions
    run require_instance
    [[ $status -eq 0 ]]
    [[ -z "$output" ]]
}

# ─── require_root ─────────────────────────────────────────────────────────────

@test "require_root exits with error when not root" {
    load_functions
    run require_root
    [[ $status -ne 0 ]]
    [[ "$output" == *"root"* ]]
}

# ─── render_config_from_template ─────────────────────────────────────────────

@test "render_config_from_template fails when template is missing" {
    instance="$TEST_INSTANCE"
    load_functions
    run render_config_from_template
    [[ $status -ne 0 ]]
    [[ "$output" == *"not found"* ]]
}

@test "render_config_from_template creates config from template" {
    instance="$TEST_INSTANCE"
    CONF_FILE="$CONFIG_DIR/$instance.conf"
    ASTRBOT_ROOT="$SYSTEM_ROOT/$instance"

    cat >"$APP_DIR/tmpl.conf" <<'TEMPLATE'
INSTANCE_NAME="${INSTANCE_NAME}"
ASTRBOT_HOST="${ASTRBOT_HOST:-0.0.0.0}"
ASTRBOT_PORT="${ASTRBOT_PORT:-3000}"
ASTRBOT_ROOT="${ASTRBOT_ROOT}"
TEMPLATE

    load_functions
    run render_config_from_template
    [[ $status -eq 0 ]]
    [[ -f "$CONF_FILE" ]]
    run cat "$CONF_FILE"
    [[ "$output" == *"INSTANCE_NAME=testinstance"* ]]
}

# ─── Integration: full command-line argument parsing ─────────────────────────

load_script() {
    # Pass overrides via environment so the script reads them
    ASTRBOTCTL_SCRIPT="${SCRIPT_DIR}/astrbotctl"
}

@test "unknown command prints help and exits with error" {
    load_script
    run bash "$SCRIPT_DIR/astrbotctl" nonexistent_command
    [[ $status -ne 0 ]]
    [[ "$output" == *"AstrBot Control Tool"* ]]
}

@test "empty invocation prints help" {
    run bash "$SCRIPT_DIR/astrbotctl"
    [[ $status -eq 0 ]]
    [[ "$output" == *"AstrBot Control Tool"* ]]
}

@test "cp command fails without source and dest" {
    run bash "$SCRIPT_DIR/astrbotctl" cp
    [[ $status -ne 0 ]]
    [[ "$output" == *"Usage:"* ]]
}

@test "rm command prints help with -h flag" {
    run bash "$SCRIPT_DIR/astrbotctl" rm -h
    [[ $status -eq 0 ]]
    [[ "$output" == *"Usage:"* ]]
}

@test "list command shows no instances when none exist" {
    run bash "$SCRIPT_DIR/astrbotctl" list
    [[ $status -eq 0 ]]
    [[ "$output" == *"(No instances found)"* ]]
}

@test "init command rejects invalid option" {
    run bash "$SCRIPT_DIR/astrbotctl" init --invalid-option testinstance
    [[ $status -ne 0 ]]
    [[ "$output" == *"Unknown option"* ]]
}

@test "admin command rejects missing -u value" {
    run bash "$SCRIPT_DIR/astrbotctl" admin -u
    [[ $status -ne 0 ]]
    [[ "$output" == *"Missing value"* ]]
}

@test "admin command rejects missing -p value" {
    run bash "$SCRIPT_DIR/astrbotctl" admin -p
    [[ $status -ne 0 ]]
    [[ "$output" == *"Missing value"* ]]
}

@test "export command requires instance" {
    run bash "$SCRIPT_DIR/astrbotctl" export
    [[ $status -ne 0 ]]
}

@test "git command requires arguments" {
    run bash "$SCRIPT_DIR/astrbotctl" git
    [[ $status -ne 0 ]]
}

@test "git command rejects --rebuild-venv without target" {
    run bash "$SCRIPT_DIR/astrbotctl" git pull --rebuild-venv
    [[ $status -ne 0 ]]
    [[ "$output" == *"--rebuild-venv"* ]]
}

@test "git command rejects both instance and --all" {
    run bash "$SCRIPT_DIR/astrbotctl" git pull --all someinstance
    [[ $status -ne 0 ]]
    [[ "$output" == *"not both"* ]]
}

@test "init command -f requires existing file" {
    run bash "$SCRIPT_DIR/astrbotctl" init -f /nonexistent/backup.zip testinstance
    [[ $status -ne 0 ]]
    [[ "$output" == *"Backup file not found"* ]]
}

@test "import command requires backup file" {
    instance="$TEST_INSTANCE"
    ASTRBOT_ROOT="$SYSTEM_ROOT/$instance"
    mkdir -p "$ASTRBOT_ROOT"
    CONF_FILE="$CONFIG_DIR/$instance.conf"
    touch "$CONF_FILE"

    run bash "$SCRIPT_DIR/astrbotctl" import "$instance" /nonexistent/backup.zip
    [[ $status -ne 0 ]]
    [[ "$output" == *"Backup file not found"* ]]
}

@test "paths command requires instance" {
    run bash "$SCRIPT_DIR/astrbotctl" paths
    [[ $status -ne 0 ]]
}
