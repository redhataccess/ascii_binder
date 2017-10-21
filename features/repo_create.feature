Feature: asciibinder create

  This command creates a new base docs repo to be managed by AsciiBinder

  Scenario: A user tries to create a repo in an existing directory
    Given an existing repo directory
    When the user runs `asciibinder create` on that repo directory
    Then the program exits with a warning

  Scenario: A user tries to create a repo in a nonexistent directory
    Given a nonexistent repo directory
    When the user runs `asciibinder create` on that repo directory
    Then the program generates a new base docs repo
