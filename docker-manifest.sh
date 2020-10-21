#!/bin/bash
set -Eeuo pipefail

# usage: docker-manifest.sh image [image ...]
#    ie: docker-manifest.sh tianon/speedtest

# TODO add support for non-Hub-hosted repos

declare -A tokens=()
declare -A manifests=()
declare -A digests=()

get_token() {
	local repo="$1"; shift
	if [ -z "${tokens[$repo]:-}" ]; then
		tokens[$repo]="$(curl -fsSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$repo:pull" | jq --raw-output .token)"
	fi
	echo "${tokens[$repo]}"
}

parse_repotag() {
	local repoTag="$1"; shift
	local repo="${repoTag%%:*}"
	local tag="${repoTag#$repo:}"
	[ "$tag" != "$repo" ] || tag=latest
	[[ "$repo" == */* ]] || repo="library/$repo"
	local repoTag="$repo:$tag"
	echo "$repoTag"
}

get_manifest() {
	local repoTag="$1"; shift
	local repo="${repoTag%%:*}"
	local tag="${repoTag#$repo:}"
	[ "$tag" != "$repo" ] || tag=latest
	[[ "$repo" == */* ]] || repo="library/$repo"
	local repoTag="$repo:$tag"
	# TODO refactor the above to use parse_repotag
	if [ -z "${manifests[$repoTag]:-}" ]; then
		local token
		token="$(get_token "$repo")"
		local headersFile
		headersFile="$(mktemp -t docker-manifest.XXXXXXXXXX)"
		local requestHeaders=(
			-H "Authorization: Bearer $token"
			-H 'Accept: application/vnd.docker.distribution.manifest.v2+json'
			-H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json'
			-H 'Accept: application/vnd.docker.distribution.manifest.v1+json'
		)
		manifests[$repoTag]="$(curl -fsSL "${requestHeaders[@]}" "https://registry-1.docker.io/v2/$repo/manifests/$tag" -D "$headersFile")"
		digests[$repoTag]="$(awk -F ': +' 'tolower($1) == "docker-content-digest" { print $2 }' "$headersFile")"
		rm "$headersFile"
	fi
	echo "${manifests[$repoTag]}"
}

get_digest() {
	local repoTag
	repoTag="$(parse_repotag "$@")"
	get_manifest "$repoTag" > /dev/null
	echo "${digests[$repoTag]}"
}

for image in "$@"; do
	digest="$(get_digest "$image")"
	echo >&2 "digest: $digest"
	get_manifest "$image"
done
