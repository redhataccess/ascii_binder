Feature: asciibinder package

  Causes the utility to run a `build` operation and then marshall
  together all of the distro / branch combinations that will be
  published into "sites". Each site has a distinct home page.

  Scenario: A user wants to package all of the sites contained in their docs repo
    Given a valid AsciiBinder docs repo with multiple distros
    When the user runs `asciibinder package` on that repo directory
    Then the program generates a site directory for each site in the distro map

  Scenario: A user wants to package one of the sites contained in their docs repo
    Given a valid AsciiBinder docs repo with multiple distros
    When the user runs `asciibinder package --site=test` on that repo directory
    Then the program generates a site directory for only the `test` site in the distro map
