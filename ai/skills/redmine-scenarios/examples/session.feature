@session
Feature: Logging in and out
  The accounts of the users registry log in through the login form, a wrong password is refused, and logging out
  ends the session.

  Scenario: An account logs in through the form and out again
    Given I am not logged in
    When I log in with the "member" user
    Then I should be logged in as "Member Test"
    When I log out
    Then I should not be logged in

  @js-off
  Scenario: A wrong password is refused
    Given I am not logged in
    When I log in as "member" with the password "not-the-right-password"
    Then the login should be refused with "Invalid user or password"
    And I should not be logged in

  Scenario: A session of the registry is put back for the next scenario
    Given I am a logged in user with the "owner" user
    Then I should be logged in as "owner"
    Given I am a logged in user with the "member" user
    Then I should be logged in as "Member Test"
