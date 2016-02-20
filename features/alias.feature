Feature: ghub alias

  Scenario: bash instructions
    Given $SHELL is "/bin/bash"
    When I successfully run `ghub alias`
    Then the output should contain exactly:
      """
      # Wrap git automatically by adding the following to ~/.bash_profile:

      eval "$(ghub alias -s)"\n
      """

  Scenario: fish instructions
    Given $SHELL is "/usr/local/bin/fish"
    When I successfully run `ghub alias`
    Then the output should contain exactly:
      """
      # Wrap git automatically by adding the following to ~/.config/fish/config.fish:

      eval (ghub alias -s)\n
      """

  Scenario: zsh instructions
    Given $SHELL is "/bin/zsh"
    When I successfully run `ghub alias`
    Then the output should contain exactly:
      """
      # Wrap git automatically by adding the following to ~/.zshrc:

      eval "$(ghub alias -s)"\n
      """

  Scenario: bash code
    Given $SHELL is "/bin/bash"
    When I successfully run `ghub alias -s`
    Then the output should contain exactly:
      """
      alias git=ghub\n
      """

  Scenario: fish code
    Given $SHELL is "/usr/local/bin/fish"
    When I successfully run `ghub alias -s`
    Then the output should contain exactly:
      """
      alias git=ghub\n
      """

  Scenario: zsh code
    Given $SHELL is "/bin/zsh"
    When I successfully run `ghub alias -s`
    Then the output should contain exactly:
      """
      alias git=ghub\n
      """

  Scenario: unsupported shell
    Given $SHELL is "/bin/zwoosh"
    When I run `ghub alias -s`
    Then the output should contain exactly:
      """
      ghub alias: unsupported shell
      supported shells: bash zsh sh ksh csh fish\n
      """
    And the exit status should be 1
