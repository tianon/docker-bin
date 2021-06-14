#!/usr/bin/env bash
set -Eeuo pipefail

# https://github.com/docker-library/perl-bashbrew/blob/d252f44273d7a8f66a46136d354b7e06da766374/lib/Bashbrew/RemoteImageRef.pm#L9-L40

# https://github.com/docker/distribution/blob/411d6bcfd2580d7ebe6e346359fa16aceec109d5/reference/regexp.go
alphaNumericRegexp='([a-z0-9]+)'
separatorRegexp='([._]|__|[-]*)'
nameComponentRegexp="($alphaNumericRegexp($separatorRegexp$alphaNumericRegexp)*)"
domainComponentRegexp='([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9])'
domainRegexp="($domainComponentRegexp([.]$domainComponentRegexp)*([:][0-9]+)?)"
tagRegexp='([0-9A-Za-z_][0-9A-Za-z_.-]{0,127})'
digestRegexp='([A-Za-z][A-Za-z0-9]*([-_+.][A-Za-z][A-Za-z0-9]*)*[:][0-9A-Fa-f]{32,})'
nameRegexp="($domainRegexp[/])?($nameComponentRegexp([/]$nameComponentRegexp)*)"
referenceRegexp="^$nameRegexp([:]$tagRegexp)?([@]$digestRegexp)?\$"
# https://github.com/docker/distribution/blob/411d6bcfd2580d7ebe6e346359fa16aceec109d5/reference/reference.go#L37
nameTotalLengthMax=255
# https://github.com/opencontainers/go-digest/blob/ac19fd6e7483ff933754af248d80be865e543d22/algorithm.go#L55-L61
allowedDigestsRegexp='^(sha256:[a-f0-9]{64}|sha384:[a-f0-9]{96}|sha512:[a-f0-9]{128})$'

parse() {
	local ref="$1"; shift

	if ! grep -qE "$referenceRegexp" <<<"$ref"; then
		echo >&2 "'$ref' is not a valid Docker image reference (does not match '$referenceRegexp')"
		return 1
	fi

	declare -g name=''
	name="$(grep -oEm1 "^$nameRegexp" <<<"$ref")" || return 1
	ref="${ref#$name}"

	if [ "${#name}" -gt "$nameTotalLengthMax" ]; then
		echo >&2 "'$name' is too long (max $nameTotalLengthMax characters)"
		return 1
	fi

	declare -g host='' repo="$name"
	local hostBit
	if hostBit="$(grep -oEm1 "^$domainRegexp[/]" <<<"$name")"; then
		host="${hostBit%/}"
		repo="${name#$hostBit}"
	fi

	# https://github.com/docker/distribution/blob/411d6bcfd2580d7ebe6e346359fa16aceec109d5/reference/normalize.go#L92-L93
	if [ -n "$host" ] && { [[ "$name" != */* ]] || { [[ "$host" != *.* ]] && [[ "$host" != *:* ]] && [ "$host" != 'localhost' ]; }; }; then
		repo="$host/$repo"
		host=''
	fi

	# https://github.com/docker/distribution/blob/411d6bcfd2580d7ebe6e346359fa16aceec109d5/reference/normalize.go#L98-L100
	if [ -z "$host" ] || [ "$host" = 'index.docker.io' ]; then
		host='docker.io'
	fi
	# https://github.com/docker/distribution/blob/411d6bcfd2580d7ebe6e346359fa16aceec109d5/reference/normalize.go#L101-L103
	if [ "$host" = 'docker.io' ] && [[ "$repo" != */* ]]; then
		repo="library/$repo"
	fi
	name="$host/$repo"

	declare -g tag=''
	local tagBit
	if tagBit="$(grep -oEm1 "^[:]$tagRegexp" <<<"$ref")"; then
		tag="${tagBit#:}"
		ref="${ref#$tagBit}"
	fi

	declare -g digest=''
	local digestBit
	if digestBit="$(grep -oEm1 "^[@]$digestRegexp" <<<"$ref")"; then
		digest="${digestBit#@}"
		ref="${ref#$digestBit}"

		if ! grep -qE "$allowedDigestsRegexp" <<<"$digest"; then
			echo >&2 "'$digest' is not a valid digest (does not match '$allowedDigestsRegexp')"
			return 1
		fi
	fi

	return 0
}

for ref; do
	parse "$ref"
	echo "$name${tag:+:$tag}${digest:+@$digest}"
done
