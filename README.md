# cw - Claude Workspace

A tmux-based workspace manager for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Run multiple Claude sessions across different projects, each in its own tmux session with a dedicated terminal tab.

```
$ cw list
=== Active Workspaces ===
  frontend [running]
    path: /Users/me/projects/frontend
  api [waiting]
    path: /Users/me/projects/api
  docs [running]
    path: /Users/me/projects/docs
```

## The Problem

If you work with Claude Code across multiple projects, you know the pain:

1. **Your terminal crashes or your Mac reboots** — all your Claude sessions are gone. You have to reopen every tab, `cd` into each project, and run `claude` again. If you had 5+ projects open, that's 5+ minutes of mindless setup just to get back to where you were.

2. **iTerm2 randomly quits**, your laptop runs out of battery, or macOS forces a restart for updates — same story. All context lost, all sessions dead.

3. **Daily startup friction** — every morning you repeat the same ritual: open terminal, make tabs, navigate to projects, start Claude in each one.

**cw** was built to solve exactly this. It wraps Claude sessions in tmux, so they survive terminal crashes, app quits, and even SSH disconnects. When iTerm2 dies, your Claude sessions keep running in the background. When your Mac reboots, just type `cw` and all your projects relaunch instantly — no manual `cd`, no remembering paths, no repetitive setup.

```
# Mac rebooted? iTerm2 crashed? No problem.
# One command to reconnect everything:
$ cw
=== Starting favorites ===
[attach] frontend - connecting to existing session
[attach] api - connecting to existing session
[attach] docs - connecting to existing session
Done! 3 project(s) started.
```

## Features

- **One command to rule them all** - `cw myapp` starts Claude in your project
- **Multi-project** - `cw frontend api docs` opens all three at once
- **Favorites** - `cw` (no args) opens all your favorite projects
- **Persistent sessions** - tmux sessions survive terminal disconnects
- **Status detection** - see which sessions are running vs waiting for input
- **Terminal support** - iTerm2, Terminal.app, Kitty, WezTerm, or plain tmux
- **Self-updating** - `cw update` pulls the latest version

## Requirements

- **tmux** - session management
- **python3** - JSON config parsing (ships with macOS/most Linux)
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** - the CLI itself

## Install

### Quick install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/galhui/cw/main/install.sh | bash
```

### Manual install

```bash
# Clone
git clone https://github.com/galhui/cw.git
cd cw

# Copy to your PATH
cp cw ~/bin/cw
chmod +x ~/bin/cw

# Make sure ~/bin is in your PATH
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
```

### Install tmux (if needed)

```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt install tmux

# Arch
pacman -S tmux
```

## Quick Start

```bash
# Register a project
cw add myapp ~/projects/myapp

# Start Claude in it
cw myapp

# Register more projects
cw add api ~/projects/api
cw add docs ~/projects/docs

# Open multiple at once
cw myapp api docs

# Add favorites for quick access
cw fav add myapp
cw fav add api

# Open all favorites with just:
cw
```

## Usage

### Project Management

```bash
cw add <alias> <path>     # Register a project
cw remove <alias>         # Remove a project
cw rename <old> <new>     # Rename alias
cw projects               # List all registered projects
```

### Starting Sessions

```bash
cw                        # Open all favorites
cw <alias>                # Open one project
cw <alias> <alias> ...    # Open multiple projects
```

### Favorites

```bash
cw fav list               # List favorites
cw fav add <alias>        # Add to favorites
cw fav remove <alias>     # Remove from favorites
```

### Session Management

```bash
cw list                   # Show active sessions with status
cw kill <alias>           # Kill a session
cw kill-all               # Kill all sessions
```

### Other

```bash
cw update                 # Update to latest version
cw version                # Show version
cw help                   # Show help
```

## Configuration

Config file: `~/.cw/config.json`

```json
{
  "projects": {
    "myapp": "/Users/me/projects/myapp",
    "api": "/Users/me/projects/api"
  },
  "favorites": ["myapp", "api"],
  "claude_flags": "",
  "terminal": "auto"
}
```

### Options

| Key | Description | Default |
|-----|-------------|---------|
| `projects` | Alias → path mapping | `{}` |
| `favorites` | List of favorite aliases | `[]` |
| `claude_flags` | Extra flags passed to `claude` CLI | `""` |
| `terminal` | Terminal app: `auto`, `iterm`, `terminal`, `kitty`, `wezterm`, `tmux` | `"auto"` |

### Claude Flags

Pass custom flags to the Claude CLI:

```json
{
  "claude_flags": "--dangerously-skip-permissions"
}
```

## How It Works

1. `cw myapp` creates a tmux session named `cw_myapp`
2. Sets the working directory to your project path
3. Runs `claude` (with any configured flags) inside the session
4. Opens a new terminal tab attached to that tmux session

If the session already exists, it just attaches to it (no duplicate sessions).

Sessions persist even if your terminal closes. Just run `cw myapp` again to reconnect.

## Tips

- **Detach from tmux** without killing the session: `Ctrl+B` then `D`
- **Switch between sessions** in tmux: `Ctrl+B` then `S`
- **Use with SSH**: Sessions persist on the remote machine; reconnect anytime
- **Pair with [CLAUDE.md](https://docs.anthropic.com/en/docs/claude-code/memory)**: Each project can have its own Claude instructions

## Update

```bash
cw update
```

Or reinstall:

```bash
curl -fsSL https://raw.githubusercontent.com/galhui/cw/main/install.sh | bash
```

## Uninstall

```bash
rm ~/bin/cw
rm -rf ~/.cw  # removes config (optional)
```

---

# 한국어 가이드

## cw란?

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) 사용자를 위한 tmux 기반 워크스페이스 관리 도구입니다. 여러 프로젝트에서 Claude를 동시에 실행하고, 각각을 별도의 tmux 세션 + 터미널 탭으로 관리합니다.

## 이런 경험 있으시죠?

Claude Code로 5개 프로젝트를 동시에 진행하고 있었는데...

- **맥북이 재부팅됐다** — iTerm2 탭 5개, 각 프로젝트 경로, Claude 세션 전부 날아감. 다시 하나하나 열고 `cd`하고 `claude` 실행하는 데만 5분.
- **iTerm2가 갑자기 꺼졌다** — 같은 상황. 작업하던 컨텍스트 전부 소멸.
- **macOS 업데이트로 강제 재시작** — 새벽에 몰래 재부팅되어 아침에 출근하면 빈 화면.
- **매일 아침 같은 루틴** — 터미널 열고, 탭 만들고, 폴더 이동하고, claude 실행. 매일 반복.

**cw**는 이 문제를 해결하기 위해 만들었습니다. Claude 세션을 tmux 안에서 실행하기 때문에 터미널이 꺼져도 세션이 살아있습니다. 맥이 재부팅되더라도 `cw` 한 번이면 모든 프로젝트가 즉시 재실행됩니다 — 경로 기억할 필요 없이, 반복 설정 없이.

```bash
# 맥 재부팅 후, iTerm2 크래시 후... 상관없이:
$ cw
=== Starting favorites ===
[attach] frontend - connecting to existing session
[attach] api - connecting to existing session
[attach] docs - connecting to existing session
Done! 3 project(s) started.
```

## 설치

### 원라인 설치

```bash
curl -fsSL https://raw.githubusercontent.com/galhui/cw/main/install.sh | bash
```

### 필수 사항

| 종속성 | 설치 방법 | 비고 |
|--------|-----------|------|
| **tmux** | `brew install tmux` (macOS) / `apt install tmux` (Ubuntu) | 세션 관리 |
| **python3** | macOS/Linux 기본 탑재 | config 파싱 |
| **Claude Code** | `npm install -g @anthropic-ai/claude-code` | Claude CLI |

### 수동 설치

```bash
git clone https://github.com/galhui/cw.git
cp cw/cw ~/bin/cw
chmod +x ~/bin/cw
```

`~/bin`이 PATH에 없다면:
```bash
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## 사용법

### 프로젝트 등록

```bash
cw add myapp ~/projects/myapp     # 프로젝트 등록
cw add api ~/projects/api         # 여러 개 등록 가능
cw projects                       # 등록 목록 확인
```

### 세션 시작

```bash
cw myapp                          # 하나만 열기
cw myapp api docs                 # 여러 개 동시에 열기
```

### 즐겨찾기

매일 쓰는 프로젝트를 즐겨찾기에 등록하면 `cw` 한 번으로 전부 실행:

```bash
cw fav add myapp                  # 즐겨찾기 추가
cw fav add api
cw fav list                       # 즐겨찾기 목록
cw                                # 즐겨찾기 전부 실행!
```

### 세션 관리

```bash
cw list                           # 활성 세션 + 상태 확인
cw kill myapp                     # 특정 세션 종료
cw kill-all                       # 전체 종료
```

### 업데이트

```bash
cw update                         # 최신 버전으로 업데이트
cw version                        # 현재 버전 확인
```

## 설정 파일

`~/.cw/config.json`에 저장됩니다:

```json
{
  "projects": {
    "myapp": "/Users/me/projects/myapp"
  },
  "favorites": ["myapp"],
  "claude_flags": "",
  "terminal": "auto"
}
```

| 설정 | 설명 | 기본값 |
|------|------|--------|
| `claude_flags` | claude 실행 시 추가 플래그 | `""` |
| `terminal` | 터미널 앱 (`auto`/`iterm`/`terminal`/`kitty`/`wezterm`/`tmux`) | `"auto"` |

## 작동 원리

1. `cw myapp` 실행 → tmux 세션 `cw_myapp` 생성
2. 프로젝트 디렉토리로 이동
3. `claude` CLI 실행
4. 새 터미널 탭에서 해당 tmux 세션에 연결

이미 세션이 있으면 새로 만들지 않고 기존 세션에 연결합니다. 터미널을 닫아도 tmux 세션은 유지되므로, `cw myapp`으로 다시 연결하면 됩니다.

## 삭제

```bash
rm ~/bin/cw
rm -rf ~/.cw          # 설정 파일 삭제 (선택)
```

---

## License

MIT

## Contributing

Issues and PRs welcome at [github.com/galhui/cw](https://github.com/galhui/cw).
