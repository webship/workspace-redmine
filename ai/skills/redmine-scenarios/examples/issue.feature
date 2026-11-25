@issues
Feature: An issue worked by a member
  A member moves an issue of its own through the workflow, adds a note to it, logs time on it and assigns it. The
  issue goes after the scenario, with all of it.

  Scenario: Its status, a note, the time spent and the assignee
    Given there is an issue "Webship test work" in the project "webship-site"
    And I am a logged in user with the "member" user
    When I open the issue "Webship test work"
    And I set the status of the issue to "In Progress"
    And I add the note "Checked on the test site" to the issue
    And I log "0.5" hours on the issue with the comment "Read the issue"
    And I assign the issue to "Member Test"
    Then the status of the issue should be "In Progress"
    And the issue should show the note "Checked on the test site" by "Member Test"
    And the time spent on the issue should be "0:30 h"
    And the issue should be assigned to "Member Test"
