# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Kollaborate** is an autonomous multi-agent development framework that orchestrates multiple AI agents working in parallel on complex software projects. It's a general-purpose LLM CLI Management Framework designed for massive parallelization and autonomous operations.

### Core Components

1. **kollaborate** - Main CLI wrapper for initializing and managing projects
2. **kollaborate.sh** - Agent watcher daemon that monitors tasks and spawns agents
3. **TASK_TRACKING.md** - Project-specific task tracking file (created per project)
4. **specs/** - Directory containing detailed specifications for tasks

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

### Key Files Structure

```
kollaborate/
├── kollaborate           # CLI entry point (zsh script)
├── kollaborate.sh        # Agent watcher daemon
├── kollaborate.md        # Framework documentation template
└── install.sh            # PATH installation script

project-using-kollaborate/
├── TASK_TRACKING.md      # Task state manifest
├── specs/                # Generated specifications
│   └── R##-task-name.md
└── .kollaborate/         # Runtime files
    └── kollaborate.sh    # Copied daemon
```

## Development Commands

### Using the CLI

```bash
# Initialize Kollaborate in a project
./kollaborate init

# Start the agent watcher daemon (3 task agents, 2 spec agents)
./kollaborate start 3 2

# Check status
./kollaborate status

# Add a new task (with type)
./kollaborate add feature "Implement user profile page" src/pages/Profile.js
./kollaborate add test "Add unit tests for auth" src/tests/auth.test.js
./kollaborate add refactor "Clean up API handlers" src/api/handlers.js

# Add task (defaults to refactor type if no type specified)
./kollaborate add "Task description (file: path/to/file.ext)"

# Show help
./kollaborate help
```

### Agent Management (via external agent system like tglm)

```bash
tglm agentName "task"    # Launch agent
tlist                    # List active agents
tcapture agentName       # View agent output
tmsg agentName "msg"     # Message agent
tstop agentName          # Stop agent
```

## Task Tracking Protocol

Tasks in `TASK_TRACKING.md` use typed prefixes with state and sequential numbering:

**Task Format**: `STATE: TYPE## - [description] (file: path)`

### Task Types (17 specialized types):

- **F##** (Feature) - New functionality implementation
- **R##** (Refactor) - Code quality improvements, restructuring
- **B##** (Bug) - Fixes and corrections
- **T##** (Test) - Test coverage, test improvements
- **D##** (Doc) - Documentation, API docs, comments
- **P##** (Perf) - Performance optimization, profiling
- **A##** (Arch) - Architecture, design patterns, setup
- **S##** (Security) - Security hardening, vulnerability fixes
- **H##** (Hotfix) - URGENT production fixes only
- **M##** (Migration) - Database migrations, data transformations
- **I##** (Integration) - Third-party service integrations
- **C##** (Chore) - Dependency updates, maintenance
- **E##** (Experiment) - POC/spike work, research experiments
- **U##** (UX) - User experience, accessibility
- **V##** (Validation) - Input validation, schema enforcement
- **W##** (Workflow) - CI/CD, automation pipelines
- **X##** (Exploration) - Research, analysis, investigation

### Task States:

- `NEW: TYPE## - [description] (file: path)` - Pending tasks
- `WORKING: TYPE## - [description]` - Active development
- `DONE: TYPE## - [description]` - Completed tasks
- `QA: TYPE## - [description]` - Awaiting quality review
- `BLOCKED: TYPE## - [description] [reason]` - Blocked tasks

Each task type maintains its own sequential numbering (F1, F2... R1, R2... T1, T2...) and must include explicit file targets.

## Typed Task System Architecture

The typed task system provides specialized agent prompts for each task type:

### Type-Specific Agent Behavior

Each task type receives a unique prompt template with specialized requirements:

- **TEST (T##)**: Requires >80% coverage, edge cases, error paths, all tests passing
- **REFACTOR (R##)**: Must preserve behavior, improve structure, maintain API contracts
- **SECURITY (S##)**: OWASP Top 10 compliance, threat modeling, vulnerability testing
- **PERFORMANCE (P##)**: Benchmark before/after, profile bottlenecks, measure improvements
- **HOTFIX (H##)**: Minimal invasive changes, surgical precision, rollback plan required
- **INTEGRATION (I##)**: API contract testing, error handling, retry logic, timeouts
- **WORKFLOW (W##)**: CI/CD pipeline validation, deployment automation, rollback procedures

### Agent Prompt Routing

When `spawn_agent()` is called:
1. Extract task type from task ID (e.g., T1 → T, F23 → F)
2. Route to specialized prompt generator: `generate_test_prompt()`, `generate_feature_prompt()`, etc.
3. Inject type-specific requirements and constraints
4. Agent receives tailored protocol for task type

This ensures agents follow domain-specific best practices automatically.

## Critical Agent Protocol Rules

When spawning agents or generating specs, these constraints are **mandatory**:

### Prohibited Anti-Patterns
- Parameter suppression via underscore prefix (`_param`, `_context`)
- Deferred implementation markers (TODO, FIXME, placeholder comments)
- Null implementations (empty method bodies, no-op functions)
- Default value stubs (`Ok(vec![])`, `Ok(Default::default())`, null returns)
- Warning suppression without functional resolution

### Mandatory Constraints
- **60 Second Rule**: Agents must begin work within 60 seconds
- **Full Implementations**: Production-ready code only, no stubs
- **Parameter Utilization**: All inputs must influence computational output
- **Semantic Alignment**: Implementation must match function signature intent
- **Zero Errors**: Build/check must pass before marking DONE
- **No Attribution**: Clean commit messages without AI credits (no "🤖 Generated with..." footers)

## Configuration Points

### In kollaborate.sh

```bash
KOLLABORATE_MD="./TASK_TRACKING.md"  # Path to task tracking file
SPECS_DIR="./specs"                   # Path to specifications directory
MAX_AGENTS=3                          # Maximum concurrent task agents
MAX_SPEC_AGENTS=2                     # Maximum spec generation agents
CHECK_INTERVAL=60                     # Monitoring cycle (seconds)
NEW_TASK_REQUIRED=5                   # Minimum task queue size
SPEC_TIMEOUT=300                      # Spec generation timeout (seconds)
```

### Agent System Integration

The framework is agent-agnostic but defaults to `tglm` commands. To adapt:
- Replace `tglm` calls in `kollaborate.sh` with your agent system
- Update `spawn_agent()` and `spawn_spec_agent()` functions
- Modify prompts to include project-specific context

## Daemon Monitoring Logic

The agent watcher (`kollaborate.sh`) runs in a loop with these phases:

1. **Cleanup Phase**: Stop agents for completed tasks (DONE/QA status) and TASK-GENERATOR when queue is replenished
2. **Reconciliation Phase**: Reset WORKING→NEW if agent disappeared
3. **Activity Monitoring**: Hash comparison with 3-strike warning system
4. **Agent Spawning**: Fill available slots with NEW tasks (if specs exist)
5. **Spec Generation**: Create specs for tasks missing them (up to limit)
6. **Task Generation**: Spawn TASK-GENERATOR agent when queue < 5, automatically cleanup when queue >= 5

### Activity Detection

Agents are monitored via output hash comparison:
- Take snapshot, wait 4 seconds, take another snapshot
- If hashes match = idle (increment warning counter)
- 3 warnings = termination and task recycled to NEW
- Active agents receive 2-minute progress reminders

## Working with This Codebase

### Modifying the CLI (kollaborate)

- Handles subcommands: init, start, status, add, help, version
- Project type detection for language-specific templates
- Generates sample tasks based on detected project type
- No external dependencies beyond standard shell utilities

### Modifying the Daemon (kollaborate.sh)

- Written in zsh with associative arrays for state tracking
- Uses `sed -i ''` for in-place file edits (macOS format)
- All agent communication via external commands (tglm/tlist/tcapture/tmsg/tstop)
- Logging prefixes: [INIT], [SPWN], [SPEC], [CLEN], [RCYL], [IDLE], [OKAY], [MNTR]

### Key Functions

- `spawn_agent()` - Spawns task execution agent with type-specific prompts and production constraints
- `spawn_spec_agent()` - Spawns specification generation agent
- `check_agent_activity()` - Monitors agent output for idle detection
- `cleanup_agent()` - Terminates agent and resets warning counters
- `generate_tasks()` - Spawns TASK-GENERATOR agent to maintain queue (auto-cleanup when done)
- `is_spec_placeholder()` - Validates spec completeness (>50 lines)
- `get_task_type()` - Extracts task type prefix (F, R, B, T, D, P, A, S, H, M, I, C, E, U, V, W, X)
- `get_task_type_name()` - Converts type prefix to human-readable name
- `generate_[type]_prompt()` - 17 specialized prompt generators for each task type

## Specification Requirements

Generated specs must contain:
- Executive summary and requirements specification
- Architectural integration context
- Complete implementation examples (no stubs)
- File system mutations and integration points
- Verification strategy and acceptance criteria
- Minimum 50 lines of content (placeholders are rejected)

## Integration with External Agent Systems

Default integration uses `tglm` commands but can be adapted for:
- OpenAI API
- Anthropic Claude API
- Custom agent systems

Replace these command patterns in `kollaborate.sh`:
- `tglm "$agent_name" "$prompt"` - Spawn agent
- `tlist` - List active agents
- `tcapture "$agent"` - Get agent output
- `tmsg "$agent" "$message"` - Send message
- `tstop "$agent"` - Terminate agent
