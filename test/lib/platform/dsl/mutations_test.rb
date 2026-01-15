# frozen_string_literal: true

require "test_helper"

class Platform::DSL::MutationsTest < ActiveSupport::TestCase
  setup do
    @existing_location = Location.create!(
      name: "Test Lokacija",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131,
      description: "Originalni opis"
    )
  end

  # Parser tests
  test "parses create command" do
    ast = Platform::DSL::Parser.parse('create location { name: "Nova Lokacija", city: "Mostar" }')

    assert_equal :mutation, ast[:type]
    assert_equal :create, ast[:action]
    assert_equal "location", ast[:table]
    assert_equal "Nova Lokacija", ast[:data][:name]
    assert_equal "Mostar", ast[:data][:city]
  end

  test "parses update command" do
    ast = Platform::DSL::Parser.parse('update location { id: 123 } set { description: "Novi opis" }')

    assert_equal :mutation, ast[:type]
    assert_equal :update, ast[:action]
    assert_equal "location", ast[:table]
    assert_equal 123, ast[:filters][:id]
    assert_equal "Novi opis", ast[:data][:description]
  end

  test "parses delete command" do
    ast = Platform::DSL::Parser.parse('delete location { id: 456 }')

    assert_equal :mutation, ast[:type]
    assert_equal :delete, ast[:action]
    assert_equal "location", ast[:table]
    assert_equal 456, ast[:data][:id]
  end

  # Create tests
  test "creates location successfully" do
    result = Platform::DSL.execute('create location { name: "Nova Lokacija", city: "Mostar", lat: 43.34, lng: 17.81 }')

    assert result[:success]
    assert_equal :create, result[:action]
    assert_equal "Location", result[:record_type]
    assert result[:record_id].present?
    assert_equal "Nova Lokacija", result[:data][:name]

    # Verify record exists
    location = Location.find(result[:record_id])
    assert_equal "Nova Lokacija", location.name
    assert_equal "Mostar", location.city
  end

  test "creates audit log on create" do
    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute('create location { name: "Audit Test", city: "Tuzla" }')
    end

    log = PlatformAuditLog.last
    assert_equal "create", log.action
    assert_equal "Location", log.record_type
    assert_equal "platform_dsl", log.triggered_by
  end

  test "rejects create for location outside BiH" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('create location { name: "Beograd", city: "Beograd", lat: 44.82, lng: 20.45 }')
    end

    assert_match(/unutar granica BiH/i, error.message)
  end

  test "rejects create without required fields" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('create location { lat: 43.85 }')
    end

    assert_match(/Nedostaju obavezna polja/i, error.message)
  end

  # Update tests
  test "updates location successfully" do
    result = Platform::DSL.execute("update location { id: #{@existing_location.id} } set { description: \"Ažurirani opis\" }")

    assert result[:success]
    assert_equal :update, result[:action]
    assert_equal @existing_location.id, result[:record_id]

    # Verify update
    @existing_location.reload
    assert_equal "Ažurirani opis", @existing_location.description
  end

  test "creates audit log on update" do
    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute("update location { id: #{@existing_location.id} } set { description: \"Novi\" }")
    end

    log = PlatformAuditLog.last
    assert_equal "update", log.action
    assert_equal "Location", log.record_type
    assert_equal @existing_location.id, log.record_id
    assert log.change_data["changes"].present?
  end

  test "rejects update for non-existent record" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('update location { id: 999999 } set { description: "Test" }')
    end

    assert_match(/nije pronađen/i, error.message)
  end

  test "rejects update that moves location outside BiH" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute("update location { id: #{@existing_location.id} } set { lat: 44.82, lng: 20.45 }")
    end

    assert_match(/unutar granica BiH/i, error.message)
  end

  # Delete tests
  test "deletes location successfully" do
    location = Location.create!(name: "Za brisanje", city: "Zenica")

    result = Platform::DSL.execute("delete location { id: #{location.id} }")

    assert result[:success]
    assert_equal :delete, result[:action]
    assert_equal location.id, result[:record_id]

    # Verify deleted
    assert_nil Location.find_by(id: location.id)
  end

  test "creates audit log on delete" do
    location = Location.create!(name: "Za brisanje", city: "Zenica")

    assert_difference "PlatformAuditLog.count", 1 do
      Platform::DSL.execute("delete location { id: #{location.id} }")
    end

    log = PlatformAuditLog.last
    assert_equal "delete", log.action
    assert_equal "Location", log.record_type
    assert_equal location.id, log.record_id
  end

  test "rejects delete without identifier" do
    error = assert_raises(Platform::DSL::ExecutionError) do
      Platform::DSL.execute('delete location { }')
    end

    assert_match(/filter za identifikaciju/i, error.message)
  end
end
