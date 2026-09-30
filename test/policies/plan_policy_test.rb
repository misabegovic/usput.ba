# frozen_string_literal: true

require "test_helper"

class PlanPolicyTest < ActiveSupport::TestCase
  setup do
    @curator = User.create!(username: "pp_curator", email: "pp_curator@example.com", password: "password123", user_type: :curator)
    @admin = User.create!(username: "pp_admin", email: "pp_admin@example.com", password: "password123", user_type: :admin)
    @traveller = User.create!(username: "pp_traveller", email: "pp_traveller@example.com", password: "password123")
    @curated = Plan.create!(title: "Curated", city_name: "Mostar")
    @shared = Plan.create!(title: "Shared", city_name: "Mostar", user: @traveller, visibility: :public_plan)
    @private = Plan.create!(title: "Private", city_name: "Mostar", user: @traveller)
  end

  test "curators edit curated plans; only admins delete them" do
    assert PlanPolicy.new(@curator, @curated).update?
    assert_not PlanPolicy.new(@curator, @curated).destroy?
    assert PlanPolicy.new(@admin, @curated).destroy?
  end

  test "a traveller's public plan can be looked at but never changed" do
    assert PlanPolicy.new(@curator, @shared).show?
    assert_not PlanPolicy.new(@curator, @shared).update?
    assert_not PlanPolicy.new(@admin, @shared).destroy?
  end

  test "a traveller's private plan is out of reach" do
    assert_not PlanPolicy.new(@admin, @private).show?
    assert_not_includes PlanPolicy.visible(Plan.all), @private
    assert_includes PlanPolicy.visible(Plan.all), @shared
    assert_includes PlanPolicy.visible(Plan.all), @curated
  end

  test "a traveller never gets in" do
    assert_not PlanPolicy.new(@traveller, @curated).show?
  end
end
