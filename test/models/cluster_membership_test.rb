# frozen_string_literal: true

require "test_helper"

class ClusterMembershipTest < ActiveSupport::TestCase
  setup do
    KnowledgeCluster.delete_all
    ClusterMembership.delete_all

    @cluster = KnowledgeCluster.create!(
      slug: "test-cluster",
      name: "Test Cluster"
    )

    @location = Location.create!(
      name: "Test Location",
      city: "TestCity",
      lat: 43.5,
      lng: 18.5
    )
  end

  test "validates record_type presence" do
    membership = ClusterMembership.new(
      knowledge_cluster: @cluster,
      record_id: 1
    )
    assert_not membership.valid?
    assert membership.errors[:record_type].any?
  end

  test "validates record_id presence" do
    membership = ClusterMembership.new(
      knowledge_cluster: @cluster,
      record_type: "Location"
    )
    assert_not membership.valid?
    assert membership.errors[:record_id].any?
  end

  test "validates uniqueness of cluster + record" do
    ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: @location.id
    )

    duplicate = ClusterMembership.new(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: @location.id
    )
    assert_not duplicate.valid?
  end

  test "creates valid membership" do
    membership = ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: @location.id,
      similarity_score: 0.85
    )

    assert membership.persisted?
    assert_equal @cluster, membership.knowledge_cluster
    assert_equal "Location", membership.record_type
    assert_equal @location.id, membership.record_id
    assert_equal 0.85, membership.similarity_score
  end

  test "for_locations scope filters by record_type" do
    location_membership = ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: @location.id
    )

    # Create an experience to have a different membership
    experience = Experience.create!(
      title: "Test Experience",
      description: "Test"
    )

    experience_membership = ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Experience",
      record_id: experience.id
    )

    result = ClusterMembership.for_locations

    assert_includes result, location_membership
    assert_not_includes result, experience_membership
  end

  test "by_similarity scope orders by similarity_score descending" do
    low = ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: @location.id,
      similarity_score: 0.3
    )

    # Create another location for the second membership
    another_location = Location.create!(name: "Another", city: "Test", lat: 44.0, lng: 19.0)

    high = ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: another_location.id,
      similarity_score: 0.9
    )

    result = ClusterMembership.by_similarity

    assert_equal high, result.first
    assert_equal low, result.last
  end

  test "record association returns polymorphic record" do
    membership = ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: @location.id
    )

    assert_equal @location, membership.record
  end

  test "records_for_cluster returns memberships for specific cluster" do
    # Create membership for our cluster
    membership = ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: @location.id
    )

    # Create another cluster and membership
    other_cluster = KnowledgeCluster.create!(slug: "other", name: "Other")
    other_location = Location.create!(name: "Other", city: "Test", lat: 44.0, lng: 19.0)
    other_membership = ClusterMembership.create!(
      knowledge_cluster: other_cluster,
      record_type: "Location",
      record_id: other_location.id
    )

    result = ClusterMembership.records_for_cluster(@cluster)

    assert_includes result, membership
    assert_not_includes result, other_membership
  end

  test "for_experiences scope filters by experience record_type" do
    experience = Experience.create!(title: "Test", description: "Test")

    experience_membership = ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Experience",
      record_id: experience.id
    )

    location_membership = ClusterMembership.create!(
      knowledge_cluster: @cluster,
      record_type: "Location",
      record_id: @location.id
    )

    result = ClusterMembership.for_experiences

    assert_includes result, experience_membership
    assert_not_includes result, location_membership
  end
end
