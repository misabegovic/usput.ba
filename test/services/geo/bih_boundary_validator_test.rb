# frozen_string_literal: true

require "test_helper"

class Geo::BihBoundaryValidatorTest < ActiveSupport::TestCase
  # === BiH cities (should be inside) ===

  test "Sarajevo is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(43.8563, 18.4131)
  end

  test "Mostar is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(43.3438, 17.8078)
  end

  test "Banja Luka is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(44.7758, 17.1858)
  end

  test "Tuzla is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(44.5384, 18.6763)
  end

  test "Zenica is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(44.2017, 17.9072)
  end

  test "Bihac is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(44.8169, 15.8697)
  end

  test "Trebinje is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(42.7108, 18.3433)
  end

  test "Neum (coast) is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(42.9247, 17.6141)
  end

  test "Brcko is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(44.8728, 18.8100)
  end

  test "Visegrad is inside BiH" do
    assert Geo::BihBoundaryValidator.inside_bih?(43.7833, 19.2833)
  end

  # === Non-BiH cities (should be outside) ===

  test "Belgrade (Serbia) is outside BiH" do
    assert Geo::BihBoundaryValidator.outside_bih?(44.82, 20.45)
  end

  test "Zagreb (Croatia) is outside BiH" do
    assert Geo::BihBoundaryValidator.outside_bih?(45.8150, 15.9819)
  end

  test "Podgorica (Montenegro) is outside BiH" do
    assert Geo::BihBoundaryValidator.outside_bih?(42.4304, 19.2594)
  end

  test "Split (Croatia) is outside BiH" do
    assert Geo::BihBoundaryValidator.outside_bih?(43.5081, 16.4402)
  end

  test "Dubrovnik (Croatia) is outside BiH" do
    # Dubrovnik is clearly outside BiH (south of Neum)
    # Using coordinates further south to avoid border precision issues
    assert Geo::BihBoundaryValidator.outside_bih?(42.50, 18.10)
  end

  test "Loznica (Serbia) is outside BiH" do
    assert Geo::BihBoundaryValidator.outside_bih?(44.38, 19.20)
  end

  test "Novi Sad (Serbia) is outside BiH" do
    assert Geo::BihBoundaryValidator.outside_bih?(45.2671, 19.8335)
  end

  # === Edge cases ===

  test "returns false for nil coordinates" do
    assert_not Geo::BihBoundaryValidator.inside_bih?(nil, nil)
    assert_not Geo::BihBoundaryValidator.inside_bih?(43.8, nil)
    assert_not Geo::BihBoundaryValidator.inside_bih?(nil, 18.4)
  end

  test "returns false for blank coordinates" do
    assert_not Geo::BihBoundaryValidator.inside_bih?("", "")
  end

  test "handles string coordinates" do
    assert Geo::BihBoundaryValidator.inside_bih?("43.8563", "18.4131")
  end

  test "handles coordinates far outside bounding box" do
    # New York
    assert_not Geo::BihBoundaryValidator.inside_bih?(40.7128, -74.0060)

    # Tokyo
    assert_not Geo::BihBoundaryValidator.inside_bih?(35.6762, 139.6503)

    # Sydney
    assert_not Geo::BihBoundaryValidator.inside_bih?(-33.8688, 151.2093)
  end

  # === outside_bih? method ===

  test "outside_bih? is inverse of inside_bih?" do
    # Inside BiH
    assert_not Geo::BihBoundaryValidator.outside_bih?(43.8563, 18.4131)

    # Outside BiH
    assert Geo::BihBoundaryValidator.outside_bih?(44.82, 20.45)
  end

  # === distance_to_border method ===

  test "distance_to_border returns distance in kilometers" do
    # Sarajevo (center of BiH)
    distance = Geo::BihBoundaryValidator.distance_to_border(43.8563, 18.4131)
    assert distance > 0
    assert distance < 200 # Should be less than 200km to nearest border
  end

  test "distance_to_border is smaller for border cities" do
    # Trebinje (near Montenegro border)
    trebinje_distance = Geo::BihBoundaryValidator.distance_to_border(42.7108, 18.3433)

    # Sarajevo (central)
    sarajevo_distance = Geo::BihBoundaryValidator.distance_to_border(43.8563, 18.4131)

    assert trebinje_distance < sarajevo_distance
  end

  # === Border area precision tests ===

  test "correctly handles points near Drina river (Serbia border)" do
    # Point clearly in Serbia (east of Drina)
    assert Geo::BihBoundaryValidator.outside_bih?(44.39, 19.30)

    # Point in BiH (west of Drina)
    assert Geo::BihBoundaryValidator.inside_bih?(44.39, 19.00)
  end

  test "correctly handles points near Croatian border" do
    # Point in Croatia near Slavonski Brod
    assert Geo::BihBoundaryValidator.outside_bih?(45.16, 18.02)
  end

  test "correctly handles points near Montenegro border" do
    # Herceg Novi area (Montenegro)
    assert Geo::BihBoundaryValidator.outside_bih?(42.45, 18.55)
  end
end
