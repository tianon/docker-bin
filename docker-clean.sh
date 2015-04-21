#!/bin/bash
set -e

dockerRoot="$(docker -D info | awk -F ': ' '$1 == "Docker Root Dir" { print $2; exit }')"
: ${dockerRoot:=/var/lib/docker}

dockerPs=( $(docker ps -a -q) )
if [ ${#dockerPs[@]} -gt 0 ]; then
	(
		set -x
		df -hT "$dockerRoot"
		docker rm "${dockerPs[@]}" || true
		df -hT "$dockerRoot"
	)
fi

dockerUntaggedImages=( $(docker images | awk '/^<none>/ { print $3 }') )
if [ ${#dockerUntaggedImages[@]} -gt 0 ]; then
	(
		set -x
		df -hT "$dockerRoot"
		docker rmi "${dockerUntaggedImages[@]}" || true
		df -hT "$dockerRoot"
	)
fi
