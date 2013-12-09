source "https://rubygems.org"

#dependencies
gem 'maestro_plugin', '>=0.0.17'
gem 'net-ssh', '>=2.2.1'
gem 'net-scp', '>=1.0.4'
gem 'andand', '>=1.3.1'

platforms :jruby do
  gem 'jruby-openssl'
end

group :development do
  gem 'maestro-plugin-rake-tasks'
end

group :test do
  gem 'rspec'
  gem 'mocha'
end
