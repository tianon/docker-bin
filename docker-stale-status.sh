#!/bin/bash
set -e

IFS=$'\n'
containers=( $(docker ps -aq --no-trunc) )
unset IFS

for container in "${containers[@]}"; do
	name="$(docker inspect -f '{{.Name}}' "$container")"
	name="${name#/}"
	imageId="$(docker inspect -f '{{.Image}}' "$container")"
	image="$(docker inspect -f '{{.Config.Image}}' "$container")"
	imageImageId="$(docker inspect -f '{{.Id}}' "$image")"
	if [ "$imageId" != "$imageImageId" ]; then
		echo "- $name ($image)"
	fi
done
