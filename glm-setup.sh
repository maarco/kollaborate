#!/bin/zsh
# ==============================================================================
# GLM (Generic Language Model) Wrapper
# ==============================================================================
# Configurable wrapper for various LLM CLI tools
# Supports: claude, gemini, opencode, or any custom LLM CLI
#
# Configuration:
#   Set GLM_BACKEND to choose your LLM:
#     export GLM_BACKEND="claude"    # Default
#     export GLM_BACKEND="gemini"
#     export GLM_BACKEND="opencode"
#     export GLM_BACKEND="custom-llm"
#
# Custom API Settings (optional):
#   export ANTHROPIC_BASE_URL="https://api.z.ai/api/anthropic"
#   export ANTHROPIC_AUTH_TOKEN="your-token"
# ==============================================================================

# Default backend
: "${GLM_BACKEND:=claude}"

glm() {
    # Apply custom API settings if defined
    if [[ -n "$ANTHROPIC_BASE_URL" ]]; then
        export ANTHROPIC_BASE_URL
    fi
    if [[ -n "$ANTHROPIC_AUTH_TOKEN" ]]; then
        export ANTHROPIC_AUTH_TOKEN
    fi

    case "$GLM_BACKEND" in
        claude)
            # Claude CLI wrapper with permissions bypass
            if [ -p /dev/stdin ]; then
                local piped_input=$(cat)
                claude --dangerously-skip-permissions "$@" "$piped_input"
            else
                claude --dangerously-skip-permissions "$@"
            fi
            ;;

        gemini)
            # Gemini CLI wrapper with YOLO mode (auto-accept actions)
            if [ -p /dev/stdin ]; then
                local piped_input=$(cat)
                gemini --yolo "$@" <<< "$piped_input"
            else
                gemini --yolo "$@"
            fi
            ;;

        opencode|*)
            # Generic wrapper for other LLM CLIs
            # Uses the backend name as the command
            local cmd="${GLM_BACKEND}"

            if [ -p /dev/stdin ]; then
                local piped_input=$(cat)
                "$cmd" "$@" <<< "$piped_input"
            else
                "$cmd" "$@"
            fi
            ;;
    esac
}

# Helper function to switch GLM backend
glm_use() {
    if [[ -z "$1" ]]; then
        echo "Current GLM backend: $GLM_BACKEND"
        echo ""
        echo "Usage: glm_use <backend>"
        echo "Available backends: claude, gemini, opencode, or custom CLI name"
        return 1
    fi

    export GLM_BACKEND="$1"
    echo "GLM backend set to: $GLM_BACKEND"
}

# Show current configuration
glm_config() {
    echo "GLM Configuration:"
    echo "  Backend: $GLM_BACKEND"
    if [[ -n "$ANTHROPIC_BASE_URL" ]]; then
        echo "  Base URL: $ANTHROPIC_BASE_URL"
    fi
    if [[ -n "$ANTHROPIC_AUTH_TOKEN" ]]; then
        echo "  Auth Token: ${ANTHROPIC_AUTH_TOKEN:0:20}..."
    fi
}
