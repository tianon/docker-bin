#!/bin/bash
set -eo pipefail

jqExpression='.results[].name'

self="$(basename "$0")"
usage() {
	cat <<-EOUSAGE

		usage: $self [options] repo

		   ie: $self library/docker

		       $self --jq '.results[]' tianon/syncthing

		       $self --jq '.results[] | [ .name, (.full_size | tostring), .last_updated ] | join("\\t")' tianon/syncthing | sort -V | column -ts \$'\\t'

		options:
		  --jq='$jqExpression'
		    modify the "jq" expression used to extract results

	EOUSAGE
}

opts="$(getopt -o 'h?' --long 'help,jq:' -- "$@" || { usage >&2 && false; })"
eval set -- "$opts"

while true; do
	flag="$1"
	shift
	case "$flag" in
		--jq) jqExpression="$1"; shift ;;
		--help|-h|'-?') usage; exit 0 ;;
		--) break ;;
		*)
			{
				echo "error: unknown flag: $flag"
				usage
			} >&2
			exit 1
			;;
	esac
done

if [ "$#" -ne 1 ]; then
	echo >&2 'error: expected exactly one "repo" argument'
	usage >&2
	exit 1
fi

_all() {
	local repo="$1"; shift

	local nextPage="https://hub.docker.com/v2/repositories/${repo}/tags/?page_size=100"
	while true; do
		local page="$(curl -fsSL "$nextPage")"

		[ "$(echo "$page" | jq --raw-output '.results | length')" -gt 0 ] || break
		echo "$page" | jq --raw-output "$jqExpression"

		nextPage="$(echo "$page" | jq --raw-output '.next')"
		[ "$nextPage" != 'null' ] || break
	done
}

_all "$@"
