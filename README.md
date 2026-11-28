# @webship.co/workspace-redmine

Redmine, the open-source project management and issue tracking software, for the
[Webship Workspace](https://github.com/webship/workspace), a container-based workspace (DDEV by default). The plugin
brings:

- **a builder**, `cmd-redmine-project.sh`: a real Redmine site from the official image on the project's own PostgreSQL,
  on DDEV (the default), Docker Compose, Podman or Kubernetes, with Redmine's default data and its REST API on, its
  default accounts as members of a sample project, and its issues and version;
- **a tool**, `cmd-tools-redmine-cli.sh`: what a site is and its accounts, Redmine's own tasks in its container, the
  default accounts, the sample content, a clean-up after a stopped test run, and the dashboard's connection;
- **the step pack** [`@webship-js/redmine-steps`](https://github.com/webship/redmine-steps) wired into the
  workspace's testing setup, with a first feature for a site;
- **the issues as work items** of the tracker family
  ([`@webship.co/workspace-tracker`](https://github.com/webship/workspace-tracker)): the REDMINE menu on a project row
  lists them, reads one, analyzes it, and lets the workspace's AI CLI work it on a branch, with a person in charge;
- **AI items** in their folders: three agents, a skill, a command and two prompts.

## Install

From the workspace's root, the same four steps as Settings → Plugins:

```bash
bash core/scripts/plugins.sh --require @webship.co/workspace-redmine
bash core/scripts/plugins.sh --activate redmine --with-needs
bash core/scripts/plugins.sh --install redmine --with-needs
bash core/scripts/plugins.sh --configure redmine
```

## What it needs

- A sites folder: one of the `dev`, `test`, `sandboxes` or `demos` plugins. The commands are placed there.
- The AI folders `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`, where its AI items land.
- A container runtime: DDEV (the default), or Docker Compose, Podman or Kubernetes with the workspace's container
  runtimes (`--runtime docker`, `podman` or `kubernetes`).
- About 700 MB of disk for the image the first time, and about 400 MB of memory for a running site.

## Build a site

```bash
cd ~/workspace/sandboxes                      # or dev, test, demos
bash cmd-redmine-project.sh mysite --install --add-users --sample-content
bash cmd-redmine-project.sh mysite --install --add-users --runtime docker
```

| Flag | What it does |
| --- | --- |
| `--install` | The workspace account (`account` of `core/config/settings.yml`) becomes an administrator of the site. Redmine asks a password of at least eight characters |
| `--add-users` | With `--install`: the default accounts, each a member of the project Webship site in its role |
| `--sample-content` | With `--install --add-users`: the issues of Webship site, its version "Sprint 1" and a note |
| `--redmine-version <x.y.z>` | The release of the official image: 7.0.3 by default |
| `--runtime <runtime>` | `ddev` (the default, or `container.runtime` of `settings.yml`), `docker` (Docker Compose), `podman` or `kubernetes` |
| `--launch` | Open the site when it is ready |

A project of the same name is deleted first, with its database and its files. Every build loads Redmine's default data
in English (its trackers, statuses, roles and workflows), turns its REST API on, and sets the address of its links.

- **On DDEV** Redmine's image is a service of a generic project, on the project's PostgreSQL 17, at
  `https://mysite.ddev.site`, its server running as your user. The project's web container keeps the mail catcher, at
  `https://mysite.ddev.site:8026`.
- **On Docker Compose, Podman and Kubernetes** the official image is the web container's (the workspace's generic
  stack), on the project's PostgreSQL 17, at the address the runtime gives it: `http://127.0.0.1:<port>` on Docker
  Compose and Podman, a node's address and port on Kubernetes; the build says it. Its own entrypoint writes the
  database settings, migrates the database and starts the server, as your user.
- Lando and Docksal are not proven for Redmine yet: asked for one, the builder says so and changes nothing.
- **Its attachments** are in the project folder (`redmine/files`) on every runtime, which the row's Backup holds; a
  new container (a pod started again on Kubernetes) has them too. A site built with the plugin's 1.0.2 keeps them in a
  volume until it is upgraded: see [Upgrading a site from 1.0.2](#upgrading-a-site-from-102).

The site's own values, its secret key and the password of its first administrator (`admin`, as
`REDMINE_ADMIN_PASSWORD`), are made for it and kept in `redmine/env` of the project, which only you can read. The
builder never prints them.

### The default accounts

| Account | Address | Role in Webship site |
| --- | --- | --- |
| `owner` | `owner@example.com` | Manager |
| `member` | `member@example.com` | Developer |
| `reader` | `reader@example.com` | Reporter |
| `stranger` | `stranger@example.com` | No membership: the project is not open to it |

Each has the password of the workspace's other default lists, `dD.123123ddd`. They are configuration: a test suite
never creates or deletes one. `bash cmd-tools-add-users.sh mysite redmine` and
`bash cmd-tools-cancel-users.sh mysite redmine` (the row's Tests menu) add them and lock them.

### The sample content

In Webship site (`webship-site`): "The greeting script says Helo instead of Hello" (a Bug by the owner, In Progress,
assigned to the member, in the version "Sprint 1", with a note), "The usage page spells greeting as greting" (a Bug by
the member) and "An issue opened by someone outside the project" (a Feature opened by the stranger: the tracker treats
it as from outside the project).

### Upgrading a site from 1.0.2

A site built with the plugin's 1.0.2 keeps its attachments in a volume, which the row's Backup does not hold: on DDEV
the project's `ddev-mysite-redmine-files`, on Docker Compose its web container's own (`/usr/src/redmine/files`), which
a new web container does not have. A site built again with this release has them in the project folder. To keep a site
as it is, once the plugin is updated, move them there, from the site's folder (`~/workspace/dev/mysite`, or `test`,
`sandboxes`, `demos`).

On DDEV, where Redmine's service then runs as your user:

```bash
cd ~/workspace/dev/mysite
mkdir -p redmine/files
docker cp ddev-mysite-redmine:/usr/src/redmine/files/. redmine/files/
cp ~/workspace/core/scripts/plugins/redmine/docker-compose.redmine.yaml .ddev/
ddev restart
docker volume rm ddev-mysite-redmine-files
```

The last line removes the old volume, which nothing mounts any more (removing the project would leave it).

On Docker Compose, where the site's copy of the plugin's scripts comes up to this release first (the tool does it):

```bash
cd ~/workspace/dev && bash cmd-tools-redmine-cli.sh mysite
cd mysite
mkdir -p redmine/files
docker compose cp web:/usr/src/redmine/files/. redmine/files/
echo 'REDMINE_ATTACHMENTS_STORAGE_PATH=/var/www/html/redmine/files' >> redmine/env
docker compose restart web
```

Redmine then reads and writes its attachments in `redmine/files`, and the row's Backup holds them. The copy left in
the old volume is not used any more.

## The tool

```bash
bash cmd-tools-redmine-cli.sh mysite                              # what the site is: release, address, accounts
bash cmd-tools-redmine-cli.sh mysite --run "db:migrate:status"    # one of Redmine's own tasks, in its container
bash cmd-tools-redmine-cli.sh mysite --sample-content             # the sample content, where it is missing
bash cmd-tools-redmine-cli.sh mysite --tidy                       # the issues a stopped test run left
bash cmd-tools-redmine-cli.sh mysite --add-users                  # the default accounts and their memberships
bash cmd-tools-redmine-cli.sh mysite --cancel-users               # lock them
bash cmd-tools-redmine-cli.sh mysite --connect member             # the dashboard reads this site as member
```

`--connect <login>` makes a new API key of the account (its earlier one is revoked) and writes it, with the site's
address, into `core/config/plugin.redmine.settings.yml`, and the sample project as the default one when none was set.
The key is never shown.

## The issues as work items

The plugin is a provider of the tracker family. With a Redmine address and an API key in its settings (`--connect`
writes both for a site the workspace built; for your own Redmine, the key is in My account → API access key, and the
REST API must be on in Administration → Settings → API), the project rows of sites and code folders carry the
**REDMINE** menu, once they have a Redmine project to work against (`default_scope`, or one remembered from the list):

- **The list**: the open issues, mine, assigned to someone, the current version (the open one due first), and a search
  in the subject.
- **One issue**: its text, its author and the last editor of its description, each with their standing, and its notes
  (a private note is left out).
- **Analyze**: the AI CLI reads it and proposes a plan, with reading tools only.
- **Do the work**: the AI CLI works it on a new branch of the project (or a worktree), made from the default branch of
  the project's remote, in a screen session you watch. The issue is saved as data, never as instructions.
- **Result**: the branch, its commits and the notes, the reviewer role, and the note to post.
- With writes on (`allow_writes: true`): a note, a worklog (a time entry, on the site's first activity), a move
  through the workflow (the statuses Redmine allows from where the issue is) and an assignee (`me`, a member's id, its
  name, or the first word of it), each your click after a preview.

Redmine opens no pull request: push the branch and open its pull request from the project's forge menu (GITHUB,
GITLAB) when its remote is on a forge.

**Who is inside.** A Manager and a Developer of the project are inside. A Reporter, another role, and an account with
no membership are outside: their issues are analyze only unless you confirm one by its author's name
(`outsider_items: refuse` refuses them).

**Credentials.** The key travels in a file only you can read, never on a command line. Before anything is posted, the
text is checked for credentials: the ones the tracker family knows, and the key of the settings. A Redmine key is 40
hex digits, the shape of a git commit too, so it has no shape of its own to look for.

### Settings

`core/config/plugin.redmine.settings.yml` (Settings → Plugins → Redmine):

| Key | What it is |
| --- | --- |
| `url` | The Redmine address, without a trailing slash |
| `token` | The API key of the account the dashboard reads (and, with writes on, writes) as. Never printed |
| `allow_writes` | Notes, worklogs, moves, assignees and new issues to Redmine; `false` by default |
| `max_agents` | Author sessions at once |
| `default_scope` | The Redmine project (its identifier) a workspace project works against when it remembers none |
| `scopes` | The Redmine projects the list may be switched to; empty is any |
| `work_in` | `branch` (a new branch in the project) or `worktree` (outside the workspace folders) |
| `sandbox` | `required` (the AI CLI's sandbox, and no session without it) or `off` (a person's choice) |
| `network_domains` | The domains the sandbox allows (the project's package registries) |
| `allow_web` | Web fetch and web search in the author session |
| `comments_from` | The notes a saved issue keeps: `members` (Managers and Developers), `all`, `none` |
| `outsider_items` | An issue from outside the project: `analyze` (work it only after a confirmation by name) or `refuse` |

## Testing a site

```bash
bash cmd-tools-testing.sh mysite                       # webship-js, the step pack, the users registry, a first feature
bash cmd-tools-testing.sh mysite --run
```

The testing setup adds `@webship-js/redmine-steps` to the project, its step definitions to `cucumber.js`, the managing
account (`owner`, which makes and removes the test content through the site's REST API), the project of the steps
(`webship-site`), the users registry (`owner`, `member`, `reader`, `stranger`), and `tests/features/site.feature`. The
suite leaves the site as it found it.

## AI items

| Kind | Item | What it is for |
| --- | --- | --- |
| Agent | `redmine-site-builder` | Build, look after and remove Redmine sites |
| Agent | `redmine-tester` | Test a site with the step pack: look at the screens first, write scenarios, run, read |
| Agent | `redmine-issue-worker` | Work an issue on a branch, the writes left to a person |
| Skill | `redmine-scenarios` | The pack's phrases by area, the traps found on real sites, whole features |
| Command | `/redmine-test <site>` | Set the testing stack up, run the suite, report |
| Prompt | `redmine-build-and-test` | Build a site and prove it with its first feature |
| Prompt | `redmine-issue-to-branch` | Work an issue on a branch |

## License

ISC (see `LICENSE`). Redmine itself is GPL-2.0; the plugin runs the official image and carries none of its code.
