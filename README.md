# Kollaborate

> Autonomous Multi-Agent Development Framework

Kollaborate orchestrates multiple AI agents working in parallel on complex software projects. It's a general-purpose LLM CLI management framework designed for massive parallelization and autonomous operations.

## Quick Start

### Installation

**Remote Installation (Recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/maarco/kollaborate/main/install.sh | zsh
source ~/.zshrc  # or ~/.bashrc
```

**Local Installation**

```bash
git clone https://github.com/maarco/kollaborate.git
cd kollaborate
./install.sh
source ~/.zshrc  # or ~/.bashrc
```

The same script works for both remote and local installation, automatically detecting the method and installing to `~/.kollaborate`.

### Initialize a Project

```bash
cd your-project
kollaborate init
```

### Start the Agent Watcher

```bash
kollaborate start 3 2  # 3 task agents, 2 spec agents
```

## Features

- **17 Typed Task System**: Specialized prompts for features, refactors, bugs, tests, docs, performance, architecture, security, hotfixes, migrations, integrations, chores, experiments, UX, validation, workflows, and exploration
- **Parallel Agent Execution**: Multiple agents work simultaneously on different tasks
- **Automatic Spec Generation**: Agents create detailed specifications before implementation
- **Activity Monitoring**: 3-strike idle detection with automatic cleanup
- **Task State Management**: NEW → WORKING → DONE/QA workflow
- **Global Installation**: Runs from ~/.kollaborate without per-project file copying

## Task Types

| Type | Prefix | Description |
|------|--------|-------------|
| Feature | F## | New functionality implementation |
| Refactor | R## | Code quality improvements, restructuring |
| Bug | B## | Fixes and corrections |
| Test | T## | Test coverage, test improvements |
| Doc | D## | Documentation, API docs, comments |
| Perf | P## | Performance optimization, profiling |
| Arch | A## | Architecture, design patterns, setup |
| Security | S## | Security hardening, vulnerability fixes |
| Hotfix | H## | URGENT production fixes only |
| Migration | M## | Database migrations, data transformations |
| Integration | I## | Third-party service integrations |
| Chore | C## | Dependency updates, maintenance |
| Experiment | E## | POC/spike work, research experiments |
| UX | U## | User experience, accessibility |
| Validation | V## | Input validation, schema enforcement |
| Workflow | W## | CI/CD, automation pipelines |
| Exploration | X## | Research, analysis, investigation |

## Usage

```bash
# Initialize in current directory
kollaborate init

# Start daemon with 3 task agents and 2 spec agents
kollaborate start 3 2

# Check status
kollaborate status

# Add tasks with types
kollaborate add feature "User authentication" src/auth.js
kollaborate add test "API integration tests" tests/api.test.js
kollaborate add bug "Fix memory leak" src/pool.js

# Show help
kollaborate help
```

## Architecture

### Agent Lifecycle

1. **NEW tasks** trigger specification agent creation
2. **Spec agents** generate detailed requirements (minimum 50 lines)
3. **Task agents** spawn once valid specs exist
4. **Activity monitoring** tracks agent progress via output hashing
5. **Cleanup** occurs when tasks transition to DONE/QA

### Task State Machine

```
NEW → WORKING → DONE/QA
  ↓       ↓
BLOCKED  ← (recycled if agent goes idle)
```

### File Structure

```
~/.kollaborate/           # Global installation
├── kollaborate           # CLI entry point
├── kollaborate.sh        # Agent watcher daemon
└── kollaborate.md        # Framework documentation

your-project/
├── TASK_TRACKING.md      # Task state manifest
└── specs/                # Generated specifications
    ├── F01-user-auth.md
    ├── R02-api-refactor.md
    └── T03-integration-tests.md
```

## Agent System Integration

Kollaborate is agent-agnostic but defaults to `tglm` commands. The framework uses these command patterns:

- `tglm "$agent_name" "$prompt"` - Spawn agent
- `tlist` - List active agents
- `tcapture "$agent"` - Get agent output
- `tmsg "$agent" "$message"` - Send message
- `tstop "$agent"` - Terminate agent

To adapt for different agent systems, modify the command patterns in `kollaborate.sh`.

## Configuration

Edit `kollaborate.sh` to customize:

```bash
MAX_AGENTS=3              # Maximum concurrent task agents
MAX_SPEC_AGENTS=2         # Maximum spec generation agents
CHECK_INTERVAL=60         # Monitoring cycle (seconds)
NEW_TASK_REQUIRED=5       # Minimum task queue size
SPEC_TIMEOUT=300          # Spec generation timeout (seconds)
```

## Requirements

- zsh or bash shell
- External agent system (e.g., tglm, Claude API, OpenAI API)
- Standard Unix utilities (sed, grep, awk)

## License

MIT

## Contributing

Contributions welcome! Please submit issues and pull requests to the GitHub repository.
