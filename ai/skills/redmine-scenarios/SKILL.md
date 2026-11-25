---
name: redmine-scenarios
description: Write webship-js scenarios for a Redmine site (the open-source project management and issue tracking software) of the Webship Workspace from phrases that exist — the Redmine step pack's steps by area (logging in and out and a refused login, a project and who may open it, the issue list, one issue with its status, notes, time and assignee, a new issue, a version and the roadmap, what a Reporter or a stranger may not do, test content), the traps found on real sites, and whole features. Use when asked to write, extend or fix scenarios for a Redmine site, or when a scenario of the site fails on a phrase.
---

# redmine-scenarios

Scenarios for a site built with the Redmine plugin (`bash cmd-redmine-project.sh <site> --install --add-users
--sample-content`) in a container-based workspace (DDEV by default), tested with webship-js and
`@webship-js/redmine-steps` once `bash cmd-tools-testing.sh <site>` set the project up. Every phrase below exists in the
pack or in webship-js; a scenario names no platform.

## Accounts

- `Given I am a logged in user with the "member" user`: `owner` (Manager of Webship site), `member` (Developer),
  `reader` (Reporter), `stranger` (no membership). `Given I am not logged in` for a visitor.
- The accounts are made by the build (`cmd-tools-redmine-cli.sh <site> --add-users`); a suite never creates or deletes
  one, and never writes a password: it logs in by the handle.

## Phrases by area

| Area | Steps |
| --- | --- |
| Session | `I am a logged in user with the "member" user`, `I log in with the "member" user`, `I log in as "member" with the password "…"`, `the login should be refused with "Invalid user or password"`, `I am not logged in`, `I log out`, `I should be logged in as "Member Test"` (or the login, `"member"`), `I should not be logged in` |
| Projects | `I open the project "webship-site"` (its identifier, or its name "Webship site"), `I should be refused the project "webship-site"` |
| Test content | `there is an issue "Webship test …" in the project "webship-site"` (it goes after the scenario), `there is no issue "Webship test …" in the project "webship-site"` |
| The list | `I open the issues of the project "webship-site"`, `the issue list should show "…"` (`should not show`), `I create an issue "Webship test …" in the project "webship-site"` (it goes after the scenario) |
| One issue | `I open the issue "…"`, `I set the status of the issue to "In Progress"`, `the status of the issue should be "In Progress"`, `I add the note "…" to the issue`, `the issue should show the note "…"` (`… by "Member Test"`), `I log "0.5" hours on the issue` (`… with the comment "…"`), `the time spent on the issue should be "0:30 h"`, `I assign the issue to "Member Test"`, `the issue should be assigned to "Member Test"` |
| What an account may not do | `I should not be able to change the status of the issue`, `I should not be able to assign the issue`, `I should be refused the project "webship-site"` |
| Versions | `I open the version "Sprint 1" of the project "webship-site"`, `the version should be "open"`, `the version should list the issue "…"` (`should not list`), `I open the roadmap of the project "webship-site"`, `the roadmap should list the version "Sprint 1"` (`should not list`) |

## The sample content

`--sample-content` adds, in Webship site: "The greeting script says Helo instead of Hello" (a Bug by the owner, In
Progress, assigned to Member Test, in the version "Sprint 1", with the owner's note "The script is in the project's
repository: `greeting.sh`."), "The usage page spells greeting as greting" (a Bug by the member, New) and "An issue
opened by someone outside the project" (a Feature opened by the stranger). A suite reads them and never changes them.

## Traps found on real sites

- A note stays in the history: change only an issue the scenario made (`there is an issue "Webship test …"`), which
  goes after it with all of it.
- The list shows the open issues: one moved to "Closed" leaves it.
- An issue changes through its update form; the steps open it ("Edit") and send it, and wait for "Successful update.".
- Time needs an activity; the step takes the site's first. The spent time shows as "0:30 h".
- A Reporter adds notes and logs time; the form shows no status and no assignee to it.
- A project an account may not open answers 403: tag those scenarios `@js-off`, and a refused login too.
- The roadmap lists only the trackers that are in the roadmap (not Bug): check an issue on its version's page.
- A run that was stopped half way leaves its "Webship test …" issues: `bash cmd-tools-redmine-cli.sh <site> --tidy`
  removes them, with their time.

## Whole features

`examples/` holds three features that pass on a site built with `--install --add-users --sample-content`: the session
(`session.feature`), an issue worked by a member (`issue.feature`) and the roles (`roles.feature`).

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For a site.** Start with `ch10-authentication-authorization.md` (logins, refusals and what each role may do),
  `ch07-waiting-dynamic-content.md` (waiting on the app's own signals) and `ch26-testing-cms-applications.md`
  (content made and removed, roles, a workflow across roles).
