#!/usr/bin/env bash

# Installed by the Redmine plugin (plugins.sh --install redmine); __WORKSPACE__ is the workspace it was
# installed into.
#
# A Redmine site of this folder: what it is and its accounts; --run one of Redmine's own tasks in its
# container; --add-users and --cancel-users the default accounts; --sample-content the sample content; --tidy what a
# stopped test run left; --connect the dashboard's Redmine to this site.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

ARGPARSE_DESCRIPTION="A Redmine site of __WORKSPACE__: what it is, its accounts, Redmine's own tasks"
# The args file comes with the plugin: core/scripts/plugins/redmine/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/redmine/args/arg-redmine-cli.sh || exit 1 ;

shift $#;

redmine_cli_tool ;
