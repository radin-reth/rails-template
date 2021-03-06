RAILS_REQUIREMENT = "~> 4.2.0"

def apply_template!
  assert_minimum_rails_version
  assert_valid_options
  assert_postgresql
  add_template_repository_to_source_path

  template "Gemfile.tt", :force => true

  template "DEPLOYMENT.md.tt"
  template "PROVISIONING.md.tt"
  template "README.md.tt", :force => true
  remove_file "README.rdoc"

  template "example.env.tt"
  copy_file "capistrano/metrics", ".capistrano/metrics"
  copy_file "gitignore", ".gitignore", :force => true
  copy_file "jenkins-ci.sh", :mode => :preserve
  copy_file "rubocop.yml", ".rubocop.yml"
  template "ruby-version.tt", ".ruby-version"
  copy_file "simplecov", ".simplecov"

  copy_file "Capfile"
  copy_file "Guardfile"

  apply "app/template.rb"
  apply "bin/template.rb"
  apply "config/template.rb"
  apply "doc/template.rb"
  apply "lib/template.rb"
  apply "public/template.rb"
  apply "test/template.rb"

  apply "variants/bootstrap/template.rb" if apply_bootstrap?

  git :init unless preexisting_git_repo?

  run "RUBYOPT=#{rubyopt_without_bundler} bin/setup"
  generate_spring_binstubs

  unless preexisting_git_repo?
    git :add => "-A ."
    git :commit => "-n -m 'Set up project'"
    git :checkout => "-b development"
    if git_repo_specified?
      git :remote => "add origin #{git_repo_url.shellescape}"
      git :push => "-u origin --all"
    end
  end
end

require "fileutils"
require "shellwords"

# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    source_paths.unshift(tempdir = Dir.mktmpdir("rails-template-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git :clone => [
      "--quiet",
      "https://github.com/mattbrictson/rails-template.git",
      tempdir
    ].map(&:shellescape).join(" ")
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def assert_minimum_rails_version
  requirement = Gem::Requirement.new(RAILS_REQUIREMENT)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_REQUIREMENT}. "\
           "You are using #{rails_version}. Continue anyway?"
  exit 1 if no?(prompt)
end

# Bail out if user has passed in contradictory generator options.
def assert_valid_options
  valid_options = {
    :skip_gemfile => false,
    :skip_bundle => false,
    :skip_git => false,
    :skip_test_unit => false,
    :edge => false
  }
  valid_options.each do |key, expected|
    actual = options[key]
    unless actual == expected
      fail Rails::Generators::Error, "Unsupported option: #{key}=#{actual}"
    end
  end
end

def assert_postgresql
  return if IO.read("Gemfile") =~ /^\s*gem ['"]pg['"]/
  fail Rails::Generators::Error,
       "This template requires PostgreSQL, "\
       "but the pg gem isn’t present in your Gemfile."
end

# Mimic the convention used by capistrano-fiftyfive in order to generate
# accurate deployment documentation.
def capistrano_app_name
  app_name.gsub(/[^a-zA-Z0-9_]/, "_")
end

def git_repo_url
  @git_repo_url ||=
    ask("What is the git remote URL for this project [skip]?", :blue)
end

def production_hostname
  @production_hostname ||=
    ask_with_default("Production hostname?", :blue, "example.com")
end

def staging_hostname
  @staging_hostname ||=
    ask_with_default("Staging hostname?", :blue, "staging.example.com")
end

def gemfile_requirement(name)
  @original_gemfile ||= IO.read("Gemfile")
  req = @original_gemfile[/gem\s+['"]#{name}['"]\s*(,[><~= \t\d\.\w'"]*).*$/, 1]
  req && req.gsub("'", %(")).strip.sub(/^,\s*"/, ', "')
end

def ask_with_default(question, color, default)
  question = (question.split("?") << " [#{default}]?").join
  answer = ask(question, color)
  answer.to_s.strip.empty? ? default : answer
end

def git_repo_specified?
  !git_repo_url.strip.empty?
end

def preexisting_git_repo?
  @preexisting_git_repo ||= (File.exist?(".git") || :nope)
  @preexisting_git_repo == true
end

def apply_bootstrap?
  ask_with_default("Use Bootstrap gems, layouts, views, etc.?", :blue, "no")\
    =~ /^y(es)?/i
end

def rubyopt_without_bundler
  ENV["RUBYOPT"].to_s.sub(%r{-rbundler/setup}, "")
end

apply_template!
