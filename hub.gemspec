# encoding: utf-8
require File.expand_path('../lib/ghub/version', __FILE__)

Gem::Specification.new do |s|
  s.name              = "ghub"
  s.version           = GHub::VERSION
  s.summary           = "Gusto's Command-line wrapper for git and GitHub"
  s.homepage          = "http://github.com/gusto/ghub/"
  s.email             = "dev@gusto.com"
  s.authors           = [ "The Gusto Dev Team" ]
  s.license           = "MIT"

  s.files             = %w( README.md Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.files            += Dir.glob("man/**/*")

  # include only files in version control
  git_dir = File.expand_path('../.git', __FILE__)
  if File.directory?(git_dir)
    s.files &= `git --git-dir='#{git_dir}' ls-files -z`.split("\0")
  end

  s.executables       = %w( ghub )
  s.description       = <<desc
  `ghub` is a command line utility which adds GitHub knowledge to `git`.

  It can used on its own or as a `git` wrapper.

  Normal:

      $ ghub clone rtomayko/tilt

      Expands to:
      $ git clone git://github.com/rtomayko/tilt.git

  Wrapping `git`:

      $ git clone rack/rack

      Expands to:
      $ git clone git://github.com/rack/rack.git
desc

  s.post_install_message = <<-message

------------------------------------------------------------

                  You there! Wait, I say!
                  =======================

       If you are a heavy user of `git` on the command
       line  you  may  want  to  install `ghub` the old
       fashioned way.  Faster  startup  time,  you see.

       Check  out  the  installation  instructions  at
       https://github.com/github/ghub#readme  under the
       "Standalone" section.

       Cheers,
       defunkt

------------------------------------------------------------

message
end
