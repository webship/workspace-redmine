@roles
Feature: What each account may do in the project
  A Reporter reads the project's issues and adds notes, but neither moves nor assigns them, and an account with no
  membership is refused the project.

  Scenario: A Reporter neither moves nor assigns an issue
    Given there is an issue "Webship test reporter" in the project "webship-site"
    And I am a logged in user with the "reader" user
    When I open the issue "Webship test reporter"
    Then I should not be able to change the status of the issue
    And I should not be able to assign the issue

  @js-off
  Scenario: An account with no membership is refused the project
    Given I am a logged in user with the "stranger" user
    Then I should be refused the project "webship-site"
