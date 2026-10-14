# frozen_string_literal: true

require "test_helper"

# The browser floor is iOS 15.4, Chrome 99, Samsung Internet 18 and Firefox 115
# (wiki/decisions/support-phones-from-ios-15.md), and the JavaScript is served
# as written, with no transpiling. These are the features above that floor
# that are easy to reach for; any of them breaks every page on an older phone.
class JavascriptFloorTest < ActiveSupport::TestCase
  ABOVE_FLOOR = {
    /\bstatic\s*\{/ => "class static blocks (Safari 16.4)",
    /\.(toSorted|toReversed|toSpliced)\(/ => "change-by-copy array methods (Chrome 110, Safari 16)",
    /\b(Object|Map)\.groupBy\(/ => "groupBy (Chrome 117, Safari 17.4)",
    /\bPromise\.withResolvers\(/ => "Promise.withResolvers (Chrome 119, Safari 17.4)",
    /\bArray\.fromAsync\(/ => "Array.fromAsync (Chrome 121, Safari 16.4)",
    /\.(union|intersection|difference|isSubsetOf)\(new Set/ => "Set methods (Chrome 122, Safari 17)"
  }.freeze

  def sources
    Dir[Rails.root.join("app/javascript/**/*.js")] + Dir[Rails.root.join("vendor/javascript/*.js")]
  end

  test "no script uses a feature above the browser floor" do
    offences = sources.flat_map do |path|
      File.readlines(path).each_with_index.flat_map do |line, index|
        ABOVE_FLOOR.filter_map { |pattern, feature| "#{path.delete_prefix("#{Rails.root}/")}:#{index + 1} #{feature}" if line.match?(pattern) }
      end
    end

    assert_empty offences
  end

  test "local and session storage are reached through safe_storage, which survives private browsing" do
    direct = sources.reject { |path| path.end_with?("safe_storage.js") }.select do |path|
      File.read(path).match?(/(?<![\w.])(window\.)?(localStorage|sessionStorage)\.(getItem|setItem|removeItem)\(/)
    end

    assert_empty direct.map { |path| path.delete_prefix("#{Rails.root}/") }
  end
end
