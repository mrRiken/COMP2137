#!/bin/bash

# --- Configuration ---
sides=6        # Default number of sides for the dice
numdice=2      # Number of dice to roll

# --- Function Definitions ---
display_help () {
cat <<EOF
Usage: $(basename "$0") [-h] [-s N] [-n N]

Options:
  -h          Display this help message and exit.
  -s N        Specify the number of sides for the dice.
              N must be a number between 2 and 20. Default is $sides.
  -n N        Specify the number of dice.
              N Default is $numdice.
EOF
}

# --- Argument Parsing ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h)
            display_help
            exit 0
            ;;
        -s)
            shift # Move to the next argument (the value for -s)
            sides="$1"
            
            # Input validation for sides
            if [[ -z "$sides" ]]; then
                echo "Error: -s requires a value." >&2
                display_help
                exit 1
            fi
            
            # Check if sides is a number between 2 and 20
            if ! [[ "$sides" =~ ^[0-9]+$ ]] || (( sides < 2 || sides > 20 )); then
                echo "Error: Number of sides '$sides' is invalid. Must be between 2 and 20." >&2
                display_help
                exit 1
            fi
            ;;
	-n)
		shift
		numdice="$2"
		;;
        *)
            echo "Error: Invalid option '$1' '$2'" >&2
            display_help
            exit 1
            ;;
    esac
    shift # Move to the next argument
done

# --- Dice Rolling Logic ---
total=0
printf "Rolling %d D%d... " "$numdice" "$sides"

for (( numrolled=0; numrolled < numdice ; numrolled++ )); do
    # Generate a random number between 1 and $sides (inclusive)
    roll=$(( RANDOM % sides + 1 ))
    printf "%d " "$roll"
    total=$(( total + roll ))
done

printf "\nTotal rolled: %d\n" "$total
