source "https://rubygems.org"

# docker-api appears to be unmaintained, and has a noisy deprecation
# warning under ruby 2.7. Use a local fork.
gem "docker-api", git: "https://github.com/chef/docker-api.git"

group :development do
  gem "chefstyle"
  gem "rake"
  # enable tests for the verification behavior in omnibus/verification
  gem "chef-cli"
  gem "rspec"
end

instance_eval(ENV["GEMFILE_MOD"]) if ENV["GEMFILE_MOD"]

# If you want to load debugging tools into the bundle exec sandbox,
# add these additional dependencies into Gemfile.local
eval_gemfile(__FILE__ + ".local") if File.exist?(__FILE__ + ".local")
