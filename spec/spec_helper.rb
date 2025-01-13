# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'
db = ENV.fetch('DB', 'sqlite3')

if ENV['COVERAGE'] && !%w[rbx jruby].include?(RUBY_ENGINE)
  require 'simplecov'
  SimpleCov.command_name ENV['SIMPLECOV_NAME'] || 'RSpec'
end

require File.expand_path('dummy/config/environment', __dir__)

FileUtils.mkdir('log') unless File.directory?('log')

# If desired can log SQL to STDERR -- this tends to overload travis' log limits though.
if ENV['LOG_SQL_TO_STDERR']
  Rails.logger = Logger.new(STDERR)
  Rails.logger.level = Logger::WARN
  ActiveRecord::Base.logger = Logger.new(STDERR)
  ActiveRecord::Base.logger.level = Logger::DEBUG
elsif !ENV['CI']
  ActiveRecord::Base.logger = Logger.new(File.open("log/test.#{db}.log", 'w'))
  ActiveRecord::SchemaMigration.logger = ActiveRecord::Base.logger unless Thredded::Compat.rails_gte_71?
end

# Re-create the test database and run the migrations
system({ 'DB' => db }, 'script/create-db-users') unless ENV['TRAVIS'] || ENV['DOCKER']
ActiveRecord::Tasks::DatabaseTasks.drop_current
ActiveRecord::Tasks::DatabaseTasks.create_current
require File.expand_path('../lib/thredded/db_tools', __dir__)
if ENV['MIGRATION_SPEC']
  Thredded::DbTools.restore
else
  Thredded::DbTools.migrate(paths: ['db/migrate/', Rails.root.join('db', 'migrate')], quiet: true)
end

require File.expand_path('../spec/support/system/page_object/authentication', __dir__)
require 'rspec/rails'
require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'pundit/rspec'
require 'webmock/rspec'
require 'factory_bot'
require 'database_cleaner/active_record'
require 'fileutils'
require 'active_support/testing/time_helpers'
require 'factories'

# Driver makes web requests to localhost, configure WebMock to let them through
WebMock.allow_net_connect!

require 'rails-controller-testing'
RSpec.configure do |config|
  %i[controller view request].each do |type|
    config.include ::Rails::Controller::Testing::TestProcess, type: type
    config.include ::Rails::Controller::Testing::TemplateAssertions, type: type
    config.include ::Rails::Controller::Testing::Integration, type: type
  end
end

def with_thredded_setting(setting, value)
  was = Thredded.send(setting)
  Thredded.send(:"#{setting}=", value)
  yield
ensure
  Thredded.send(:"#{setting}=", was)
end

Dir[Rails.root.join('..', '..', 'spec', 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config| # rubocop:disable Metrics/BlockLength
  config.backtrace_inclusion_patterns << %r{gems/([0-9.])+/gems/(?!rspec|capybara)} if ENV['BACKTRACE']
  config.filter_run_excluding migration_spec: !ENV['MIGRATION_SPEC'], configuration_spec: !ENV['CONFIGURATION_SPEC']
  config.use_transactional_fixtures = !ENV['MIGRATION_SPEC']
  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods
  config.include ActiveSupport::Testing::TimeHelpers

  if ENV['MIGRATION_SPEC']
    config.before(:each, migration_spec: true) do
      DatabaseCleaner.strategy = :transaction unless ThreddedSpecSupport.using_mysql?
      DatabaseCleaner.start unless ThreddedSpecSupport.using_mysql?
    end

    config.after(:each, migration_spec: true) do
      if ThreddedSpecSupport.using_mysql?
        ActiveRecord::Tasks::DatabaseTasks.drop_current
        ActiveRecord::Tasks::DatabaseTasks.create_current
        Thredded::DbTools.restore
      else
        DatabaseCleaner.clean
      end
    end
  end

  config.before(:suite) do
    ActiveJob::Base.queue_adapter = :inline
  end

  config.before do
    Time.zone = 'UTC'
  end
end

require 'capybara/cuprite'

browser_path = ENV['CHROMIUM_BIN'] || %w[
  /usr/bin/chromium-browser
  /snap/bin/chromium
  /Applications/Chromium.app/Contents/MacOS/Chromium
  /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome
].find { |path| File.executable?(path) }

# https://evilmartians.com/chronicles/system-of-a-test-setting-up-end-to-end-rails-testing
Capybara.register_driver(:cuprite) do |app|
  browser_options = {}
  browser_options['no-sandbox'] = nil if ENV['CI']

  options = {
    window_size: [1280, 1024],
    browser_options: browser_options,
    # Increase Chrome startup wait time (required for stable CI builds)
    process_timeout: ENV['CI'] ? 60 : 20,
    # Enable debugging capabilities (except on CI)
    inspector: !ENV['CI'],
    # Allow running Chrome in a headful mode by setting HEADLESS env
    # var to a falsey value
    headless: !ENV['HEADLESS'].in?(%w[n 0 no false])
  }
  options[:browser_path] = browser_path if browser_path
  Capybara::Cuprite::Driver.new(app, **options)
end

RSpec.configure do |config|
  config.before :each, type: :feature, js: true do
    # page.driver.browser.url_blacklist = %r{https://twemoji.maxcdn.com}
    page.driver.browser.url_whitelist = %r{http://127.0.0.1:\d+}
  end
end
Capybara.javascript_driver = ENV['CAPYBARA_JS_DRIVER']&.to_sym || :cuprite
Capybara.configure do |config|
  # bump from the default of 2 seconds because travis can be slow
  config.default_max_wait_time = 5
end

Capybara.asset_host = ENV['CAPYBARA_ASSET_HOST'] if ENV['CAPYBARA_ASSET_HOST']
