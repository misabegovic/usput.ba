# frozen_string_literal: true

require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  VISITOR = { "REMOTE_ADDR" => "203.0.113.7" }.freeze

  # Each throttle, with a request that should count against it.
  THROTTLED = {
    "plan_sync/ip" => [ "POST", "/user/plans/sync" ],
    "search/ip" => [ "GET", "/plans/search_cities" ],
    "mine-check/ip" => [ "POST", "/mine-check/check" ],
    "mine-areas/ip" => [ "GET", "/mine-check/areas" ],
    "map-route/ip" => [ "GET", "/route" ]
  }.freeze

  setup do
    @original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rack::Attack.cache.store = @original_store
  end

  test "every throttle names a path the app routes" do
    THROTTLED.each do |name, (verb, path)|
      assert Rack::Attack.throttles.key?(name), "#{name} is gone from the initializer"
      assert Rails.application.routes.recognize_path(path, method: verb), "#{name} points at #{verb} #{path}, which is not routed"
    end
  end

  test "every throttle counts its own path and nothing else" do
    THROTTLED.each do |name, (verb, path)|
      block = Rack::Attack.throttles.fetch(name).block

      assert_equal "203.0.113.7", block.call(rack_request(verb, path)), "#{name} should count #{verb} #{path}"
      assert_nil block.call(rack_request(verb, "/explore")), "#{name} should not count /explore"
    end
  end

  test "no throttle is left on a path the app does not have" do
    assert_equal (THROTTLED.keys + [ "req/ip" ]).sort, Rack::Attack.throttles.keys.sort
  end

  test "the city lookup answers 429 after thirty requests in a minute" do
    30.times { get "/plans/search_cities", params: { q: "sa" }, env: VISITOR }
    assert_response :success

    get "/plans/search_cities", params: { q: "sa" }, env: VISITOR

    assert_response :too_many_requests
    assert response.headers["Retry-After"].present?
  end

  test "localhost is never throttled" do
    31.times { get "/plans/search_cities", params: { q: "sa" } }

    assert_response :success
  end

  test "exploit probes are refused before they reach the app" do
    %w[/wp-login.php /.env /phpmyadmin /index.php].each do |path|
      get path, env: VISITOR
      assert_response :forbidden, "#{path} should be blocked"
    end
  end

  private

  def rack_request(verb, path)
    Rack::Request.new(Rack::MockRequest.env_for(path, method: verb, "REMOTE_ADDR" => "203.0.113.7"))
  end
end
