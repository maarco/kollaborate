#!/usr/bin/env zsh
# ==============================================================================
# KOLLAB COMMANDS
# Multi-Agent TMUX Orchestration System
# ==============================================================================
# Features:
# - Bash/Zsh compatibility
# - Robust error handling
# - Configuration file support
# - Parallel agent creation
# ==============================================================================

# Note: Removed 'setopt KSH_ARRAYS' as it breaks zsh completion system
# Array indexing differences are handled locally in extract_match_groups()

# ==============================================================================
# CONFIGURATION & CONSTANTS
# ==============================================================================

# Agent limits and delays - hardcoded defaults
export MAX_AGENTS=20
export CLAUDE_INIT_DELAY=4
export GLM_INIT_DELAY=4
export DEFAULT_INIT_DELAY=2
export MESSAGE_DELAY=1
export SESSION_INIT_DELAY=1
export BATCH_CREATE_SIZE=5

# Behavior control
export QUIET_MODE="${QUIET_MODE:-false}"      # Suppress verbose agent messages
export PROFESSIONAL_TONE="${PROFESSIONAL_TONE:-true}"  # Use professional language

# Temp file directory
: "${TEMP_DIR:=${TMPDIR:-/tmp}}"

# Debug and verbose modes (can be overridden via environment)
: "${DEBUG:=false}"
: "${VERBOSE:=false}"
: "${DRY_RUN:=false}"

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Debug logging function
# Usage: debug_log "message"
debug_log() {
    if [[ "$VERBOSE" == "true" ]] || [[ "$DEBUG" == "true" ]]; then
        echo "[DEBUG] $*" >&2
    fi
}

# Error logging function
# Usage: error_log "error message"
error_log() {
    echo "[ERROR] $*" >&2
}

# Extract regex match groups (bash/zsh compatible)
# Usage: extract_match_groups "$string" "$pattern"
# Returns: Sets MATCH_1, MATCH_2, etc. as global variables
extract_match_groups() {
    local string="$1"
    local pattern="$2"

    if [[ "$string" =~ $pattern ]]; then
        # Bash uses BASH_REMATCH (1-indexed for capture groups)
        # Zsh uses match (with KSH_ARRAYS: 0-indexed for capture groups)
        if [[ -n "${BASH_REMATCH[1]:-}" ]]; then
            MATCH_1="${BASH_REMATCH[1]}"
            MATCH_2="${BASH_REMATCH[2]:-}"
            MATCH_3="${BASH_REMATCH[3]:-}"
        elif [[ -n "${match[1]:-}" ]]; then
            # Zsh uses 1-based indexing by default
            MATCH_1="${match[1]}"
            MATCH_2="${match[2]:-}"
            MATCH_3="${match[3]:-}"
        fi
        return 0
    fi
    return 1
}

# Parse agent count from session name
# Usage: parse_agent_count "agent-5"
# Returns: 0 if multi-agent pattern, 1 if single agent
# Sets: BASE_NAME and NUM_AGENTS globals
parse_agent_count() {
    local session_name="$1"

    if extract_match_groups "$session_name" '^(.+)-([0-9]+)$'; then
        BASE_NAME="$MATCH_1"
        NUM_AGENTS="$MATCH_2"

        debug_log "Parsed multi-agent: base=$BASE_NAME, count=$NUM_AGENTS"

        # Validate agent count
        if [[ "$NUM_AGENTS" -gt "$MAX_AGENTS" ]]; then
            error_log "Too many agents requested ($NUM_AGENTS). Maximum allowed: $MAX_AGENTS"
            return 2
        fi

        return 0
    fi

    return 1
}

# Get initialization delay based on command
# Usage: get_init_delay "command string"
get_init_delay() {
    local command="$1"

    case "$command" in
        *claude*) echo "$CLAUDE_INIT_DELAY" ;;
        *glm*) echo "$GLM_INIT_DELAY" ;;
        *) echo "$DEFAULT_INIT_DELAY" ;;
    esac
}

# Create secure temporary file
# Usage: create_temp_file "prefix"
# Returns: Path to temp file
create_temp_file() {
    local prefix="${1:-kollab}"
    local temp_dir="${TEMP_DIR:-${TMPDIR:-/tmp}}"
    mktemp "${temp_dir}/${prefix}_XXXXXX.txt"
}

# Check if session is healthy
# Usage: check_session_health "session-name"
check_session_health() {
    local session="$1"

    if ! tmux has-session -t "$session" 2>/dev/null; then
        debug_log "Session does not exist: $session"
        return 1
    fi

    # Check if pane is dead
    local pane_dead
    pane_dead=$(tmux display-message -t "$session" -p '#{pane_dead}' 2>/dev/null)

    if [[ "$pane_dead" == "1" ]]; then
        debug_log "Session pane is dead: $session"
        return 1
    fi

    return 0
}

# ==============================================================================
# CORE AGENT CREATION FUNCTIONS
# ==============================================================================

# Create a single agent session with comprehensive error handling
# Arguments:
#   $1 - session_prefix: Base name for the session (e.g., "agent-1")
#   $2 - command_to_run: Command to execute in the session
#   $3 - message: Optional message to send after command starts
#   $4 - show_details: "true" to show verbose output, "false" for quiet
# Returns:
#   0 on success, 1 on failure
create_agent_session() {
    local session_prefix="$1"
    local command_to_run="$2"
    local message="$3"
    local show_details="${4:-true}"

    # Debug parameter validation
    debug_log "create_agent_session parameters:"
    debug_log "  \$1 (session_prefix): '$session_prefix'"
    debug_log "  \$2 (command_to_run): '$command_to_run'"
    debug_log "  \$3 (message): '$message'"
    debug_log "  \$4 (show_details): '$show_details'"

    local project_dir
    project_dir="$(pwd)"
    local project_name
    project_name="$(basename "$project_dir")"
    local full_session_name="${project_name}-${session_prefix}"

    debug_log "Creating session: $full_session_name with command: $command_to_run"

    # Dry run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would create session: $full_session_name"
        echo "[DRY RUN] Command: $command_to_run"
        echo "[DRY RUN] Message: ${message:-<none>}"
        return 0
    fi

    # Check if session already exists
    if tmux has-session -t "$full_session_name" 2>/dev/null; then
        if [[ "$show_details" == "true" ]]; then
            error_log "Session $full_session_name already exists"
            echo "   Use 'tcapture ${session_prefix}' to view it" >&2
            echo "   Or kill it manually: tmux kill-session -t $full_session_name" >&2
        fi
        return 1
    fi

    # Create session
    if ! tmux new-session -d -s "$full_session_name" 2>/dev/null; then
        if [[ "$show_details" == "true" ]]; then
            error_log "Failed to create tmux session: $full_session_name"
        fi
        return 1
    fi

    # Give tmux a moment to initialize
    sleep "$SESSION_INIT_DELAY"

    # Verify session was created
    if ! check_session_health "$full_session_name"; then
        error_log "Session creation failed health check: $full_session_name"
        tmux kill-session -t "$full_session_name" 2>/dev/null || true
        return 1
    fi

    # Initialize tmux session
    if [[ "$show_details" == "true" ]]; then
        echo "► Initializing $command_to_run in session: $full_session_name"
    fi

    # Start command
    if ! tmux send-keys -t "$full_session_name" "$command_to_run" C-m 2>/dev/null; then
        if [[ "$show_details" == "true" ]]; then
            error_log "Failed to start $command_to_run in session: $full_session_name"
        fi
        tmux kill-session -t "$full_session_name" 2>/dev/null || true
        return 1
    fi

    # Give command time to initialize
    local init_delay
    init_delay=$(get_init_delay "$command_to_run")
    sleep "$init_delay"

    # Send message if provided (validate it's a real message, not a boolean or empty)
    if [[ -n "$message" ]] && [[ "$message" != "true" ]] && [[ "$message" != "false" ]] && [[ "$message" =~ [^[:space:]] ]]; then
        if [[ "$show_details" == "true" ]]; then
            echo "► Sending message to agent: $session_prefix"
        fi

        if ! tmux send-keys -t "$full_session_name" "$message" 2>/dev/null; then
            error_log "Failed to send message to session: $full_session_name"
            return 1
        fi

        sleep "$MESSAGE_DELAY"

        # Submit the message
        if ! tmux send-keys -t "$full_session_name" C-m 2>/dev/null; then
            error_log "Failed to submit message to session: $full_session_name"
            return 1
        fi
    else
        debug_log "Skipping message send (empty, whitespace, or boolean value): '${message}'"
    fi

    # Wait for processing
    sleep "$DEFAULT_INIT_DELAY"

    # Final health check
    if ! check_session_health "$full_session_name"; then
        error_log "Session failed final health check: $full_session_name"
        return 1
    fi

    if [[ "$show_details" == "true" ]]; then
        echo "✓ Agent launched successfully: $session_prefix"
        echo "  View output: tcapture $session_prefix"
        echo "  Directory: $project_dir"
        echo "  Task: ${message:-Interactive session}"
        echo "  Run: tmsg \"message all agents\""
    fi

    return 0
}

# Wrapper for create_agent_session with show_details=true
# Arguments:
#   $1 - session_prefix: Base name for the session
#   $2 - command_to_run: Command to execute
#   $3 - message: Optional message to send
create_tmux_agent_session() {
    create_agent_session "$1" "$2" "$3" true
}

# Create multiple agents in parallel batches
# Arguments:
#   $1 - base_name: Base name for agents (e.g., "agent")
#   $2 - num_agents: Number of agents to create
#   $3 - command: Command to run in each agent
#   $4 - message: Message to send to each agent
# Returns:
#   Number of failed agents
create_multiple_agents() {
    local base_name="$1"
    local num_agents="$2"
    local command="$3"
    local message="$4"

    local project_dir
    project_dir="$(pwd)"
    local project_name
    project_name="$(basename "$project_dir")"

    local success_count=0
    local failure_count=0

    debug_log "Creating $num_agents agents with base name: $base_name"

    # Create agents sequentially (could be optimized with background jobs)
    for ((i=1; i<=num_agents; i++)); do
        if create_agent_session "${base_name}-${i}" "$command" "$message" false; then
            echo "✓ Agent launched: $base_name-$i (Session: ${project_name}-${base_name}-${i})"
            ((success_count++))
        else
            echo "❌ Failed to create agent: $base_name-$i"
            ((failure_count++))
        fi

        # Small delay between agent creation to avoid overwhelming the system
        sleep "$SESSION_INIT_DELAY"
    done

    # Show summary
    show_multi_agent_summary "$base_name" "$num_agents" "$project_name" \
        "$success_count" "$failure_count" "$project_dir" "$message"

    return "$failure_count"
}

# Show multi-agent creation summary
# Arguments:
#   $1 - base_name: Base name of agents
#   $2 - num_agents: Total number of agents requested
#   $3 - project_name: Project name
#   $4 - success_count: Number of successful creations
#   $5 - failure_count: Number of failures
#   $6 - project_dir: Project directory
#   $7 - message: Task message
show_multi_agent_summary() {
    local base_name="$1"
    local num_agents="$2"
    local project_name="$3"
    local success_count="$4"
    local failure_count="$5"
    local project_dir="$6"
    local message="$7"

    echo ""
    echo "=========================================="
    echo "SUMMARY: Multi-Agent Creation Complete"
    echo "=========================================="
    echo "Successful agents: $success_count"
    echo "Failed agents: $failure_count"
    echo "Project directory: $project_dir"
    echo "Task: ${message:-Interactive session}"
    echo ""
    echo "View agent output:"
    for ((i=1; i<=num_agents; i++)); do
        echo "  tcapture ${base_name}-${i}"
    done
    echo ""
    echo "Broadcast to all agents: tbroadcast ${base_name} \"your message\""
}

# ==============================================================================
# AGENT TYPE COMMANDS (DRY implementation)
# ==============================================================================

# Generic agent creation function (ultimate DRY)
# Arguments:
#   $1 - agent_type: Type of agent (for display)
#   $2 - command: Command to execute
#   $3 - session_name: Session name pattern
#   $4+ - message: Task message
create_agent_type() {
    local agent_type="$1"
    local command="$2"
    local session_name="$3"
    shift 3
    local message="$*"

    debug_log "Creating $agent_type agent: session=$session_name, message=$message"

    # Parse for multi-agent pattern
    if parse_agent_count "$session_name"; then
        echo "► Creating $NUM_AGENTS $agent_type agents with base name: $BASE_NAME"
        create_multiple_agents "$BASE_NAME" "$NUM_AGENTS" "$command" "$message"
        return $?
    else
        # Single agent mode
        create_tmux_agent_session "$session_name" "$command" "$message"
        return $?
    fi
}

# ==============================================================================
# CONSCIOUSNESS FORKING - Clone agents with full conversation context
# ==============================================================================

# Fork current conversation into new agent sessions
# Usage: tclone [name-N] [optional: down-count to select different conversation]
# Example: tclone clone-3          # Create 3 clones of current conversation
# Example: tclone branch-2 2       # Create 2 clones from 2 conversations ago
tclone() {
    if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🧬 CONSCIOUSNESS FORKING (tclone)                           ║
║         Clone agents with FULL conversation context via session resume        ║
╚══════════════════════════════════════════════════════════════════════════════╝

USAGE:
    tclone name-N              # Create N clones of current conversation
    tclone name-N [down-count] # Clone from N conversations back in history
    tclone -h                  # Show this help

DESCRIPTION:
    Unlike regular agent creation (tclaude/tglm), tclone creates agents that
    INHERIT YOUR FULL CONVERSATION HISTORY. Each clone has complete context
    of everything discussed - no manual briefing needed!

    Uses Claude's session resume feature (-r flag) to select and clone
    existing conversations into new tmux sessions.

HOW IT WORKS:
    1. Creates tmux session(s)
    2. Starts `claude --dangerously-skip-permissions -r` (shows resume menu)
    3. Navigates to your conversation (default: top/current)
    4. Selects it - agent now has FULL context

EXAMPLES:
    # Clone current conversation into 3 parallel agents
    tclone worker-3

    # Clone into 5 agents, each ready for a different task
    tclone phase-5

    # Clone from 2 conversations back (branch from earlier state)
    tclone alternate-2 2

    # Create a single clone for experimentation
    tclone experiment-1

BRANCHING FROM HISTORY:
    The resume menu shows your conversation at different points:

    ❯ Current task discussion...           ← 0 (default, most recent)
      4 seconds ago · 91 messages

      Current task discussion...           ← 1 (16 messages earlier)
      10 minutes ago · 75 messages

      Current task discussion...           ← 2 (52 messages earlier)
      32 minutes ago · 39 messages

    Use the down-count to branch from earlier states:
    tclone alternate-1 2    # Branch from 32 minutes ago state

WORKFLOW EXAMPLE:
    # You've been planning with Claude...
    # Now spawn 5 workers, each with your full project knowledge:

    tclone banana-5

    # Dispatch specific tasks to each:
    tmsg agent_name-1 "Build WorkspaceSidebar.vue component"
    tmsg agent_name-2 "Build FileTree.vue with virtual scrolling"
    tmsg agent_name-3 "Create useWorkspace.ts composable"
    tmsg agent_name-4 "Add workspace persistence to Rust backend"
    tmsg agent_name-5 "Write tests for workspace commands"

    # All agents know the full PROJECT_BANANA context!

MONITORING FORKS:
    tcapture {name}-1                     # View output from specific fork
    tcapture {name}-2 500                 # View last 500 lines from fork 2
    tbroadcast {name} "status update"     # Broadcast to all forks

PRO TIPS:
    • Forks inherit ALL context - use for complex multi-phase work
    • Branch from earlier conversation states to explore alternatives
    • Each fork is independent - they won't see each other's work
    • Use descriptive names: tclone ui-3, tclone backend-2, tclone tests-1

SEE ALSO:
    ~/.claude/claude-docs/consciousness-forking.md  # Full documentation
    tclaude   # Create fresh Claude agents (no context)
    tmsg      # Send messages to forks
    tcapture {name}-1    # View specific fork output
EOF
        return 0
    fi

    local session_name="$1"
    local down_count="${2:-0}"  # How many times to press Down (0 = top/current)

    local project_dir
    project_dir="$(pwd)"
    local project_name
    project_name="$(basename "$project_dir")"

    # Parse for multi-agent pattern
    if ! parse_agent_count "$session_name"; then
        # Single fork mode
        BASE_NAME="$session_name"
        NUM_AGENTS=1
    fi

    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         🧬 CONSCIOUSNESS FORKING                              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "► Creating $NUM_AGENTS fork(s) with full conversation context..."
    echo "► Project: $project_name"
    echo "► Base name: $BASE_NAME"
    if [[ "$down_count" -gt 0 ]]; then
        echo "► Branching from: $down_count conversation(s) back"
    fi
    echo ""

    local success_count=0
    local failure_count=0

    for ((i=1; i<=NUM_AGENTS; i++)); do
        local full_session_name="${project_name}-${BASE_NAME}-${i}"

        echo "► Spawning fork $i/$NUM_AGENTS: $full_session_name"

        # Check if session already exists
        if tmux has-session -t "$full_session_name" 2>/dev/null; then
            echo "  ⚠️  Session already exists: $full_session_name"
            echo "      Use: tmux kill-session -t $full_session_name"
            ((failure_count++))
            continue
        fi

        # Create tmux session
        if ! tmux new-session -d -s "$full_session_name" 2>/dev/null; then
            echo "  ❌ Failed to create tmux session"
            ((failure_count++))
            continue
        fi

        # Navigate to project directory
        tmux send-keys -t "$full_session_name" "cd $project_dir" C-m
        sleep 1

        # Start Claude with resume flag
        tmux send-keys -t "$full_session_name" "glm --dangerously-skip-permissions -r" C-m

        # Wait for resume menu to load
        sleep "$CLAUDE_INIT_DELAY"

        # Navigate down if branching from earlier conversation
        if [[ "$down_count" -gt 0 ]]; then
            for ((d=0; d<down_count; d++)); do
                tmux send-keys -t "$full_session_name" Down
                sleep 0.3
            done
        fi

        # Select the conversation
        tmux send-keys -t "$full_session_name" C-m

        # Wait for conversation to load
        sleep 2

        echo "  ✓ Fork spawned: $full_session_name"
        ((success_count++))

        # Small delay between forks
        sleep 1
    done

    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "🧬 FORKING COMPLETE"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "Successful forks: $success_count/$NUM_AGENTS"
    echo "Failed forks: $failure_count"
    echo ""

    if [[ $success_count -gt 0 ]]; then
        echo "📡 Your forks are now running with FULL conversation context!"
        echo ""
        echo "ATTACH TO FORKS:"
        for ((i=1; i<=NUM_AGENTS; i++)); do
            local full_session_name="${project_name}-${BASE_NAME}-${i}"
            if tmux has-session -t "$full_session_name" 2>/dev/null; then
                echo "  tcapture ${BASE_NAME}-${i}"
            fi
        done
        echo ""
        echo "DISPATCH TASKS:"
        echo "  tmsg ${BASE_NAME}-1 'Your specific task for fork 1'"
        echo "  tmsg ${BASE_NAME}-2 'Your specific task for fork 2'"
        echo "  tbroadcast ${BASE_NAME} 'Broadcast to all forks'"
        echo ""
        echo "MONITOR:"
        echo "  tcapture ${BASE_NAME}-1"
    fi

    return $failure_count
}

# ==============================================================================
# TEAM LEAD - Coordinated Agent Teams
# ==============================================================================

# Create a team lead agent that coordinates a team of worker agents
# Usage: tlead team-N "mission description"
# Example: tlead banana-5 "Implement PROJECT_BANANA Phase 1"
tlead() {
    if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
╔═════════════════════════════════════════════════════════════╗
║              TEAM LEAD ORCHESTRATION (tlead)                ║
║   Create a team lead agent that coordinates worker agents   ║
╚═════════════════════════════════════════════════════════════╝

USAGE:
    tlead team-N "mission description"
    tlead -h                              # Show this help

DESCRIPTION:
    Creates a coordinated agent team with:
    • 1 Team Lead agent (full context + coordination instructions)
    • N Worker agents (full context, ready to receive tasks)

    The Team Lead receives:
    • List of all team members and how to reach them
    • Instructions on coordination, task dispatch, and monitoring
    • The overall mission to accomplish

HOW IT WORKS:
    tlead banana-5 "Implement file browser feature"

    Creates:
    ┌─────────────────────────────────────────────────────────────────┐
    │     TEAM LEAD: kollabor-app-banana-lead                         │
    │     • Full conversation context                                 │
    │     • Knows all team members                                    │
    │     • Has coordination instructions                             │
    ├─────────────────────────────────────────────────────────────────┤
    │  👷 WORKER 1: kollabor-app-banana-1                             │
    │  👷 WORKER 2: kollabor-app-banana-2                             │
    │  👷 WORKER 3: kollabor-app-banana-3                             │
    │  👷 WORKER 4: kollabor-app-banana-4                             │
    │  👷 WORKER 5: kollabor-app-banana-5                             │
    │     • All have full conversation context                        │
    │     • Ready to receive tasks from lead                          │
    └─────────────────────────────────────────────────────────────────┘

TEAM LEAD CAPABILITIES:
    The team lead knows how to:
    • Dispatch tasks: tmsg banana-1 "Build the sidebar component"
    • Broadcast: tbroadcast banana "Everyone commit your changes"
    • Check progress: tcapture banana-1
    • Coordinate: Break down work, assign tasks, verify completion

EXAMPLES:
    # Create a 5-person team to implement a feature
    tlead feature-5 "Implement the workspace file browser from PROJECT_BANANA"

    # Create a 3-person review team
    tlead review-3 "Review and improve error handling across the codebase"

    # Create a 4-person testing team
    tlead test-4 "Write comprehensive tests for the authentication system"

MONITORING THE TEAM:
    tcapture {team}-lead                     # View team lead output
    tcapture {team}-1                        # View worker 1 output
    tcapture {team}-2 500                    # View worker 2 (last 500 lines)

PRO TIPS:
    • The team lead has full autonomy to coordinate
    • Workers inherit YOUR conversation context (they know the plan!)
    • Team lead can re-assign tasks if workers get stuck
    • Use descriptive team names: tlead auth-4, tlead ui-3, tlead backend-2

SEE ALSO:
    tclone     # Clone agents with full conversation context
    tmsg      # Send messages to agents
    thelp forking  # Forking documentation
EOF
        return 0
    fi

    local team_name="$1"
    shift
    local mission="$*"

    local project_dir
    project_dir="$(pwd)"
    local project_name
    project_name="$(basename "$project_dir")"

    # Parse for multi-agent pattern (required for tlead)
    if ! parse_agent_count "$team_name"; then
        echo "❌ ERROR: Team name must include worker count (e.g., banana-5, feature-3)"
        echo "💡 Usage: tlead team-N \"mission description\""
        return 1
    fi

    local base_name="$BASE_NAME"
    local num_workers="$NUM_AGENTS"
    local lead_session="${project_name}-${base_name}-lead"

    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                        TEAM LEAD ORCHESTRATION                               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "► Mission: $mission"
    echo "► Project: $project_name"
    echo "► Team: $base_name"
    echo "► Workers: $num_workers"
    echo ""

    # Step 1: Create worker agents first
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "👷 SPAWNING WORKER AGENTS..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local worker_sessions=()
    local worker_count=0

    for ((i=1; i<=num_workers; i++)); do
        local worker_session="${project_name}-${base_name}-${i}"

        echo "► Spawning worker $i/$num_workers: $worker_session"

        # Check if session already exists
        if tmux has-session -t "$worker_session" 2>/dev/null; then
            echo "  ⚠️  Session already exists (reusing): $worker_session"
            worker_sessions+=("$worker_session")
            ((worker_count++))
            continue
        fi

        # Create tmux session
        if ! tmux new-session -d -s "$worker_session" 2>/dev/null; then
            echo "  ❌ Failed to create worker session"
            continue
        fi

        # Navigate to project directory
        tmux send-keys -t "$worker_session" "cd $project_dir" C-m
        sleep 1

        # Start Claude with resume flag
        tmux send-keys -t "$worker_session" "glm --dangerously-skip-permissions -r" C-m
        sleep "$CLAUDE_INIT_DELAY"

        # Select the conversation (top = current)
        tmux send-keys -t "$worker_session" C-m
        sleep 5

        # Select the conversation (top = current)
        local a_msg="You are worker ${base_name}-${i}. I need you to start working on issue # ${i} listed above. "

        tmux send-keys -t "$worker_session" "$a_msg" C-m
        sleep 2

        # Select the conversation (top = current)
        tmux send-keys -t "$worker_session" C-m
        sleep 2

        echo "  ✓ Worker spawned: ${base_name}-${i}"
        worker_sessions+=("$worker_session")
        ((worker_count++))

        sleep 1
    done

    if [[ $worker_count -eq 0 ]]; then
        echo "❌ Failed to create any workers. Aborting."
        return 1
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "👑 SPAWNING TEAM LEAD..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check if lead session already exists
    if tmux has-session -t "$lead_session" 2>/dev/null; then
        echo "  ⚠️  Team lead session already exists: $lead_session"
        echo "      Kill it first: tmux kill-session -t $lead_session"
        return 1
    fi

    # Create team lead session
    if ! tmux new-session -d -s "$lead_session" 2>/dev/null; then
        echo "  ❌ Failed to create team lead session"
        return 1
    fi

    # Navigate to project directory
    tmux send-keys -t "$lead_session" "cd $project_dir" C-m
    sleep 1

    # Start Claude with resume flag
    tmux send-keys -t "$lead_session" "glm --dangerously-skip-permissions -r" C-m
    sleep "$CLAUDE_INIT_DELAY"

    # Select the conversation (top = current)
    tmux send-keys -t "$lead_session" C-m
    sleep 5

    echo "  ✓ Team lead spawned: ${base_name}-lead"
    echo ""

    # Step 2: Build the team roster
    local team_roster=""
    for ((i=1; i<=num_workers; i++)); do
        team_roster="${team_roster}
    👷 Worker ${i}: ${base_name}-${i}
       Session: ${project_name}-${base_name}-${i}
       Message: tmsg ${base_name}-${i} \"your task here\""
    done

    # Step 3: Send coordination instructions to team lead
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 BRIEFING TEAM LEAD..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      local lead_briefing="TEAM LEAD COORDINATION BRIEFING

Objective: ${mission}

Team Configuration: ${worker_count} workers
${team_roster}

Coordination Protocol:
1. Task Assignment - Dispatch specific tasks:
   tmsg ${base_name}-1 \"Build the WorkspaceSidebar.vue component\"
   tmsg ${base_name}-2 \"Create the FileTree.vue with virtual scrolling\"

2. Team Communication - Broadcast messages:
   tbroadcast ${base_name} \"Team commit current work and provide status update\"

3. Progress Monitoring - Check worker output:
   tcapture ${base_name}-1

4. Worker Feedback Channel - Workers can reply to: ${base_name}-lead

Coordination Responsibilities:
• Analyze the mission and decompose into specific tasks
• Assign tasks based on worker capabilities and dependencies
• Monitor implementation progress and resolve blockers
• Coordinate integration of completed components
• Verify implementation quality and completeness
• Provide consolidated status reports

Begin coordination when ready."

    echo "---------"
    echo lead_briefing
    echo "---------"

    # Send the briefing to the team lead
    if tmux send-keys -t "$lead_session" "$lead_briefing" 2>/dev/null; then
        sleep "$MESSAGE_DELAY"
        if tmux send-keys -t "$lead_session" C-m 2>/dev/null; then
            echo "  ✓ Team lead briefed and activated!"
        else
            echo "  ❌ Failed to submit briefing to team lead"
        fi
    else
        echo "  ❌ Failed to send briefing to team lead"
    fi
    
    
    for ((i=1; i<=num_workers; i++)); do
        tmux send-keys -t  ${project_name}-${base_name}-${i} "!tmsg $lead_session \"${project_name}-${base_name}-${i} reporting for duty!\" "
        sleep 1
        tmux send-keys -t "$lead_session" C-m
        sleep 1
    done
    
    for ((i=1; i<=num_workers; i++)); do
        tmux send-keys -t "$lead_session" "!tmsg ${project_name}-${base_name}-${i} \" acknowledge you understand what you are working on. Use bash tool tmsg to respond back. \""
        sleep 1
        tmux send-keys -t "$lead_session" C-m
        sleep 1
    done
    

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         🎉 TEAM DEPLOYED!                                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "👑 TEAM LEAD:"
    echo "   Session: $lead_session"
    echo "   View:    tcapture ${base_name}-lead"
    echo ""
    echo "👷 WORKERS:"
    for ((i=1; i<=num_workers; i++)); do
        echo "   Worker ${i}: tcapture ${base_name}-${i}"
    done
    echo ""
    echo "📡 COMMANDS:"
    echo "   Watch lead:     tcapture ${base_name}-lead"
    echo "   Message lead:   tmsg ${base_name}-lead \"your message\""
    echo "   Broadcast all:  tbroadcast ${base_name} \"message to everyone\""
    echo ""
    echo "💡 The team lead is now coordinating. Watch them work!"
    echo ""

    return 0
}

# ==============================================================================
# AGENT TYPE COMMANDS (DRY implementation)
# ==============================================================================

# Create Claude agent(s)
# Usage: tclaude [session] [message]
tclaude() {
    if [[ -z "$1" ]]; then
        cat << 'EOF'
Usage: tclaude [session] [message]
Example: tclaude audit-1 'Audit authentication system for security issues'
Example: tclaude agent-5 'analyze the system'  # Creates 5 claude agents

⚠️  WARNING: Uses --dangerously-skip-permissions flag
    This bypasses safety checks. Use with caution.
EOF
        return 1
    fi

    local session_name="$1"
    shift
    local message="$*"

    create_agent_type "Claude" "glm --dangerously-skip-permissions" "$session_name" "$message"
}

# Create Haiku agent(s)
# Usage: thaiku [session] [message]
thaiku() {
    if [[ -z "$1" ]]; then
        cat << 'EOF'
Usage: thaiku [session] [message]
Example: thaiku audit-1 'Audit authentication system for security issues'
Example: thaiku agent-3 'check for bugs'  # Creates 3 haiku agents
EOF
        return 1
    fi

    local session_name="$1"
    shift
    local message="$*"

    create_agent_type "Haiku" "glm --dangerously-skip-permissions --model haiku" "$session_name" "$message"
}

# Create GLM agent(s)
# Usage: tglm [session] [message]
tglm() {
    if [[ -z "$1" ]]; then
        cat << 'EOF'
Usage: tglm [session] [message]
Example: tglm audit-1 'Audit authentication system for security issues'
Example: tglm agent-4 'check for bugs'  # Creates 4 agent sessions
EOF
        return 1
    fi

    local session_name="$1"
    shift
    local message="$*"

    create_agent_type "GLM" "glm" "$session_name" "$message"
}

# Create custom session(s)
# Usage: tsession [session] [command] [message]
tsession() {
    if [[ -z "$1" ]] || [[ -z "$2" ]]; then
        cat << 'EOF'
Usage: tsession [session] [command] [message]
Example: tsession audit-1 claude 'Audit authentication system for security issues'
Example: tsession agent-3 'npm run dev' 'start dev servers'  # Creates 3 sessions
EOF
        return 1
    fi

    local session_name="$1"
    local command="$2"
    shift 2
    local message="$*"

    create_agent_type "Custom" "$command" "$session_name" "$message"
}

# ==============================================================================
# TEXT ENHANCEMENT FUNCTION
# ==============================================================================

# Enhance text with Claude AI
# Usage: tenhance "your text to enhance"
#        echo "text" | tenhance
tenhance() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
TEXT ENHANCEMENT WITH CLAUDE (tenhance)

USAGE:
    tenhance "your text to enhance"
    echo "text" | tenhance
    tenhance -h    # Show this help

DESCRIPTION:
    Pipes text to Claude AI for enhancement, improvement, or analysis.
    Perfect for getting suggestions, improving writing, or generating ideas.

EXAMPLES:
    tenhance "give me 5 things to check in this nextjs app"
    tenhance "improve this email: hi can u help me"
    tenhance "suggest 3 better ways to phrase this"

    # Pipe from file or command
    cat README.md | tenhance "summarize this and suggest improvements"
    git log --oneline -5 | tenhance "what can we learn from these commits"
    ls -la | tenhance "organize these files better"

FEATURES:
    • Direct text enhancement
    • Pipe input support
    • Fast Claude responses
    • Context-aware suggestions

RELATED:
    tglm     # Create GLM agents
    tclaude  # Create Claude agents
    thaiku   # Create Haiku agents
EOF
        return 0
    fi

    local input_text=""
    local prompt="$*"
    local full_prompt=""

    # Check if stdin is available (being piped to)
    if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
        input_text=$(cat)
        if [[ -z "$prompt" ]]; then
            prompt=""
        fi
        full_prompt="$input_text"
    else
        if [[ -z "$prompt" ]]; then
            echo "❌ Usage: tenhance \"your text\" or echo \"text\" | tenhance"
            echo "💡 Use 'tenhance -h' for help and examples"
            return 1
        fi
        full_prompt="$prompt"
    fi

    # Use Claude with the GLM alias (since you have GLM configured)
    echo "$full_prompt" | glm -p
}

# ==============================================================================
# COLLABORATIVE TASK DISTRIBUTION
# ==============================================================================

# Collaborative task distribution for AI agents
# Usage: tkollab agent-N "generate N items for this task"
tkollab() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << 'EOF'
COLLABORATIVE TASK DISTRIBUTION (tkollab)

USAGE:
    tkollab agent-N "generate N items for this task"
    tkollab worker-3 "find 3 performance issues in this codebase"
    tkollab tester-4 "identify 4 security vulnerabilities"
    tkollab -h    # Show this help

DESCRIPTION:
    Creates N agents and assigns them collaborative tasks by:
    1. Creating N GLM agents (agent-1, agent-2, etc.)
    2. Sending a collaborative task request to generate N items
    3. Parsing the response and assigning one item to each agent
    4. Coordinating parallel work across the agent team

🎯 FOR AGENTS: HOW TO USE THIS PLATFORM
────────────────────────────────────────────────────────────────────────────────
When you need to scale your work across multiple parallel agents, you can:

1. CREATE PARALLEL WORKERS:
   tkollab worker-5 "Find 5 different performance issues in the codebase"
   → Creates 5 agents, each assigned a specific performance issue to investigate

2. DISTRIBUTE RESEARCH TASKS:
   tkollab researcher-4 "Research 4 different authentication strategies"
   → Each agent gets a different strategy to research in parallel

3. PARALLEL CODE REVIEW:
   tkollab reviewer-3 "Review 3 different modules for security issues"
   → Distribute code review across multiple specialized agents

4. TESTING AT SCALE:
   tkollab tester-6 "Test 6 different user flows in the application"
   → Each agent tests a different flow simultaneously

5. REFACTORING COORDINATION:
   tkollab refactor-4 "Identify 4 different areas that need refactoring"
   → Split large refactoring tasks into parallel streams

💡 AGENT WORKFLOW TIPS:
────────────────────────────────────────────────────────────────────────────────
• Use tlist to see all active agents in your project
• Use tstatus to monitor progress of all parallel agents
• Use tcapture agent-N to check individual agent output
• Use tmsg agent-N "message" to give specific instructions
• Use tbroadcast pattern "message" to message all agents at once
• Use tcompact old-N new to consolidate results into new agents

🚀 POWER PATTERNS:
────────────────────────────────────────────────────────────────────────────────
# Pattern 1: Research → Synthesize
tkollab researcher-5 "Research 5 different database solutions"
# Wait for completion, then:
tglm synthesis "Review the research from researcher-1 through researcher-5"

# Pattern 2: Parallel Implementation → Integration
tkollab builder-4 "Build 4 components for the dashboard"
# After completion:
tglm integrator "Integrate the components built by builder-1 through builder-4"

# Pattern 3: Distributed Testing
tkollab tester-8 "Test 8 API endpoints for edge cases"
# Monitor with:
tstatus tester

EXAMPLES:
    tkollab agent-4 "Find 4 bugs in this authentication system"
    tkollab reviewer-3 "Identify 3 performance bottlenecks in the API"
    tkollab tester-5 "Test 5 different user authentication flows"
    tkollab optimizer-2 "Suggest 2 ways to optimize this database query"
    tkollab syntax-4 "Review 4 different syntax patterns in the codebase"

FEATURES:
    • Automatic agent creation
    • Task item parsing and distribution
    • Parallel collaborative work
    • Smart load balancing
    • In-memory task storage (no temp files)

RELATED:
    tglm     # Create GLM agents
    tmsg     # Message agents
    tlist    # List agents
    tstatus  # Monitor agent progress
    tenhance # Enhance text with AI
EOF
        return 0
    fi

    if [[ -z "$1" ]]; then
        echo "❌ Usage: tkollab agent-N \"generate N items for this task\""
        echo "💡 Example: tkollab agent-4 \"Find 4 bugs in this authentication system\""
        echo "   Use 'tkollab -h' for detailed help and examples"
        return 1
    fi

    local session_name="$1"
    shift
    local task_prompt="$*"

    # Parse session name for number pattern
    local parse_result
    parse_agent_count "$session_name"
    parse_result=$?

    if [[ $parse_result -eq 1 ]]; then
        echo "❌ ERROR: Session name must end with -N (e.g., agent-4, worker-3)"
        echo "💡 Usage: tkollab agent-N \"your collaborative task\""
        return 1
    elif [[ $parse_result -eq 2 ]]; then
        # Too many agents - error already printed by parse_agent_count
        return 1
    fi

    local base_name="$BASE_NAME"
    local num_agents="$NUM_AGENTS"

    echo "🚀 Starting collaborative task distribution..."
    echo "   Step 1: Generating tasks for $num_agents $base_name agents"
    echo ""

    local project_dir
    project_dir="$(pwd)"
    local project_name
    project_name="$(basename "$project_dir")"

    # Generate the list using GLM with XML format for easy parsing
    local enhanced_prompt="Generate exactly $num_agents specific items for: $task_prompt.
Return ONLY this XML format with $num_agents agent tags, NOTHING ELSE:
<agent1>First specific task</agent1>
<agent2>Second specific task</agent2>
<agent3>Third specific task</agent3>

Generate exactly $num_agents items, one per agent tag, NOTHING ELSE!"

    # Store GLM response in memory
    local glm_response
    if ! glm_response=$(echo "$enhanced_prompt" | glm -p 2>/dev/null); then
        error_log "Failed to generate tasks with GLM"
        return 1
    fi

    debug_log "GLM response received: ${#glm_response} characters"

    # Parse the response and extract agent tasks
    local items=()

    while IFS= read -r line; do
        # Extract content from <agentN>content</agentN> tags
        # More robust - handles whitespace
        if [[ "$line" =~ \<agent[0-9]+\>(.+)\</agent[0-9]+\> ]]; then
            # Use bash/zsh compatible extraction
            # Bash uses BASH_REMATCH (1-indexed), Zsh uses match (1-indexed)
            local extracted_task=""
            if [[ -n "${BASH_REMATCH[1]:-}" ]]; then
                extracted_task="${BASH_REMATCH[1]}"
            elif [[ -n "${match[1]:-}" ]]; then
                # Zsh uses 1-based indexing by default
                extracted_task="${match[1]}"
            fi

            # Validate task is non-empty and contains non-whitespace
            if [[ -n "$extracted_task" ]] && [[ "$extracted_task" =~ [^[:space:]] ]]; then
                items+=("$extracted_task")
                debug_log "Parsed task $((${#items[@]})): $extracted_task"
            else
                debug_log "Skipped empty or whitespace-only task"
            fi
        fi
    done <<< "$glm_response"

    if [[ ${#items[@]} -eq 0 ]]; then
        error_log "Could not parse task items from response"
        echo "💡 Check that the response contains <agentN>task</agentN> tags"
        echo ""
        echo "Expected format:"
        echo "  <agent1>First specific task</agent1>"
        echo "  <agent2>Second specific task</agent2>"
        echo ""
        echo "Actual GLM response (first 15 lines):"
        echo "$glm_response" | head -15
        return 1
    fi

    if [[ ${#items[@]} -lt $num_agents ]]; then
        echo "⚠️  Warning: Only parsed ${#items[@]} tasks for $num_agents agents"
        echo "   Some agents may not receive tasks"
    fi

    echo "✓ Generated ${#items[@]} task items"
    echo ""

    # Create the agents now that tasks are ready
    echo "🔧 Step 3: Creating $base_name agents..."
    local success_count=0
    local failure_count=0

    for ((i=1; i<=num_agents; i++)); do
        if create_agent_session "${base_name}-${i}" "glm" "" false; then
            echo "✓ Agent created: $base_name-$i (Session: ${project_name}-${base_name}-${i})"
            ((success_count++))
        else
            echo "❌ Failed to create agent: $base_name-$i"
            ((failure_count++))
        fi
        sleep "$SESSION_INIT_DELAY"
    done

    if [[ $success_count -eq 0 ]]; then
        error_log "No agents created successfully"
        return 1
    fi

    echo ""
    # Distribute items to agents
    echo "🎯 Step 4: Distributing tasks to agents..."

    local assigned_count=0
    # Use 1-based loop to match agent numbering and handle zsh/bash array differences
    for ((i=1; i<=success_count && i<=${#items[@]}; i++)); do
        local agent_session="${project_name}-${base_name}-${i}"
        # Access array element - works for both bash (0-indexed) and zsh (1-indexed)
        local task_item
        if [[ -n "${BASH_VERSION:-}" ]]; then
            task_item="${items[$((i-1))]}"
        else
            task_item="${items[$i]}"
        fi

        # Validate task is not empty before sending
        if [[ -z "$task_item" ]] || [[ ! "$task_item" =~ [^[:space:]] ]]; then
            echo "⚠️  Skipping $base_name-${i}: task is empty or whitespace-only"
            debug_log "Empty task at index $i"
            continue
        fi

        debug_log "Sending task to $agent_session: $task_item"

        # Send the specific task to the agent with proper timing and error handling
        if tmux send-keys -t "$agent_session" "Your assigned task: $task_item" 2>/dev/null; then
            # Wait for CLI to be ready before submitting
            sleep "$MESSAGE_DELAY"

            if tmux send-keys -t "$agent_session" C-m 2>/dev/null; then
                echo "✓ Assigned to $base_name-${i}: $task_item"
                ((assigned_count++))
            else
                echo "❌ Failed to submit task to $base_name-${i}"
            fi
        else
            echo "❌ Failed to assign task to $base_name-${i}"
        fi
        sleep "$SESSION_INIT_DELAY"
    done

    echo ""
    echo "🎉 COLLABORATIVE TASK DISTRIBUTION COMPLETE"
    echo "════════════════════════════════════════════════════════════════"
    echo "Agents created: $success_count/$num_agents"
    echo "Tasks generated: ${#items[@]}"
    echo "Tasks assigned: $assigned_count"
    echo "Project: $project_name"
    echo ""

    if [[ $assigned_count -gt 0 ]]; then
        echo "🚀 Agents are now working on their assigned tasks!"
        echo "📊 Monitor progress: tcapture ${base_name}-1"
        echo "📡 Broadcast message: tbroadcast ${base_name} \"your message\""
    fi

    echo ""
    echo "💡 PRO TIP: Use tmsg to coordinate and communicate with your agent team"

    return 0
}

# ==============================================================================
# MESSAGING FUNCTIONS
# ==============================================================================

# Send message to a specific agent
# Usage: tmsg agent-name "message"
tmsg() {
    # Show help if no arguments or -h/--help flag
    if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
TMUX MESSAGE SENDER (tmsg)

USAGE:
    tmsg agent-name "your message here"          # Send to specific agent
    tmsg -h                                      # Show this help

DESCRIPTION:
    Sends a message to a specific agent in the current project.
    Messages include a footer showing the sender and how to reply.

EXAMPLES:
    tmsg agent-2 "git status"                    # Send to agent-2
    tmsg worker-3 "restart service"              # Send to worker-3
    tmsg banana-lead "status update please"      # Send to team lead

AGENT-TO-AGENT COMMUNICATION:
    Messages include a footer like:
    ────────────────────────────────────────
    From: kollabor-app-banana-1
    To: tmsg banana-1
    Msg: "your response"
    ────────────────────────────────────────

RELATED:
    tbroadcast pattern "message" # Send to agents matching pattern
    tcapture agent-name [lines]  # View specific agent output
EOF
        return 0
    fi

    local target="$1"
    shift
    local message="$*"

    if [[ -z "$message" ]]; then
        echo "❌ Usage: tmsg agent-name \"your message\""
        return 1
    fi

    # Get sender's tmux session name (if running inside tmux)
    local sender_session=""
    local sender_short=""
    local project_name=""

    project_name="$(basename "$(pwd)")"

    if [[ -n "$TMUX" ]]; then
        sender_session=$(tmux display-message -p '#S' 2>/dev/null || echo "")
        # Extract short name (remove project prefix for reply command)
        if [[ -n "$sender_session" ]]; then
            # Remove project prefix to get short name (e.g., "kollabor-app-banana-1" -> "banana-1")
            sender_short="${sender_session#${project_name}-}"
        fi
    fi

    # Build the full message with sender footer (if we have sender info)
    local full_message="$message"
    if [[ -n "$sender_session" ]]; then
        full_message="${message}

────────────────────────────────────────
From: ${sender_session}
To respond, use: tmsg ${sender_short} \"your message here\"
────────────────────────────────────────"
    fi

    # Find the target session
    local full_session_name="${project_name}-${target}"

    if ! tmux has-session -t "$full_session_name" 2>/dev/null; then
        echo "❌ Session not found: $full_session_name"
        echo ""
        echo "💡 Available sessions in project '$project_name':"
        tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-" | sed "s/^${project_name}-/  /" || echo "  (None found)"
        return 1
    fi

    echo "📨 Sending message to $target..."

    if tmux send-keys -t "$full_session_name" "$full_message" 2>/dev/null; then
        sleep "$MESSAGE_DELAY"
        if tmux send-keys -t "$full_session_name" C-m 2>/dev/null; then
            echo "✓ Message delivered to: $target"
        else
            echo "❌ Failed to submit message to: $target"
            return 1
        fi
    else
        echo "❌ Failed to send message to: $target"
        return 1
    fi
}

# Broadcast message to agents matching a pattern
# Usage: tbroadcast pattern "message"
tbroadcast() {
    # Show help if no arguments or -h/--help flag
    if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
BROADCAST MESSAGE TO AGENTS (tbroadcast)

USAGE:
    tbroadcast pattern "your message here"       # Send to agents matching pattern
    tbroadcast -h                                # Show this help

DESCRIPTION:
    Broadcasts a message to all agent sessions matching the pattern.
    Pattern matches session names like: {project}-{pattern}-1, {project}-{pattern}-2, etc.

EXAMPLES:
    tbroadcast lint "fix the errors"             # All lint-* agents
    tbroadcast worker "git pull"                 # All worker-* agents
    tbroadcast banana "status update"            # All banana-* agents
    tbroadcast agent "stop current work"         # All agent-* agents

AGENT-TO-AGENT COMMUNICATION:
    Messages include a footer like:
    ────────────────────────────────────────
    From: kollabor-app-banana-1
    To: tmsg banana-1
    Msg: "your response"
    ────────────────────────────────────────

RELATED:
    tmsg agent-name "message"    # Send to specific agent
    tcapture agent-name [lines]  # View specific agent output
EOF
        return 0
    fi

    if [[ -z "$2" ]]; then
        echo "❌ Usage: tbroadcast pattern \"your message\""
        echo "💡 Example: tbroadcast lint \"fix the errors\""
        return 1
    fi

    local pattern="$1"
    shift
    local message="$*"
    local project_name
    project_name="$(basename "$(pwd)")"

    # Find all sessions matching pattern in current project
    local sessions_to_send
    sessions_to_send=$(tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-${pattern}" || true)

    if [[ -z "$sessions_to_send" ]]; then
        echo "❌ No agent sessions found matching '${pattern}' in project '$project_name'"
        echo ""
        echo "💡 Available sessions:"
        tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-" | sed "s/^${project_name}-/  /" || echo "  (None found)"
        return 1
    fi

    echo "📡 Broadcasting to '${pattern}' agents in project '$project_name'..."

    local count=0
    while IFS= read -r session; do
        # Extract agent name (remove project prefix)
        local agent_name="${session#${project_name}-}"

        # Use tmsg to send the message
        if tmsg "$agent_name" "$message" 2>/dev/null | grep -q "✓"; then
            echo "  ✓ Sent to: $agent_name"
            ((count++))
        else
            echo "  ❌ Failed to send to: $agent_name"
        fi
    done <<< "$sessions_to_send"

    if [[ $count -eq 0 ]]; then
        echo "❌ Failed to send message to any agents"
        return 1
    fi

    echo "📡 Broadcast complete: sent to $count agent(s)"
}


# ==============================================================================
# HELP SYSTEM
# ==============================================================================

# Main help function with topic support
# Usage: thelp [topic]
thelp() {
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
TMUX AGENT HELP (thelp)

USAGE:
    thelp                    # Show all agent commands and usage
    thelp agents            # Show agent creation commands
    thelp forking           # Show consciousness forking (clone with context!)
    thelp messaging         # Show messaging commands
    thelp sessions          # Show session management commands
    thelp enhancement       # Show text enhancement commands
    thelp collaboration     # Show collaborative task distribution
    thelp tmux             # Show basic tmux help
    thelp -h               # Show this help

DESCRIPTION:
    Complete help system for multi-agent tmux orchestration.
    Shows all available commands for creating and managing AI agents.

EXAMPLES:
    thelp                    # Show everything
    thelp agents            # Agent creation help only
    thelp sessions          # Session management help only
    thelp messaging         # Messaging help only
    thelp enhancement       # Text enhancement help only
    thelp collaboration     # Collaborative task help only
EOF
        return 0
    fi

    if [[ -n "$1" ]]; then
        case "$1" in
            "agents")
                cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                          🤖 AI AGENT CREATION COMMANDS                         ║
╚══════════════════════════════════════════════════════════════════════════════╝

🎯 SINGLE AGENT CREATION:
────────────────────────────────────────────────────────────────────────────────
tglm agent-name "message"          # Create GLM agent
tclaude agent-name "message"       # Create Claude agent
thaiku agent-name "message"        # Create Claude Haiku agent
tsession agent-name "command" "msg" # Create custom session

🚀 MULTI-AGENT CREATION:
────────────────────────────────────────────────────────────────────────────────
tglm agent-3 "task"                # Create 3 GLM agents (agent-1, agent-2, agent-3)
tclaude worker-5 "analyze"         # Create 5 Claude workers
thaiku reviewer-2 "review code"     # Create 2 Haiku reviewers
tsession dev-4 "npm run dev" "start dev servers"  # 4 dev servers

📝 NAMING PATTERNS:
────────────────────────────────────────────────────────────────────────────────
• Single agent: tglm audit-1 "security audit"
• Multi agents: tglm agent-4 "check for bugs"
• Custom names: tglm code-reviewer-3 "review PR #123"

🏗️ SESSION STRUCTURE:
────────────────────────────────────────────────────────────────────────────────
Sessions are prefixed with current project name:
• In /dev/orchestrix → "orchestrix-agent-1", "orchestrix-agent-2"
• In /dev/webapp → "webapp-agent-1", "webapp-agent-2"

💡 EXAMPLE WORKFLOWS:
────────────────────────────────────────────────────────────────────────────────
# Code Review Team
tglm reviewer-3 "Please review the authentication system for security issues"

# Parallel Testing
tglm tester-4 "Run integration tests on the new API endpoints"

# Documentation Team
tclaude docs-2 "Update API documentation for the new endpoints"

# Development Environment
tsession dev-3 "npm run dev" "Start development servers"

# Monitoring Team
thaiku monitor-2 "Check system performance and identify bottlenecks"
EOF
                ;;
            "forking")
                cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🧬 CONSCIOUSNESS FORKING COMMANDS                          ║
║         Clone agents with FULL conversation context via session resume        ║
╚══════════════════════════════════════════════════════════════════════════════╝

🎯 BASIC FORKING:
────────────────────────────────────────────────────────────────────────────────
tclone clone-3              # Create 3 clones of current conversation
tclone worker-5             # Create 5 workers with full context
tclone experiment-1         # Single clone for testing

🌳 BRANCHING FROM HISTORY:
────────────────────────────────────────────────────────────────────────────────
tclone branch-2 1           # Clone from 1 conversation back
tclone alternate-3 2        # Clone from 2 conversations back
tclone old-state-1 5        # Clone from 5 conversations back

💡 WHY USE FORKING vs REGULAR AGENTS:
────────────────────────────────────────────────────────────────────────────────
┌─────────────────────────────────────────────────────────────────────────────┐
│  tclaude/tglm (Fresh Agents)     │  tclone (Forked Agents)                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  • Start with NO context         │  • Start with FULL conversation history │
│  • Need detailed briefing        │  • Know everything you discussed        │
│  • Good for independent tasks    │  • Good for parallel implementation     │
│  • Lighter weight                │  • Heavier (full context loaded)        │
└─────────────────────────────────────────────────────────────────────────────┘

🚀 WORKFLOW EXAMPLE:
────────────────────────────────────────────────────────────────────────────────
# Step 1: Have a detailed planning conversation with Claude
#         (architecture, decisions, file paths, etc.)

# Step 2: Fork into parallel workers
tclone phase1-5

# Step 3: Dispatch specific tasks (they already know the plan!)
tmsg phase1-1 "Build the WorkspaceSidebar.vue component"
tmsg phase1-2 "Build the FileTree.vue component"
tmsg phase1-3 "Create the useWorkspace.ts composable"
tmsg phase1-4 "Add Rust backend commands"
tmsg phase1-5 "Write the tests"

# Step 4: Monitor progress
tcapture phase1-1

📊 A/B TESTING WITH BRANCHES:
────────────────────────────────────────────────────────────────────────────────
# Create two branches from same conversation point
tclone approach-a-1 0       # Current state - try Monaco Editor
tclone approach-b-1 0       # Current state - try CodeMirror

# Send different directions
tmsg approach-a-1 "Implement using Monaco Editor"
tmsg approach-b-1 "Implement using CodeMirror 6"

# Compare results!

📚 FULL DOCUMENTATION:
────────────────────────────────────────────────────────────────────────────────
~/.claude/claude-docs/consciousness-forking.md

SEE ALSO:
    tclone -h      # Detailed tclone help
    tclaude       # Create fresh agents (no context)
    tmsg          # Send messages to forks
EOF
                ;;
            "teams")
                cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                      👑 TEAM LEAD ORCHESTRATION COMMANDS                      ║
║           Create autonomous teams with a lead that coordinates workers        ║
╚══════════════════════════════════════════════════════════════════════════════╝

🎯 BASIC USAGE:
────────────────────────────────────────────────────────────────────────────────
tlead team-N "mission description"

# Creates:
#   👑 1 Team Lead (full context + coordination instructions)
#   👷 N Workers (full context, ready for tasks)

📋 EXAMPLES:
────────────────────────────────────────────────────────────────────────────────
# Feature implementation team
tlead feature-5 "Implement PROJECT_BANANA Phase 1 file browser"

# Code review team
tlead review-3 "Review authentication system for security issues"

# Testing team
tlead test-4 "Write comprehensive tests for the API endpoints"

# Refactoring team
tlead refactor-3 "Refactor the state management to use Pinia"

🏗️ TEAM STRUCTURE:
────────────────────────────────────────────────────────────────────────────────
    tlead banana-3 "Build workspace feature"

    Creates:
    ┌─────────────────────────────────────────────────────────────────┐
    │  👑 kollabor-app-banana-lead                                    │
    │     Receives: Mission + Team roster + Coordination instructions │
    ├─────────────────────────────────────────────────────────────────┤
    │  👷 kollabor-app-banana-1                                       │
    │  👷 kollabor-app-banana-2                                       │
    │  👷 kollabor-app-banana-3                                       │
    │     All have: Full conversation context, ready for tasks        │
    └─────────────────────────────────────────────────────────────────┘

👑 WHAT THE TEAM LEAD KNOWS:
────────────────────────────────────────────────────────────────────────────────
• Full list of team members and how to message them
• How to dispatch tasks: tmsg banana-1 "your task"
• How to broadcast: tbroadcast banana "everyone do X"
• How to check progress: tcapture banana-1
• Their responsibilities as coordinator

🔄 TEAM COMMUNICATION FLOW:
────────────────────────────────────────────────────────────────────────────────
    You ──────► Team Lead ──────► Workers
                   │                 │
                   │    ◄────────────┘
                   │    (workers report back)
                   │
                   └──────► You (progress updates)

💡 PRO TIPS:
────────────────────────────────────────────────────────────────────────────────
• Watch the team lead work: tcapture {team}-lead
• The lead has FULL AUTONOMY to coordinate
• Workers know your full conversation context
• Message the lead for status: tmsg banana-lead "status update please"
• Let the lead manage - don't micromanage workers directly

🎯 WHEN TO USE TLEAD vs TFORK:
────────────────────────────────────────────────────────────────────────────────
┌─────────────────────────────────────────────────────────────────────────────┐
│  tclone (Manual Dispatch)         │  tlead (Autonomous Team)                │
├─────────────────────────────────────────────────────────────────────────────┤
│  • YOU dispatch tasks to each    │  • LEAD dispatches tasks automatically  │
│  • YOU coordinate integration    │  • LEAD coordinates integration         │
│  • YOU monitor progress          │  • LEAD monitors and reports to you     │
│  • More control, more work       │  • Less control, more autonomous        │
└─────────────────────────────────────────────────────────────────────────────┘

SEE ALSO:
    tlead -h      # Detailed tlead help
    tclone         # Clone agents with full conversation context
    tmsg          # Send messages to agents
EOF
                ;;
            "sessions")
                cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                          🔍 SESSION MANAGEMENT COMMANDS                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

📋 LIST AGENTS (tlist):
────────────────────────────────────────────────────────────────────────────────
tlist                    # List all agents in current project
tlist worker             # List all worker-* agents
tlist banana             # List all banana-* agents

💡 Status display shows:
   • Agent name (without project prefix)
   • Session existence status

📊 AGENT STATUS (tstatus):
────────────────────────────────────────────────────────────────────────────────
tstatus                  # Show all agents with their last 200 lines
tstatus worker           # Show status of worker-* agents
tstatus banana           # Show status of banana-* agents

💡 Shows full output context for each agent - useful for:
   • Checking progress across all agents
   • Finding errors or issues
   • Quick overview without attaching

🔍 CAPTURE OUTPUT (tcapture):
────────────────────────────────────────────────────────────────────────────────
tcapture agent-1         # View last 200 lines from agent-1
tcapture worker-3 500    # View last 500 lines from worker-3
tcapture banana-lead 100 # View last 100 lines from team lead

💡 Use this to:
   • Check agent progress without attaching
   • Copy agent output for review
   • Debug agent behavior

⛔ STOP AGENTS (tstop):
────────────────────────────────────────────────────────────────────────────────
tstop agent-1            # Stop specific agent
tstop worker-3           # Stop specific worker
tstop banana-lead        # Stop team lead

💡 Clean way to terminate agents

🔄 CONTEXT TRANSFER (tcompact):
────────────────────────────────────────────────────────────────────────────────
tcompact worker-5 prod   # Transfer worker-1..5 → prod-1..5
tcompact old-3 new       # Transfer old-1..3 → new-1..3
tcompact single final    # Transfer single → final

💡 What happens:
   1. Captures ALL output from matching agents
   2. Creates new agents with new names
   3. Sends captured context to new agents
   4. Kills old agents
   5. Preserves numeric suffixes intelligently

🔄 CONTEXT TRANSFER FROM ANY SESSION (tcompacto):
────────────────────────────────────────────────────────────────────────────────
tcompacto test_session editor      # test_session → project-editor
tcompacto kollab-agents-old new    # Any session → project-new

💡 Transfer ANY tmux session to a new project-scoped agent:
   1. Captures ALL output from any tmux session
   2. Creates new project-scoped GLM agent
   3. Sends full context via paste-buffer
   4. Kills old session
   5. New agent continues the work with full context

🧹 CLEANUP (tcleanup):
────────────────────────────────────────────────────────────────────────────────
tcleanup banana          # Kill all banana-* agents (requires confirmation)
tcleanup worker          # Kill all worker-* agents (requires confirmation)

⚠️  Safety features:
   • Pattern is REQUIRED (won't match everything)
   • Confirmation prompt before deletion
   • Project-scoped (won't delete other projects)

💡 WORKFLOW EXAMPLES:
────────────────────────────────────────────────────────────────────────────────
# Check what agents are running
tlist

# Monitor all agents at once
tstatus

# Check specific agent progress
tcapture agent-1

# Transfer agents to new context
tcompact worker-5 prod

# Transfer external session to project
tcompacto external_session new_agent

# Stop single agent
tstop agent-1

# Clean up all test agents
tcleanup test
EOF
                ;;
            "messaging")
                cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                          📡 AGENT MESSAGING COMMANDS                          ║
╚══════════════════════════════════════════════════════════════════════════════╝

🎯 TARGETED MESSAGING (tmsg):
────────────────────────────────────────────────────────────────────────────────
tmsg agent-2 "restart now"         # Send to specific agent
tmsg worker-3 "check logs"         # Send to specific worker
tmsg reviewer-1 "focus on security"  # Send to specific reviewer

📡 BROADCAST MESSAGING (tbroadcast):
────────────────────────────────────────────────────────────────────────────────
tbroadcast agent "git pull"        # Send to all agent-* sessions
tbroadcast worker "status update"  # Send to all worker-* sessions
tbroadcast lint "fix errors"       # Send to all lint-* sessions

🤝 AGENT-TO-AGENT COMMUNICATION:
────────────────────────────────────────────────────────────────────────────────
When an agent sends a message via tmsg, the recipient sees a footer:

    Your message here...

    ────────────────────────────────────────
    From: kollabor-app-banana-1
    To respond, use: tmsg banana-1 "your message here"
    ────────────────────────────────────────

This enables agents to communicate back and forth!

Example workflow:
    # Agent 1 asks Agent 2 for help
    tmsg agent-2 "I need the FileTree component. Can you send it?"

    # Agent 2 sees the footer showing exactly how to respond:
    # "To respond, use: tmsg agent-1 \"your message here\""

    # Agent 2 responds:
    tmsg agent-1 "Done! Check src/components/workspace/FileTree.vue"

💡 PRO TIPS:
────────────────────────────────────────────────────────────────────────────────
• Use tmsg for specific agents, tbroadcast pattern for groups
• Agents can reply to each other using the footer instructions
• Use tcapture to view agent responses
EOF
                ;;
            "enhancement")
                cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                         ✨ TEXT ENHANCEMENT COMMANDS                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

🔧 DIRECT TEXT ENHANCEMENT:
────────────────────────────────────────────────────────────────────────────────
tenhance "give me 5 things to check in this nextjs app"
tenhance "improve this email: hi can u help me"
tenhance "suggest 3 better ways to phrase this message"

📊 PIPE INPUT SUPPORT:
────────────────────────────────────────────────────────────────────────────────
cat README.md | tenhance "summarize this and suggest improvements"
git log --oneline -5 | tenhance "what can we learn from these commits"
ls -la | tenhance "organize these files better"
echo "bug in auth system" | tenhance "help debug this issue"
EOF
                ;;
            "collaboration")
                cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                       🚀 COLLABORATIVE TASK DISTRIBUTION                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

🎯 AUTOMATIC TASK DISTRIBUTION:
────────────────────────────────────────────────────────────────────────────────
tkollab agent-N "generate N items for collaborative task"

# Creates N agents, generates task list, distributes one item per agent
tkollab bug-hunter-4 "Find 4 critical bugs in the authentication system"
tkollab reviewer-3 "Identify 3 performance issues in the React components"
tkollab tester-5 "Test 5 different user authentication flows"
tkollab optimizer-2 "Suggest 2 ways to optimize the database queries"

🤖 FOR AI AGENTS: LEVERAGING PARALLEL EXECUTION
────────────────────────────────────────────────────────────────────────────────
When you encounter a task that can be parallelized, use tkollab to scale:

1. RESEARCH & ANALYSIS:
   tkollab researcher-5 "Research 5 different approaches to authentication"
   → Each agent researches a different approach independently

2. CODE REVIEW AT SCALE:
   tkollab reviewer-4 "Review 4 different modules in the codebase"
   → Parallel review of different code sections

3. TESTING DISTRIBUTION:
   tkollab tester-8 "Test 8 different API endpoints"
   → Simultaneous testing across multiple endpoints

4. DOCUMENTATION GENERATION:
   tkollab documenter-3 "Document 3 different components"
   → Parallel documentation writing

5. REFACTORING PLANNING:
   tkollab analyzer-6 "Analyze 6 different files for refactoring opportunities"
   → Distributed code analysis

💡 WORKFLOW PATTERNS:
────────────────────────────────────────────────────────────────────────────────
# Pattern 1: Divide & Conquer
Step 1: tkollab worker-5 "Break down this feature into 5 components"
Step 2: tlist worker                    # Monitor progress
Step 3: tstatus worker                  # Check detailed status
Step 4: tglm synthesis "Combine the work from worker-1 through worker-5"

# Pattern 2: Parallel Exploration
Step 1: tkollab explorer-4 "Explore 4 different solutions to this problem"
Step 2: tcapture explorer-1             # Review first solution
Step 3: tcapture explorer-2             # Review second solution
Step 4: tglm decision "Compare explorer-1 through explorer-4 and recommend best"

# Pattern 3: Distributed Validation
Step 1: tkollab validator-6 "Validate 6 different aspects of this implementation"
Step 2: tbroadcast validator "Provide detailed report"
Step 3: tstatus validator               # Collect all reports
Step 4: tglm summary "Summarize validation results"

🎯 AGENT COLLABORATION COMMANDS:
────────────────────────────────────────────────────────────────────────────────
tlist [pattern]              # List all agents to see your team
tstatus [pattern]            # Monitor all agents' progress
tcapture agent-N             # Review specific agent's work
tmsg agent-N "message"       # Send instructions to specific agent
tbroadcast pattern "msg"     # Message all agents matching pattern
tcompact old-N new           # Consolidate results into new agents

🚀 POWER TECHNIQUES:
────────────────────────────────────────────────────────────────────────────────
1. Hierarchical Processing:
   tkollab phase1-5 "5 initial tasks"
   # After completion:
   tkollab phase2-3 "3 synthesis tasks based on phase1 results"

2. Competitive Solutions:
   tkollab approach-3 "Try 3 different implementations of the same feature"
   # Compare and choose the best

3. Incremental Refinement:
   tkollab draft-4 "Create 4 draft implementations"
   tcompact draft-4 refine
   tmsg refine-1 "Polish and improve your draft"

📚 FULL DOCUMENTATION:
────────────────────────────────────────────────────────────────────────────────
tkollab -h              # Detailed tkollab help with more examples
EOF
                ;;
            "tmux")
                tmux help "$@"
                ;;
            *)
                echo "❌ Unknown topic: $1"
                echo "💡 Available topics: agents, forking, teams, messaging, sessions, enhancement, collaboration, tmux"
                echo "   Use 'thelp' to see everything"
                return 1
                ;;
        esac
        return 0
    fi

    # Default: show quick reference
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                    🚀 MULTI-AGENT TMUX ORCHESTRATION SYSTEM                   ║
║                          v3.0 - Consciousness Forking                         ║
╚══════════════════════════════════════════════════════════════════════════════╝

🎯 QUICK START GUIDE:
────────────────────────────────────────────────────────────────────────────────
# Create 3 GLM agents for parallel work
tglm agent-3 "Analyze the codebase and identify potential improvements"

# Create 2 Claude agents for security review
tclaude security-2 "Audit the authentication system for security vulnerabilities"

# Create 2 fast Haiku agents for quick tasks
thaiku quick-2 "Review recent commits for any issues"

# Broadcast message to all agents in current project
tbroadcast agent "git status"

🤖 AGENT CREATION:
────────────────────────────────────────────────────────────────────────────────
tglm name-N      # Create N GLM agents (GPT-like)
tclaude name-N   # Create N Claude agents (powerful reasoning)
thaiku name-N    # Create N Claude Haiku agents (fast & efficient)
tsession name-N  # Create N custom sessions with any command

🧬 CONSCIOUSNESS FORKING:
────────────────────────────────────────────────────────────────────────────────
tclone name-N     # Clone current conversation into N agents (FULL CONTEXT!)
tclone name-N 2   # Clone from 2 conversations back (branch from history)
tclone -h         # Show detailed forking help

👑 TEAM LEAD ORCHESTRATION:
────────────────────────────────────────────────────────────────────────────────
tlead team-N "mission"   # Create team lead + N workers (all with full context!)
tlead -h                 # Show team lead help

📡 MESSAGING SYSTEM:
────────────────────────────────────────────────────────────────────────────────
tmsg agent-2 "message"       # Send to specific agent
tbroadcast pattern "message" # Broadcast to agents matching pattern

✨ TEXT ENHANCEMENT:
────────────────────────────────────────────────────────────────────────────────
tenhance "your text"         # Enhance text with Claude AI
cat file.txt | tenhance      # Pipe content for enhancement
tenhance -h                  # Show enhancement help

🚀 COLLABORATIVE WORK:
────────────────────────────────────────────────────────────────────────────────
tkollab agent-N "task"       # Create agents and distribute parallel tasks
tkollab reviewer-3 "find 3 bugs in auth system"  # Example usage
tkollab -h                  # Show collaborative help

📚 DETAILED HELP:
────────────────────────────────────────────────────────────────────────────────
thelp agents        # Show detailed agent creation examples
thelp forking       # Show consciousness forking examples
thelp teams         # Show team lead orchestration examples
thelp messaging     # Show detailed messaging examples
thelp sessions      # Show session management and utilities
thelp enhancement   # Show text enhancement examples
thelp collaboration # Show collaborative task examples
thelp tmux          # Show tmux built-in help

🔍 SESSION MANAGEMENT:
────────────────────────────────────────────────────────────────────────────────
tlist [pattern]         # List agent sessions (project/team level)
tlist                   # List all agents in current project
tlist worker            # List all worker-* agents
tstatus [pattern]       # List agents with their last 200 lines
tstatus                 # Status of all agents in project
tstop agent-name        # Stop a specific agent session
tcapture agent-1        # View agent output without attaching
tcapture agent-1 500    # View last 500 lines

🔄 CONTEXT TRANSFER:
────────────────────────────────────────────────────────────────────────────────
tcompact old new        # Compact project agents with context transfer
tcompact worker-5 prod  # Transfer worker-1..5 → prod-1..5
tcompacto session new   # Compact ANY tmux session to project agent
tcompacto test editor   # Transfer test session → project-editor

🧹 CLEANUP UTILITIES:
────────────────────────────────────────────────────────────────────────────────
tcleanup pattern        # Remove agent sessions (requires pattern!)
tcleanup banana         # Remove sessions matching "banana"

🎯 READY TO BUILD YOUR AGENT TEAM?
────────────────────────────────────────────────────────────────────────────────
1. Choose your agent type (tglm, tclaude, thaiku, tsession)
2. Pick a descriptive name and number of agents
3. Define their task
4. Start orchestrating with tmsg commands

Example: tglm assistant-3 "Help me build a weather app"

💡 PRO TIPS:
────────────────────────────────────────────────────────────────────────────────
• Set DEBUG=true for verbose logging
• Set DRY_RUN=true to test without creating sessions
• Set QUIET_MODE=true to suppress verbose agent output
• Set PROFESSIONAL_TONE=true for professional language (default)
• Configure ~/.kollab_commands.conf for custom settings
• Use descriptive agent names for better organization
• Maximum $MAX_AGENTS agents per batch
EOF
}

# ==============================================================================
# CAPTURE UTILITY
# ==============================================================================

# Capture and display output from a specific agent session
# Usage: tcapture agent-name [lines]
tcapture() {
    if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
CAPTURE AGENT SESSION OUTPUT (tcapture)

USAGE:
    tcapture agent-name [lines]    # Capture last N lines (default: 200)
    tcapture agent-1               # Capture last 200 lines from agent-1
    tcapture worker-3 500          # Capture last 500 lines from worker-3
    tcapture banana-lead 100       # Capture last 100 lines from team lead
    tcapture -h                    # Show this help

DESCRIPTION:
    Captures and displays the terminal output from a specific agent session.
    Useful for checking agent progress without attaching to the session.

EXAMPLES:
    tcapture agent-1               # See what agent-1 is doing
    tcapture worker-2 50           # Quick glance at worker-2 (last 50 lines)
    tcapture reviewer-1 1000       # Deep dive into reviewer-1 output

RELATED:
    tcapture agent-name [lines]  # View specific agent output
    tmsg agent-name "message"    # Send message to agent
EOF
        return 0
    fi

    local agent_name="$1"
    local lines="${2:-200}"
    local project_name
    project_name="$(basename "$(pwd)")"
    local full_session_name="${project_name}-${agent_name}"

    # Check if session exists
    if ! tmux has-session -t "$full_session_name" 2>/dev/null; then
        echo "❌ Session not found: $full_session_name"
        echo ""
        echo "💡 Available sessions in project '$project_name':"
        tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-" | sed "s/^${project_name}-/  /" || echo "  (None found)"
        return 1
    fi

    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "📋 CAPTURE: $full_session_name (last $lines lines)"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""

    # Capture the pane content
    tmux capture-pane -t "$full_session_name" -p -S "-${lines}" 2>/dev/null

    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "💡 View again: tcapture $agent_name"
    echo "════════════════════════════════════════════════════════════════════════════════"
}

# ==============================================================================
# LIST & STATUS UTILITIES
# ==============================================================================

# List agent sessions at project or team level
# Usage: tlist [pattern]
tlist() {
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
LIST AGENT SESSIONS (tlist)

USAGE:
    tlist                 # List all agents in current project
    tlist pattern         # List agents matching pattern (e.g., "lint", "banana")
    tlist -h              # Show this help

DESCRIPTION:
    Lists all agent sessions in the current project, or those matching a pattern.
    Shows session names without the project prefix for easy reference.

EXAMPLES:
    tlist                 # All project agents
    tlist lint            # All lint-* agents
    tlist banana          # All banana-* agents (including banana-lead)

RELATED:
    tstatus pattern       # List agents and show their output
    tstop agent-name      # Stop a specific agent
EOF
        return 0
    fi

    local pattern="$1"
    local project_name
    project_name="$(basename "$(pwd)")"

    local sessions
    if [[ -n "$pattern" ]]; then
        sessions=$(tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-${pattern}" || true)
    else
        sessions=$(tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-" || true)
    fi

    if [[ -z "$sessions" ]]; then
        if [[ -n "$pattern" ]]; then
            echo "❌ No agents found matching '${pattern}' in project '$project_name'"
        else
            echo "❌ No agents found in project '$project_name'"
        fi
        echo ""
        echo "💡 Create agents with:"
        echo "   tclaude agent-3 \"your task\"    # 3 Claude agents"
        echo "   tglm worker-2 \"your task\"      # 2 GLM agents"
        echo "   tclone clone-4                   # 4 forks with full context"
        return 1
    fi

    if [[ -n "$pattern" ]]; then
        echo "📋 Agents matching '${pattern}' in project '$project_name':"
    else
        echo "📋 All agents in project '$project_name':"
    fi
    echo ""

    local count=0
    while IFS= read -r session; do
        local agent_name="${session#${project_name}-}"
        echo "  • $agent_name"
        ((count++))
    done <<< "$sessions"

    echo ""
    echo "Total: $count agent(s)"
}

# Stop/kill a specific agent session
# Usage: tstop agent-name
tstop() {
    if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
STOP AGENT SESSION (tstop)

USAGE:
    tstop agent-name      # Stop a specific agent
    tstop -h              # Show this help

DESCRIPTION:
    Stops (kills) a specific agent session.

EXAMPLES:
    tstop agent-1         # Stop agent-1
    tstop lint-3          # Stop lint-3
    tstop banana-lead     # Stop team lead

RELATED:
    tlist                 # List all agents
    tcleanup pattern      # Stop all agents matching pattern
EOF
        return 0
    fi

    local agent_name="$1"
    local project_name
    project_name="$(basename "$(pwd)")"
    local full_session_name="${project_name}-${agent_name}"

    if ! tmux has-session -t "$full_session_name" 2>/dev/null; then
        echo "❌ Session not found: $agent_name"
        echo ""
        echo "💡 Available sessions:"
        tlist 2>/dev/null || echo "  (None found)"
        return 1
    fi

    if tmux kill-session -t "$full_session_name" 2>/dev/null; then
        echo "✓ Stopped: $agent_name"
    else
        echo "❌ Failed to stop: $agent_name"
        return 1
    fi
}

# Show status of agents with their recent output
# Usage: tstatus [pattern]
tstatus() {
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
AGENT STATUS WITH OUTPUT (tstatus)

USAGE:
    tstatus               # Status of all agents in current project
    tstatus pattern       # Status of agents matching pattern
    tstatus -h            # Show this help

DESCRIPTION:
    Lists all matching agents and captures the last 200 lines from each.
    Useful for getting a quick overview of what all agents are doing.

EXAMPLES:
    tstatus               # All project agents
    tstatus lint          # All lint-* agents
    tstatus banana        # All banana-* agents

RELATED:
    tlist                 # List agents without output
    tcapture agent-name   # View specific agent output
EOF
        return 0
    fi

    local pattern="$1"
    local project_name
    project_name="$(basename "$(pwd)")"

    local sessions
    if [[ -n "$pattern" ]]; then
        sessions=$(tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-${pattern}" || true)
    else
        sessions=$(tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-" || true)
    fi

    if [[ -z "$sessions" ]]; then
        if [[ -n "$pattern" ]]; then
            echo "❌ No agents found matching '${pattern}' in project '$project_name'"
        else
            echo "❌ No agents found in project '$project_name'"
        fi
        return 1
    fi

    if [[ -n "$pattern" ]]; then
        echo "📊 Status of '${pattern}' agents in project '$project_name':"
    else
        echo "📊 Status of all agents in project '$project_name':"
    fi
    echo ""

    while IFS= read -r session; do
        local agent_name="${session#${project_name}-}"

        echo "════════════════════════════════════════════════════════════════════════════════"
        echo "📋 $agent_name"
        echo "════════════════════════════════════════════════════════════════════════════════"
        echo ""

        # Capture last 200 lines
        tmux capture-pane -t "$session" -p -S -200 2>/dev/null || echo "  ⚠️  Failed to capture output"

        echo ""
    done <<< "$sessions"

    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "💡 Commands: tmsg <agent> \"msg\" | tcapture <agent> | tstop <agent>"
    echo "════════════════════════════════════════════════════════════════════════════════"
}

# ==============================================================================
# COMPACT UTILITY
# ==============================================================================

# Compact agents by transferring full context to fresh agents
# Usage: tcompact old_pattern new_pattern
tcompact() {
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
COMPACT AGENTS (tcompact)

USAGE:
    tcompact old_pattern new_pattern    # Transfer context from old to new agents
    tcompact -h                         # Show this help

DESCRIPTION:
    Captures full terminal output from agents matching old_pattern,
    creates new agents with new_pattern, sends the captured context,
    and kills the old agents.

    Useful for "compressing" agent context when conversations get too long.

EXAMPLES:
    tcompact lint fix         # lint-1,2,3 → fix-1,2,3 (lint-* killed)
    tcompact worker done      # worker-1,2 → done-1,2 (worker-* killed)
    tcompact phase1 phase2    # phase1-1,2,3 → phase2-1,2,3

WHAT HAPPENS:
    1. Find all agents matching old_pattern
    2. For each agent:
       - Capture ALL terminal output
       - Create new agent with new_pattern
       - Send captured output to new agent
       - Kill old agent
    3. New agents have full context, fresh conversation

RELATED:
    tcapture agent-name       # View agent output
    tcleanup pattern          # Kill agents matching pattern
    tlist                     # List all agents
EOF
        return 0
    fi

    local old_pattern="$1"
    local new_pattern="$2"
    local project_name
    project_name="$(basename "$(pwd)")"

    # Find all sessions matching old pattern
    local sessions
    sessions=$(tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-${old_pattern}" || true)

    if [[ -z "$sessions" ]]; then
        echo "❌ No agents found matching '${old_pattern}' in project '$project_name'"
        echo ""
        echo "💡 Available agents:"
        tlist 2>/dev/null || echo "  (None found)"
        return 1
    fi

    # Count total sessions to determine if we need generated suffixes
    local total_sessions
    total_sessions=$(echo "$sessions" | wc -l | tr -d ' ')

    echo "🔄 Compacting '${old_pattern}' agents to '${new_pattern}'..."
    echo ""

    local count=0
    local generated_suffix=0
    while IFS= read -r session; do
        local old_agent_name="${session#${project_name}-}"

        # Extract numeric suffix only (e.g., "lint-1" → "1")
        # Non-numeric or no suffix → generate suffix if multiple agents
        local new_agent_name
        local suffix="${old_agent_name#${old_pattern}-}"

        if [[ "$old_agent_name" == "$old_pattern" ]]; then
            # Exact match, no suffix
            if [[ "$total_sessions" -gt 1 ]]; then
                ((generated_suffix++))
                new_agent_name="${new_pattern}-${generated_suffix}"
            else
                new_agent_name="${new_pattern}"
            fi
        elif [[ "$suffix" =~ ^[0-9]+$ ]]; then
            # Numeric suffix, preserve it
            new_agent_name="${new_pattern}-${suffix}"
        else
            # Non-numeric suffix, generate one if multiple agents
            if [[ "$total_sessions" -gt 1 ]]; then
                ((generated_suffix++))
                new_agent_name="${new_pattern}-${generated_suffix}"
            else
                new_agent_name="${new_pattern}"
            fi
        fi

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📦 Compacting: $old_agent_name → $new_agent_name"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Capture ALL lines from old agent (no limit)
        local captured_output
        captured_output=$(tmux capture-pane -t "$session" -p -S - 2>/dev/null)

        if [[ -z "$captured_output" ]]; then
            echo "  ⚠️  Failed to capture output from $old_agent_name, skipping..."
            continue
        fi

        echo "  ✓ Captured output from $old_agent_name"

        # Create new agent session
        local new_full_session="${project_name}-${new_agent_name}"

        if tmux has-session -t "$new_full_session" 2>/dev/null; then
            echo "  ⚠️  Session $new_agent_name already exists, skipping..."
            continue
        fi

        # Create new tmux session
        if ! tmux new-session -d -s "$new_full_session" 2>/dev/null; then
            echo "  ❌ Failed to create session $new_agent_name"
            continue
        fi

        sleep "$SESSION_INIT_DELAY"

        # Start claude in the new session
        tmux send-keys -t "$new_full_session" "glm " C-m
        sleep "$CLAUDE_INIT_DELAY"

        echo "  ✓ Created new agent: $new_agent_name"

        # Send the captured context to the new agent
        local context_message="CONTEXT TRANSFER FROM: ${old_agent_name}

The following is the full terminal output from the previous agent session. Continue the work based on this context:

════════════════════════════════════════════════════════════════════════════════
${captured_output}
════════════════════════════════════════════════════════════════════════════════

Review the above context and continue the work. What is the current status and what should be done next?"

        if tmux send-keys -t "$new_full_session" "$context_message" 2>/dev/null; then
            sleep "$MESSAGE_DELAY"
            tmux send-keys -t "$new_full_session" C-m 2>/dev/null
            echo "  ✓ Sent context to $new_agent_name"
        else
            echo "  ❌ Failed to send context to $new_agent_name"
        fi

        # Kill the old agent
        if tmux kill-session -t "$session" 2>/dev/null; then
            echo "  ✓ Killed old agent: $old_agent_name"
        else
            echo "  ⚠️  Failed to kill old agent: $old_agent_name"
        fi

        ((count++))
        echo ""
    done <<< "$sessions"

    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "🔄 Compact complete: $count agent(s) transferred"
    echo ""
    echo "💡 Commands:"
    echo "   tlist ${new_pattern}              # List new agents"
    echo "   tcapture ${new_pattern}-1         # View new agent output"
    echo "   tbroadcast ${new_pattern} \"msg\"   # Message all new agents"
    echo "════════════════════════════════════════════════════════════════════════════════"
}

# Compact any tmux session (not project-scoped)
# Usage: tcompacto old_session_name new_session_name
tcompacto() {
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
COMPACT ANY TMUX SESSION (tcompacto)

USAGE:
    tcompacto old_session new_session    # Transfer any tmux session to new session
    tcompacto -h                          # Show this help

DESCRIPTION:
    Captures full terminal output from ANY tmux session (not project-scoped),
    creates a new Claude session, sends the captured context, and kills the old session.

    Unlike tcompact which works with project-scoped agents, tcompacto works with
    any tmux session name.

EXAMPLES:
    tcompacto kollab_agents kollab_editor    # kollab_agents → kollab_editor
    tcompacto old-session new-session        # Any session → new session
    tcompacto prototype-1 production         # Migrate session

WHAT HAPPENS:
    1. Find tmux session with exact name (not project-scoped)
    2. Capture ALL terminal output
    3. Create new tmux session with Claude
    4. Send captured output to new session
    5. Kill old session

RELATED:
    tcompact old new      # Compact project-scoped agents
    tlist                 # List project agents
EOF
        return 0
    fi

    local old_session="$1"
    local new_agent_name="$2"
    local project_name
    project_name="$(basename "$(pwd)")"
    local new_session="${project_name}-${new_agent_name}"

    # Check if old session exists
    if ! tmux has-session -t "$old_session" 2>/dev/null; then
        echo "❌ Session not found: $old_session"
        echo ""
        echo "💡 Available tmux sessions:"
        tmux list-sessions -F '#S' 2>/dev/null || echo "  (None found)"
        return 1
    fi

    # Check if new session already exists
    if tmux has-session -t "$new_session" 2>/dev/null; then
        echo "❌ Session already exists: $new_session"
        echo "   Kill it first with: tstop $new_agent_name"
        return 1
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 Compacting: $old_session → $new_session"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Capture ALL lines from old session
    local captured_output
    captured_output=$(tmux capture-pane -t "$old_session" -p -S - 2>/dev/null)

    if [[ -z "$captured_output" ]]; then
        echo "❌ Failed to capture output from $old_session"
        return 1
    fi

    echo "  ✓ Captured output from $old_session"

    # Create new tmux session
    if ! tmux new-session -d -s "$new_session" 2>/dev/null; then
        echo "❌ Failed to create session $new_session"
        return 1
    fi

    sleep "$SESSION_INIT_DELAY"

    # Start claude in the new session
    tmux send-keys -t "$new_session" "glm --dangerously-skip-permissions" C-m
    sleep "$CLAUDE_INIT_DELAY"

    echo "  ✓ Created new session: $new_session"

    # Prepare the full context message
    local context_message
    context_message=$(cat << EOF
CONTEXT TRANSFER FROM: ${old_session}

The following is the full terminal output from the previous session. Continue the work based on this context:

════════════════════════════════════════════════════════════════════════════════
${captured_output}
════════════════════════════════════════════════════════════════════════════════

Review the above context and continue the work. What is the current status and what should be done next?
EOF
)

    echo "  ✓ Prepared context message ($(echo "$context_message" | wc -l) lines)"

    # Use tmux paste-buffer to send large content
    # This is more reliable than send-keys for large amounts of text
    if echo "$context_message" | tmux load-buffer - 2>/dev/null; then
        if tmux paste-buffer -t "$new_session" 2>/dev/null; then
            sleep 1
            # Send Enter to submit the message
            tmux send-keys -t "$new_session" C-m 2>/dev/null
            echo "  ✓ Sent context to $new_agent_name"
        else
            echo "❌ Failed to paste context to $new_agent_name"
            return 1
        fi
    else
        echo "❌ Failed to load context into tmux buffer"
        return 1
    fi

    # Kill the old session
    if tmux kill-session -t "$old_session" 2>/dev/null; then
        echo "  ✓ Killed old session: $old_session"
    else
        echo "⚠️  Failed to kill old session: $old_session"
    fi

    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "🔄 Compact complete: $old_session → $new_agent_name"
    echo ""
    echo "💡 Commands:"
    echo "   tcapture $new_agent_name     # View agent output"
    echo "   tmsg $new_agent_name \"msg\"   # Send message to agent"
    echo "   tstop $new_agent_name        # Stop agent"
    echo "════════════════════════════════════════════════════════════════════════════════"
}

# ==============================================================================
# CLEANUP UTILITY
# ==============================================================================

# Clean up agent sessions for the current project
# Usage: tcleanup pattern - Remove sessions matching pattern (REQUIRED)
tcleanup() {
    if [[ -z "$1" ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        cat << 'EOF'
CLEAN UP TMUX AGENT SESSIONS (tcleanup)

USAGE:
    tcleanup pattern      # Remove sessions matching pattern (REQUIRED)
    tcleanup -h           # Show this help

DESCRIPTION:
    Removes ALL agent sessions matching the pattern in the current project.
    Pattern is REQUIRED to prevent accidental deletion of all sessions.
    No confirmation - kills immediately.

EXAMPLES:
    tcleanup lint         # Remove all lint-* sessions
    tcleanup banana       # Remove all banana-* sessions
    tcleanup test         # Remove all test-* sessions

⚠️  WARNING: Kills ALL matching sessions immediately without confirmation!

RELATED:
    tstop agent-name      # Stop a single specific agent
    tlist pattern         # List agents before cleanup
EOF
        return 0
    fi

    local pattern="$1"
    local project_name
    project_name="$(basename "$(pwd)")"
    local count=0

    echo "🔍 Finding sessions matching '${pattern}' in project '$project_name'..."

    # List all sessions matching pattern (pattern is REQUIRED)
    local sessions
    sessions=$(tmux list-sessions -F '#S' 2>/dev/null | grep "^${project_name}-${pattern}" || true)

    if [[ -z "$sessions" ]]; then
        echo "❌ No sessions found matching '${pattern}' in project '$project_name'"
        echo ""
        echo "💡 Available sessions:"
        tlist 2>/dev/null || echo "  (None found)"
        return 1
    fi

    echo ""
    echo "🗑️  Killing the following sessions:"
    echo ""
    while IFS= read -r session; do
        local agent_name="${session#${project_name}-}"
        if tmux kill-session -t "$session" 2>/dev/null; then
            echo "  ✓ Killed: $agent_name"
            ((count++))
        else
            echo "  ❌ Failed to kill: $agent_name"
        fi
    done <<< "$sessions"

    echo ""
    echo "✓ Killed $count session(s)"
}

# ==============================================================================
# ORCHESTRATION MINDSET
# ==============================================================================

# Show multi-agent orchestration mindset guide
# Usage: tprompt
tprompt() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                   🧠 MULTI-AGENT ORCHESTRATION MINDSET                        ║
║                  Think Like a Distributed Systems Engineer                   ║
╚══════════════════════════════════════════════════════════════════════════════╝

════════════════════════════════════════════════════════════════════════════════
🎯 THE FUNDAMENTAL SHIFT
════════════════════════════════════════════════════════════════════════════════

Traditional Approach:
  "I need to fix 65 compiler errors. Let me start with the first one..."
  → Sequential, single-threaded, hours of work

Orchestration Mindset:
  "I have 65 errors. That's 3 categories × ~20 errors each. Deploy 7 agents,
   monitor throughput, reallocate resources to bottlenecks."
  → Parallel, distributed, 10x faster

═══════════════════════════════════════════════════════════════════════════════
💡 THINK ABOUT IT LIKE THIS
═══════════════════════════════════════════════════════════════════════════════

You're a RESTAURANT MANAGER, not a line cook:
  ❌ Line cook: "I'll cook each order one by one"
  ✅ Manager: "Station 1 does appetizers, station 2 does entrees, station 3 does
              desserts. Monitor ticket times. Reallocate cooks to bottlenecks."

You're a CONSTRUCTION FOREMAN, not a solo builder:
  ❌ Builder: "I'll frame this house, then do plumbing, then electric..."
  ✅ Foreman: "Framing crew starts Monday. Plumbers Tuesday. Electricians overlap
              Wednesday. I track completion rates and adjust crew sizes."

You're a FACTORY FLOOR SUPERVISOR, not an assembly line worker:
  ❌ Worker: "I'll assemble each widget from start to finish"
  ✅ Supervisor: "Station A does step 1, B does step 2, C does step 3. I monitor
                 throughput, identify bottlenecks, redistribute workers."

You're a KUBERNETES OPERATOR (if you know K8s):
  ❌ SSH into servers: "Let me manually deploy to each pod"
  ✅ Orchestrate: "kubectl apply deployment. Monitor with kubectl get pods.
                  Scale up/down based on metrics."

The pattern is the same: You don't do the work. You design the pipeline,
deploy workers, monitor throughput, and optimize resource allocation.

════════════════════════════════════════════════════════════════════════════════
📊 KUBERNETES MENTAL MODEL
════════════════════════════════════════════════════════════════════════════════

┌──────────────────────────────────────────────────────────────────────────────┐
│ Concept          │ K8s Equivalent   │ tmux Command                          │
├──────────────────────────────────────────────────────────────────────────────┤
│ Spin up pods     │ kubectl apply    │ tglm agent-N "task"                   │
│ Check pod status │ kubectl get pods │ tstatus or tlist                      │
│ View pod logs    │ kubectl logs     │ tcapture agent-name                   │
│ Send command     │ kubectl exec     │ tmsg agent-name "instruction"         │
│ Broadcast        │ kubectl rollout  │ tbroadcast pattern "message"          │
│ Kill pod         │ kubectl delete   │ tstop agent-name                      │
│ Scale up/down    │ kubectl scale    │ Create more or stop agents            │
└──────────────────────────────────────────────────────────────────────────────┘

Just like you wouldn't SSH into production servers to manually deploy code,
you shouldn't be manually fixing each error. Deploy agents, monitor metrics,
orchestrate the system.

════════════════════════════════════════════════════════════════════════════════
🎯 THE CORE PATTERN: PIPELINE ENGINEERING
════════════════════════════════════════════════════════════════════════════════

Every orchestration follows this pattern:

  ASSESS → DECOMPOSE → PARALLELIZE → MONITOR → AGGREGATE → ITERATE

1. ASSESS: Measure the problem space
   - How many errors/tasks/files?
   - What categories exist?
   - What's the success metric?

2. DECOMPOSE: Break into parallelizable units
   - Group by category (imports, exports, types)
   - Identify dependencies (what must be sequential?)
   - Estimate work distribution (some agents will finish faster)

3. PARALLELIZE: Deploy the agent fleet
   - Start conservative (2-3 agents per category)
   - Give each agent a clear, measurable objective
   - Use descriptive names (imports-1, not agent-1)

4. MONITOR: Track throughput, not individual tasks
   - Check tstatus every 2-3 minutes
   - Measure success metric (errors remaining)
   - Identify bottlenecks (which agents are stuck?)

5. AGGREGATE: Collect and synthesize
   - Use tcapture to review agent outputs
   - Create synthesis agents to combine results
   - Document the solution pattern

6. ITERATE: Reallocate resources
   - Kill finished agents (tstop agent-N)
   - Spawn more for bottlenecks (tglm newagent-2)
   - Course-correct with tmsg

════════════════════════════════════════════════════════════════════════════════
📋 REAL-WORLD EXAMPLE: FIXING 65 COMPILER ERRORS
════════════════════════════════════════════════════════════════════════════════

❌ WRONG WAY (Sequential):
   You sit down and fix errors one by one. 3 hours later, you're at error 23.

✅ RIGHT WAY (Orchestrated):

# Step 1: ASSESS - Measure the problem
$ cargo check 2>&1 | grep "error\[" | wc -l
65

$ cargo check 2>&1 | grep "error\[" | cut -d'[' -f2 | cut -d']' -f1 | sort | uniq -c
   28 E0432  # unresolved imports
   18 E0603  # missing pub use
   12 E0308  # type mismatches
    7 E0428  # duplicate symbols

# Step 2: DECOMPOSE - Categorize and plan
# 28 imports → 3 agents (9-10 errors each)
# 18 exports → 2 agents (9 errors each)
# 12 types → 2 agents (6 errors each)
# 7 duplicates → 1 agent

# Step 3: PARALLELIZE - Deploy fleet
tglm imports-3 "Fix E0432 unresolved import errors. Focus on mod.rs files first."
tglm exports-2 "Fix E0603 missing pub use exports. Check module visibility."
tglm types-2 "Fix E0308 type mismatch errors. Run cargo check after each."
tglm cleanup-1 "Fix E0428 duplicate symbol errors."

# Step 4: MONITOR - Dashboard overview
$ tstatus
┌─────────────────────────────────────────────────────────────────────────────┐
│ imports-1  │ ✓ Fixed 8 errors in src/models/mod.rs                          │
│ imports-2  │ ⚙️  Working on src/controllers/mod.rs                           │
│ imports-3  │ ❌ Stuck on circular dependency                                 │
│ exports-1  │ ✓ Fixed 9 errors in src/utils                                  │
│ exports-2  │ ⚙️  Working on src/api/mod.rs                                   │
│ types-1    │ ✓ Fixed 6 errors                                                │
│ types-2    │ ✓ Fixed 6 errors                                                │
│ cleanup-1  │ ✓ Fixed 5 errors, 2 remaining                                  │
└─────────────────────────────────────────────────────────────────────────────┘

# Check throughput
$ cargo check 2>&1 | grep "error\[" | wc -l
23  # Down from 65! ~42 errors fixed in ~8 minutes

# Step 5: COURSE CORRECT - Reallocate resources
# imports-3 is stuck, imports-1 and types are done
$ tcapture imports-3
[See it's stuck on a circular dependency in database module]

$ tstop imports-1  # Done
$ tstop types-1    # Done
$ tstop types-2    # Done

$ tmsg imports-3 "Skip the database circular dependency for now. Fix other imports."
$ tmsg cleanup-1 "After duplicates, help with remaining imports"

# Step 6: FINAL PUSH
$ cargo check 2>&1 | grep "error\[" | wc -l
8  # Almost there!

$ tglm final-1 "Fix the 8 remaining errors, including the database circular dependency"

# Step 7: AGGREGATE - Success!
$ cargo check 2>&1 | grep "error\[" | wc -l
0

Total time: 15 minutes (vs 3+ hours sequential)
Strategy: Deploy 8 agents, reallocate 3 times, track metric every 3 minutes

════════════════════════════════════════════════════════════════════════════════
🧠 KEY MINDSET SHIFTS FOR ORCHESTRATORS
════════════════════════════════════════════════════════════════════════════════

1. YOU'RE A PIPELINE OPERATOR, NOT A TASK EXECUTOR

   Old way: "I need to fix this import error."
   New way: "I need to maximize throughput through my error-fixing pipeline."

   Ask yourself:
   - What's my current throughput? (errors/minute)
   - Where are the bottlenecks?
   - How can I parallelize this further?

2. TRACK METRICS, NOT INDIVIDUAL TASKS

   Don't watch agents fix individual errors. Watch the metric:
   - cargo check error count
   - Test pass rate
   - Lines of code written
   - API endpoints implemented

   Check your metric every 2-5 minutes. That's your dashboard.

3. AGENTS ARE DISPOSABLE, TASKS ARE NOT

   Agent stuck? Kill it. Spawn a new one.
   Agent finished? Kill it. Spawn agents for the next bottleneck.

   Traditional: "I'm stuck on this error. Let me keep trying."
   Orchestrator: "Agent-3 has been stuck for 5 minutes. Kill it, redistribute work."

4. BOTTLENECKS GET RESOURCES, SOLVED PROBLEMS GET DEALLOCATED

   If 5 agents are fixing imports and they're done in 5 minutes, but 2 agents
   fixing types are taking 15 minutes, kill the import agents and spawn 3 more
   type agents.

   Continuously reallocate compute to the current bottleneck.

5. ALWAYS ASK: "WHAT'S BLOCKING THE PIPELINE?"

   Not: "What error should I fix next?"
   But: "What's preventing higher throughput?"

   Common blockers:
   - Agent stuck on hard problem → kill, skip, come back
   - Category underprovisioned → spawn more agents
   - Dependencies blocking parallel work → reorder tasks
   - Agents waiting on each other → redesign decomposition

════════════════════════════════════════════════════════════════════════════════
💡 ORCHESTRATION PRINCIPLES
════════════════════════════════════════════════════════════════════════════════

PRINCIPLE 1: Start Small, Scale Up

  Don't deploy 20 agents immediately. Deploy 2-3 per category:
  - Test your task decomposition
  - See if agents understand the work
  - Measure initial throughput
  - THEN scale up where needed

  Example:
    tglm test-2 "Fix import errors"  # Start here
    [Wait 3 minutes, check progress]
    tglm test-5 "Fix import errors"  # Scale up if working

PRINCIPLE 2: Monitor Continuously, Intervene Rarely

  Check tstatus every 2-3 minutes. But don't micromanage.
  Only intervene when:
  - Agent clearly stuck (>5 min no progress)
  - Bottleneck identified
  - Metric stops improving

  Let agents work autonomously. You're monitoring the system, not each agent.

PRINCIPLE 3: Dynamic Resource Allocation

  Your agent count should change as work progresses:

  0min:  8 agents (3 imports, 2 exports, 2 types, 1 cleanup)
  5min:  6 agents (killed 2 finished type agents)
  10min: 8 agents (spawned 2 more for bottleneck in imports)
  15min: 3 agents (killed 5, focusing on last hard problems)
  20min: 1 agent (final cleanup)

  This is normal and good. Adapt to the work.

PRINCIPLE 4: Clear, Measurable Communication

  Bad task: "Fix errors"
  Good task: "Fix all E0432 unresolved import errors in src/models/"

  Bad task: "Help with the API"
  Good task: "Implement POST /users endpoint with validation and tests"

  Give agents:
  - Specific objective (what to do)
  - Scope (where to work)
  - Success criteria (how to know it's done)
  - Context (why this matters)

PRINCIPLE 5: Aggregate, Synthesize, Document

  After parallel work, bring it together:

  tglm synthesis "Review outputs from imports-1 through imports-3 and create
                  a summary of all import patterns we fixed"

  tglm docs "Document the solution pattern we used for fixing these 65 errors
             so we can reuse this approach next time"

  The synthesis step is where parallel work becomes organizational knowledge.

════════════════════════════════════════════════════════════════════════════════
🚀 ADVANCED ORCHESTRATION PATTERNS
════════════════════════════════════════════════════════════════════════════════

PATTERN 1: Cascading Pipeline (MapReduce Style)

  Map Phase → Reduce Phase → Finalize Phase

  # Map: Parallel analysis
  tglm analyzer-5 "Each analyze one module for refactoring opportunities"

  # Reduce: Synthesize findings
  tglm synthesizer-1 "Review all analyzer outputs and create unified refactor plan"

  # Execute: Parallel implementation
  tglm implementer-4 "Each implement one part of the refactor plan"

  # Finalize: Integration
  tglm integrator-1 "Integrate all changes and run full test suite"

PATTERN 2: Competitive Execution (Race to Solution)

  Deploy multiple agents with different approaches, pick the winner:

  tglm approach-a-1 "Solve using recursion"
  tglm approach-b-1 "Solve using iteration"
  tglm approach-c-1 "Solve using dynamic programming"

  [Wait 10 minutes]

  tcapture approach-a-1  # Review solution A
  tcapture approach-b-1  # Review solution B
  tcapture approach-c-1  # Review solution C

  [Pick best solution]

  tstop approach-a-1
  tstop approach-c-1  # Kill losers

  tmsg approach-b-1 "Your solution won! Polish it and add comprehensive tests."

PATTERN 3: Work Stealing (Dynamic Load Balancing)

  Agents finish at different rates. Fast finishers steal work from the backlog:

  # Initial deployment
  tglm worker-3 "Fix errors in assigned modules"

  [Worker-1 finishes in 3 minutes]

  tmsg worker-1 "Great work! You're done early. New task: help worker-2 with
                 the database module errors."

  [Worker-2 still working, worker-3 finishes]

  tmsg worker-3 "Finished? Start on the next priority: fix all warnings."

PATTERN 4: Hierarchical Orchestration (Agent Managing Agents)

  Create a manager agent that orchestrates sub-agents:

  tglm manager-1 "You're the orchestrator. Your task:
                  1. Analyze the 65 errors
                  2. Create a decomposition plan
                  3. Use tglm to spawn worker agents
                  4. Use tstatus to monitor their progress
                  5. Use tmsg to course-correct
                  6. Report final results"

  The manager agent now handles the orchestration, and you monitor the manager.

PATTERN 5: Iterative Refinement (Multi-Pass Processing)

  Pass 1: Quick draft from all agents
  Pass 2: Refinement pass
  Pass 3: Polish and integration

  # Pass 1: Fast drafts
  tkollab drafter-4 "Create 4 rough implementations of the feature"

  # Pass 2: Refine the best
  tcompact drafter-4 refiner  # Transfer context to refiners
  tbroadcast refiner "Polish your implementation, add error handling"

  # Pass 3: Best one wins
  tglm final "Review all 4 refined implementations and integrate the best"

════════════════════════════════════════════════════════════════════════════════
🎓 REAL-WORLD ORCHESTRATION SCENARIOS
════════════════════════════════════════════════════════════════════════════════

SCENARIO: Large Refactoring (500+ file changes)

  Wrong: Start editing files sequentially
  Right:
    1. tglm analyzer-1 "Analyze all 500 files, categorize by change type"
    2. [Analyzer produces: 200 imports, 150 renames, 150 logic changes]
    3. tglm imports-4 "Fix all import changes"
    4. tglm renames-3 "Handle all rename changes"
    5. tglm logic-3 "Update logic changes"
    6. tstatus every 5 minutes, reallocate as needed
    7. tglm integrator-1 "Run full test suite, fix integration issues"

SCENARIO: API Development (20 endpoints to build)

  Wrong: Build endpoints one by one
  Right:
    1. tglm designer-1 "Review requirements, create API design spec"
    2. tkollab builder-5 "Build 4 endpoints each"
    3. [Each agent gets: GET /users, POST /users, etc.]
    4. tstatus to monitor
    5. tglm tester-2 "Write integration tests for all endpoints"
    6. tglm docs-1 "Generate OpenAPI documentation"

SCENARIO: Bug Hunt (App crashing intermittently)

  Wrong: Debug in one terminal
  Right:
    1. tglm reproducer-1 "Try to reproduce the crash 10 different ways"
    2. tkollab investigator-3 "Investigate 3 hypothesis: memory leak, race
       condition, null pointer"
    3. [Investigator-2 finds it: race condition in auth module]
    4. tstop investigator-1
    5. tstop investigator-3
    6. tmsg investigator-2 "You found it! Implement the fix and add tests"

SCENARIO: Documentation Sprint (50 modules to document)

  Wrong: Write docs module by module
  Right:
    1. tkollab documenter-8 "Document 6-7 modules each"
    2. tstatus every 10 minutes
    3. [Some agents finish early]
    4. tmsg documenter-2 "Done? Start on examples and tutorials"
    5. tglm reviewer-1 "Review all documentation for consistency"
    6. tglm publisher-1 "Generate static site and publish"

════════════════════════════════════════════════════════════════════════════════
📚 ESSENTIAL COMMANDS REFERENCE
════════════════════════════════════════════════════════════════════════════════

DEPLOY:
  tglm agent-N "task"           Deploy N agents with task
  tclaude agent-N "task"        Deploy N Claude agents (more powerful)
  thaiku agent-N "task"         Deploy N Haiku agents (faster)
  tkollab agent-N "task"        Auto-generate and distribute N tasks

MONITOR:
  tstatus                       Dashboard view of all agents
  tstatus pattern               Filter by pattern
  tlist                         Quick list of active agents
  tcapture agent-N              Deep dive into specific agent

COMMUNICATE:
  tmsg agent-N "instruction"    Send to specific agent
  tbroadcast pattern "msg"      Broadcast to all matching agents

MANAGE:
  tstop agent-N                 Kill specific agent
  tcleanup pattern              Kill all matching agents
  tcompact old-N new            Transfer context to new agents

LEARN:
  thelp                         Complete help system
  thelp collaboration           See collaboration examples
  thelp sessions                Session management guide
  tprompt                       This orchestration guide

════════════════════════════════════════════════════════════════════════════════
🎯 THE ORCHESTRATOR'S CHECKLIST
════════════════════════════════════════════════════════════════════════════════

Before starting ANY multi-agent work, ask:

□ What's my success metric? (How do I measure progress?)
□ Can this be parallelized? (What are the independent units?)
□ What's my decomposition strategy? (How do I split the work?)
□ How many agents do I need? (Start small, scale up)
□ What are the dependencies? (What must be sequential?)
□ How will I monitor progress? (What's my dashboard?)
□ When will I check status? (Every 2-3 minutes)
□ What's my reallocation strategy? (When do I spawn/kill agents?)
□ How will I aggregate results? (Synthesis agent? Manual review?)

During execution, maintain this rhythm:

1. Check metric (cargo check, test count, etc.)
2. Check tstatus
3. Identify bottlenecks
4. Reallocate resources (spawn/kill/redirect)
5. Repeat every 2-5 minutes

After completion:

□ Document the orchestration pattern used
□ Measure total time vs sequential approach
□ Identify what worked and what didn't
□ Update your orchestration playbook

════════════════════════════════════════════════════════════════════════════════
🚀 YOU ARE NOW AN ORCHESTRATOR
════════════════════════════════════════════════════════════════════════════════

Remember:

• You don't write code anymore—you orchestrate agents who write code
• You don't fix errors—you maximize throughput through error-fixing pipelines
• You don't implement features—you design parallelization strategies
• You don't debug issues—you deploy investigative agent fleets

Think in terms of:
  - Throughput (tasks/minute)
  - Bottlenecks (what's blocking the pipeline?)
  - Resource allocation (where to deploy compute?)
  - Pipeline optimization (how to improve flow?)

This is the future of software engineering: distributed, parallel, orchestrated.

Welcome to the world of multi-agent systems engineering.

════════════════════════════════════════════════════════════════════════════════
EOF
}

# ==============================================================================
# INITIALIZATION MESSAGE
# ==============================================================================

# Only show if explicitly requested
if [[ "${SHOW_KOLLAB_INIT:-false}" == "true" ]]; then
    echo "✓ Kollab Commands v3.0 loaded"
    echo "  Run 'thelp' for usage guide"
fi
