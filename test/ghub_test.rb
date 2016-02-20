require 'helper'
require 'webmock/minitest'
require 'rbconfig'
require 'yaml'
require 'forwardable'
require 'fileutils'
require 'tempfile'

WebMock::BodyPattern.class_eval do
  undef normalize_hash
  # override normalizing hash since it otherwise requires JSON
  def normalize_hash(hash) hash end

  # strip out the "charset" directive from Content-type value
  alias matches_with_dumb_content_type matches?
  def matches?(body, content_type = "")
    content_type = content_type.split(';').first if content_type.respond_to? :split
    matches_with_dumb_content_type(body, content_type)
  end
end

class HubTest < Minitest::Test
  extend Forwardable

  if defined? WebMock::API
    include WebMock::API
  else
    include WebMock
  end

  COMMANDS = []

  GHub::Context::System.class_eval do
    remove_method :which
    define_method :which do |name|
      COMMANDS.include?(name) ? "/usr/bin/#{name}" : nil
    end
  end

  attr_reader :git_reader
  include GHub::Context::GitReaderMethods
  def_delegators :git_reader, :stub_config_value, :stub_command_output

  def setup
    super
    COMMANDS.replace %w[open groff]
    GHub::Context::PWD.replace '/path/to/ghub'
    GHub::SshConfig::CONFIG_FILES.replace []

    @prompt_stubs = prompt_stubs = []
    @password_prompt_stubs = password_prompt_stubs = []
    @repo_file_read = repo_file_read = {}

    GHub::GitHubAPI::Configuration.class_eval do
      undef prompt
      undef prompt_password

      define_method :prompt do |what|
        prompt_stubs.shift.call(what)
      end
      define_method :prompt_password do |host, user|
        password_prompt_stubs.shift.call(host, user)
      end
    end

    GHub::Context::LocalRepo.class_eval do
      undef file_read
      undef file_exist?

      define_method(:file_read) do |*args|
        name = File.join(*args)
        if value = repo_file_read[name]
          value.dup
        else
          raise Errno::ENOENT
        end
      end

      define_method(:file_exist?) do |*args|
        name = File.join(*args)
        !!repo_file_read[name]
      end
    end

    @git_reader = GHub::Context::GitReader.new 'git' do |cache, cmd|
      unless cmd.index('config --get alias.') == 0
        raise ArgumentError, "`git #{cmd}` not stubbed"
      end
    end

    GHub::Commands.instance_variable_set :@git_reader, @git_reader
    GHub::Commands.instance_variable_set :@local_repo, nil
    GHub::Commands.instance_variable_set :@api_client, nil

    FileUtils.rm_rf ENV['HUB_CONFIG']

    edit_hub_config do |data|
      data['github.com'] = [{'user' => 'tpw', 'oauth_token' => 'OTOKEN'}]
    end

    @git_reader.stub! \
      'remote -v' => "origin\tgit://github.com/defunkt/ghub.git (fetch)\nmislav\tgit://github.com/mislav/ghub.git (fetch)",
      'rev-parse --symbolic-full-name master@{upstream}' => 'refs/remotes/origin/master',
      'config --get --bool ghub.http-clone' => 'false',
      'config --get ghub.protocol' => nil,
      'config --get-all ghub.host' => nil,
      'config --get push.default' => nil,
      'rev-parse -q --git-dir' => '.git'

    stub_branch('refs/heads/master')
    stub_remote_branch('origin/master')
  end

  def teardown
    super
    WebMock.reset!
  end

  def test_version
    out = ghub('--version')
    assert_includes "git version 1.7.0.4", out
    assert_includes "ghub version #{GHub::Version}", out
  end

  def test_exec_path
    out = ghub('--exec-path')
    assert_equal "/usr/lib/git-core\n", out
  end

  def test_exec_path_arg
    out = ghub('--exec-path=/home/wombat/share/my-l33t-git-core')
    assert_equal improved_help_text, out
  end

  def test_html_path
    out = ghub('--html-path')
    assert_equal "/usr/share/doc/git-doc\n", out
  end

  def test_help
    assert_equal improved_help_text, ghub("help")
  end

  def test_help_by_default
    assert_equal improved_help_text, ghub("")
  end

  def test_help_with_pager
    assert_equal improved_help_text, ghub("-p")
  end

  def test_help_hub
    help_manpage = strip_man_escapes ghub("help ghub")
    assert_includes "git + ghub = github", help_manpage
    assert_includes "GHub will prompt for GitHub username & password", help_manpage.gsub(/ {2,}/, ' ')
  end

  def test_help_flag_on_command
    help_manpage = strip_man_escapes ghub("browse --help")
    assert_includes "git + ghub = github", help_manpage
    assert_includes "git browse", help_manpage
  end

  def test_help_custom_command
    help_manpage = strip_man_escapes ghub("help fork")
    assert_includes "git fork [--no-remote]", help_manpage
  end

  def test_help_short_flag_on_command
    usage_help = ghub("create -h")
    expected = "Usage: git create [NAME] [-p] [-d DESCRIPTION] [-h HOMEPAGE]\n"
    assert_equal expected, usage_help

    usage_help = ghub("pull-request -h")
    expected = "Usage: git pull-request [-o|--browse] [-f] [-m MESSAGE|-F FILE|-i ISSUE|ISSUE-URL] [-b BASE] [-h HEAD]\n"
    assert_equal expected, usage_help
  end

  def test_help_hub_no_groff
    stub_available_commands()
    assert_equal "** Can't find groff(1)\n", ghub("help ghub")
  end

  def test_hub_standalone
    assert_includes 'This file is generated code', ghub("ghub standalone")
  end

  def test_custom_browser
    with_browser_env("custom") do
      assert_browser("custom")
    end
  end

  def test_linux_browser
    stub_available_commands "open", "xdg-open", "cygstart"
    with_browser_env(nil) do
      with_host_os("i686-linux") do
        assert_browser("xdg-open")
      end
    end
  end

  def test_cygwin_browser
    stub_available_commands "open", "cygstart"
    with_browser_env(nil) do
      with_host_os("i686-linux") do
        assert_browser("cygstart")
      end
    end
  end

  def test_no_browser
    stub_available_commands()
    expected = "Please set $BROWSER to a web launcher to use this command.\n"
    with_browser_env(nil) do
      with_host_os("i686-linux") do
        assert_equal expected, ghub("browse")
      end
    end
  end

  def test_context_method_doesnt_hijack_git_command
    assert_forwarded 'remotes'
  end

  def test_not_choking_on_ruby_methods
    assert_forwarded 'id'
    assert_forwarded 'name'
  end

  def test_global_flags_preserved
    cmd = '--no-pager --bare -c core.awesome=true -c name=value --git-dir=/srv/www perform'
    assert_command cmd, 'git --bare -c core.awesome=true -c name=value --git-dir=/srv/www --no-pager perform'
    assert_equal %w[git --bare -c core.awesome=true -c name=value --git-dir=/srv/www], git_reader.executable
  end

  private

    def stub_repo_url(value, remote_name = 'origin')
      stub_command_output 'remote -v', "#{remote_name}\t#{value} (fetch)"
    end

    def stub_branch(value)
      @repo_file_read['HEAD'] = "ref: #{value}\n"
    end

    def stub_tracking(from, upstream, remote_branch = nil)
      stub_command_output "rev-parse --symbolic-full-name #{from}@{upstream}",
        remote_branch ? "refs/remotes/#{upstream}/#{remote_branch}" : upstream
    end

    def stub_tracking_nothing(from = 'master')
      stub_tracking(from, nil)
    end

    def stub_remote_branch(branch, sha = 'abc123')
      @repo_file_read["refs/remotes/#{branch}"] = sha
    end

    def stub_remotes_group(name, value)
      stub_config_value "remotes.#{name}", value
    end

    def stub_no_remotes
      stub_command_output 'remote -v', nil
    end

    def stub_no_git_repo
      stub_command_output 'rev-parse -q --git-dir', nil
    end

    def stub_alias(name, value)
      stub_config_value "alias.#{name}", value
    end

    def stub_existing_fork(user, repo = 'ghub')
      stub_fork(user, repo, 200)
    end

    def stub_nonexisting_fork(user, repo = 'ghub')
      stub_fork(user, repo, 404)
    end

    def stub_fork(user, repo, status)
      stub_request(:get, "https://api.github.com/repos/#{user}/#{repo}").
        to_return(:status => status)
    end

    def stub_available_commands(*names)
      COMMANDS.replace names
    end

    def stub_https_is_preferred
      stub_config_value 'ghub.protocol', 'https'
    end

    def stub_hub_host(names)
      stub_config_value "ghub.host", Array(names).join("\n"), '--get-all'
    end

    def with_browser_env(value)
      browser, ENV['BROWSER'] = ENV['BROWSER'], value
      yield
    ensure
      ENV['BROWSER'] = browser
    end

    def with_tmpdir(value)
      dir, ENV['TMPDIR'] = ENV['TMPDIR'], value
      yield
    ensure
      ENV['TMPDIR'] = dir
    end

    def with_host_env(value)
      host, ENV['GITHUB_HOST'] = ENV['GITHUB_HOST'], value
      yield
    ensure
      ENV['GITHUB_HOST'] = host
    end

    def assert_browser(browser)
      assert_command "browse", "#{browser} https://github.com/defunkt/ghub"
    end

    def with_host_os(value)
      host_os = RbConfig::CONFIG['host_os']
      RbConfig::CONFIG['host_os'] = value
      begin
        yield
      ensure
        RbConfig::CONFIG['host_os'] = host_os
      end
    end

    def mock_pullreq_response(id, name_with_owner = 'defunkt/ghub', host = 'github.com')
      GHub::JSON.generate :html_url => "https://#{host}/#{name_with_owner}/pull/#{id}"
    end

    def mock_pull_response(label, priv = false)
      GHub::JSON.generate :head => {
        :label => label,
        :repo => {:private => !!priv}
      }
    end

    def improved_help_text
      GHub::Commands.send :improved_help_text
    end

    def with_ssh_config content
      config_file = Tempfile.open 'ssh_config'
      config_file << content
      config_file.close

      begin
        GHub::SshConfig::CONFIG_FILES.replace [config_file.path]
        yield
      ensure
        config_file.unlink
      end
    end

    def strip_man_escapes(manpage)
      manpage.gsub(/_\010/, '').gsub(/\010./, '')
    end

end
