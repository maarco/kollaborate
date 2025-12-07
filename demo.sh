#!/bin/sh

# Terminal DOM Control Demo - Matches terminal_frames.md specification
# Creates a bordered terminal interface with sections

# ANSI escape codes
CURSOR_SAVE='\033[s'
CURSOR_RESTORE='\033[u'
CURSOR_HOME='\033[H'
CLEAR_LINE='\033[2K'
CLEAR_SCREEN='\033[2J'
HIDE_CURSOR='\033[?25l'
SHOW_CURSOR='\033[?25h'

# Box drawing characters
BOX_H='─'
BOX_V='│'
BOX_TL='┌'
BOX_TR='┐'
BOX_BL='└'
BOX_BR='┘'
BOX_LM='├'
BOX_RM='┤'
BOX_TM='┬'
BOX_BM='┴'
BOX_CROSS='┼'

# Terminal dimensions
TERM_WIDTH=80
TERM_HEIGHT=25
MAIN_HEIGHT=13
INPUT_HEIGHT=2
MODEL_HEIGHT=2
OUTPUT_HEIGHT=7

# Position calculations
MAIN_TOP=1
INPUT_TOP=$((MAIN_TOP + MAIN_HEIGHT))
MODEL_TOP=$((INPUT_TOP + INPUT_HEIGHT))
OUTPUT_TOP=$((MODEL_TOP + MODEL_HEIGHT))

# Utility functions
print_escape() {
    printf '%b' "$1"
}

goto_pos() {
    print_escape "\033[$1;$2H"
}

save_cursor() {
    print_escape "${CURSOR_SAVE}"
}

restore_cursor() {
    print_escape "${CURSOR_RESTORE}"
}

# Draw box functions
draw_horizontal_line() {
    local line=$1
    local start_col=$2
    local end_col=$3
    goto_pos $line $start_col
    local i=$start_col
    while [ $i -lt $end_col ]; do
        printf '%c' "$BOX_H"
        i=$((i + 1))
    done
}

draw_box() {
    local top=$1
    local left=$2
    local width=$3
    local height=$4

    # Top border
    goto_pos $top $left
    printf '%c' "$BOX_TL"
    draw_horizontal_line $top $((left + 1)) $((left + width - 1))
    printf '%c' "$BOX_TR"

    # Vertical borders
    local i=1
    while [ $i -lt $((height - 1)) ]; do
        goto_pos $((top + i)) $left
        printf '%c' "$BOX_V"
        goto_pos $((top + i)) $((left + width - 1))
        printf '%c' "$BOX_V"
        i=$((i + 1))
    done

    # Bottom border
    goto_pos $((top + height - 1)) $left
    printf '%c' "$BOX_BL"
    draw_horizontal_line $((top + height - 1)) $((left + 1)) $((left + width - 1))
    printf '%c' "$BOX_BR"
}

draw_separator() {
    local line=$1
    local left=$2
    local width=$3

    goto_pos $line $left
    printf '%c' "$BOX_LM"
    draw_horizontal_line $line $((left + 1)) $((left + width - 1))
    printf '%c' "$BOX_RM"
}

clear_box_area() {
    local top=$1
    local left=$2
    local width=$3
    local height=$4

    local i=0
    while [ $i -lt $((height - 2)) ]; do
        goto_pos $((top + i + 1)) $((left + 1))
        printf '%*s' $((width - 2)) ''
        i=$((i + 1))
    done
}

# Content update functions
print_input_line() {
    local line_num=$1
    local content="$2"
    local pos=$((INPUT_TOP + 1 + line_num))

    save_cursor
    goto_pos $pos 2  # Inside box, after left border and space
    printf '%-76s' "$content"
    restore_cursor
}

print_model_info() {
    local model="$1"
    save_cursor
    goto_pos $((MODEL_TOP + 1)) 2
    printf '%-76s' "$model"
    restore_cursor
}

print_output_line() {
    local line_num=$1
    local content="$2"
    local pos=$((OUTPUT_TOP + 1 + line_num))

    if [ $pos -lt $((OUTPUT_TOP + OUTPUT_HEIGHT - 1)) ]; then
        save_cursor
        goto_pos $pos 2
        printf '%-76s' "$content"
        restore_cursor
    fi
}

# Initialize the interface
init_terminal() {
    print_escape "${CLEAR_SCREEN}${HIDE_CURSOR}"

    # Draw main sections
    draw_box $MAIN_TOP 1 $TERM_WIDTH $MAIN_HEIGHT

    # Draw separators
    draw_separator $INPUT_TOP 1 $TERM_WIDTH
    draw_separator $MODEL_TOP 1 $TERM_WIDTH

    # Clear all areas
    clear_box_area $MAIN_TOP 1 $TERM_WIDTH $MAIN_HEIGHT
    clear_box_area $INPUT_TOP 1 $TERM_WIDTH $INPUT_HEIGHT
    clear_box_area $MODEL_TOP 1 $TERM_WIDTH $MODEL_HEIGHT
    clear_box_area $OUTPUT_TOP 1 $TERM_WIDTH $OUTPUT_HEIGHT

    # Initial content
    print_input_line 0 "> Hello"
    print_model_info "Model Opus 6.7"

    local i=0
    while [ $i -lt 7 ]; do
        print_output_line $i "line $((i + 1))"
        i=$((i + 1))
    done
}

# Demo animation
run_demo() {
    init_terminal

    sleep 1

    # Frame 2: print_out("Welcome to System")
    print_input_line 0 "Welcome to System"

    sleep 1

    # Frame 3: print_input_line_1("Status: Ready")
    print_input_line 1 "Status: Ready"

    sleep 1

    # Interactive demo
    local step=1
    while [ $step -le 10 ]; do
        print_output_line 0 "Processing step $step..."
        print_input_line 1 "> Command: run_task_$step"
        print_model_info "Model Opus 6.7 - Processing"

        sleep 0.5

        case $step in
            1) print_output_line 1 "Initializing connection..." ;;
            2) print_output_line 2 "Authenticating user..." ;;
            3) print_output_line 3 "Loading data..." ;;
            4) print_output_line 4 "Processing..." ;;
            5) print_output_line 5 "Analyzing results..." ;;
            6) print_output_line 6 "Generating report..." ;;
        esac

        sleep 0.5
        step=$((step + 1))
    done

    # Final state
    print_input_line 0 "> Task completed successfully"
    print_input_line 1 "> Ready for next command"
    print_model_info "Model Opus 6.7"
    print_output_line 0 "All tasks completed"
    print_output_line 1 "Results saved"
    print_output_line 2 "System ready"
}

# Cleanup
cleanup() {
    print_escape "${SHOW_CURSOR}"
    print_escape "${CLEAR_SCREEN}"
    goto_pos 1 1
    printf "Demo completed.\n"
}

# Trap cleanup
trap cleanup EXIT INT TERM

# Run the demo
run_demo