#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the Redmine project in this folder.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='Run one of Redmine\'s own tasks (bundle exec rake <task>) in its container. Example: --run "db:migrate:status"')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Make the default accounts (owner, member, reader, stranger) and their memberships of Webship site, or give them back their names, passwords and roles.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Lock the default accounts: they cannot log in any more, and their work stays.')
parser.add_argument('-s', '--sample-content',
                    action='store_true',
                    default=False,
                    help='Add the sample content the step pack and the tracker are tested on, where it is missing.')
parser.add_argument('-t', '--tidy',
                    action='store_true',
                    default=False,
                    help='Remove what a test run that was stopped half way left: its issues ("Webship test …"), with their time.')
parser.add_argument('--connect',
                    default="_none_",
                    help='Point the dashboard\'s Redmine at this site as this account: a new API key of it goes into core/config/plugin.redmine.settings.yml (never shown), with the site\'s address. Example: --connect member')
ARGEOF
