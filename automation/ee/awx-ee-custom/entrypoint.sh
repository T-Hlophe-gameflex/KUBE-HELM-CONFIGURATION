#!/usr/bin/env bash
# Ensure HOME and Ansible temp dirs point to runner (writable)
export HOME=/runner
export ANSIBLE_LOCAL_TEMP=/runner/.ansible_local_tmp
export ANSIBLE_REMOTE_TEMP=/runner/.ansible_remote_tmp

# Silent sanitizer: ensure /runner/inventory/hosts doesn't contain a concatenated
# coding header + print(...) on the same line which can break inventory parsing.
# This sed invocation is idempotent and silent; it only modifies the file in-place
# if the problematic pattern is present.
if [ -f "$HOME/inventory/hosts" ]; then

	# Snapshot the raw inventory to /tmp for debugging/forensics. This copies the
	# file immediately before any sanitizer or Ansible parser runs so we can
	# inspect the exact bytes AWX provided when parsing fails.
	TIMESTAMP=$(date +%s)
	SNAPSHOT_DEST="/tmp/awx_inventory_snapshot_${TIMESTAMP}.json"
	cp "$HOME/inventory/hosts" "$SNAPSHOT_DEST" 2>/dev/null || true
	# keep a stable symlink to the latest snapshot for easy retrieval
	ln -sf "$SNAPSHOT_DEST" /tmp/awx_inventory_snapshot_latest.json 2>/dev/null || true

	# Robust sanitizer: if the file contains a print('...') or print("...") on the
	# same line as the coding header or shebang, extract the JSON payload inside
	# the print(...) call and overwrite the file with that JSON plus a newline.
	# This is idempotent and will only modify the file when the pattern is found.
	set -o pipefail
	PAYLOAD=$(sed -n '1,10p' "$HOME/inventory/hosts" | tr -d '\\r' | tr -d '\\n' | sed -n "s/.*print(\(['\"]\)\(.*\)\1).*/\2/p") || true
	if [ -n "$PAYLOAD" ]; then
		# Write only the extracted JSON payload and ensure a trailing newline
		printf '%s\n' "$PAYLOAD" > "$HOME/inventory/hosts" || true
	else
		# Fallback: try inserting newline between coding header and print as before
		sed -i -E "1s/(# -\*- coding: utf-8 -\*-)([[:space:]]*print\()/\1\n\2/; 1s/(# -\*- coding: utf-8 -\*-)(print\()/\1\n\2/; 1s/(# -\*- coding: utf-8 -\*-)(\\'\\{)/\1\n\2/" "$HOME/inventory/hosts" || true
		sed -i -E "1,2 s/^(#!.*)(# -\*- coding: utf-8 -\*-)([[:space:]]*print\()/\1\n\2\n\3/" "$HOME/inventory/hosts" || true
	fi
	set +o pipefail
fi

# Background watcher: if the inventory file is created later (by AWX worker at
# runtime), run a background loop that will snapshot it to /tmp/awx_inventory_snapshot_latest.json
# as soon as it appears. This allows capturing the exact runtime file even when
# the entrypoint executed earlier.
(
	WATCHER_PIDFILE=/tmp/awx_inventory_watcher.pid
	( while true; do
			# check runner path
			if [ -f "$HOME/inventory/hosts" ]; then
				TIMESTAMP2=$(date +%s)
				SNAP2="/tmp/awx_inventory_snapshot_${TIMESTAMP2}.json"
				cp "$HOME/inventory/hosts" "$SNAP2" 2>/dev/null || true
				ln -sf "$SNAP2" /tmp/awx_inventory_snapshot_latest.json 2>/dev/null || true
				break
			fi
			# also check AWX private_data_dir locations under /tmp (e.g., /tmp/awx_*)
			for d in /tmp/awx_*; do
				if [ -d "$d" ] && [ -f "$d/inventory/hosts" ]; then
					TIMESTAMP2=$(date +%s)
					SNAP2="/tmp/awx_inventory_snapshot_${TIMESTAMP2}.json"
					cp "$d/inventory/hosts" "$SNAP2" 2>/dev/null || true
					ln -sf "$SNAP2" /tmp/awx_inventory_snapshot_latest.json 2>/dev/null || true
					break 2
				fi
			done
			sleep 0.25
		done ) &
	echo $! > "$WATCHER_PIDFILE" 2>/dev/null || true
)

# NOTE: Keep entrypoint quiet to avoid emitting non-JSON lines that can break AWX
exec "$@"
