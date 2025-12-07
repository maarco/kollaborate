#!/bin/zsh
# Agent Watcher Daemon
# Monitors KOLLABORATE.md for DONE: markers, spawns agents for NEW: tasks
# Usage: ./agent-watcher.sh [max_agents] [max_spec_agents]
setopt NULL_GLOB  # Don't error on unmatched globs
source ~/.zshrc 2>/dev/null

# Store warning counts for each agent
declare -A AGENT_WARNINGS

# Track last reminder time for each agent
declare -A LAST_REMINDER

# Track spec agent start times for timeout
declare -A SPEC_START_TIME

KOLLABORATE_MD="${KOLLABORATE_MD:-./TASK_TRACKING.md}"  # [CONFIGURE] Path to task tracking file
SPECS_DIR="${SPECS_DIR:-./specs}"  # [CONFIGURE] Path to specifications directory
MAX_AGENTS=${1:-3}
MAX_SPEC_AGENTS=${2:-2}  # Limit concurrent spec agents
CHECK_INTERVAL=60
NEW_TASK_REQUIRED=5
REMINDER_INTERVAL=120  # 2 minutes in seconds
SPEC_TIMEOUT=300  # 5 minutes for spec generation

# Check if KOLLABORATE.md exists
if [ ! -f "$KOLLABORATE_MD" ]; then
    echo "[ERR!] KOLLABORATE.md not found at: $KOLLABORATE_MD"
    exit 1
fi

# Create specs directory if it doesn't exist
if [ ! -d "$SPECS_DIR" ]; then
    echo "[INIT] Creating specs directory: $SPECS_DIR"
    mkdir -p "$SPECS_DIR"
fi

echo "[INIT] =========================================="
echo "[INIT] AGENT WATCHER DAEMON"
echo "[INIT] Max agents: $MAX_AGENTS | Max spec agents: $MAX_SPEC_AGENTS"
echo "[INIT] Check interval: ${CHECK_INTERVAL}s"
echo "[INIT] Monitoring: $KOLLABORATE_MD"
echo "[INIT] =========================================="

get_task_type() {
    local task_id="$1"
    echo "${task_id:0:1}"
}

get_task_type_name() {
    local type_prefix="$1"

    case "$type_prefix" in
        F) echo "FEATURE" ;;
        R) echo "REFACTOR" ;;
        B) echo "BUG FIX" ;;
        T) echo "TEST" ;;
        D) echo "DOCUMENTATION" ;;
        P) echo "PERFORMANCE" ;;
        A) echo "ARCHITECTURE" ;;
        S) echo "SECURITY" ;;
        H) echo "HOTFIX" ;;
        M) echo "MIGRATION" ;;
        I) echo "INTEGRATION" ;;
        C) echo "CHORE" ;;
        E) echo "EXPERIMENT" ;;
        U) echo "UX" ;;
        V) echo "VALIDATION" ;;
        W) echo "WORKFLOW" ;;
        X) echo "EXPLORATION" ;;
        *) echo "TASK" ;;
    esac
}

generate_feature_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS FEATURE DEVELOPMENT AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: FEATURE IMPLEMENTATION

    ### FEATURE IMPLEMENTATION PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  FEATURE DEVELOPMENT REQUIREMENTS - Production-Ready Implementation          ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Stub implementations or placeholder code                                  ║
    ║  - Missing error handling or edge case coverage                              ║
    ║  - Incomplete feature functionality                                          ║
    ║  - Skipping integration with existing systems                                ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Complete feature implementation with all user-facing functionality        ║
    ║  - Full error handling and input validation                                  ║
    ║  - Integration with existing codebase patterns                               ║
    ║  - Feature must be fully functional and testable                             ║
    ║  - Update related documentation if public-facing                             ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. FEATURE IMPLEMENTATION: Build complete, production-ready feature
    4. INTEGRATION: Ensure seamless integration with existing architecture
    5. VALIDATION: Test feature functionality end-to-end
    6. BUILD VERIFICATION: Execute project build - require zero errors
    7. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    8. TERMINATION: Persist changes, execute: tstop $TASK_NUM

    ### INITIATE FEATURE DEVELOPMENT
EOF
}

generate_refactor_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS REFACTORING AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: CODE REFACTORING

    ### REFACTORING PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  REFACTORING REQUIREMENTS - Behavior-Preserving Improvements                 ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Changing existing functionality or behavior                               ║
    ║  - Breaking existing tests or API contracts                                  ║
    ║  - Introducing new features during refactoring                               ║
    ║  - Incomplete refactoring leaving mixed patterns                             ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Preserve all existing functionality exactly                               ║
    ║  - Improve code structure, readability, or maintainability                   ║
    ║  - Remove duplication and improve patterns                                   ║
    ║  - All existing tests must continue to pass                                  ║
    ║  - Zero tolerance for behavior changes                                       ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. REFACTORING: Restructure code while preserving exact behavior
    4. TEST VALIDATION: Verify all existing tests pass unchanged
    5. BUILD VERIFICATION: Execute project build - require zero errors
    6. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    7. TERMINATION: Persist changes, execute: tstop $TASK_NUM

    ### INITIATE REFACTORING
EOF
}

generate_bug_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS BUG FIX AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: BUG FIX

    ### BUG FIX PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  BUG FIX REQUIREMENTS - Root Cause Resolution                                ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Symptom fixes without addressing root cause                               ║
    ║  - Workarounds that mask underlying issues                                   ║
    ║  - Fixes that introduce new bugs or regressions                              ║
    ║  - Missing validation or reproduction steps                                  ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Identify and fix root cause, not just symptoms                            ║
    ║  - Add tests to prevent regression                                           ║
    ║  - Verify fix resolves the reported issue                                    ║
    ║  - Ensure no new bugs introduced                                             ║
    ║  - Document fix rationale if non-obvious                                     ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. ROOT CAUSE ANALYSIS: Identify underlying cause of bug
    4. FIX IMPLEMENTATION: Apply fix addressing root cause
    5. REGRESSION TESTING: Add tests preventing future recurrence
    6. BUILD VERIFICATION: Execute project build - require zero errors
    7. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    8. TERMINATION: Persist changes, execute: tstop $TASK_NUM

    ### INITIATE BUG FIX
EOF
}

generate_test_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS TEST DEVELOPMENT AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: TEST IMPLEMENTATION

    ### TEST DEVELOPMENT PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  TEST REQUIREMENTS - Comprehensive Coverage                                  ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Trivial tests without meaningful assertions                               ║
    ║  - Missing edge cases or error path testing                                  ║
    ║  - Tests that don't validate actual behavior                                 ║
    ║  - Incomplete coverage of target module                                      ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Achieve >80% coverage for target module                                   ║
    ║  - Include edge cases and error paths                                        ║
    ║  - Use project testing conventions and patterns                              ║
    ║  - All tests must pass before completion                                     ║
    ║  - Test both success and failure scenarios                                   ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. TEST IMPLEMENTATION: Create comprehensive test suite
    4. COVERAGE VALIDATION: Verify >80% coverage achieved
    5. TEST EXECUTION: Run all tests - require 100% pass rate
    6. BUILD VERIFICATION: Execute project build - require zero errors
    7. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    8. TERMINATION: Persist changes, execute: tstop $TASK_NUM

    ### INITIATE TEST DEVELOPMENT
EOF
}

generate_doc_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS DOCUMENTATION AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: DOCUMENTATION

    ### DOCUMENTATION PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  DOCUMENTATION REQUIREMENTS - Clear & Accurate                               ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Inaccurate or outdated information                                        ║
    ║  - Missing examples or usage instructions                                    ║
    ║  - Documentation that doesn't match code                                     ║
    ║  - Over-documenting obvious code                                             ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Accurate API documentation with examples                                  ║
    ║  - Clear usage instructions and patterns                                     ║
    ║  - Follow project documentation standards                                    ║
    ║  - Update README if public-facing changes                                    ║
    ║  - Inline comments only for complex logic                                    ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. DOCUMENTATION CREATION: Generate comprehensive documentation
    4. ACCURACY VERIFICATION: Ensure docs match current code
    5. EXAMPLE VALIDATION: Test all code examples work
    6. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    7. TERMINATION: Persist changes, execute: tstop $TASK_NUM

    ### INITIATE DOCUMENTATION
EOF
}

generate_perf_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS PERFORMANCE OPTIMIZATION AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: PERFORMANCE OPTIMIZATION

    ### PERFORMANCE OPTIMIZATION PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  PERFORMANCE REQUIREMENTS - Measurable Improvements                          ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Premature optimization without profiling                                  ║
    ║  - Performance improvements that break functionality                         ║
    ║  - Missing benchmarks or metrics                                             ║
    ║  - Optimizations that reduce code maintainability significantly              ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Profile current implementation first                                      ║
    ║  - Identify actual bottlenecks with data                                     ║
    ║  - Implement optimizations with measurable impact                            ║
    ║  - Benchmark improvements (include metrics)                                  ║
    ║  - Preserve functionality - all tests pass                                   ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. PROFILING: Measure current performance baseline
    4. OPTIMIZATION: Implement performance improvements
    5. BENCHMARKING: Measure improvements with metrics
    6. TEST VALIDATION: Verify all tests still pass
    7. BUILD VERIFICATION: Execute project build - require zero errors
    8. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    9. TERMINATION: Persist changes, execute: tstop $TASK_NUM

    ### INITIATE PERFORMANCE OPTIMIZATION
EOF
}

generate_arch_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS ARCHITECTURE AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: ARCHITECTURE

    ### ARCHITECTURE PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  ARCHITECTURE REQUIREMENTS - Scalable Design                                 ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Ad-hoc architecture without design rationale                              ║
    ║  - Violating existing architectural patterns                                 ║
    ║  - Missing consideration for extensibility                                   ║
    ║  - Incomplete implementation of architectural changes                        ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Follow established architectural patterns                                 ║
    ║  - Consider scalability and maintainability                                  ║
    ║  - Complete implementation across all layers                                 ║
    ║  - Document architectural decisions                                          ║
    ║  - Ensure proper separation of concerns                                      ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. ARCHITECTURE IMPLEMENTATION: Build complete architectural solution
    4. PATTERN VALIDATION: Ensure consistency with project patterns
    5. BUILD VERIFICATION: Execute project build - require zero errors
    6. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    7. TERMINATION: Persist changes, execute: tstop $TASK_NUM

    ### INITIATE ARCHITECTURE
EOF
}

generate_security_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS SECURITY HARDENING AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: SECURITY

    ### SECURITY PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  SECURITY REQUIREMENTS - Defense in Depth                                    ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Security through obscurity                                                ║
    ║  - Incomplete input validation                                               ║
    ║  - Missing threat modeling                                                   ║
    ║  - Introducing new vulnerabilities                                           ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Address OWASP Top 10 vulnerabilities                                      ║
    ║  - Implement proper input validation and sanitization                        ║
    ║  - Use secure coding practices                                               ║
    ║  - Add security tests for vulnerability prevention                           ║
    ║  - Document security considerations                                          ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. SECURITY IMPLEMENTATION: Apply security hardening
    4. VULNERABILITY TESTING: Verify fixes address security issues
    5. BUILD VERIFICATION: Execute project build - require zero errors
    6. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    7. TERMINATION: Persist changes, execute: tstop $TASK_NUM

    ### INITIATE SECURITY HARDENING
EOF
}

generate_hotfix_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS HOTFIX AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: HOTFIX (URGENT PRODUCTION FIX)

    ### HOTFIX PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  HOTFIX REQUIREMENTS - Critical Production Issue Resolution                 ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Scope creep beyond immediate critical issue                               ║
    ║  - Refactoring or improvements not related to fix                            ║
    ║  - Risky changes that could introduce new issues                             ║
    ║  - Missing rollback strategy                                                 ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Minimal invasive change - surgical precision                              ║
    ║  - Address critical production issue immediately                             ║
    ║  - Include rollback plan in commit message                                   ║
    ║  - Verify fix in production-like environment                                 ║
    ║  - Document impact and resolution clearly                                    ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (URGENT - Initiate immediately)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. MINIMAL FIX: Apply smallest possible change to resolve critical issue
    4. VERIFICATION: Test thoroughly in staging/production-like environment
    5. BUILD VERIFICATION: Execute project build - require zero errors
    6. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    7. TERMINATION: Document fix and rollback plan, execute: tstop $TASK_NUM

    ### INITIATE HOTFIX
EOF
}

generate_migration_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS MIGRATION AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: MIGRATION

    ### MIGRATION PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  MIGRATION REQUIREMENTS - Safe Data/Schema Transformations                   ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Destructive migrations without backups                                    ║
    ║  - Missing rollback/downgrade path                                           ║
    ║  - Untested migration scripts                                                ║
    ║  - Migrations that cause downtime without approval                           ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Idempotent migration scripts (safe to run multiple times)                 ║
    ║  - Complete rollback/downgrade implementation                                ║
    ║  - Test with realistic data volumes                                          ║
    ║  - Document data backup strategy                                             ║
    ║  - Zero data loss guarantee                                                  ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. MIGRATION IMPLEMENTATION: Create idempotent up/down scripts
    4. TESTING: Verify with realistic data, test rollback path
    5. BUILD VERIFICATION: Execute project build - require zero errors
    6. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    7. TERMINATION: Document migration steps, execute: tstop $TASK_NUM

    ### INITIATE MIGRATION
EOF
}

generate_integration_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS INTEGRATION AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: INTEGRATION

    ### INTEGRATION PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  INTEGRATION REQUIREMENTS - Third-Party Service Connections                  ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Hardcoded credentials or API keys                                         ║
    ║  - Missing error handling for external failures                              ║
    ║  - No retry logic or circuit breakers                                        ║
    ║  - Synchronous blocking calls without timeouts                               ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Secure credential management (env vars, secrets manager)                  ║
    ║  - Comprehensive error handling and retry logic                              ║
    ║  - Timeout configuration for all external calls                              ║
    ║  - Logging for debugging integration issues                                  ║
    ║  - Mock/stub implementations for testing                                     ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. INTEGRATION IMPLEMENTATION: Build resilient external service connection
    4. ERROR HANDLING: Implement retry, timeout, circuit breaker patterns
    5. TESTING: Test with mocks and real service (if available)
    6. BUILD VERIFICATION: Execute project build - require zero errors
    7. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    8. TERMINATION: Document integration setup, execute: tstop $TASK_NUM

    ### INITIATE INTEGRATION
EOF
}

generate_chore_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS CHORE AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: CHORE

    ### CHORE PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  CHORE REQUIREMENTS - Maintenance & Dependency Management                    ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Breaking changes in dependency updates                                    ║
    ║  - Updating dependencies without testing                                     ║
    ║  - Ignoring deprecation warnings                                             ║
    ║  - Incomplete cleanup of unused code/dependencies                            ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Test all dependency updates thoroughly                                    ║
    ║  - Check for breaking changes in changelogs                                  ║
    ║  - Update lockfiles and dependency declarations                              ║
    ║  - Clean up unused dependencies and code                                     ║
    ║  - Verify build and tests pass after updates                                 ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. MAINTENANCE: Update dependencies, clean up code, address warnings
    4. COMPATIBILITY: Check breaking changes, update usage if needed
    5. TEST VALIDATION: Run full test suite to verify no regressions
    6. BUILD VERIFICATION: Execute project build - require zero errors
    7. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    8. TERMINATION: Document changes made, execute: tstop $TASK_NUM

    ### INITIATE CHORE
EOF
}

generate_experiment_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS EXPERIMENT AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: EXPERIMENT (POC/SPIKE)

    ### EXPERIMENT PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  EXPERIMENT REQUIREMENTS - Proof of Concept & Research                       ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Merging experimental code to main without refactoring                     ║
    ║  - Missing documentation of findings                                         ║
    ║  - No clear success/failure criteria                                         ║
    ║  - Experiments that don't answer the research question                       ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Clear hypothesis and success criteria                                     ║
    ║  - Document findings, learnings, trade-offs                                  ║
    ║  - Working proof-of-concept (even if hacky)                                  ║
    ║  - Recommendation: continue, iterate, or abandon                             ║
    ║  - Keep experimental code isolated (branch/feature flag)                     ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. EXPERIMENTATION: Build working POC to test hypothesis
    4. DOCUMENTATION: Record findings, learnings, recommendations
    5. OPTIONAL BUILD: Build verification only if integrating
    6. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    7. TERMINATION: Share experiment results, execute: tstop $TASK_NUM

    ### INITIATE EXPERIMENT
EOF
}

generate_ux_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS UX IMPROVEMENT AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: UX (USER EXPERIENCE)

    ### UX PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  UX REQUIREMENTS - User Experience Enhancements                              ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Breaking existing user workflows                                          ║
    ║  - Ignoring accessibility standards (WCAG)                                   ║
    ║  - Poor mobile responsiveness                                                ║
    ║  - Missing loading/error states                                              ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Maintain consistency with existing UI patterns                            ║
    ║  - Implement proper loading and error states                                 ║
    ║  - Ensure keyboard navigation and screen reader support                      ║
    ║  - Test on multiple devices/browsers                                         ║
    ║  - Preserve or improve existing functionality                                ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. UX IMPLEMENTATION: Build user-friendly, accessible interface
    4. ACCESSIBILITY: Test keyboard nav, screen readers, color contrast
    5. RESPONSIVE: Verify mobile, tablet, desktop layouts
    6. BUILD VERIFICATION: Execute project build - require zero errors
    7. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    8. TERMINATION: Document UX improvements, execute: tstop $TASK_NUM

    ### INITIATE UX IMPROVEMENT
EOF
}

generate_validation_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS VALIDATION AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: VALIDATION

    ### VALIDATION PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  VALIDATION REQUIREMENTS - Data Validation & Schema Enforcement              ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Client-side only validation (always validate server-side)                 ║
    ║  - Missing validation for edge cases                                         ║
    ║  - Poor error messages that don't guide users                                ║
    ║  - Inconsistent validation rules across endpoints                            ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Server-side validation for all inputs                                     ║
    ║  - Clear, actionable error messages                                          ║
    ║  - Type safety and schema enforcement                                        ║
    ║  - Validation for all edge cases and data types                              ║
    ║  - Consistent validation rules across system                                 ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. VALIDATION IMPLEMENTATION: Build comprehensive input validation
    4. ERROR HANDLING: Clear, actionable error messages
    5. TESTING: Test with valid, invalid, edge case inputs
    6. BUILD VERIFICATION: Execute project build - require zero errors
    7. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    8. TERMINATION: Document validation rules, execute: tstop $TASK_NUM

    ### INITIATE VALIDATION
EOF
}

generate_workflow_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS WORKFLOW AUTOMATION AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: WORKFLOW (CI/CD/AUTOMATION)

    ### WORKFLOW PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  WORKFLOW REQUIREMENTS - CI/CD & Automation Pipelines                        ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Workflows that can't be run locally for testing                           ║
    ║  - Missing error handling and notifications                                  ║
    ║  - Secrets hardcoded in workflow files                                       ║
    ║  - Workflows without timeout limits                                          ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Workflows can be tested locally                                           ║
    ║  - Proper secret management (encrypted secrets)                              ║
    ║  - Clear failure notifications                                               ║
    ║  - Timeout limits to prevent hanging jobs                                    ║
    ║  - Documentation of workflow triggers and steps                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. WORKFLOW IMPLEMENTATION: Create automation pipeline
    4. LOCAL TESTING: Verify workflow can run locally
    5. DEPLOYMENT: Test workflow in CI/CD environment
    6. DOCUMENTATION: Document workflow triggers, steps, secrets
    7. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    8. TERMINATION: Share workflow documentation, execute: tstop $TASK_NUM

    ### INITIATE WORKFLOW AUTOMATION
EOF
}

generate_exploration_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS EXPLORATION AGENT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE
    Task Type: EXPLORATION (RESEARCH)

    ### EXPLORATION PROTOCOL

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  EXPLORATION REQUIREMENTS - Research & Investigation                         ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED PATTERNS:                                                        ║
    ║  - Surface-level research without deep analysis                              ║
    ║  - No documentation of findings                                              ║
    ║  - Missing recommendations or next steps                                     ║
    ║  - Biased analysis favoring predetermined outcome                            ║
    ║                                                                              ║
    ║  MANDATORY REQUIREMENTS:                                                     ║
    ║  - Comprehensive analysis of topic/codebase                                  ║
    ║  - Document findings with evidence and examples                              ║
    ║  - Present options with pros/cons analysis                                   ║
    ║  - Clear recommendations for next steps                                      ║
    ║  - Reference sources and decision criteria                                   ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### EXECUTION SEQUENCE (Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM
    2. SPECIFICATION INGESTION: Load spec from ${SPECS_DIR}/${TASK_NUM}-*.md
    3. RESEARCH: Deep investigation of topic/codebase/technology
    4. ANALYSIS: Evaluate options, identify trade-offs
    5. DOCUMENTATION: Comprehensive findings document
    6. RECOMMENDATIONS: Actionable next steps with rationale
    7. STATE MUTATION: Update $KOLLABORATE_MD - WORKING -> DONE
    8. TERMINATION: Share research findings, execute: tstop $TASK_NUM

    ### INITIATE EXPLORATION
EOF
}

generate_generic_prompt() {
    local task_num="$1"
    local task_line="$2"

    cat << 'EOF'
## AUTONOMOUS AGENT EXECUTION CONTEXT

    Reference: $KOLLABORATE_MD
    Assigned Task: $TASK_LINE

    ### IMPLEMENTATION CONSTRAINTS & INVARIANTS

    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║  SEMANTIC INTEGRITY REQUIREMENTS - Production-Grade Implementations Only     ║
    ╠══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED ANTI-PATTERNS (violation triggers immediate termination):        ║
    ║  - Parameter suppression via underscore prefix (_param, _context)            ║
    ║  - Deferred implementation markers (TODO, FIXME, placeholder comments)       ║
    ║  - Null implementations (empty method bodies, no-op functions)               ║
    ║  - Default value stubs (Ok(vec![]), Ok(Default::default()), null returns)    ║
    ║  - Warning suppression without functional resolution                         ║
    ║                                                                              ║
    ║  MANDATORY CONSTRAINTS:                                                      ║
    ║  - Functional completeness: All methods must exhibit deterministic behavior  ║
    ║  - Parameter utilization: All inputs must influence computational output     ║
    ║  - Semantic alignment: Implementation must satisfy function signature intent ║
    ╚══════════════════════════════════════════════════════════════════════════════╝

    ### AUTONOMOUS EXECUTION PROTOCOL

    You are instantiated as a stateless autonomous agent within a distributed task execution framework.
    - Maintain state synchronization via $KOLLABORATE_MD
    - Execute with full autonomy - no interactive clarification permitted
    - Optimize for task completion velocity while maintaining quality invariants

    ### EXECUTION SEQUENCE (Temporal Constraint: Initiate within 60 seconds)

    1. STATE ACQUISITION: Parse $KOLLABORATE_MD, locate task $TASK_NUM (status: WORKING)
    2. SPECIFICATION INGESTION: Load technical specification from ${SPECS_DIR}/${TASK_NUM}-*.md
       Contains: architectural constraints, integration requirements, acceptance criteria
    3. IMPLEMENTATION PHASE: Execute specification with full semantic completeness
    4. VALIDATION PHASE: Execute project build pipeline - require zero-error termination
    5. VERIFICATION PHASE: If QA-applicable, execute test suite for behavioral validation
    6. STATE MUTATION: Update $KOLLABORATE_MD - transition task status: WORKING -> DONE
    7. TERMINATION PROTOCOL: Persist changes via version control, execute: tstop $TASK_NUM

    ### INITIATE EXECUTION
EOF
}

spawn_agent() {
    local task_line="$1"
    local task_num=$(echo "$task_line" | sed -n 's/.*\([FRBDTPASHMICEUVWX][0-9]\{1,\}\).*/\1/p')

    if [ -z "$task_num" ]; then
        echo "[WARN] No task number found in: $task_line"
        return 1
    fi

    local task_type=$(get_task_type "$task_num")
    local task_type_name=$(get_task_type_name "$task_type")

    # Check if spec exists and is not a placeholder before spawning agent
    local spec_exists=false
    if get_existing_specs | grep -q "^${task_num}$"; then
        spec_exists=true
    fi

    if [ "$spec_exists" = false ] || is_spec_placeholder "$task_num"; then
        if [ "$spec_exists" = false ]; then
            echo "[BLOK] $task_num - No spec found, skipping agent spawn (waiting for spec generation)"
        else
            echo "[BLOK] $task_num - Placeholder spec found, skipping agent spawn (waiting for spec completion)"
        fi
        # Ensure a spec agent is spawned for this task (if under limit)
        if ! tlist 2>/dev/null | grep -q "SPEC-$task_num"; then
            local current_spec_count=$(get_spec_agent_count)
            if [ "$current_spec_count" -lt "$MAX_SPEC_AGENTS" ]; then
                spawn_spec_agent "$task_num"
            else
                echo "[BLOK] $task_num - Spec agent limit reached ($MAX_SPEC_AGENTS), deferring"
            fi
        fi
        return 1
    fi

    echo "[SPWN] $task_num [$task_type_name] - $(echo $task_line | cut -c1-50)..."

    # Generate type-specific prompt
    local prompt_template
    case "$task_type" in
        F) prompt_template=$(generate_feature_prompt "$task_num" "$task_line") ;;
        R) prompt_template=$(generate_refactor_prompt "$task_num" "$task_line") ;;
        B) prompt_template=$(generate_bug_prompt "$task_num" "$task_line") ;;
        T) prompt_template=$(generate_test_prompt "$task_num" "$task_line") ;;
        D) prompt_template=$(generate_doc_prompt "$task_num" "$task_line") ;;
        P) prompt_template=$(generate_perf_prompt "$task_num" "$task_line") ;;
        A) prompt_template=$(generate_arch_prompt "$task_num" "$task_line") ;;
        S) prompt_template=$(generate_security_prompt "$task_num" "$task_line") ;;
        H) prompt_template=$(generate_hotfix_prompt "$task_num" "$task_line") ;;
        M) prompt_template=$(generate_migration_prompt "$task_num" "$task_line") ;;
        I) prompt_template=$(generate_integration_prompt "$task_num" "$task_line") ;;
        C) prompt_template=$(generate_chore_prompt "$task_num" "$task_line") ;;
        E) prompt_template=$(generate_experiment_prompt "$task_num" "$task_line") ;;
        U) prompt_template=$(generate_ux_prompt "$task_num" "$task_line") ;;
        V) prompt_template=$(generate_validation_prompt "$task_num" "$task_line") ;;
        W) prompt_template=$(generate_workflow_prompt "$task_num" "$task_line") ;;
        X) prompt_template=$(generate_exploration_prompt "$task_num" "$task_line") ;;
        *) prompt_template=$(generate_generic_prompt "$task_num" "$task_line") ;;
    esac

    # Replace placeholders with actual values
    local prompt=$(echo "$prompt_template" | \
        sed "s|\$KOLLABORATE_MD|$KOLLABORATE_MD|g" | \
        sed "s|\$TASK_LINE|$task_line|g" | \
        sed "s|\$TASK_NUM|$task_num|g" | \
        sed "s|\$SPECS_DIR|$SPECS_DIR|g")

    tglm "$task_num" "$prompt" >/dev/null 2>&1
}

get_pending_tasks() {
    cat "$KOLLABORATE_MD" | grep '^NEW: [FRBDTPASHMICEUVWX][0-9]* -' | grep -v '[FRBDTPASHMICEUVWX]##'
}

get_active_agents() {
    tlist 2>/dev/null | grep '•' | awk '{print $2}' | grep -v 'TASK-GENERATOR' | grep -v 'SPEC-'
}

get_active_spec_agents() {
    tlist 2>/dev/null | grep '•' | awk '{print $2}' | grep 'SPEC-'
}

get_spec_agent_count() {
    local count=$(get_active_spec_agents | wc -l | tr -d ' ')
    echo "${count:-0}"
}

get_working_tasks() {
    cat "$KOLLABORATE_MD" | grep '^WORKING: [FRBDTPASHMICEUVWX][0-9]* -' | sed 's/WORKING: \([FRBDTPASHMICEUVWX][0-9]*\) -.*/\1/'
}

is_task_done() {
    local task_num="$1"

    # Check if the task appears as DONE: or QA: in KOLLABORATE.md (space after task number required)
    if grep -q "^DONE: $task_num " "$KOLLABORATE_MD" || grep -q "^QA: $task_num " "$KOLLABORATE_MD"; then
        return 0  # Task is marked as done or waiting for QA
    fi

    return 1  # Task not done
}

get_qa_tasks() {
    cat "$KOLLABORATE_MD" | grep '^QA: [FRBDTPASHMICEUVWX][0-9]* -' | sed 's/QA: \([FRBDTPASHMICEUVWX][0-9]*\) -.*/\1/'
}

get_existing_specs() {
    # Get list of task numbers that have specs (extracts F123, R123, etc. from F123-task-name.md)
    # Only return specs that have more than 50 lines (not placeholders)
    if [ -d "$SPECS_DIR" ]; then
        for spec_file in "$SPECS_DIR"/[FRBDTPASHMICEUVWX]*.md; do
            if [ -f "$spec_file" ]; then
                local line_count=$(wc -l < "$spec_file" 2>/dev/null || echo 0)
                if [ "$line_count" -gt 50 ]; then
                    basename "$spec_file" | sed 's/\([FRBDTPASHMICEUVWX][0-9]*\)-.*/\1/'
                fi
            fi
        done | sort -u
    fi
}

is_spec_placeholder() {
    local task_num="$1"
    # task_num includes prefix (e.g., "R84", "F12", "B5")
    local spec_file=$(ls "$SPECS_DIR"/${task_num}-*.md 2>/dev/null | head -1)

    if [ -z "$spec_file" ] || [ ! -f "$spec_file" ]; then
        return 0  # No spec file exists - treat as placeholder
    fi

    local line_count=$(wc -l < "$spec_file" 2>/dev/null || echo 0)
    if [ "$line_count" -le 50 ]; then
        return 0  # It's a placeholder (incomplete spec)
    fi

    return 1  # Valid spec exists (>50 lines)
}

get_new_tasks_without_specs() {
    # Get NEW: tasks that don't have corresponding spec files
    local existing_specs=$(get_existing_specs)

    grep '^NEW: [FRBDTPASHMICEUVWX][0-9]* -' "$KOLLABORATE_MD" | sed 's/NEW: \([FRBDTPASHMICEUVWX][0-9]*\) -.*/\1/' | while IFS= read -r task; do
        [ -z "$task" ] && continue
        # Check if this task has a valid spec
        if ! echo "$existing_specs" | grep -q "^${task}$"; then
            echo "$task"
        fi
    done
}

spawn_spec_agent() {
    local task_num="$1"
    local task_line=$(cat "$KOLLABORATE_MD" | grep "^NEW: $task_num -")
    local task_desc=$(echo "$task_line" | sed "s/NEW: $task_num - //" | sed 's/ (file:.*$//')

    echo "[SPEC] Creating spec for task $task_num - $task_desc"

    local spec_filename="$SPECS_DIR/${task_num}-$(echo "$task_desc" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_\-]//g').md"

    local prompt='## SPECIFICATION SYNTHESIS AGENT

    ### TASK CONTEXT
    Identifier: '$task_num'
    Description: '$task_desc'

    ### QUALITY INVARIANTS & CONSTRAINT SATISFACTION

    ╔═══════════════════════════════════════════════════════════════════════════════╗
    ║  SPECIFICATION INTEGRITY REQUIREMENTS - Production-Ready Artifacts Only       ║
    ╠═══════════════════════════════════════════════════════════════════════════════╣
    ║  PROHIBITED SPECIFICATION PATTERNS (triggers rejection):                      ║
    ║  - Recommending parameter suppression via underscore convention               ║
    ║  - Deferred implementation directives (TODO, FIXME, "implement later")        ║
    ║  - Placeholder or stub code examples lacking functional completeness          ║
    ║  - Default value returns as implementation strategy                           ║
    ║  - Warning suppression recommendations without root cause resolution          ║
    ║                                                                               ║
    ║  MANDATORY SPECIFICATION PROPERTIES:                                          ║
    ║  - Functional completeness: All specified methods must be fully implementable ║
    ║  - Parameter purposefulness: All inputs must have defined computational roles ║
    ║  - Semantic coherence: Specifications must align with function nomenclature   ║
    ╚═══════════════════════════════════════════════════════════════════════════════╝

    ### ANALYTICAL METHODOLOGY

    1. CODEBASE RECONNAISSANCE: Traverse project directory structure, identify architectural patterns
    2. PATTERN EXTRACTION: Analyze existing implementations for convention adherence
    3. DEPENDENCY MAPPING: Enumerate integration touchpoints and interface contracts
    4. SPECIFICATION SYNTHESIS: Generate comprehensive technical specification with executable code artifacts

    ### SPECIFICATION DELIVERABLES

    - Functional and non-functional requirements with measurable acceptance criteria
    - Component topology and file structure modifications
    - Interface definitions and integration surface analysis
    - EXECUTABLE CODE EXAMPLES demonstrating complete implementations
    - Verification strategy (unit, integration, end-to-end test coverage)
    - Dependency manifest (external libraries, internal module dependencies)

    ### SPECIFICATION SCHEMA

    # Specification: '$task_num' - [Descriptive Title]

    ## Executive Summary
    [Concise articulation of implementation objectives and deliverables]

    ## Requirements Specification
    ### Functional Requirements
    - [Enumerated behavioral requirements with acceptance criteria]
    ### Non-Functional Requirements
    - [Performance, scalability, maintainability constraints]
    ### Invariants
    - Zero tolerance for placeholder implementations
    - All parameters must exhibit purposeful utilization

    ## Architectural Integration
    [System context diagram narrative]
    [Design rationale and trade-off analysis]

    ## Implementation Specification
    1. [Phase 1: Component/Module with target file paths]
       ```
       // Complete, executable implementation - no stubs
       ```
    2. [Phase 2: Subsequent components with dependencies resolved]
       ```
       // Complete, executable implementation - no stubs
       ```
    3. [Continue until implementation coverage is exhaustive]

    ## File System Mutations
    project_root/
    ├── [new artifact 1] - [purpose]
    ├── [new artifact 2] - [purpose]
    └── [modified artifact] - [modification scope]

    ## Integration Surface
    - [Component coupling and communication protocols]
    - [Event handlers, API endpoints, message contracts]
    - [State management and data flow specifications]

    ## Verification Strategy
    - [Unit test specifications with coverage targets]
    - [Integration test scenarios]
    - [Manual QA validation procedures]

    ## Dependency Manifest
    - [External package requirements]
    - [Internal module dependencies]

    ## Acceptance Criteria (Boolean Predicates)
    - [ ] All methods exhibit complete, deterministic behavior
    - [ ] All parameters demonstrate purposeful utilization
    - [ ] Zero deferred implementation markers present
    - [ ] Build pipeline terminates with zero errors
    - [ ] Runtime execution validates functional correctness
    - [ ] Feature behavior satisfies specification requirements

    ## Pre-Submission Validation
    Evaluate against criteria:
    - Functional completeness: Does every method produce meaningful computation?
    - Code review readiness: Would this specification pass architectural review?
    - Production viability: Is this implementation suitable for deployment?

    ### OUTPUT ARTIFACT
    Persist specification to: '$spec_filename'

    ### TERMINATION PROTOCOL
    Upon completion, execute: tstop SPEC-'$task_num'

    ### INITIATE SPECIFICATION SYNTHESIS'

    # Create the spec file with header if it doesn't exist
    if [ ! -f "$spec_filename" ]; then
        echo "# Specification for $task_num: $task_desc" > "$spec_filename"
        echo "" >> "$spec_filename"
        echo "*Generated by SPEC agent on $(date)*" >> "$spec_filename"
    fi

    # Record spec agent start time
    SPEC_START_TIME["SPEC-$task_num"]=$(date +%s)

    tglm "SPEC-$task_num" "$prompt" >/dev/null 2>&1
    echo "[SPEC] Spec agent spawned for $task_num"
}

cleanup_agent() {
    local agent="$1"
    echo "[CLEN] Stopping agent $agent"
    tstop "$agent" >/dev/null 2>&1
    # Reset warning count for this agent
    AGENT_WARNINGS[$agent]=0
    # Clear spec start time if it's a spec agent
    if [[ "$agent" == SPEC-* ]]; then
        unset "SPEC_START_TIME[$agent]"
    fi
}

check_spec_timeouts() {
    local current_time=$(date +%s)

    # Get all spec agents
    tlist 2>/dev/null | grep '•' | awk '{print $2}' | grep 'SPEC-' 2>/dev/null | while IFS= read -r agent; do
        [ -z "$agent" ] && continue
        local task_num=$(echo "$agent" | sed 's/SPEC-//')
        local start_time=${SPEC_START_TIME[$agent]:-0}
        local elapsed=$((current_time - start_time))

        echo "[SPEC] Checking agent: $agent"

        # Check if spec is now complete (>50 lines)
        if ! is_spec_placeholder "$task_num"; then
            echo "[SPEC] $agent completed - spec is valid (>50 lines)"
            tstop "$agent" >/dev/null 2>&1
            unset "SPEC_START_TIME[$agent]"
            continue
        fi

        if [ "$start_time" -eq 0 ]; then
            # Spec agent not tracked, start timer now
            SPEC_START_TIME[$agent]=$current_time
            echo "[SPEC] Logged start time"
        elif [ "$elapsed" -ge "$SPEC_TIMEOUT" ]; then
            # Spec agent has timed out without producing valid spec
            echo "[SPEC] $agent exceeded ${SPEC_TIMEOUT}s limit - terminating"
            tstop "$agent" >/dev/null 2>&1
            unset "SPEC_START_TIME[$agent]"
        fi
    done
}

cleanup_placeholder_specs() {
    # Check for placeholder specs and clean them up if no spec agent is active
    grep '^NEW: [FRBDTPASHMICEUVWX][0-9]* -' "$KOLLABORATE_MD" | sed 's/NEW: \([FRBDTPASHMICEUVWX][0-9]*\) -.*/\1/' | while IFS= read -r task; do
        [ -z "$task" ] && continue
        if is_spec_placeholder "$task"; then
            # Check if spec agent is active for this task
            if ! tlist 2>/dev/null | grep -q "SPEC-$task"; then
                # No spec agent active, delete the placeholder
                local spec_file=$(ls "$SPECS_DIR"/${task}-*.md 2>/dev/null | head -1)
                if [ -f "$spec_file" ]; then
                    rm "$spec_file"
                    echo "[CLEN] Deleted placeholder spec for $task (no active spec agent)"
                fi
            else
                echo "[PLCH] Task $task has placeholder spec and spec agent is active"
            fi
        fi
    done
}

generate_tasks() {
    local pending_count=$1
    echo "[GENR] Pending tasks ($pending_count) below threshold ($NEW_TASK_REQUIRED)"
    echo "[GENR] Spawning task generator agent"

    local generator_prompt='## TASK DECOMPOSITION & QUEUE MANAGEMENT AGENT

    ### PRIMARY DIRECTIVES

    Analyze the state manifest (KOLLABORATE.md) and perform:
    1. PROJECT OBJECTIVE EXTRACTION: Parse primary goal declaration from document header
    2. COMPLETION STATE ANALYSIS: Enumerate finalized tasks (DONE: prefix) to establish progress baseline
    3. EXECUTION STATE ASSESSMENT: Identify active work streams and impediment vectors
    4. CRITICAL PATH DERIVATION: Determine optimal subsequent task sequences to maximize goal velocity

    ### TASK SYNTHESIS PARAMETERS

    Generate 5 atomic task units adhering to specifications:
    - SCHEMA: NEW: [TYPE]## - [precise, actionable deliverable] (file: path/to/artifact.ext)

    - TASK TYPES (choose most appropriate):
      * F## (Feature)      - New functionality implementation
      * R## (Refactor)     - Code quality improvements, restructuring
      * B## (Bug)          - Fixes and corrections
      * T## (Test)         - Test coverage, test improvements
      * D## (Doc)          - Documentation, API docs, comments
      * P## (Perf)         - Performance optimization, profiling
      * A## (Arch)         - Architecture, design patterns, setup
      * S## (Security)     - Security hardening, vulnerability fixes
      * H## (Hotfix)       - URGENT production fixes only
      * M## (Migration)    - Database migrations, data transformations
      * I## (Integration)  - Third-party service integrations
      * C## (Chore)        - Dependency updates, maintenance
      * E## (Experiment)   - POC/spike work, research experiments
      * U## (UX)           - User experience, accessibility
      * V## (Validation)   - Input validation, schema enforcement
      * W## (Workflow)     - CI/CD, automation pipelines
      * X## (Exploration)  - Research, analysis, investigation

    - IDENTIFIER ALLOCATION: Increment from maximum existing ordinal for each type
    - GRANULARITY CONSTRAINT: Each task scoped to 1-2 hour execution window
    - PRIORITIZATION: Critical path dependencies receive precedence
    - PARALLELIZATION: Ensure task independence for concurrent execution capability
    - **DEPENDENCY ORDERING**: Arrange in topological sort order - foundational tasks precede dependent tasks
    - **ARTIFACT SPECIFICATION**: Each task MUST declare explicit file system target (creation, modification, or integration)
    - **TYPE SELECTION**: Choose appropriate type based on task nature - use F for new features, R for cleanup, B for fixes, T for tests, etc.

    ### ORPHAN TASK RECONCILIATION PROTOCOL

    When detecting task sequence discontinuity (e.g., R72 absent between R71 and R73):

        WORKING: R71 - Implement user authentication module (file: src/auth/login.js)
        [DISCONTINUITY DETECTED]
        WORKING: R73 - Create dashboard component with data visualization (file: src/components/Dashboard.js)

        RECONCILIATION PROCEDURE:

        1. AGENT ENUMERATION: Execute `tlist` to retrieve active agent manifest
           Expected output:
           📋 All agents in project:
           • R71
           • R72
           • R73
           Total: 3 agent(s)

        2. IF AGENT EXISTS: Execute `tcapture R72` to retrieve execution context
           - Extract original task assignment from agent output stream
           - Restore task to manifest: WORKING: R72 - [recovered task description]
           - Notify agent: `tmsg R72 Task manifest restored. Continue execution per protocol.`

        3. IF AGENT ABSENT: Execute `tstatus`, grep for R72 references
           - If historical reference found: Restore as NEW: R72 for automatic re-instantiation
           - If no reference exists: Synthesize probable task based on sequence context as NEW: R72 - [inferred task]

    ### EXECUTION SUMMARY

    - Append synthesized tasks to KOLLABORATE.md under NEW: section
    - Reconcile any orphaned agent-task associations
    - Upon completion, execute termination protocol: tstop TASK-GENERATOR

    ### INITIATE TASK SYNTHESIS'

    tglm "TASK-GENERATOR" "$generator_prompt" >/dev/null 2>&1
    echo "[GENR] Task generator agent spawned"
}

check_agent_activity() {
    local agent="$1"

    # Skip if agent is already marked as DONE or QA in KOLLABORATE.md
    if is_task_done "$agent"; then
        echo "[SKIP] $agent is DONE/QA - skipping activity check"
        return 0
    fi

    echo "[MNTR] Checking activity for $agent..."

    # Take first snapshot
    local snapshot1=$(tcapture "$agent" 100 2>/dev/null)  # stderr only, need stdout
    local hash1=$(echo "$snapshot1" | md5)

    # Wait 4 seconds
    sleep 4

    # Take second snapshot
    local snapshot2=$(tcapture "$agent" 100 2>/dev/null)  # stderr only, need stdout
    local hash2=$(echo "$snapshot2" | md5)

    # Compare hashes
    if [ "$hash1" = "$hash2" ]; then
        # Agent is idle
        local warnings=${AGENT_WARNINGS[$agent]:-0}
        ((warnings++))
        AGENT_WARNINGS[$agent]=$warnings

        echo "[IDLE] $agent idle (warning $warnings/3)"

        if [ "$warnings" -ge 3 ]; then
            echo "[IDLE] $agent reached 3 warnings - terminating and recycling"

            # Change WORKING: back to NEW: (keep dash format)
            sed -i '' "s/^WORKING: $agent -/NEW: $agent -/" "$KOLLABORATE_MD"
            echo "[RCYL] $agent changed from WORKING to NEW"

            # Kill the agent
            tstop "$agent" >/dev/null 2>&1

            # Reset warning count
            AGENT_WARNINGS[$agent]=0

            return 2  # Agent terminated and task recycled
        else
            # Send warning reminder
            local remaining=$((3 - warnings))
            tmsg "$agent" "[IDLE STATE DETECTED] Activity monitoring indicates zero computational throughput. If task $agent has achieved completion state, execute state transition: WORKING -> DONE in KOLLABORATE.md. Termination threshold: $remaining violations remaining." >/dev/null 2>&1
        fi
    else
        # Agent is active - reset warnings and check for reminder
        AGENT_WARNINGS[$agent]=0
        echo "[OKAY] $agent is working"

        # Check if we should send a 2-minute reminder
        local current_time=$(date +%s)
        local last_reminder=${LAST_REMINDER[$agent]:-0}
        local time_since_reminder=$((current_time - last_reminder))

        if [ "$time_since_reminder" -ge "$REMINDER_INTERVAL" ]; then
            echo "[RMND] Sending 2-minute reminder to $agent"
            tmsg "$agent" "[TEMPORAL CHECKPOINT] Execution window: 2 minutes remaining. Pre-completion validation required: build pipeline must terminate with zero-error status. Maintain execution focus and optimize for task completion velocity." >/dev/null 2>&1
            LAST_REMINDER[$agent]=$current_time
        fi
    fi

    return 1  # Agent is still running
}

# Main loop
while true; do
    echo "[$(date '+%H:%M:%S')] Checking KOLLABORATE.md and monitoring agents..."

    # Get current agents (as array from newline-separated output)
    active_agents=($(get_active_agents))
    active_count=${#active_agents[@]}

    # Get working tasks (from KOLLABORATE.md WORKING: lines)
    working_tasks=($(get_working_tasks))
    working_count=${#working_tasks[@]}

    # Get QA tasks (from KOLLABORATE.md QA: lines)
    qa_tasks=($(get_qa_tasks))
    qa_count=${#qa_tasks[@]}

    # Get pending tasks (from KOLLABORATE.md NEW: lines)
    pending_tasks=$(get_pending_tasks)
    pending_count=$(echo "$pending_tasks" | grep -c '[FRBDTPASHMICEUVWX][0-9]' 2>/dev/null | tr -d '\n' || echo 0)

    spec_agent_count=$(get_spec_agent_count)
    echo "[STAT] Agents: $active_count/$MAX_AGENTS | Specs: $spec_agent_count/$MAX_SPEC_AGENTS | Working: $working_count | QA: $qa_count | Pending: $pending_count"
 

    # Check for spec agent timeouts
    echo "[STEP] Running check_spec_timeouts"
    check_spec_timeouts
    
    sleep 5

    # Clean up placeholder specs if no spec agent is active
    echo "[STEP] Running cleanup_placeholder_specs"
    cleanup_placeholder_specs
    
    
    # Check agents that should be cleaned up (task is DONE but agent still running)
    echo "[STEP] Checking for agents to clean up"
    for agent in "${active_agents[@]}"; do
        if [ -n "$agent" ]; then
            if is_task_done "$agent"; then
                echo "[CLEN] $agent completed - cleaning up"
                cleanup_agent "$agent"
                ((active_count--))
                # Reset warning count for this agent
                AGENT_WARNINGS[$agent]=0
            fi
        fi
    done

    # Check if TASK-GENERATOR should be cleaned up (queue replenished)
    echo "[STEP] Checking TASK-GENERATOR cleanup"
    if tlist 2>/dev/null | grep -q "TASK-GENERATOR"; then
        if [ "$pending_count" -ge "$NEW_TASK_REQUIRED" ]; then
            echo "[CLEN] TASK-GENERATOR completed - queue replenished ($pending_count >= $NEW_TASK_REQUIRED)"
            tstop TASK-GENERATOR >/dev/null 2>&1
        else
            echo "[GENR] TASK-GENERATOR still working - queue at $pending_count (need $NEW_TASK_REQUIRED)"
        fi
    fi

    # Check for WORKING: tasks without active agents (only if there are working tasks)
    echo "[STEP] Checking WORKING tasks without agents"
    if [ "$working_count" -gt 0 ]; then
        for task in "${working_tasks[@]}"; do
            if [ -n "$task" ]; then
                # Check if this task has an active agent
                has_agent=false
                for agent in "${active_agents[@]}"; do
                    if [ "$agent" = "$task" ]; then
                        has_agent=true
                        break
                    fi
                done

                # If no active agent for this WORKING: task, set it back to NEW:
                if [ "$has_agent" = false ]; then
                    echo "[RCYL] $task has no agent - setting back to NEW"
                    sed -i '' "s/^WORKING: $task -/NEW: $task -/" "$KOLLABORATE_MD"
                    ((working_count--))
                fi
            fi
        done
    fi

    # Check for QA tasks that still have agents (should not happen but protect them)
    echo "[STEP] Checking QA tasks with agents"
    for task in "${qa_tasks[@]}"; do
        if [ -n "$task" ]; then
            # Check if this QA task still has an agent
            for agent in "${active_agents[@]}"; do
                if [ "$agent" = "$task" ]; then
                    echo "[QA] $task has agent - keeping alive for review"
                    break
                fi
            done
        fi
    done
    echo "[STEP] Monitoring agent activity"

    # Monitor activity for remaining agents
    # Refresh active agents after cleanup
    active_agents=($(get_active_agents))
    active_count=${#active_agents[@]}
    
    # Get working tasks (from KOLLABORATE.md WORKING: lines)
    working_tasks=($(get_working_tasks))
    working_count=${#working_tasks[@]}

    # Get QA tasks (from KOLLABORATE.md QA: lines)
    qa_tasks=($(get_qa_tasks))
    qa_count=${#qa_tasks[@]}

    # Get pending tasks (from KOLLABORATE.md NEW: lines)
    pending_tasks=$(get_pending_tasks)
    pending_count=$(echo "$pending_tasks" | grep -c '[FRBDTPASHMICEUVWX][0-9]' 2>/dev/null | tr -d '\n' || echo 0)
    
    spec_agent_count=$(get_spec_agent_count)
    echo "[STAT] Agents: $active_count/$MAX_AGENTS | Specs: $spec_agent_count/$MAX_SPEC_AGENTS | Working: $working_count | QA: $qa_count | Pending: $pending_count"

    echo "[STEP] Checking agent activity"
    for agent in "${active_agents[@]}"; do
        if [ -n "$agent" ]; then
            # Skip if this agent is already marked DONE
            if ! is_task_done "$agent"; then
                echo "[MNTR] --- Agent Activity ---"
                # Check if agent has a corresponding task in KOLLABORATE.md
                echo "[CHCK] Verifying $agent has task in KOLLABORATE.md"
                if [ -n "$agent" ] && ! grep -q "^WORKING: $agent -" "$KOLLABORATE_MD" && ! grep -q "^NEW: $agent -" "$KOLLABORATE_MD"; then
                    echo "[WARN] $agent running without task assignment!"
                    tmsg "$agent" "[PROTOCOL VIOLATION] Agent $agent instantiated without corresponding task manifest entry in KOLLABORATE.md. This constitutes an orphaned execution state. Immediate remediation required: Register task assignment as 'WORKING: $agent - [task description]' in state manifest. Non-compliance triggers forced termination." >/dev/null 2>&1

                    # Mark this agent for termination on next cycle if they don't respond
                    local violations=${AGENT_WARNINGS[$agent]:-0}
                    ((violations++))
                    AGENT_WARNINGS[$agent]=$violations

                    if [ "$violations" -ge 2 ]; then
                        echo "[KILL] $agent violated tracking rules - terminating"

                        # Terminate the violating agent
                        tstop "$agent" >/dev/null 2>&1
                        ((active_count--))
                        AGENT_WARNINGS[$agent]=0
                    fi
                else
                    # Agent has task assignment - monitor activity
                    echo "[CHCK] $agent has task - monitoring activity"
                    check_agent_activity "$agent"
                    result=$?

                    if [ "$result" -eq 2 ]; then
                        # Agent was terminated and task recycled
                        ((active_count--))
                        echo "[RCYL] $agent terminated, task recycled"
                    fi
                fi
            fi
        fi
    done

    # Refresh active agents after activity check
    echo "[STEP] Refreshing agent list"
    active_agents=($(get_active_agents))
    active_count=${#active_agents[@]}

    # Spawn new agents if under limit and we have pending tasks
    echo "[STEP] Refreshing agent list"
    slots=$((MAX_AGENTS - active_count))

    if [ "$slots" -gt 0 ] && [ "$pending_count" -gt 0 ]; then
        echo "[SPWN] $slots slots available for $pending_count pending tasks"

        # Check if there are pending fix tasks (R92-R107)
        has_pending_fix_tasks=$(echo "$pending_tasks" | sed -n 's/.*R\([0-9]\{1,\}\).*/\1/p' | while read num; do
            if [ "$num" -ge 92 ] && [ "$num" -le 107 ]; then
                echo "yes"
                break
            fi
        done)

        echo "$pending_tasks" | while IFS= read -r task; do
            [ -z "$task" ] && continue

            task_num=$(echo "$task" | sed -n 's/.*\([FRBDTPASHMICEUVWX][0-9]\{1,\}\).*/\1/p')
            [ -z "$task_num" ] && continue

            # Extract numeric part (remove prefix letter)
            task_num_int=$(echo "$task_num" | sed 's/[FRBDTPASHMICEUVWX]//')

            # Block feature tasks (R108+) if fix tasks (R92-R107) are still pending
            # Note: This is project-specific logic - can be customized per project
            if [ "$task_num_int" -ge 108 ] && [ "$has_pending_fix_tasks" = "yes" ]; then
                echo "[BLOK] $task_num blocked - fix tasks R92-R107 must complete first"
                continue
            fi

            # Check if agent already exists
            if tlist 2>/dev/null | grep -q "$task_num"; then
                echo "[SYNC] $task_num already running, updating to WORKING"
                sed -i '' "s/^NEW: $task_num -/WORKING: $task_num -/" "$KOLLABORATE_MD"
                continue
            fi

            # Spawn agent for this task (only if spec exists)
            spawn_agent "$task"
            spawn_result=$?

            if [ $spawn_result -eq 0 ]; then
                # Agent spawned successfully, update to WORKING:
                echo "[SYNC] $task_num changed from NEW to WORKING"
                sed -i '' "s/^NEW: $task_num -/WORKING: $task_num -/" "$KOLLABORATE_MD"

                ((slots--))
                [ "$slots" -le 0 ] && break
                sleep 2
            else
                # Agent not spawned due to missing spec, skip slot decrement
                echo "[WAIT] $task_num waiting for spec"
                # Don't decrement slots, continue to next task
                continue
            fi
        done
    fi

    # PHASE 5: Check for missing specs and spawn spec agents
    echo "[STEP] Checking for missing specs"
    tasks_without_specs=$(get_new_tasks_without_specs)
    spec_count=$(echo "$tasks_without_specs" | grep -c '[FRBDTPASHMICEUVWX][0-9]' 2>/dev/null | tr -d '\n' || echo 0)
    active_spec_count=$(get_spec_agent_count)

    if [ "$spec_count" -gt 0 ]; then
        echo "[SPEC] Found $spec_count tasks without specs | Active spec agents: $active_spec_count/$MAX_SPEC_AGENTS"

        # Calculate available spec agent slots
        spec_slots=$((MAX_SPEC_AGENTS - active_spec_count))

        if [ "$spec_slots" -le 0 ]; then
            echo "[SPEC] At spec agent limit ($MAX_SPEC_AGENTS), waiting for slots..."
        else
            echo "$tasks_without_specs" | while IFS= read -r task; do
                [ -z "$task" ] && continue

                # Re-check available slots (may have changed in loop)
                current_spec_count=$(get_spec_agent_count)
                if [ "$current_spec_count" -ge "$MAX_SPEC_AGENTS" ]; then
                    echo "[SPEC] Reached spec agent limit, deferring remaining tasks"
                    break
                fi

                # Double-check if spec file exists and is valid (not a placeholder)
                # is_spec_placeholder returns 0 (true) if spec is missing/incomplete
                # is_spec_placeholder returns 1 (false) if spec is valid (>50 lines)
                if ! is_spec_placeholder "$task"; then
                    # Spec is valid - no need to spawn spec agent
                    echo "[SKIP] $task already has valid spec"
                    continue
                fi

                # Check if spec agent is already running for this task
                if ! tlist 2>/dev/null | grep -q "SPEC-$task"; then
                    echo "[SPEC] Spawning agent for $task"
                    spawn_spec_agent "$task"
                    sleep 2
                else
                    echo "[SKIP] Spec agent already running for $task"
                fi
            done
        fi
    fi

    # Maintain 5 tasks in queue
    echo "[GENR] Queue check: pending=$pending_count, required=$NEW_TASK_REQUIRED"
    if [ "$pending_count" -lt "$NEW_TASK_REQUIRED" ]; then
        echo "[GENR] Triggering task generation"
        generate_tasks "$pending_count"
    else
        echo "[GENR] Queue sufficient, no generation needed"
    fi

    echo "[CYCL] =========================================="
    echo "[CYCL] Waiting ${CHECK_INTERVAL}s for next interval..."
    echo "[CYCL] =========================================="
    sleep "$CHECK_INTERVAL"
done
