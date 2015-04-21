#!/bin/bash
set -e

set -x
exec docker pull $(awk 'toupper($1) == "FROM" { print $2; exit }' "${1:-Dockerfile}")
