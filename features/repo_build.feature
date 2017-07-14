Feature: asciibinder build

  Causes the utility to process one or more distro/branch combinations,
  transforming AsciiDoc files to a unified docs set in HTML

  Scenario: A user wants to do any build in a repo with an invalid distro map
    Given an invalid AsciiBinder docs repo due to a malformed distro map
    When the user runs `asciibinder build` on that repo directory
    Then the program exits with a warning

  Scenario: A user wants to build all distros against the current repo branch
    Given a valid AsciiBinder docs repo with multiple distros
    When the user runs `asciibinder build` on that repo directory
    Then the program generates preview content for all distros in the current branch

  Scenario: A user wants to build a single distro against the current repo branch
    Given a valid AsciiBinder docs repo with multiple distros
    When the user runs `asciibinder build --distro=distro_test` on that repo directory
    Then the program generates preview content for only the `distro_test` distro

  Scenario: A user wants to build all distros against all relevant branches
    Given a valid AsciiBinder docs repo with multiple distros
    When the user runs `asciibinder build --all-branches` on that repo directory
    Then the program generates preview content for all relevant distro/branch combos

  Scenario: A user wants to build a specific page in the current branch
    Given a valid AsciiBinder docs repo with multiple distros
    When the user runs `asciibinder build --page=welcome:index` on that repo directory
    Then the program generates preview content for the specified page in all distros

  Scenario: A user wants to build from a repo where the docs root is not the repo root
    Given a valid AsciiBinder docs repo where the docs root is not at the repo root
    When the user runs `asciibinder build` on that docs root directory
    Then the program generates preview content for all distros in the current branch
