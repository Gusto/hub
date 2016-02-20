Feature: ghub init
  Background:
    Given I am "mislav" on github.com with OAuth token "OTOKEN"
    Given a directory named "dotfiles"
    When I cd to "dotfiles"

  Scenario: Initializes a git repo with remote
    When I successfully run `ghub init -g`
    Then the url for "origin" should be "git@github.com:mislav/dotfiles.git"

  Scenario: Enterprise host
    Given $GITHUB_HOST is "git.my.org"
    And I am "mislav" on git.my.org with OAuth token "FITOKEN"
    And "git.my.org" is a whitelisted Enterprise host
    When I successfully run `ghub init -g`
    Then the url for "origin" should be "git@git.my.org:mislav/dotfiles.git"
