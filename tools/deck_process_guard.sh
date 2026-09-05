#!/usr/bin/env bash
# Identify, stop, and verify a single Devkit title by its exact executable path.
# This script runs on the Deck.  It deliberately never uses process names, pkill,
# or SIGKILL: a title that will not stop is a deployment refusal, not a reason to
# risk terminating an unrelated Steam process.
set -u

PROC_ROOT="${PROC_ROOT:-/proc}"
KILL_BIN="${KILL_BIN:-kill}"
SLEEP_BIN="${SLEEP_BIN:-sleep}"
READLINK_BIN="${READLINK_BIN:-readlink}"
PROC_LINK_TEST_BIN="${PROC_LINK_TEST_BIN:-}"

usage() {
	cat >&2 <<'EOF'
usage: deck_process_guard.sh list <target-exe>
       deck_process_guard.sh stop <target-exe> [attempts] [interval]
       deck_process_guard.sh verify-fresh <target-exe> <prior-pid-csv>
EOF
}

validate_target() {
	local target=$1
	case "$target" in
		/home/deck/devkit-game/*/*) ;;
		*) echo "refusing unsafe target executable: $target" >&2; return 2 ;;
	esac
	if [ "$PROC_ROOT" = "/proc" ] && [ "${target#/home/deck/devkit-game/}" = "$target" ]; then
		echo "refusing target outside /home/deck/devkit-game/: $target" >&2
		return 2
	fi
}

raw_link() {
	"$READLINK_BIN" "$1/exe" 2>/dev/null || true
}

is_exe_link() {
	if [ -n "$PROC_LINK_TEST_BIN" ]; then
		"$PROC_LINK_TEST_BIN" "$1/exe"
	else
		[ -L "$1/exe" ]
	fi
}

list_exact() {
	local target=$1 proc actual
	for proc in "$PROC_ROOT"/[0-9]*; do
		is_exe_link "$proc" || continue
		actual="$(raw_link "$proc")"
		actual="${actual% (deleted)}"
		[ "$actual" = "$target" ] || continue
		printf '%s\n' "${proc##*/}"
	done
}

csv_contains() {
	local csv=$1 needle=$2 item
	[ -n "$csv" ] || return 1
	local IFS=,
	read -r -a items <<< "$csv"
	for item in "${items[@]}"; do
		[ "$item" = "$needle" ] && return 0
	done
	return 1
}

stop_exact() {
	local target=$1 attempts=$2 interval=$3 pid survivors attempt
	mapfile -t pids < <(list_exact "$target")
	for pid in "${pids[@]}"; do
		"$KILL_BIN" -TERM "$pid" || {
			echo "refusing deploy: could not TERM $target (pid $pid)" >&2
			return 1
		}
	done
	for ((attempt = 0; attempt < attempts; attempt++)); do
		"$SLEEP_BIN" "$interval"
		survivors="$(list_exact "$target")"
		[ -z "$survivors" ] && return 0
	done
	survivors="$(list_exact "$target" | tr '\n' ' ' | sed 's/ $//')"
	echo "refusing deploy: $target still running after TERM (PID(s): $survivors)" >&2
	return 1
}

verify_fresh() {
	local target=$1 prior=$2 proc pid raw
	local -a live=() deleted=()
	for proc in "$PROC_ROOT"/[0-9]*; do
		is_exe_link "$proc" || continue
		pid="${proc##*/}"
		raw="$(raw_link "$proc")"
		if [ "$raw" = "$target" ]; then
			live+=("$pid")
		elif [ "$raw" = "$target (deleted)" ]; then
			deleted+=("$pid")
		fi
	done
	if [ "${#deleted[@]}" -gt 0 ]; then
		echo "fresh launch verification refused: deleted executable remains for $target (PID(s): ${deleted[*]})" >&2
		return 1
	fi
	if [ "${#live[@]}" -ne 1 ]; then
		echo "fresh launch verification refused: expected one live PID for $target, found ${#live[@]} (${live[*]:-none})" >&2
		return 1
	fi
	if csv_contains "$prior" "${live[0]}"; then
		echo "fresh launch verification refused: PID ${live[0]} was already running for $target" >&2
		return 1
	fi
	printf '%s\n' "${live[0]}"
}

[ $# -ge 1 ] || { usage; exit 2; }
action=$1
shift
case "$action" in
	list)
		[ $# -eq 1 ] || { usage; exit 2; }
		validate_target "$1" || exit $?
		list_exact "$1"
		;;
	stop)
		[ $# -ge 1 ] && [ $# -le 3 ] || { usage; exit 2; }
		target=$1; attempts=${2:-20}; interval=${3:-0.25}
		validate_target "$target" || exit $?
		[[ "$attempts" =~ ^[1-9][0-9]*$ ]] || { echo "attempts must be a positive integer" >&2; exit 2; }
		[[ "$interval" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "interval must be a non-negative seconds value" >&2; exit 2; }
		stop_exact "$target" "$attempts" "$interval"
		;;
	verify-fresh)
		[ $# -eq 2 ] || { usage; exit 2; }
		validate_target "$1" || exit $?
		verify_fresh "$1" "$2"
		;;
	*) usage; exit 2 ;;
esac
