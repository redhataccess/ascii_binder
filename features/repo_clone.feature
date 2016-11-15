Feature: asciibinder clone

  This command clones a remote docs repo to a local directory and
  sets up tracking branches for each branch listed in the distro map

  Scenario: A user tries to clone a nonexistant remote repo
    Given a nonexistant remote repo
    And a nonexistant repo directory
    When the user runs `asciibinder clone` on that repo directory
    Then the program exits with a warning

  Scenario: A user tries to clone a remote repo into an existing directory
    Given an existing remote repo
    And an existing repo directory
    When the user runs `asciibinder clone` on that repo directory
    Then the program exits with a warning

  Scenario: A user tries to clone a remote repo into a nonexistant directory
    Given an existing remote repo
    And a nonexistant repo directory
    When the user runs `asciibinder clone` on that repo directory
    Then the program clones the remote repo into the local directory
