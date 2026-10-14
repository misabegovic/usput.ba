# frozen_string_literal: true

require "test_helper"

class Maps::IpPositionTest < ActiveSupport::TestCase
  Response = Struct.new(:body) do
    def is_a?(klass) = klass == Net::HTTPSuccess || super
  end

  test "asks with a two-second limit and reads the position" do
    seen = nil
    http = Object.new
    http.define_singleton_method(:get) { |_path| Response.new({ status: "success", lat: 43.85, lon: 18.41 }.to_json) }
    start = ->(host, port, **options, &block) { seen = [ host, port, options ]; block.call(http) }

    Net::HTTP.stub(:start, start) do
      assert_equal [ 43.85, 18.41 ], Maps::IpPosition.new("8.8.8.8").send(:lookup)
    end

    assert_equal [ "ip-api.com", 80, { open_timeout: 2, read_timeout: 2 } ], seen
  end

  test "a lookup that times out is no position, not an error" do
    Net::HTTP.stub(:start, ->(*, **) { raise Net::ReadTimeout }) do
      assert_nil Maps::IpPosition.new("8.8.8.8").send(:lookup)
    end
  end

  test "a private address is never looked up" do
    Net::HTTP.stub(:start, ->(*, **) { flunk "a private address must not leave the server" }) do
      assert_nil Maps::IpPosition.call("192.168.1.10")
    end
  end
end
