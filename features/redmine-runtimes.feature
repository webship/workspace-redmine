Feature: A Redmine site on Docker Compose
  The builder builds on DDEV by default, and with --runtime docker on Docker Compose: the official image is the web
  container's, on the project's own PostgreSQL. A site built there has the row a DDEV site has: its state, its own
  address, the runtime's menu, and the test users of Redmine in its Tests menu.

  # Each scenario drives a real Redmine site built with cmd-redmine-project.sh --runtime docker: the first
  # running one the workspace holds. Without one it is skipped, with the reason. In the plugin's CI it is the one the
  # manifest's featuresSite builds.

  @needs-runtime-docker @needs-platform-redmine
  Scenario: A site built on Docker Compose runs at its own address, with the DOCKER menu
    Given I am on the folder of the "docker" site
     Then the row of the "docker" site should show "Running"
      And the row of the "docker" site should link to the address of its runtime
      And the address of the "docker" site should answer
      And the row of the "docker" site should carry the "DOCKER" menu and no DDEV menu

  @needs-runtime-docker @needs-platform-redmine
  Scenario: The Tests menu of a site on Docker Compose offers the test users
    Given I am on the folder of the "docker" site
     When I open the "tests" menu of the "docker" site
     Then the open menu should offer "Add the test users"
      And the open menu should offer "Cancel the test users"

  @needs-runtime-docker @needs-platform-redmine
  Scenario: The site on Docker Compose is installed: its login screen
    Given I am on the folder of the "docker" site
     When I open "/login" on the "docker" site
     Then I should see "Login"
      And I should see "Password"
      And I should see "Lost password"
