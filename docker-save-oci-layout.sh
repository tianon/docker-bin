#!/usr/bin/env bash
set -Eeuo pipefail

dir="$1"; shift
mkdir -p "$dir"
cd "$dir"

[ "$#" -gt 0 ]

rm -f index.json

docker save -o temp.tar "$@"
tar -xvf temp.tar
rm temp.tar

if [ -s index.json ]; then
	# yay, new enough Docker! (v25+; https://github.com/moby/moby/pull/44598)
	exit 0
fi

# oh no, convert "docker save" output into OCI format
[ -s manifest.json ] # if this fails, your Docker is way too old for saving -- throw it out!

if [ ! -s oci-layout ]; then
	jq -nc '{ imageLayoutVersion: "1.0.0" }' > oci-layout
fi

mkdir -p blobs/sha256
put() {
	local file="$1"; shift
	local mediaType="$1"; shift

	local size
	size="$(stat --format '%s' "$file")" || return 1

	local sha256
	sha256="$(sha256sum "$file")" || return 1
	sha256="${sha256%% *}"
	[ "${#sha256}" = 64 ] || return 1

	ln -sf --relative -T "$file" "blobs/sha256/$sha256"

	jq -nc --arg mediaType "$mediaType" --arg size "$size" --arg digest "sha256:$sha256" '{
		mediaType: $mediaType,
		digest: $digest,
		size: ($size | tonumber),
	}'
}

shell="$(jq -r '
	map(
		tojson
		| @sh
	)
	| join(" ")
' manifest.json)"
eval "set -- $shell"

index="$(jq -nc '{
	schemaVersion: 2,
	mediaType: "application/vnd.oci.image.index.v1+json",
	manifests: [],
}')"
for json; do
	# {"Config":"d2c94e258dcb3c5ac2798d32e1249e42ef01cba4841c2234249495f87264ac5a.json","RepoTags":["hello-world:latest"],"Layers":["df1c22f7c9ab11ff627ce477eae827d0eb29e637b95bffe1c5fd3f414ace672c/layer.tar"]}
	shell="$(jq <<<"$json" -r '
		@sh "config=\(.Config)",
		@sh "tags=\(.RepoTags // [] | tojson)",
		"layers=( \(.Layers | map(@sh) | join(" ")) )",
		empty
	')"
	eval "$shell"
	configDesc="$(put "$config" 'application/vnd.oci.image.config.v1+json')"
	imageManifest="$(jq -nc --argjson desc "$configDesc" '{
		schemaVersion: 2,
		mediaType: "application/vnd.oci.image.manifest.v1+json",
		config: $desc,
		layers: [],
	}')"
	for layer in "${layers[@]}"; do
		layerDesc="$(put "$layer" 'application/vnd.oci.image.layer.v1.tar')"
		imageManifest="$(jq <<<"$imageManifest" -c --argjson desc "$layerDesc" '.layers += [ $desc ]')"
	done
	jq <<<"$imageManifest" --tab '.' > "image-manifest-$config"
	imageDesc="$(put "image-manifest-$config" 'application/vnd.oci.image.manifest.v1+json')"
	index="$(jq <<<"$index" -c --argjson desc "$imageDesc" --argjson tags "$tags" '.manifests += [ $desc | if $tags | length > 0 then .annotations["org.opencontainers.image.ref.name"] = $tags[] else . end ]')"
done

jq <<<"$index" --tab '.' | tee index.json
