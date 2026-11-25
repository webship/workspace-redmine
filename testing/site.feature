@site
Feature: The issues of the site
  A first feature of a Redmine site of the Webship Workspace, placed by the testing setup: a member logs in, reads the
  sample project's issues and version, and works an issue of its own, which goes after the scenario. It passes on a
  site built with --install --add-users --sample-content; add your own features beside it.

  Scenario: A member reads the sample project
    Given I am a logged in user with the "member" user
    When I open the issues of the project "webship-site"
    Then the issue list should show "The greeting script says Helo instead of Hello"
    When I open the version "Sprint 1" of the project "webship-site"
    Then the version should be "open"
    And the version should list the issue "The greeting script says Helo instead of Hello"

  Scenario: A member works an issue of its own
    Given there is an issue "Webship test site" in the project "webship-site"
    And I am a logged in user with the "member" user
    When I open the issue "Webship test site"
    And I set the status of the issue to "In Progress"
    And I add the note "Checked on the test site" to the issue
    And I log "0.5" hours on the issue
    Then the issue should show the note "Checked on the test site" by "Member Test"
    And the time spent on the issue should be "0:30 h"

  @js-off
  Scenario: An account with no membership is refused the project
    Given I am a logged in user with the "stranger" user
    Then I should be refused the project "webship-site"
