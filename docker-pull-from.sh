#!/bin/bash
set -e

if [ "$#" -le 0 ]; then
	set -- Dockerfile
fi

dockerfiles=()
for arg; do
	if [ -d "$arg" ]; then
		dockerfiles+=( "$arg/Dockerfile" )
	else
		dockerfiles+=( "$arg" )
	fi
done

awk 'toupper($1) == "FROM" { print $2 }' "${dockerfiles[@]}" | sort -u | xargs -trn1 docker pull
