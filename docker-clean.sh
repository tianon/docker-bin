#!/bin/bash
set -e

dockerInfo="$(docker -D info)"
dockerRoot="$(echo "$dockerInfo" | awk -F ': ' '$1 == "Docker Root Dir" { print $2; exit }')"
: ${dockerRoot:=/var/lib/docker}

dockerPs=( $(docker ps -aq) )
if [ ${#dockerPs[@]} -gt 0 ]; then
	(
		set -x
		df -hT "$dockerRoot"
		df -hTi "$dockerRoot"
		docker rm "${dockerPs[@]}" || true
		df -hT "$dockerRoot"
		df -hTi "$dockerRoot"
	)
fi

dockerUntaggedImages=( $(docker images -q --filter 'dangling=true') )
if [ ${#dockerUntaggedImages[@]} -gt 0 ]; then
	(
		set -x
		df -hT "$dockerRoot"
		df -hTi "$dockerRoot"
		docker rmi "${dockerUntaggedImages[@]}" || true
		df -hT "$dockerRoot"
		df -hTi "$dockerRoot"
	)
fi
