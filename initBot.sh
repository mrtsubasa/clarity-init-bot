#!/bin/bash

set -eo pipefail
IFS=$'\n\t'

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_NAME="Clarity-V2"
readonly REPO_URL=""
readonly ENV_FILE=".env"
readonly PM2_PROCESS_PREFIX="gestion"

# Global variables
declare GIT_TOKEN=""
declare BOT_TOKEN=""
declare BOT_ID=""
declare BUYER_ID=""
declare PREFIX="/"
declare NODE_ENV=""
declare OS_TYPE=""
declare PLATFORM=""
declare CURL_AVAILABLE=false
declare SQLITE_DRIVER="" # NEW: To store the SQLite driver choice


# ====================================
# Stockage Directory Settings Get
# ====================================

detect_storage_dir() {
    # 1. Determine Centralized Path
    # If STORAGE_DIR is already set (env var or previous call), verify and use it
    if [[ -n "${STORAGE_DIR:-}" ]] && [[ -d "${STORAGE_DIR}" ]]; then
        STORAGE_DIR="${STORAGE_DIR%/}"
        return
    fi

    # Define centralized location relative to user home (works on Linux, Mac, and Git Bash on Windows)
    # This ensures data persists even if the repo is moved or deleted/re-cloned.
    local central_path="${HOME}/.clarity-v2-data"
    
    if [[ -n "${STORAGE_DIR:-}" ]]; then
         # If env var was provided but dir doesn't exist yet
         STORAGE_DIR="${STORAGE_DIR%/}"
    else
         STORAGE_DIR="${central_path}"
    fi

    # 2. Create Directory & Handle Permissions
    if [[ ! -d "${STORAGE_DIR}" ]]; then
        if ! mkdir -p "${STORAGE_DIR}" 2>/dev/null; then
            echo "Error: Failed to create storage directory at ${STORAGE_DIR}."
            echo "Please check your permissions or set STORAGE_DIR manually."
            exit 1
        fi
        
        if command -v log_debug &>/dev/null; then
            log_debug "Created centralized storage directory: ${STORAGE_DIR}"
        fi
        
        # 3. Migration from Legacy Local Storage
        local legacy_storage="${SCRIPT_DIR}/stockage"
        if [[ -d "${legacy_storage}" ]]; then
            if command -v log_info &>/dev/null; then
                log_info "Migrating legacy data from ${legacy_storage} to ${STORAGE_DIR}..."
            fi
            # Use -R for recursive copy, suppress errors if empty
            cp -R "${legacy_storage}/." "${STORAGE_DIR}/" 2>/dev/null || true
        fi
    fi

    # 4. Verify Access Permissions
    if [[ ! -w "${STORAGE_DIR}" ]]; then
        echo "Error: Storage directory ${STORAGE_DIR} is not writable."
        exit 1
    fi
    
    # Test file creation to ensure full access
    local test_file="${STORAGE_DIR}/.write_test"
    if ! touch "${test_file}" 2>/dev/null; then
         echo "Error: Cannot write to ${STORAGE_DIR}."
         exit 1
    fi
    rm -f "${test_file}"
}

get_git_token_file() {
    GIT_TOKEN_FILE="${STORAGE_DIR}/git_token/container.txt"
    if [[ ! -f "${GIT_TOKEN_FILE}" ]]; then
        log_error "Git token file not found: ${GIT_TOKEN_FILE}"
        exit 1
    fi
}

create_storage_dir() {
    mkdir -p "${STORAGE_DIR}"
}

create_git_token_file() {
    mkdir -p "${STORAGE_DIR}/git_token"
    touch "${GIT_TOKEN_FILE}"
}




# Detect OS and Platform
detect_os() {
    case "$OSTYPE" in
        linux*)
            OS_TYPE="linux"
            PLATFORM="Linux"
            ;;
        darwin*)
            OS_TYPE="macos"
            PLATFORM="Mac"
            ;;
        msys*|mingw*|cygwin*)
            OS_TYPE="windows"
            PLATFORM="Windows"
            ;;
        *)
            OS_TYPE="unknown"
            PLATFORM="Unknown"
            ;;
    esac

    if [[ "$OS_TYPE" == "unknown" ]]; then
        if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
            OS_TYPE="wsl"
            PLATFORM="Windows"
        fi
    fi
}

detect_platform() {
    detect_os
}

# Error handling
trap 'error_handler $? $LINENO' ERR

error_handler() {
    local exit_code=$1
    local line_number=$2
    log_error "Error occurred in script at line ${line_number} (exit code: ${exit_code})"
    exit "${exit_code}"
}

# ============================================================================
# Colors
# ============================================================================

setup_colors() {
    if [[ "${PLATFORM}" == "Windows" ]]; then
        if [[ -n "${WT_SESSION:-}" ]] || [[ "${TERM:-}" == "xterm-256color" ]]; then
            readonly RED='\033[1;31m'
            readonly GREEN='\033[1;32m'
            readonly YELLOW='\033[1;33m'
            readonly BLUE='\033[1;34m'
            readonly CYAN='\033[1;36m'
            readonly RESET='\033[0m'
        else
            readonly RED=''
            readonly GREEN=''
            readonly YELLOW=''
            readonly BLUE=''
            readonly CYAN=''
            readonly RESET=''
        fi
    else
        readonly RED='\e[1;31m'
        readonly GREEN='\e[1;32m'
        readonly YELLOW='\e[1;33m'
        readonly BLUE='\e[1;34m'
        readonly CYAN='\e[1;36m'
        readonly RESET='\e[0m'
    fi
}

# ============================================================================
# Logging Functions
# ============================================================================

log_debug() {
    echo -e "${CYAN}[DEBUG] ${1}${RESET}"
}

log_info() {
    echo -e "${CYAN}ℹ ${1}${RESET}"
}

log_success() {
    echo -e "${GREEN}✓ ${1}${RESET}"
}

log_warning() {
    echo -e "${YELLOW}⚠ ${1}${RESET}"
}

log_error() {
    echo -e "${RED}✗ ${1}${RESET}"
}

print_header() {
    local title=$1
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${YELLOW}${title}${RESET}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

clear_screen() {
    if [[ "$OS_TYPE" == "windows" ]]; then
        cmd.exe /c cls 2>/dev/null || clear
    else
        clear
    fi
}

# ============================================================================
# Data Persistence Functions
# ============================================================================

init_persistence() {
    detect_storage_dir
    local persistence_file="${STORAGE_DIR}/persistence.json"
    if [[ ! -f "${persistence_file}" ]]; then
        mkdir -p "$(dirname "${persistence_file}")"
        echo "{}" > "${persistence_file}"
        log_debug "Created new persistence file at ${persistence_file}"
    fi
}

verify_integrity() {
    detect_storage_dir
    local persistence_file="${STORAGE_DIR}/persistence.json"
    if [[ ! -f "${persistence_file}" ]]; then return 0; fi
    
    # Check if file content is valid JSON (basic check)
    if command -v python3 &>/dev/null; then
        if ! python3 -c "import json; json.load(open('${persistence_file}'))" &>/dev/null; then
            log_warning "Corrupted persistence file detected. Resetting."
            echo "{}" > "${persistence_file}"
            return 1
        fi
    else
         # Fallback basic check
         local content=$(cat "${persistence_file}")
         if [[ ! "${content}" =~ ^\{.*\}$ ]]; then
             log_warning "Corrupted persistence file detected (basic check). Resetting."
             echo "{}" > "${persistence_file}"
             return 1
         fi
    fi
    return 0
}

save_persistence_data() {
    local key="$1"
    local value="$2"
    detect_storage_dir
    local persistence_file="${STORAGE_DIR}/persistence.json"
    local timestamp=$(date +%s)
    
    init_persistence
    verify_integrity

    if command -v python3 &>/dev/null; then
        python3 -c "import json, os;
f='${persistence_file}';
try:
    data=json.load(open(f))
except:
    data={}
data['${key}']='${value}';
data['${key}_timestamp']=${timestamp};
json.dump(data, open(f,'w'), indent=2)"
        log_debug "Saved '${key}' to persistence file"
    else
        # Fallback to simple sed (fragile but works for simple flat JSON)
        log_warning "No Python found. Using basic JSON update."
        echo "{ \"${key}\": \"${value}\", \"${key}_timestamp\": ${timestamp} }" > "${persistence_file}"
    fi
}

get_persistence_data() {
    local key="$1"
    detect_storage_dir
    local persistence_file="${STORAGE_DIR}/persistence.json"
    
    if [[ ! -f "${persistence_file}" ]]; then echo ""; return; fi
    
    verify_integrity
    
    local value=""
    if command -v python3 &>/dev/null; then
        value=$(python3 -c "import json;
try:
  print(json.load(open('${persistence_file}')).get('${key}', ''))
except: pass")
    else
        value=$(grep -o "\"${key}\": *\"[^\"]*\"" "${persistence_file}" | cut -d'"' -f4)
    fi
    echo "${value}"
}

cleanup_persistence() {
    detect_storage_dir
    local persistence_file="${STORAGE_DIR}/persistence.json"
    local max_age=$((30 * 24 * 3600)) # 30 days
    local current_time=$(date +%s)
    
    if [[ ! -f "${persistence_file}" ]]; then return; fi
    
    if command -v python3 &>/dev/null; then
        python3 -c "import json, os, time;
f='${persistence_file}';
max_age=${max_age};
now=${current_time};
try:
    data=json.load(open(f));
    keys_to_del=[];
    for k in list(data.keys()):
        if not k.endswith('_timestamp'):
            ts = data.get(k+'_timestamp', 0);
            if now - ts > max_age:
                keys_to_del.append(k);
                keys_to_del.append(k+'_timestamp');
    for k in keys_to_del:
        if k in data: del data[k];
    json.dump(data, open(f,'w'), indent=2);
except Exception as e: pass"
        log_debug "Persistence cleanup check completed"
    fi
}

# ============================================================================
# Utility Functions
# ============================================================================

get_bot_id_from_token() {
    local token=$1

    local response
    response=$(curl -s -X GET "https://discord.com/api/v10/users/@me" \
        -H "Authorization: Bot ${token}" \
        -H "Content-Type: application/json" 2>/dev/null)

    if [[ -z "${response}" ]]; then
        return 1
    fi

    if echo "${response}" | grep -q '"code"'; then
        return 1
    fi

    local bot_id
    bot_id=$(echo "${response}" | grep -o '"id":"[0-9]*"' | head -1 | sed 's/"id":"\([0-9]*\)"/\1/')

    if [[ -z "${bot_id}" ]]; then
        return 1
    fi

    echo "${bot_id}"
    return 0
}

update_env() {
    local key=$1
    local value=$2

    if [[ ! -f "${ENV_FILE}" ]]; then
        touch "${ENV_FILE}"
    fi

    if [[ "${PLATFORM}" == "Mac" ]]; then
        if grep -q "^${key}=" "${ENV_FILE}" 2>/dev/null; then
            sed -i '' "s|^${key}=.*|${key}=${value}|g" "${ENV_FILE}"
        else
            echo "${key}=${value}" >> "${ENV_FILE}"
        fi
    else
        if grep -q "^${key}=" "${ENV_FILE}" 2>/dev/null; then
            sed -i "s|^${key}=.*|${key}=${value}|g" "${ENV_FILE}"
        else
            echo "${key}=${value}" >> "${ENV_FILE}"
        fi
    fi
}

read_with_default() {
    local prompt=$1
    local default=$2
    local var_name=$3
    local input

    if [[ -n "${default}" ]]; then
        read -r -p "$(echo -e "${CYAN}${prompt}${RESET} [${YELLOW}${default}${RESET}]: ")" input
        eval "${var_name}=\"\${input:-${default}}\""
    else
        read -r -p "$(echo -e "${CYAN}${prompt}${RESET}: ")" input
        eval "${var_name}=\"\${input}\""
    fi
}

check_command() {
    local cmd=$1
    if ! command -v "${cmd}" &> /dev/null; then
        log_warning "${cmd} is not installed."
        return 1
    fi
    return 0
}

# NEW: Function to install system build tools (make, cmake, etc.)
install_system_tools() {
    print_header "System Build Tools Check"

    if check_command "make"; then
        log_success "make is already installed."
        return 0
    fi

    log_warning "make (part of build-essential/Development Tools) is missing. Installing now."
    
    case "$OS_TYPE" in
        linux|wsl)
            log_info "Installing build-essential and cmake (requires sudo)..."
            if command -v apt &> /dev/null; then
                sudo apt update && sudo apt install -y build-essential cmake
            elif command -v dnf &> /dev/null; then
                sudo dnf groupinstall "Development Tools"
                sudo dnf install -y cmake
            elif command -v yum &> /dev/null; then
                sudo yum groupinstall "Development Tools"
                sudo yum install -y cmake
            else
                log_error "Cannot determine package manager (apt/dnf/yum). Please install build-essential and cmake manually."
                return 1
            fi
            ;;
        macos)
            log_info "Installing Xcode Command Line Tools and cmake (requires xcode-select)..."
            xcode-select --install 2>/dev/null || true # Ignore error if already installed
            if ! command -v brew &> /dev/null; then
                log_warning "Homebrew is not installed. cmake will not be installed automatically."
            else
                brew install cmake
            fi
            ;;
        *)
            log_warning "Automatic system tool installation is not supported for OS: ${OS_TYPE}. Please install 'make' and 'cmake' manually."
            return 1
            ;;
    esac

    if ! check_command "make"; then
        log_error "Failed to install 'make' and system tools."
        exit 1
    fi
    
    log_success "System build tools (make, gcc, cmake) are now installed."
}


install_bun() {
    log_info "Installing Bun..."

    if [[ "${OS_TYPE}" == "windows" ]]; then
        log_info "Installing Bun on Windows..."
        if ! powershell -c "irm bun.sh/install.ps1 | iex"; then
            log_error "Failed to install Bun. Please install manually from https://bun.sh"
            exit 1
        fi
    else
        log_info "Installing Bun on ${OS_TYPE}..."
        if ! curl -fsSL https://bun.sh/install | bash; then
            log_error "Failed to install Bun. Please install manually from https://bun.sh"
            exit 1
        fi

        # IMPORTANT FIX: Add bun to PATH for current session immediately
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"

        log_success "Bun installed successfully"
        log_info "Bun has been added to your PATH"

        # Verify bun is now accessible
        if ! command -v bun &> /dev/null; then
            log_error "Bun was installed but is not available in PATH."
            log_info "Please run: source ~/.bashrc"
            log_info "Then restart this script."
            exit 1
        fi
    fi

    log_success "Bun is ready to use"
}

check_and_install_bun() {
    if ! check_command "bun"; then
        echo -e "${YELLOW}Bun is not installed. Would you like to install it now? (Y/n)${RESET}"
        read -r -p "> " INSTALL_BUN

        if [[ ! "${INSTALL_BUN}" =~ ^[Nn]$ ]]; then
            install_bun
        else
            log_error "Bun is required to run this bot. Please install it manually from https://bun.sh"
            exit 1
        fi
    else
        # FIX: Ensure PATH is set even if bun was pre-installed (crucial for execution)
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        log_success "Bun is already installed"
    fi
}

install_pm2() {
    log_info "Installing PM2..."

    if ! bun add -g pm2; then
        log_error "Failed to install PM2"
        exit 1
    fi

    log_success "PM2 installed successfully"
}

check_and_install_pm2() {
    if ! check_command "pm2"; then
        echo -e "${YELLOW}PM2 is not installed. Would you like to install it now? (Y/n)${RESET}"
        read -r -p "> " INSTALL_PM2

        if [[ ! "${INSTALL_PM2}" =~ ^[Nn]$ ]]; then
            install_pm2
        else
            log_error "PM2 is required to run this bot in production. Please install it manually."
            exit 1
        fi
    else
        log_success "PM2 is already installed"
    fi
}

check_curl() {
    if ! command -v curl &> /dev/null; then
        log_warning "curl is not installed. Bot ID auto-detection will be disabled."
        return 1
    fi
    return 0
}

# ============================================================================
# Repository Functions
# ============================================================================

get_git_token_access() {
    print_header "GitHub Configuration"

    detect_storage_dir
    
    # 1. Clean old persistence
    cleanup_persistence
    
    # 2. Try to load from persistence
    local persisted_token=$(get_persistence_data "GIT_TOKEN")
    
    if [[ -n "${persisted_token}" ]]; then
         GIT_TOKEN="${persisted_token}"
         log_success "Using GitHub token from persistence (loaded automatically)"
         export GIT_TOKEN
         return 0
    fi

    local token_file="${STORAGE_DIR}/git_token/container.txt"

    if [[ -f "${token_file}" ]]; then
        GIT_TOKEN=$(cat "${token_file}")
        # Trim whitespace
        GIT_TOKEN=$(echo "${GIT_TOKEN}" | xargs)
        
        if [[ -n "${GIT_TOKEN}" ]]; then
             log_success "Using GitHub token from file: ${token_file}"
             # Migrate to persistence
             save_persistence_data "GIT_TOKEN" "${GIT_TOKEN}"
             export GIT_TOKEN
             return 0
        fi
    fi

    echo -e "${CYAN}Enter your GitHub Personal Access Token${RESET}"
    echo -e "${YELLOW}Note: The token needs 'repo' scope to clone private repositories${RESET}"
    echo -e "${YELLOW}Create one at: https://github.com/settings/tokens${RESET}\n"

    read_with_default "GitHub Token Access" "" "GIT_TOKEN"

    if [[ -z "${GIT_TOKEN}" ]]; then
        log_error "GitHub token is required to clone the repository"
        exit 1
    fi

    # Trim whitespace
    GIT_TOKEN=$(echo "${GIT_TOKEN}" | xargs)

    # 3. Save to persistence
    save_persistence_data "GIT_TOKEN" "${GIT_TOKEN}"

    export GIT_TOKEN
    log_success "GitHub token configured and saved to persistence"
}

clone_git_repo() {
    if [[ ! -d "${REPO_NAME}" ]]; then
        log_info "Cloning ${REPO_NAME} repository..."

        # Remove https:// from REPO_URL to build the authenticated URL
        local repo_path="${REPO_URL#https://}"
        local clone_url="https://${GIT_TOKEN}@${repo_path}"

        log_info "Attempting to clone repository..."

        if ! git clone "${clone_url}" 2>&1; then
            log_error "Failed to clone repository."
            log_error "Possible issues:"
            log_error "  1. Invalid GitHub token"
            log_error "  2. Repository doesn't exist or is private"
            log_error "  3. Token doesn't have 'repo' permissions"
            exit 1
        fi

        if [[ ! -d "${REPO_NAME}" ]]; then
            log_error "Repository directory was not created after cloning."
            exit 1
        fi

        log_success "Repository cloned successfully"
    else
        log_info "Repository directory already exists, skipping clone."
    fi
}

# ============================================================================
# Installation Functions
# ============================================================================

# MODIFIED: Conditional installation based on SQLITE_DRIVER choice
install_dependencies() {
    log_info "Installing dependencies..."

    if [[ "${SQLITE_DRIVER}" == "bun:sqlite" ]]; then
        log_info "Skipping installation of native better-sqlite3 by removing it from the package.json..."
        
        # Remove 'better-sqlite3' from package.json to prevent installation failure
        if [[ "${PLATFORM}" == "Mac" ]]; then
            sed -i '' '/better-sqlite3/d' package.json 2>/dev/null
        else
            sed -i '/better-sqlite3/d' package.json 2>/dev/null
        fi

        # Remove lock file to force fresh dependency resolution without better-sqlite3
        if [[ -f "bun.lockb" ]]; then
             log_warning "bun.lockb exists. Deleting it to force a fresh dependency resolution."
             rm bun.lockb
        fi

        log_success "better-sqlite3 entry removed from package.json for bun:sqlite usage."
        
    elif [[ "${SQLITE_DRIVER}" == "better-sqlite3" ]]; then
        log_warning "Installing dependencies including better-sqlite3. Ensure system build tools are installed."
    fi

    if ! bun install; then
        log_error "Failed to install dependencies"
        
        if [[ "${SQLITE_DRIVER}" == "better-sqlite3" ]]; then
            log_error "Installation likely failed because of missing build tools (make/gcc) for better-sqlite3."
            log_info "Please ensure 'build-essential' and 'cmake' are installed."
        fi
        exit 1
    fi

    log_success "Dependencies installed successfully"
}

create_env_file() {
    if [[ ! -f "${ENV_FILE}" ]]; then
        log_info "Creating ${ENV_FILE} file..."
        touch "${ENV_FILE}"
        log_success "${ENV_FILE} file created"
    else
        log_warning "${ENV_FILE} file already exists. Will update values."
    fi
}

# ============================================================================
# Configuration Functions
# ============================================================================

# NEW: Function to select the SQLite driver
configure_sqlite_driver() {
    print_header "SQLite Driver Selection"

    echo -e "${CYAN}Which SQLite driver do you want to use?${RESET}"
    echo -e "1) ${GREEN}bun:sqlite${RESET} (Recommended for Bun - faster, no native dependency issues)"
    echo -e "2) ${YELLOW}better-sqlite3${RESET} (Node.js native module - high compatibility, requires build tools)"
    
    local choice
    while true; do
        read -r -p "$(echo -e "${CYAN}Select option (1 or 2)${RESET}: ")" choice
        case "${choice}" in
            1)
                SQLITE_DRIVER="bun:sqlite"
                log_success "Selected bun:sqlite"
                break
                ;;
            2)
                SQLITE_DRIVER="better-sqlite3"
                log_warning "Selected better-sqlite3 (Requires system build tools: make, C++ compiler)"
                break
                ;;
            *)
                log_error "Invalid selection. Please enter 1 or 2."
                ;;
        esac
    done
    
    # Store the choice in .env for application logic
    update_env "SQLITE_DRIVER" "${SQLITE_DRIVER}"
}


configure_bot_basics() {
    print_header "1. Bot Basic Configuration"

    read_with_default "Discord Bot Token" "" "BOT_TOKEN"
    [[ -z "${BOT_TOKEN}" ]] && log_error "Bot token is required" && exit 1
    update_env "token" "${BOT_TOKEN}"
    export BOT_TOKEN

    if [[ "${CURL_AVAILABLE}" == "true" ]]; then
        if BOT_ID=$(get_bot_id_from_token "${BOT_TOKEN}"); then
            log_success "Bot ID retrieved automatically: ${BOT_ID}"
            echo -e "${CYAN}Use this Bot ID? (Y/n)${RESET}"
            read -r -p "> " USE_AUTO_ID

            if [[ ! "${USE_AUTO_ID}" =~ ^[Nn]$ ]]; then
                export BOT_ID
            else
                read_with_default "Discord Bot ID" "" "BOT_ID"
                [[ -z "${BOT_ID}" ]] && log_error "Bot ID is required" && exit 1
                export BOT_ID
            fi
        else
            log_warning "Could not retrieve Bot ID automatically. Please enter it manually."
            read_with_default "Discord Bot ID" "" "BOT_ID"
            [[ -z "${BOT_ID}" ]] && log_error "Bot ID is required" && exit 1
            export BOT_ID
        fi
    else
        read_with_default "Discord Bot ID" "" "BOT_ID"
        [[ -z "${BOT_ID}" ]] && log_error "Bot ID is required" && exit 1
        export BOT_ID
    fi

    update_env "botId" "${BOT_ID}"

    read_with_default "Owner/Buyer Discord ID" "" "BUYER_ID"
    [[ -z "${BUYER_ID}" ]] && log_error "Buyer ID is required" && exit 1
    update_env "buyer" "${BUYER_ID}"

    read_with_default "Command Prefix" "/" "PREFIX"
    update_env "prefix" "${PREFIX}"

    read_with_default "Enable Sharding? (true/false)" "false" "ENABLE_SHARDING"
    update_env "ENABLE_SHARDING" "${ENABLE_SHARDING}"

    log_success "Bot basics configured"
}

configure_ai_apis() {
    print_header "2. AI & API Keys Configuration"
    echo -e "${CYAN}Press Enter to use default values or skip optional keys${RESET}\n"

    read_with_default "Google Gemini API Key" "" "GEMINI_KEY"
    update_env "gemini_api_key" "${GEMINI_KEY}"

    read_with_default "Grok API Key (xAI)" "" "GROK_KEY"
    update_env "api_grok" "${GROK_KEY}"

    read_with_default "Hugging Face API Key" "" "HF_KEY"
    update_env "api_hf" "${HF_KEY}"


    log_success "AI APIs configured"
}

configure_spotify() {
    print_header "3. Spotify Integration"

    read_with_default "Spotify Client ID" "" "SPOTIFY_ID"
    update_env "api_spotify_id" "${SPOTIFY_ID}"

    read_with_default "Spotify Client Secret" "" "SPOTIFY_SECRET"
    update_env "api_spotify_secret" "${SPOTIFY_SECRET}"

    log_success "Spotify configured"
}


configure_webhooks() {
    print_header "6. Webhook Configuration"

    read_with_default "Error Webhook URL (optional)" "" "ERROR_WEBHOOK"
    if [[ -n "${ERROR_WEBHOOK}" ]]; then
        update_env "ERROR_WEBHOOK_URL" "${ERROR_WEBHOOK}"
    fi

    read_with_default "Log Webhook URL (optional)" "" "LOG_WEBHOOK"
    if [[ -n "${LOG_WEBHOOK}" ]]; then
        update_env "LOG_WEBHOOK_URL" "${LOG_WEBHOOK}"
    fi

    log_success "Webhooks configured"
}

configure_app_settings() {
    print_header "7. Application Settings"

    read_with_default "Node Environment (development/production)" "production" "NODE_ENV"
    update_env "NODE_ENV" "${NODE_ENV}"

    read_with_default "Enable Debug Mode? (true/false)" "false" "DEBUG_MODE"
    update_env "DEBUG_MODE" "${DEBUG_MODE}"

    log_success "App settings configured"
}

configure_optional_features() {
    print_header "8. Optional Features"

    echo -e "${CYAN}Configure optional features (press Enter to skip)${RESET}\n"

    read_with_default "Enable Analytics? (true/false)" "false" "ENABLE_ANALYTICS"
    update_env "ENABLE_ANALYTICS" "${ENABLE_ANALYTICS}"

    read_with_default "Enable Auto Backup? (true/false)" "true" "ENABLE_BACKUP"
    update_env "ENABLE_BACKUP" "${ENABLE_BACKUP}"

    log_success "Optional features configured"
}

configure_customization() {
    print_header "9. Customization"

    read_with_default "Bot Status Message" "Playing with music!" "STATUS_MESSAGE"
    update_env "STATUS_MESSAGE" "${STATUS_MESSAGE}"

    read_with_default "Support Server Invite (optional)" "" "SUPPORT_SERVER"
    if [[ -n "${SUPPORT_SERVER}" ]]; then
        update_env "SUPPORT_SERVER" "${SUPPORT_SERVER}"
    fi

    log_success "Customization configured"
}

show_summary() {
    print_header "Configuration Summary"
    echo -e "${GREEN}✓ Bot Configuration Complete!${RESET}\n"
    echo -e "${CYAN}Bot ID:${RESET} ${BOT_ID}"
    echo -e "${CYAN}Buyer ID:${RESET} ${BUYER_ID}"
    echo -e "${CYAN}Prefix:${RESET} ${PREFIX}"
    echo -e "${CYAN}Environment:${RESET} ${NODE_ENV}"
    echo -e "${CYAN}Sharding:${RESET} ${ENABLE_SHARDING}"
    echo -e "${CYAN}SQLite Driver:${RESET} ${SQLITE_DRIVER}"
}

start_bot_with_pm2() {
    log_info "Starting bot with PM2..."

    if pm2 start bun --name "${PM2_PROCESS_PREFIX}_${BOT_ID}" -- index.ts; then
        log_success "Bot started successfully!"
        log_info "View logs with: pm2 logs ${PM2_PROCESS_PREFIX}_${BOT_ID}"
        log_info "Stop bot with: pm2 stop ${PM2_PROCESS_PREFIX}_${BOT_ID}"
        log_info "Restart bot with: pm2 restart ${PM2_PROCESS_PREFIX}_${BOT_ID}"
    else
        log_error "Failed to start bot with PM2"
        exit 1
    fi
}

# ============================================================================
# Main Script Execution
# ============================================================================

main() {
    clear_screen
    detect_platform
    setup_colors

    echo -e "${BLUE}╔════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║   Clarity V2 - Complete Setup Script  ║${RESET}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${RESET}\n"
    echo -e "${YELLOW}Detected OS: ${OS_TYPE}${RESET}\n"

    # Check Git
    if ! check_command "git"; then
        log_error "Git is not installed. Please install it first."
        case "${PLATFORM}" in
            Linux)
                log_info "Install with: sudo apt install git"
                ;;
            Mac)
                log_info "Install with: brew install git"
                ;;
            Windows)
                log_info "Download from: https://git-scm.com/download/win"
                ;;
        esac
        exit 1
    fi
    log_success "Git is installed"
    
    # NEW: Install system tools (make, gcc, cmake) before using Bun/NPM/Yarn
    install_system_tools

    # Check and install Bun
    check_and_install_bun

    # Check and install PM2
    check_and_install_pm2

    CURL_AVAILABLE=false
    if check_curl; then
        CURL_AVAILABLE=true
    fi

    cd "${SCRIPT_DIR}" || exit 1

    if [[ ! -d "${REPO_NAME}" ]]; then
        get_git_token_access
        clone_git_repo
    else
        log_success "Repository directory '${REPO_NAME}' already exists."
    fi

    if [[ ! -d "${REPO_NAME}" ]]; then
        log_error "Repository directory '${REPO_NAME}' does not exist. Clone may have failed."
        exit 1
    fi

    cd "${REPO_NAME}" || {
        log_error "Failed to change directory to ${REPO_NAME}"
        exit 1
    }

    log_success "Working directory: $(pwd)"
    
    # NOUVEAU: Configuration du driver SQLite
    configure_sqlite_driver

    install_dependencies
    create_env_file

    configure_bot_basics
    configure_ai_apis
    configure_spotify
    configure_webhooks
    configure_app_settings
    configure_optional_features
    configure_customization

    show_summary

    echo -e "\n${YELLOW}Start bot now? (y/n)${RESET}"
    read -r -p "> " START_NOW

    if [[ "${START_NOW}" =~ ^[Yy]$ ]]; then
        start_bot_with_pm2
    else
        echo -e "\n${CYAN}You can start the bot later with:${RESET}"
        echo -e "${YELLOW}cd ${REPO_NAME} && pm2 start bun --name '${PM2_PROCESS_PREFIX}_${BOT_ID}' -- index.ts${RESET}\n"
    fi

    echo -e "\n${GREEN}╔════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║      Setup Complete! 🎉               ║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${RESET}\n"
}

main "$@"