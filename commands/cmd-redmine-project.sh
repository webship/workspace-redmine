#!/usr/bin/env bash

# workspace-name: Redmine (project management and issue tracking)

# Installed by the Redmine plugin (plugins.sh --install redmine); __WORKSPACE__ is the workspace it was
# installed into.
#
# Build a Redmine site in containers from the official image, on the project's own PostgreSQL: on DDEV at
# https://<name>.ddev.site (the default), or on Docker Compose, Podman or Kubernetes with --runtime docker, podman or
# kubernetes, at the address the runtime gives it. With --install the workspace account is an administrator of the
# site; with --add-users the default accounts are members of the project Webship site; with --sample-content its
# issues, its version Sprint 1 and a note.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="redmine";
distribution_title="Redmine";

ARGPARSE_DESCRIPTION="Build an ${distribution_title} site in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/redmine/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/redmine/args/arg-redmine.sh || exit 1 ;

shift $#;

redmine_build ;
