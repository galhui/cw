#!/bin/bash
#
# cw (Claude Workspace) - tmux-based workspace manager for Claude Code
#
# Usage:
#   cw                     Open all favorite projects
#   cw <alias> [alias...]  Open specific project(s)
#   cw fav                 Open all favorites
#   cw fav add <alias>     Add to favorites
#   cw fav remove <alias>  Remove from favorites
#   cw fav list            List favorites
#   cw add <alias> <path>  Register a project
#   cw remove <alias>      Remove a project
#   cw rename <old> <new>  Rename alias
#   cw projects            List registered projects
#   cw list                List active tmux sessions
#   cw kill <alias>        Kill a session
#   cw kill-all            Kill all sessions
#

set -e

CONFIG_DIR="$HOME/.cw"
CONFIG_FILE="$CONFIG_DIR/config.json"
SESSION_PREFIX="cw_"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- JSON helpers (uses python3) ---

json_get() {
    python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
keys = '$1'.split('.')
for k in keys:
    if isinstance(data, dict):
        data = data.get(k, {})
    else:
        data = {}
if isinstance(data, (dict, list)):
    print(json.dumps(data))
else:
    print(data)
"
}

json_set() {
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
$1
with open('$CONFIG_FILE', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
}

get_project_path() {
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
path = data.get('projects', {}).get('$1', '')
print(path)
"
}

get_favorites() {
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for f in data.get('favorites', []):
    print(f)
"
}

get_claude_flags() {
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
print(data.get('claude_flags', ''))
"
}

get_all_projects() {
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
favs = data.get('favorites', [])
for name, path in sorted(data.get('projects', {}).items()):
    star = ' ★' if name in favs else ''
    print(f'{name}\t{path}{star}')
"
}

# --- Init ---

init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p "$CONFIG_DIR"
        cat > "$CONFIG_FILE" << 'EOF'
{
  "projects": {},
  "favorites": [],
  "claude_flags": "",
  "terminal": "auto"
}
EOF
        echo -e "${GREEN}Config created: $CONFIG_FILE${NC}"
    fi
}

# --- Terminal detection & tab opening ---

detect_terminal() {
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
t = data.get('terminal', 'auto')
if t != 'auto':
    print(t)
elif '$TERM_PROGRAM' == 'iTerm.app':
    print('iterm')
elif '$TERM_PROGRAM' == 'Apple_Terminal':
    print('terminal')
elif '${KITTY_WINDOW_ID:-}' != '':
    print('kitty')
elif '${WEZTERM_PANE:-}' != '':
    print('wezterm')
else:
    print('tmux')
"
}

open_tab() {
    local alias_name="$1"
    local is_first="$2"
    local tmux_session="${SESSION_PREFIX}${alias_name}"
    local terminal
    terminal=$(detect_terminal)

    case "$terminal" in
        iterm)
            if [ "$is_first" = "true" ]; then
                osascript <<APPLESCRIPT
tell application "iTerm2"
    activate
    if (count of windows) = 0 then
        set newWindow to (create window with default profile)
        tell current session of current tab of newWindow
            write text "tmux attach -t ${tmux_session}"
        end tell
    else
        tell current window
            tell current session of current tab
                write text "tmux attach -t ${tmux_session}"
            end tell
        end tell
    end if
end tell
APPLESCRIPT
            else
                osascript <<APPLESCRIPT
tell application "iTerm2"
    activate
    tell current window
        set newTab to (create tab with default profile)
        tell current session of newTab
            write text "tmux attach -t ${tmux_session}"
        end tell
    end tell
end tell
APPLESCRIPT
            fi
            ;;
        terminal)
            osascript <<APPLESCRIPT
tell application "Terminal"
    activate
    do script "tmux attach -t ${tmux_session}"
end tell
APPLESCRIPT
            ;;
        kitty)
            kitty @ launch --type=tab tmux attach -t "$tmux_session" 2>/dev/null || true
            ;;
        wezterm)
            wezterm cli spawn -- tmux attach -t "$tmux_session" 2>/dev/null || true
            ;;
        tmux|*)
            # Fallback: just print instructions
            echo -e "  ${CYAN}Run:${NC} tmux attach -t ${tmux_session}"
            ;;
    esac
}

# --- Core: start project ---

start_project() {
    local alias_name="$1"
    local is_first="$2"
    local project_path
    project_path=$(get_project_path "$alias_name")

    if [ -z "$project_path" ]; then
        echo -e "${RED}Unknown project: $alias_name${NC}"
        echo "  Run 'cw projects' to see registered projects."
        return 1
    fi

    if [ ! -d "$project_path" ]; then
        echo -e "${RED}Path not found: $project_path${NC}"
        return 1
    fi

    local tmux_session="${SESSION_PREFIX}${alias_name}"
    local claude_flags
    claude_flags=$(get_claude_flags)

    if tmux has-session -t "$tmux_session" 2>/dev/null; then
        echo -e "${CYAN}[attach]${NC} ${BOLD}$alias_name${NC} - connecting to existing session"
    else
        echo -e "${GREEN}[start]${NC} ${BOLD}$alias_name${NC} - $project_path"
        tmux new-session -d -s "$tmux_session" -c "$project_path"

        local cmd="claude"
        if [ -n "$claude_flags" ]; then
            # Remove --continue flag (fails if no prior conversation)
            local flags_clean
            flags_clean=$(echo "$claude_flags" | sed 's/--continue//g' | xargs)
            if [ -n "$flags_clean" ]; then
                cmd="claude $flags_clean"
            fi
        fi
        tmux send-keys -t "$tmux_session" "$cmd" Enter
    fi

    open_tab "$alias_name" "$is_first"
}

start_multiple() {
    local projects=("$@")
    local first="true"

    for alias_name in "${projects[@]}"; do
        start_project "$alias_name" "$first"
        first="false"
        sleep 0.5
    done
}

# --- Command handlers ---

cmd_fav() {
    local sub="$1"
    shift 2>/dev/null || true

    case "$sub" in
        add)
            local alias_name="$1"
            if [ -z "$alias_name" ]; then
                echo -e "${RED}Usage: cw fav add <alias>${NC}"
                return 1
            fi
            local path
            path=$(get_project_path "$alias_name")
            if [ -z "$path" ]; then
                echo -e "${RED}Unknown project: $alias_name${NC}"
                return 1
            fi
            json_set "
if '$alias_name' not in data.get('favorites', []):
    data.setdefault('favorites', []).append('$alias_name')
"
            echo -e "${GREEN}Added to favorites: $alias_name${NC}"
            ;;
        remove)
            local alias_name="$1"
            if [ -z "$alias_name" ]; then
                echo -e "${RED}Usage: cw fav remove <alias>${NC}"
                return 1
            fi
            json_set "
if '$alias_name' in data.get('favorites', []):
    data['favorites'].remove('$alias_name')
"
            echo -e "${GREEN}Removed from favorites: $alias_name${NC}"
            ;;
        list)
            echo -e "${BLUE}=== Favorites ===${NC}"
            local favs
            favs=$(get_favorites)
            if [ -z "$favs" ]; then
                echo "No favorites yet."
                return
            fi
            while IFS= read -r name; do
                local path
                path=$(get_project_path "$name")
                echo -e "  ${BOLD}$name${NC} → $path"
            done <<< "$favs"
            ;;
        ""|*)
            if [ -n "$sub" ] && [ "$sub" != "add" ] && [ "$sub" != "remove" ] && [ "$sub" != "list" ]; then
                echo -e "${RED}Usage: cw fav [add|remove|list]${NC}"
                return 1
            fi
            local favs_arr=()
            while IFS= read -r name; do
                [ -n "$name" ] && favs_arr+=("$name")
            done <<< "$(get_favorites)"

            if [ ${#favs_arr[@]} -eq 0 ]; then
                echo -e "${YELLOW}No favorites. Add with: cw fav add <alias>${NC}"
                return 1
            fi

            echo -e "${BLUE}=== Starting favorites ===${NC}"
            start_multiple "${favs_arr[@]}"
            echo -e "\n${GREEN}Done! ${#favs_arr[@]} project(s) started.${NC}"
            ;;
    esac
}

cmd_add() {
    local alias_name="$1"
    local project_path="$2"

    if [ -z "$alias_name" ] || [ -z "$project_path" ]; then
        echo -e "${RED}Usage: cw add <alias> <path>${NC}"
        return 1
    fi

    project_path=$(cd "$project_path" 2>/dev/null && pwd || echo "$project_path")

    if [ ! -d "$project_path" ]; then
        echo -e "${RED}Path not found: $project_path${NC}"
        return 1
    fi

    json_set "data.setdefault('projects', {})['$alias_name'] = '$project_path'"
    echo -e "${GREEN}Registered: $alias_name → $project_path${NC}"
}

cmd_remove() {
    local alias_name="$1"
    if [ -z "$alias_name" ]; then
        echo -e "${RED}Usage: cw remove <alias>${NC}"
        return 1
    fi

    json_set "
data.get('projects', {}).pop('$alias_name', None)
if '$alias_name' in data.get('favorites', []):
    data['favorites'].remove('$alias_name')
"
    echo -e "${GREEN}Removed: $alias_name${NC}"
}

cmd_rename() {
    local old_name="$1"
    local new_name="$2"

    if [ -z "$old_name" ] || [ -z "$new_name" ]; then
        echo -e "${RED}Usage: cw rename <old> <new>${NC}"
        return 1
    fi

    json_set "
path = data.get('projects', {}).pop('$old_name', None)
if path:
    data['projects']['$new_name'] = path
    if '$old_name' in data.get('favorites', []):
        idx = data['favorites'].index('$old_name')
        data['favorites'][idx] = '$new_name'
"
    echo -e "${GREEN}Renamed: $old_name → $new_name${NC}"
}

cmd_projects() {
    echo -e "${BLUE}=== Registered Projects ===${NC}"
    local output
    output=$(get_all_projects)
    if [ -z "$output" ]; then
        echo "No projects registered."
        return
    fi
    while IFS=$'\t' read -r name path_star; do
        echo -e "  ${BOLD}$name${NC} → $path_star"
    done <<< "$output"
}

cmd_list() {
    echo -e "${BLUE}=== Active Workspaces ===${NC}"

    local sessions
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^${SESSION_PREFIX}" || true)

    if [ -z "$sessions" ]; then
        echo "No active sessions."
        return
    fi

    while IFS= read -r session; do
        local alias_name="${session#$SESSION_PREFIX}"
        local pane_path
        pane_path=$(tmux display-message -t "$session" -p "#{pane_current_path}" 2>/dev/null || echo "unknown")

        local last_output
        last_output=$(tmux capture-pane -t "$session" -p -S -3 2>/dev/null | tail -3)

        local status
        if echo "$last_output" | grep -qE '\? \[?[Yy]/[Nn]\]?|Enter to confirm|\(yes/no\)|❯'; then
            status="${YELLOW}[waiting]${NC}"
        else
            status="${GREEN}[running]${NC}"
        fi

        echo -e "  ${BOLD}$alias_name${NC} $status"
        echo -e "    path: $pane_path"
    done <<< "$sessions"
}

cmd_kill() {
    local alias_name="$1"
    if [ -z "$alias_name" ]; then
        echo -e "${RED}Usage: cw kill <alias>${NC}"
        return 1
    fi

    local tmux_session="${SESSION_PREFIX}${alias_name}"
    if tmux has-session -t "$tmux_session" 2>/dev/null; then
        tmux kill-session -t "$tmux_session"
        echo -e "${GREEN}Killed: $alias_name${NC}"
    else
        echo -e "${RED}Session not found: $alias_name${NC}"
        return 1
    fi
}

cmd_kill_all() {
    local sessions
    sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "^${SESSION_PREFIX}" || true)

    if [ -z "$sessions" ]; then
        echo "No sessions to kill."
        return
    fi

    local count=0
    while IFS= read -r session; do
        tmux kill-session -t "$session" 2>/dev/null
        local alias_name="${session#$SESSION_PREFIX}"
        echo -e "${GREEN}Killed: $alias_name${NC}"
        ((count++))
    done <<< "$sessions"

    echo -e "\n${GREEN}${count} session(s) killed.${NC}"
}

cmd_help() {
    echo -e "${BOLD}cw${NC} - Claude Workspace manager"
    echo ""
    echo -e "${CYAN}Start projects:${NC}"
    echo "  cw                     Open all favorites"
    echo "  cw <alias> [alias...]  Open specific project(s)"
    echo ""
    echo -e "${CYAN}Favorites:${NC}"
    echo "  cw fav                 Open all favorites"
    echo "  cw fav add <alias>     Add to favorites"
    echo "  cw fav remove <alias>  Remove from favorites"
    echo "  cw fav list            List favorites"
    echo ""
    echo -e "${CYAN}Project management:${NC}"
    echo "  cw add <alias> <path>  Register a project"
    echo "  cw remove <alias>      Remove a project"
    echo "  cw rename <old> <new>  Rename alias"
    echo "  cw projects            List all projects"
    echo ""
    echo -e "${CYAN}Session management:${NC}"
    echo "  cw list                List active sessions"
    echo "  cw kill <alias>        Kill a session"
    echo "  cw kill-all            Kill all sessions"
    echo ""
    echo -e "${CYAN}Config:${NC}"
    echo "  ~/.cw/config.json      Configuration file"
    echo ""
    echo -e "${CYAN}Other:${NC}"
    echo "  cw update              Update to latest version"
    echo "  cw version             Show version"
    echo "  cw help                Show this help"
}

CW_VERSION="1.0.0"

cmd_version() {
    echo -e "${BOLD}cw${NC} v${CW_VERSION}"
}

cmd_update() {
    local RAW_URL="https://raw.githubusercontent.com/galhui/cw/main/cw"
    local SELF_PATH
    SELF_PATH="$(realpath "$0")"

    echo -e "Checking for updates..."

    # Download to temp file
    local tmp_file
    tmp_file=$(mktemp)
    if ! curl -fsSL "$RAW_URL" -o "$tmp_file" 2>/dev/null; then
        echo -e "${RED}Failed to download update.${NC}"
        rm -f "$tmp_file"
        return 1
    fi

    # Extract remote version
    local remote_version
    remote_version=$(grep '^CW_VERSION=' "$tmp_file" | head -1 | cut -d'"' -f2)

    if [ -z "$remote_version" ]; then
        echo -e "${RED}Could not determine remote version.${NC}"
        rm -f "$tmp_file"
        return 1
    fi

    if [ "$remote_version" = "$CW_VERSION" ]; then
        echo -e "${GREEN}Already up to date (v${CW_VERSION}).${NC}"
        rm -f "$tmp_file"
        return 0
    fi

    # Update
    chmod +x "$tmp_file"
    mv "$tmp_file" "$SELF_PATH"
    echo -e "${GREEN}Updated: v${CW_VERSION} → v${remote_version}${NC}"
}

# --- Main ---

init_config

case "${1:-}" in
    "")
        cmd_fav ""
        ;;
    fav)
        shift
        cmd_fav "$@"
        ;;
    add)
        shift
        cmd_add "$@"
        ;;
    remove)
        shift
        cmd_remove "$@"
        ;;
    rename)
        shift
        cmd_rename "$@"
        ;;
    projects)
        cmd_projects
        ;;
    list)
        cmd_list
        ;;
    kill)
        shift
        cmd_kill "$@"
        ;;
    kill-all)
        cmd_kill_all
        ;;
    help|-h|--help)
        cmd_help
        ;;
    version|-v|--version)
        cmd_version
        ;;
    update)
        cmd_update
        ;;
    *)
        start_multiple "$@"
        echo -e "\n${GREEN}Done! $# project(s) started.${NC}"
        ;;
esac
