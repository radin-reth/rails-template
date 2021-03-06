insert_into_file "config/application.rb", :before => /^  end/ do
  <<-'RUBY'

    # Ensure non-standard paths are eager-loaded
    config.eager_load_paths += ["#{config.root}/app/workers"]
  RUBY
end

copy_file "config/brakeman.yml"
copy_file "config/pre_commit.yml"
template "config/database.example.yml.tt"
remove_file "config/database.yml"
remove_file "config/secrets.yml"
copy_file "config/sidekiq.yml"

template "config/deploy.rb.tt"
template "config/deploy/production.rb.tt"
template "config/deploy/staging.rb.tt"

gsub_file "config/routes.rb", /  # root 'welcome#index'/ do
  '  root "home#index"'
end

copy_file "config/initializers/active_job.rb"
copy_file "config/initializers/generators.rb"
copy_file "config/initializers/rotate_log.rb"
copy_file "config/initializers/secret_token.rb"
copy_file "config/initializers/secure_headers.rb"
copy_file "config/initializers/version.rb"
template "config/initializers/sidekiq.rb.tt"

gsub_file "config/initializers/filter_parameter_logging.rb", /\[:password\]/ do
  "%w(password secret session cookie csrf)"
end

apply "config/environments/development.rb"
apply "config/environments/production.rb"
apply "config/environments/test.rb"
template "config/environments/staging.rb.tt"

route 'mount Sidekiq::Web => "/sidekiq" # monitoring console'
