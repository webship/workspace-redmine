#!/usr/bin/env bash

# Redmine's own server on a runtime other than DDEV (Docker Compose): the web container is the official image with the
# workspace's layer, and runs this as the host user from the project's root (rt_serve) once the project's PostgreSQL
# takes connections. The image's own entrypoint writes the database settings from the site's values, migrates the
# database, then starts the server. Written by the Redmine builder of the workspace; build again rather than editing.

set -a ;
# shellcheck disable=SC1091
. "$(dirname "$0")/env" || exit 1 ;
set +a ;
cd /usr/src/redmine || exit 1 ;
exec /docker-entrypoint.sh rails server -b 0.0.0.0 -p 3000
