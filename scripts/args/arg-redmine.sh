#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, its project in containers and its host name.')
parser.add_argument('--runtime',
                    dest='RUNTIME',
                    default="_none_",
                    choices=['ddev', 'docker'],
                    help='The container runtime to build on: ddev (the default, or container.runtime of settings.yml) or docker (Docker Compose). Redmine is not proven on the other runtimes yet.')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Make the workspace account an administrator of the site.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts (owner: Manager, member: Developer, reader: Reporter of the project Webship site; stranger: no membership): the ones the test scenarios log in as.')
parser.add_argument('-s', '--sample-content',
                    action='store_true',
                    default=False,
                    help='With --install and --add-users, add the sample content the step pack and the tracker are tested on: the issues of Webship site, its version Sprint 1 and a note.')
parser.add_argument('-v', '--redmine-version',
                    dest='REDMINE_VERSION',
                    default="",
                    help='The release of the site (a tag of the official image): 7.0.3 by default. Example: --redmine-version 7.0.3')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the site in a browser when it is ready.')
ARGEOF
