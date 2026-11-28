#!/usr/bin/env bash

# Redmine's own server on a runtime other than DDEV (Docker Compose, Podman, Kubernetes): the web container is the official image with the
# workspace's layer, and runs this as the host user from the project's root (rt_serve) once the project's PostgreSQL
# takes connections. The image's own entrypoint writes the database settings from the site's values, migrates the
# database, then starts the server. Written by the Redmine builder of the workspace; build again rather than editing.

set -a ;
# shellcheck disable=SC1091
. "$(dirname "$0")/env" || exit 1 ;
set +a ;
cd /usr/src/redmine || exit 1 ;
# The attachments in the project folder, on a site built since the plugin keeps them there (its env says so): Redmine
# reads that folder from its configuration.yml, which the image leaves to the site (its config folder is open to all).
if [ -n "${REDMINE_ATTACHMENTS_STORAGE_PATH:-}" ] ; then
  mkdir -p "${REDMINE_ATTACHMENTS_STORAGE_PATH}" || exit 1 ;
  printf 'production:\n  attachments_storage_path: %s\n' "${REDMINE_ATTACHMENTS_STORAGE_PATH}" > config/configuration.yml || exit 1 ;
fi
exec /docker-entrypoint.sh rails server -b 0.0.0.0 -p 3000
