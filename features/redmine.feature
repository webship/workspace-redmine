Feature: The Redmine plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Redmine builder, each AI folder lists the
  items of its kind the plugin ships, the Plugins page lists the plugin with its settings, and the project rows of
  sites and code folders carry the REDMINE menu of issues once a Redmine is connected.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package, what it ships and its settings
    Given I am on "/settings"
     Then I should see "Redmine"
     When I go to "/settings/plugin/redmine"
     Then I should see "@webship.co/workspace-redmine"
      And I should see "cmd-redmine-project.sh"
      And I should see "redmine-site-builder"
      And I should see "Writes to Redmine (issues as work items)"

  Scenario: A sites folder offers the Redmine builder
    Given I am on "/dev"
     Then "option[value='cmd-redmine-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=redmine-"
     Then I should see "redmine-site-builder"
      And I should see "redmine-tester"
      And I should see "redmine-issue-worker"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=redmine-scenarios"
     Then I should see "redmine-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=redmine-test"
     Then I should see "redmine-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=redmine-"
     Then I should see "redmine-build-and-test"
      And I should see "redmine-issue-to-branch"

  # The issues as work items (@webship.co/workspace-tracker). The list asks Redmine again when its View or
  # its filter changes, and Enter submits it. It needs a Redmine with a token, a default project and a project in
  # the dev folder: CI has none, so it skips this, saying why.
  @needs-setting-redmine-token @needs-setting-redmine-default_scope @needs-project-dev
  Scenario: The issue list follows its View and its filter
    Given I am on "/dev"
     When I click on the element ".act-menu-redmine > button"
      And I click on the element ".act-menu-redmine a[hx-get*='/tracker/list/']"
     Then eventually I should see "All open issues ·" within 30 seconds
     When I select "Current version" from "view"
     Then eventually I should see "Current version ·" within 30 seconds
     When I fill in "q" with "#1"
      And I press the key "Enter" on the element "input[name=q]"
     Then eventually I should see "Redmine issue #1 ·" within 30 seconds
