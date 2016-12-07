#!/bin/bash
set -e

if [ $# -eq 0 ]; then
	echo >&2 "usage: $0 repo [repo ...]"
	echo >&2 "   ie: $0 tianon/centos"
	echo >&2 "       $0 tianon/centos tianon/debian"
	exit 1
fi

awkward=
for repo in "$@"; do
	if [ "$repo" = '<none>' ]; then
		awkward+=' $1 == "<none>" && $2 == "<none>" { print $4 }'
	else
		awkward+=' $1 == "'"$repo"'" { if ($2 == "<none>") { print $1 "@" $3 } else { print $1 ":" $2 } }'
	fi
done
awkward="${awkward# }"

set -x
docker images --digests | awk -F '  +' "$awkward" | xargs --no-run-if-empty docker rmi
