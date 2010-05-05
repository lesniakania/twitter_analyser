require 'config/init'
require 'config/environments/test'

Spec::Runner.configure do |config|
  config.before(:each) do
    clear_tables
  end
end