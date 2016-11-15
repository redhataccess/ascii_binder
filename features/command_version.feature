Feature: asciibinder version

  This command returns the version of the installed utility

  Scenario: A user wants to display the version of the asciibinder utility
    Given a nonexistant repo directory
    When the user runs `asciibinder version` on that repo directory
    Then the program prints the current version of the utility
