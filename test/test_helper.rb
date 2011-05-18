# This file is copied to ~/spec when you run 'ruby script/generate rspec'
# from the project root directory.
ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test/unit'

gem 'context'
require 'action_controller/test_process'
require 'action_controller/integration'
require 'context_on_crack'
require 'rr'
require 'matchy'
require 'faker'
require File.join(File.dirname(__FILE__), 'blueprints')

#require "webrat"
#Webrat.configure do |config|
#  config.mode = :rails
#end

[Test::Unit::TestCase, ActionController::TestCase, ActionController::IntegrationTest].each do |test_case|
  test_case.before do
    Sham.reset
    ActiveRecord::Base.connection.increment_open_transactions
    ActiveRecord::Base.connection.begin_db_transaction
  end

  test_case.after do
    ActiveRecord::Base.connection.rollback_db_transaction
    ActiveRecord::Base.verify_active_connections!
  end
end

class Test::Unit::TestCase
  include RR::Adapters::RRMethods

  class << self
    attr_accessor :suite_context
  end

  before do
    @all_jobs = nil
    RR.reset
  end

  after do
    RR.verify
  end

  def self.fixtures(options = {}, &block)
    fixture = FixtureRunner.new(block, options)
    before(:all) { fixture.run(self) }
  end

  def self.run_once(options = {}, &block)
    fixtures(options.update(:skip_transactions => true), &block)
  end

  def self.transaction(&block)
    ActiveRecord::Base.transaction &block
  end

  def transaction(&block)
    ActiveRecord::Base.transaction &block
  end

  def self.cleanup(*klasses)
    before :all do
      transaction { klasses.each { |k| k.delete_all } }
    end
  end

  def assert_hash_equal(expected, actual)
    assert_equal expected, actual, "Hash diff: #{expected.diff(actual).inspect}"
  end

  def cleanup(*klasses)
    klasses.each { |k| k.delete_all }
  end

  def pending(msg)
    assert(false, msg)
  end

  # Sets the current user in the session from the user fixtures.
  def login_as(user)
    @request.session[:user_id] = user ? instance_variable_get("@#{user}").id : nil
  end


  def assert_job(klass, attributes = {})
    @all_jobs ||= Delayed::Job.all
    job  = @all_jobs.detect { |j| j.payload_object.is_a?(klass) }
    assert job
    attributes.each do |key, value|
      assert_equal value, job.payload_object.send(key)
    end
  end

  def assert_no_job(klass)
    @all_jobs ||= Delayed::Job.all
    assert_nil @all_jobs.detect { |j| j.payload_object.is_a?(klass) }, "#{klass} is a loaded job :("
  end

  def run_job(klass, attributes = {})
    @all_jobs ||= Delayed::Job.all
    jobs = @all_jobs.select do |j|
      if j.payload_object.is_a?(klass) && attributes.keys.all? { |key| j.payload_object.send(key) == attributes[key] }
        #puts "RUNNING #{j.payload_object.inspect}"
        j.payload_object.perform
        @all_jobs.delete(j)
        j.destroy
      end
    end
    if jobs.empty?
      raise "no #{klass} job(s) matching #{attributes.inspect}"
    else
      jobs
    end
  end

  def stub_open_id_consumer(url)
    @openid_url = url
    @open_id_consumer = "Open ID Consumer"
    stub(@open_id_consumer).add_extension
    stub(@open_id_consumer).begin {@open_id_consumer}
    stub(@controller).open_id_consumer {@open_id_consumer}
    stub(@controller).add_simple_registration_fields
    stub(@controller).open_id_redirect_url {@openid_url}
  end

  def stub_open_id_result(url, success = true)
    @openid_url = url
    @open_id_result = "Result"
    stub(@open_id_result).successful? {success}
    stub(@controller).complete_open_id_authentication.yields(@open_id_result, @openid_url)
  end

  def set_cookie(name, value, expiration)
    @request.cookies[name] = CGI::Cookie.new('name' => name, 'value' => value, 'expires' => expiration)
  end

  # rspec
  def mock_user
    user = mock_model(User, :id => 1,
      :email  => 'user_name@example.com',
      :name   => 'U. Surname',
      :to_xml => "User-in-XML", :to_json => "User-in-JSON", 
      :errors => [])
    user
  end  
end

class FixtureRunner
  class << self
    attr_accessor :skipped_ivars
  end

  self.skipped_ivars = Set.new(["@test_passed", "@values", "@method_name"])

  attr_reader :proc, :values

  # :skip_transaction => true
  def initialize(proc, options = {})
    @proc    = proc
    @options = options
  end

  def run(binding)
    if !already_run?
      binding.instance_variables.each do |ivar|
        next if self.class.skipped_ivars.include?(ivar)
        instance_variable_set ivar, binding.instance_variable_get(ivar)
      end
      existing = instance_variables
      action   = lambda { instance_eval &@proc }
      @options[:skip_transaction] ? action.call : transaction(&action)
      store_values_except existing
    end
    values = @values
    reload_method = method(:reload_or_use)
    binding.instance_eval do
      values.each do |key, value|
        instance_variable_set key, reload_method.call(value)
      end
    end
  end

  def store_values_except(existing)
    @values = {}
    (instance_variables - existing).each do |ivar|
      @values[ivar] = instance_variable_get(ivar)
    end
  end

  def cleanup(*klasses)
    klasses.each { |k| k.delete_all }
  end

  def already_run?
    !@values.blank?
  end

  def transaction
    ActiveRecord::Base.transaction { yield }
  end

  def reload_or_use(value)
    value.class.respond_to?(:find) ? value.class.find(value.id) : value
  end
end

module MailerSpecHelper
  def self.included(base)
    base.send :include, ActionMailer::Quoting
  end

  def sample_email(options = {})
    email = TMail::Mail.new
    email.set_content_type 'text', 'plain', { 'charset' => 'utf-8' }
    email.mime_version = '1.0'
    if to = options.delete(:to)
      email.to = (to.is_a?(Symbol) ? users(to).email : to.to_s)
    end
    if fixture_name = options.delete(:body)
      email.body = read_fixture(fixture_name)
    end
    options.each do |key, value|
      email.send("#{key}=", value)
    end
    email
  end

private
  def read_fixture(action)
    IO.read(File.join(RAILS_ROOT, 'test', 'fixtures', 'mail', action.to_s))
  end
end

module ModelsWithAnonymousUserAssociationsTests
  def self.included(base)
    base.before do
      @record.send("#{@prefix}user_id=",    nil)
      @record.send("#{@prefix}user_name=",  'bob')
      @record.send("#{@prefix}user_email=", 'bob@whatever.com')
    end

    base.it "#author returns a dynamic User record with no user_id" do
      @record.send("#{@prefix}author").name.should  == @record.send("#{@prefix}user_name")
      @record.send("#{@prefix}author").email.should == @record.send("#{@prefix}user_email")
    end

    base.it "#author returns set User record with user_id" do
      @record.send("#{@prefix}user_id=", @user.id)
      @record.send("#{@prefix}author").name.should  == @user.name
      @record.send("#{@prefix}author").email.should == @user.email
    end

    base.it "downcases #user_email" do
      @record.send("#{@prefix}user_email=", "FOO@BAR.com")
      @record.send("#{@prefix}user_email").should == 'foo@bar.com'
    end
  end
end

module ModelsWithAnonymousUserValidationsTests
  def self.included(base)
    base.before do
      @record.send("user_id=",    nil)
      @record.send("user_name=",  'bob')
      @record.send("user_email=", 'bob@whatever.com')
    end

    base.it "clears #user_name and #user_email when setting #user_id" do
      @record.user_id = @user.id
      @record.valid?
      assert @record.user_name.blank?
      assert @record.user_email.blank?
    end

    base.it "is invalid with invalid user_id" do
      @record.user_id    = 1234
      @record.user_name  = nil
      @record.user_email = nil
      @record.valid?
      @record.errors.on(:user_email).should_not == nil
    end

    base.it "is valid with just a valid user" do
      @record.user = @user
      assert @record.valid?
    end

    base.it "is valid with anonymous user" do
      assert @record.valid?
    end

    base.it "is invalid without #user_email" do
      @record.user_email = nil
      @record.valid?
      @record.errors.on(:user_email).should_not == nil
    end
  end
end

class ActionController::IntegrationTest
  def current_path
    URI(current_url).path
  end
end

class ApiTest < ActionController::IntegrationTest
  def login_as(user)
    @auth = user
  end

  def api_prefix(*args)
    @api_prefix = args.map! { |a| a.to_param } * "/"
  end

  def get(path, json = nil, headers = nil)
    process_api_request(path, json, headers) { |p, params, h| super(p, params, h) }
  end

  def post(path, json = nil, headers = nil)
    process_api_request(path, json, headers) { |p, params, h| super(p, params, h) }
  end

  def put(path, json = nil, headers = nil)
    process_api_request(path, json, headers) { |p, params, h| super(p, params, h) }
  end

  def delete(path, json = nil, headers = nil)
    process_api_request(path, json, headers) { |p, params, h| super(p, params, h) }
  end

private
  def process_api_request(path, json = nil, headers = nil)
    headers ||= {}
    headers[:authorization] = ActionController::HttpAuthentication::Basic.encode_credentials(@auth.email, 'monkey') if @auth
    headers['Accept']       = Mime::TS1.to_s
    full_path = "#{@api_prefix}/#{path}"
    data = {}
    if json && json.respond_to?(:key?) && json.key?(:params)
      data.update(json.delete(:params))
    end
    if !json.blank?
      data = json.to_json
      headers['Content-Type']  = Mime::TS1.to_s
    end
    status = yield(full_path, data, headers)
    status.to_s =~ /^20(0|1)$/ ? ActiveSupport::JSON.decode(response.body) : status
  end
end