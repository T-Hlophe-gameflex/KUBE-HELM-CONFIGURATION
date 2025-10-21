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

# NOTE: Keep entrypoint quiet to avoid emitting non-JSON lines that can break AWX
exec "$@"
