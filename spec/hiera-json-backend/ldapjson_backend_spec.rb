$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

TEST_LDIF_FILE = 'spec/hiera-json-backend/testing.ldif'
TEST_HIERA_CONF = 'spec/hiera-json-backend/test-hiera.yaml'

require 'rspec'
require 'ladle'
require 'hiera'
require 'hiera/backend/ldapjson_backend'
require 'hiera/config'
require 'mocha/setup'
require 'mocha/api'


RSpec.configure do |config|
  config.mock_with :mocha
end


class Hiera
  module Backend
    describe Ldapjson_backend, "" do

      before(:all) do
        @ldap_server = Ladle::Server.new(:tmpdir => '/tmp',
                                         :port => 3897,
                                         :quiet => true,
                                         :domain => 'dc=example,dc=org',
                                         :ldif => TEST_LDIF_FILE).start
      end

      before do
        Hiera::Config.load(TEST_HIERA_CONF)
        Hiera.stubs(:debug)
        Hiera.stubs(:warn)
        Hiera::Backend.stubs(:empty_answer).returns(nil)
        @backend = Ldapjson_backend.new()
      end

      after(:all) do
        @ldap_server.stop if @ldap_server
      end

      describe "#initialize" do
        it "should announce its creation" do # because other specs checks this
          Hiera.expects(:debug).with("Hiera LdapJson backend starting")
          Ldapjson_backend.new
        end
      end

      describe "#lookup" do
        it "should find a single value" do
          Backend.expects(:datasources).multiple_yields(["easy"],
                                                        ["second"])
          @backend.lookup("testkey",
                          {},
                          nil,
                          :priority).should eq("test value one")
        end

        it "should find multiple values" do
          Backend.expects(:datasources).multiple_yields(["easy"],
                                                        ["second"])
          @backend.lookup("testkey",
                          {},
                          nil,
                          :array).should eq(["test value one",
                                             "another tv1"])
        end

        it "should not support hash searches" do
          Backend.expects(:datasources).multiple_yields(["easy"],
                                                        ["second"])
          expect {
            @backend.lookup("testkey",
                            {},
                            nil,
                            :hash)
          }.to raise_error
        end

        it "should return nil on priority no such key" do
          Backend.expects(:datasources).multiple_yields(["easy"],
                                                        ["second"])

          @backend.lookup("not a key",
                          {},
                          nil,
                          :priority).should eq(nil)
        end

        it "should return nil on array no such key" do
          Backend.expects(:datasources).multiple_yields(["easy"],
                                                        ["second"])

          @backend.lookup("not a key",
                          {},
                          nil,
                          :array).should eq(nil)
        end

        it "should return nil on priority no ldap entry" do
          Backend.expects(:datasources).multiple_yields(["squeasy"])

          @backend.lookup("testkey",
                          {},
                          nil,
                          :priority).should eq(nil)
        end

        it "should return nil on array no such key" do
          Backend.expects(:datasources).multiple_yields(["squeasy"])

          @backend.lookup("testkey",
                          {},
                          nil,
                          :array).should eq(nil)
        end

        it "should handle hierarchy in sources" do
          Backend.expects(:datasources).multiple_yields(["triple/nested/source"])

          @backend.lookup("testkey",
                          {},
                          nil,
                          :priority).should eq("nested testkey")
        end

        it "should error with multiple attrs" do
          Backend.expects(:datasources).multiple_yields(["multattrs"])

          expect {
            @backend.lookup("testkey",
                            {},
                            nil,
                            :priority)
          }.to raise_error
        end

      end
    end
  end
end
