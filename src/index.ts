/**
 * Redmine for Webship Workspace: a platform plugin and a provider of the tracker family.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the tool in the sites
 * folders, their functions and argparse under core/scripts/plugins/redmine/ (with the compose file of Redmine's
 * service, the Rails runner script the builder runs in its container, the start of a site on another runtime and the
 * first feature of a site), and its AI items (ai/ in this package) in the folder of their kind.
 *
 * What register() adds: the issues of a Redmine as work items (@webship.co/workspace-tracker): the REDMINE menu on
 * the project rows of sites and code folders that work against a Redmine project, the list, one issue, analyze, do the
 * work with the workspace's AI CLI on a branch, and, with writes on, a note, a worklog, a move and an assignee, each a
 * person's click after a preview. And what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the dashboard's own
 * files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';
import { registerTracker } from '@webship.co/workspace-tracker';

import { redmineTracker } from './lib/tracker';

export { redmineTracker };

/** The plugin's name: a site is a generic project in containers that the plugin claims, and the core's tools call its functions under it. */
export const PLATFORM = 'redmine';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-redmine-project.sh', 'cmd-tools-redmine-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['redmine-site-builder', 'redmine-tester', 'redmine-issue-worker'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['redmine-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['redmine-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['redmine-build-and-test', 'redmine-issue-to-branch'];

/** What the assistant is told about Redmine sites in this workspace (the issues are told by the tracker). */
export function assistantContext(): string {
  return [
    'Redmine (a plugin, @webship.co/workspace-redmine), the open-source project management and issue tracking software: a site is built with',
    '`bash cmd-redmine-project.sh <name> --install --add-users --sample-content` from a sites folder (dev, test, sandboxes, demos):',
    'the official image (7.0.3 by default, `--redmine-version`) on the project\'s own PostgreSQL, on DDEV at https://<name>.ddev.site, or with `--runtime docker`, `podman` or `kubernetes` at the address the runtime gives it (the build says it).',
    'The build loads Redmine\'s default data and turns its REST API on; `--install` makes the workspace account an administrator; `--add-users` adds the default accounts (owner: Manager, member: Developer, reader: Reporter of the project Webship site, stranger: no membership), each @example.com;',
    '`--sample-content` adds the issues of Webship site, its version "Sprint 1" and a note.',
    '`bash cmd-tools-redmine-cli.sh <name>` says what the site is and lists its accounts; `--run "<task>"` runs one of Redmine\'s own rake tasks in its container,',
    '`--sample-content` adds the sample content later, `--tidy` removes the issues a stopped test run left ("Webship test …"), `--add-users` and `--cancel-users` manage the default accounts,',
    'and `--connect <login>` points the dashboard\'s Redmine at the site as that account (a new API key in the plugin\'s settings, never shown).',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Redmine step pack; `--run` runs the suite.',
    `For Redmine sites hand over to the agent \`${AGENTS[0]}\`, for testing one to \`${AGENTS[1]}\`, for working an issue to \`${AGENTS[2]}\`.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run Redmine\'s tools on the host for a project; removing the project removes its database and its files too.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  registerTracker(api, redmineTracker(api));
  if (typeof api.addAssistantContext === 'function') api.addAssistantContext(assistantContext);
}
