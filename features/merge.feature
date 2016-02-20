Feature: ghub merge
  Background:
    Given I am in "ghub" git repo
    And the "origin" remote has url "git://github.com/defunkt/ghub.git"
    And I am "mislav" on github.com with OAuth token "OTOKEN"

  Scenario: Merge pull request
    Given the GitHub API server:
      """
      require 'json'
      get('/repos/defunkt/ghub/pulls/164') { json \
        :head => {
          :label => 'jfirebaugh:hub_merge',
          :repo  => {:private => false, :name=>"ghub"}
        },
        :title => "Add `ghub merge` command"
      }
      """
    And there is a commit named "jfirebaugh/hub_merge"
    When I successfully run `ghub merge https://github.com/defunkt/ghub/pull/164`
    Then "git fetch git://github.com/jfirebaugh/ghub.git +refs/heads/hub_merge:refs/remotes/jfirebaugh/hub_merge" should be run
    When I successfully run `git show -s --format=%B`
    Then the output should contain:
      """
      Merge pull request #164 from jfirebaugh/hub_merge

      Add `ghub merge` command
      """

  Scenario: Merge pull request with --ff-only option
    Given the GitHub API server:
      """
      require 'json'
      get('/repos/defunkt/ghub/pulls/164') { json \
        :head => {
          :label => 'jfirebaugh:hub_merge',
          :repo  => {:private => false, :name=>"ghub"}
        },
        :title => "Add `ghub merge` command"
      }
      """
    And there is a commit named "jfirebaugh/hub_merge"
    When I successfully run `ghub merge --ff-only https://github.com/defunkt/ghub/pull/164`
    Then "git fetch git://github.com/jfirebaugh/ghub.git +refs/heads/hub_merge:refs/remotes/jfirebaugh/hub_merge" should be run
    When I successfully run `git show -s --format=%B`
    Then the output should contain:
      """
      Fast-forward (no commit created; -m option ignored)
      """

  Scenario: Merge private pull request
    Given the GitHub API server:
      """
      require 'json'
      get('/repos/defunkt/ghub/pulls/164') { json \
        :head => {
          :label => 'jfirebaugh:hub_merge',
          :repo  => {:private => true, :name=>"ghub"}
        },
        :title => "Add `ghub merge` command"
      }
      """
    And there is a commit named "jfirebaugh/hub_merge"
    When I successfully run `ghub merge https://github.com/defunkt/ghub/pull/164`
    Then "git fetch git@github.com:jfirebaugh/ghub.git +refs/heads/hub_merge:refs/remotes/jfirebaugh/hub_merge" should be run

  Scenario: Missing repo
    Given the GitHub API server:
      """
      require 'json'
      get('/repos/defunkt/ghub/pulls/164') { json \
        :head => {
          :label => 'jfirebaugh:hub_merge',
          :repo  => nil
        }
      }
      """
    When I run `ghub merge https://github.com/defunkt/ghub/pull/164`
    Then the exit status should be 1
    And the stderr should contain exactly:
      """
      Error: jfirebaugh's fork is not available anymore\n
      """

  Scenario: Renamed repo
    Given the GitHub API server:
      """
      require 'json'
      get('/repos/defunkt/ghub/pulls/164') { json \
        :head => {
          :label => 'jfirebaugh:hub_merge',
          :repo  => {:private => false, :name=>"ghub-1"}
        }
      }
      """
    And there is a commit named "jfirebaugh/hub_merge"
    When I successfully run `ghub merge https://github.com/defunkt/ghub/pull/164`
    Then "git fetch git://github.com/jfirebaugh/ghub-1.git +refs/heads/hub_merge:refs/remotes/jfirebaugh/hub_merge" should be run

  Scenario: Unchanged merge
    When I run `ghub merge master`
    Then "git merge master" should be run
