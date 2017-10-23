Feature: asciibinder help

  Displays help information for the asciibinder utility

  Scenario: A user wants to see help information for the utility
    Given a nonexistent repo directory
    When the user runs `asciibinder help` on that repo directory
    Then the program displays help information
