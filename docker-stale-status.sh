#!/bin/bash
set -e

IFS=$'\n'
containers=( $(docker ps --all --quiet --no-trunc) )
unset IFS

for container in "${containers[@]}"; do
	name="$(docker inspect --type container --format '{{.Name}}' "$container")"
	name="${name#/}"
	imageId="$(docker inspect --type container --format '{{.Image}}' "$container")"
	image="$(docker inspect --type container --format '{{.Config.Image}}' "$container")"
	imageImageId="$(docker inspect --type image --format '{{.Id}}' "$image")"
	if [ "$imageId" != "$imageImageId" ]; then
		echo "- $name ($image)"
	fi
done
