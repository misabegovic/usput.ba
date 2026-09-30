# frozen_string_literal: true

require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @existing_user = User.create!(
      username: "existing_user",
      email: "existing_user@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  teardown do
    @existing_user&.destroy
  end


  test "new renders registration form" do
    get new_user_registration_path

    assert_response :success
  end

  test "registering returns the visitor to the page they came from" do
    get new_user_registration_path, headers: { "HTTP_REFERER" => explore_path }

    post user_registration_path, params: {
      user: {
        username: "returning_user",
        email: "returning_user@example.test",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to explore_path
    User.find_by(username: "returning_user")&.destroy
  end

  test "new redirects to root when already logged in" do
    post user_session_path, params: { user: { email: @existing_user.email, password: "password123" } }

    get new_user_registration_path

    assert_redirected_to root_path
  end

  test "create registers new user with valid data" do
    assert_difference "User.count" do
      post user_registration_path, params: {
        user: {
          username: "newuser123",
          email: "newuser123@example.test",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_redirected_to root_path
    assert_equal I18n.t("devise.registrations.signed_up"), flash[:notice]
    assert_signed_in
  end

  test "create fails with duplicate username" do
    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          username: @existing_user.username,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with case-insensitive duplicate username" do
    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          username: @existing_user.username.upcase,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with short username" do
    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          username: "ab",
          email: "ab@example.test",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with long username" do
    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          username: "a" * 31,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with invalid username characters" do
    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          username: "user@name",
          email: "user@name@example.test",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with short password" do
    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          username: "validuser",
          email: "validuser@example.test",
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create fails with password mismatch" do
    assert_no_difference "User.count" do
      post user_registration_path, params: {
        user: {
          username: "validuser",
          email: "validuser@example.test",
          password: "password123",
          password_confirmation: "different123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create merges travel profile from localStorage" do
    travel_profile = {
      "visited" => [ { "id" => "test-location" } ],
      "favorites" => [ "fav-1" ]
    }.to_json

    post user_registration_path, params: {
      user: {
        username: "newuser_profile",
        email: "newuser_profile@example.test",
        password: "password123",
        password_confirmation: "password123"
      },
      travel_profile_data: travel_profile
    }

    assert_redirected_to root_path

    user = User.find_by(username: "newuser_profile")
    assert_equal [ "fav-1" ], user.travel_profile_data["favorites"]
    assert_empty user.travel_profile_data["visited"], "visited comes from PlanVisit, not the browser"

    user.destroy
  end

  test "create ignores invalid travel profile JSON" do
    post user_registration_path, params: {
      user: {
        username: "newuser_invalid",
        email: "newuser_invalid@example.test",
        password: "password123",
        password_confirmation: "password123"
      },
      travel_profile_data: "invalid json {{{"
    }

    assert_redirected_to root_path

    user = User.find_by(username: "newuser_invalid")
    user&.destroy
  end

  test "create syncs plans from localStorage" do
    # Create an experience first
    location = Location.create!(
      name: "Test Location",
      city: "Sarajevo",
      lat: 43.8563,
      lng: 18.4131
    )

    experience = Experience.create!(
      title: "Test Experience"
    )
    experience.add_location(location, position: 1)

    plans_data = [
      {
        "id" => "local-plan-1",
        "city_name" => "Sarajevo",
        "duration_days" => 2,
        "days" => [
          {
            "day_number" => 1,
            "experiences" => [
              { "id" => experience.uuid }
            ]
          }
        ]
      }
    ].to_json

    post user_registration_path, params: {
      user: {
        username: "newuser_plans",
        email: "newuser_plans@example.test",
        password: "password123",
        password_confirmation: "password123"
      },
      plans_data: plans_data
    }

    assert_redirected_to root_path

    user = User.find_by(username: "newuser_plans")
    assert user.plans.exists?

    user.destroy
    experience.destroy
    location.destroy
  end

  test "create ignores invalid plans JSON" do
    post user_registration_path, params: {
      user: {
        username: "newuser_badplans",
        email: "newuser_badplans@example.test",
        password: "password123",
        password_confirmation: "password123"
      },
      plans_data: "invalid json"
    }

    assert_redirected_to root_path

    User.find_by(username: "newuser_badplans")&.destroy
  end

  test "create prevents SQL injection in username" do
    post user_registration_path, params: {
      user: {
        username: "'; DROP TABLE users; --",
        email: "'; DROP TABLE users; --@example.test",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    # Should fail validation, not execute SQL
    assert_response :unprocessable_entity
  end

  test "create handles XSS attempt in username" do
    post user_registration_path, params: {
      user: {
        username: "<script>alert('xss')</script>",
        email: "<script>alert('xss')</script>@example.test",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    # Should fail validation due to invalid characters
    assert_response :unprocessable_entity
  end

  test "create accepts username with underscore" do
    post user_registration_path, params: {
      user: {
        username: "valid_user_name",
        email: "valid_user_name@example.test",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to root_path

    User.find_by(username: "valid_user_name")&.destroy
  end

  test "create accepts username with numbers" do
    post user_registration_path, params: {
      user: {
        username: "user123",
        email: "user123@example.test",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to root_path

    User.find_by(username: "user123")&.destroy
  end

  test "create normalizes username to lowercase" do
    post user_registration_path, params: {
      user: {
        username: "MixedCaseUser",
        email: "MixedCaseUser@example.test",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_redirected_to root_path

    user = User.find_by(username: "mixedcaseuser")
    assert user.present?
    user.destroy
  end

  test "registration requires an email" do
    assert_no_difference "User.count" do
      post user_registration_path, params: { user: { username: "noemail", password: "password123", password_confirmation: "password123" } }
    end

    assert_response :unprocessable_entity
  end

  test "registration refuses an email that is not an address" do
    assert_no_difference "User.count" do
      post user_registration_path, params: { user: { username: "bademail", email: "not-an-address", password: "password123", password_confirmation: "password123" } }
    end

    assert_response :unprocessable_entity
  end

  test "registration stores the email trimmed and in lower case" do
    post user_registration_path, params: { user: { username: "mixedcase", email: "  Ime.Prezime@Example.TEST ", password: "password123", password_confirmation: "password123" } }

    assert_equal "ime.prezime@example.test", User.find_by(username: "mixedcase").email
  end

  test "an email already in use in another case is refused" do
    User.create!(username: "firstowner", email: "shared@example.test", password: "password123")

    assert_no_difference "User.count" do
      post user_registration_path, params: { user: { username: "secondowner", email: "Shared@Example.test", password: "password123", password_confirmation: "password123" } }
    end

    assert_response :unprocessable_entity
  end

  test "registering signs the new traveller in and sends a confirmation link" do
    perform_enqueued_jobs do
      post user_registration_path, params: { user: { username: "freshsession", email: "fresh@example.test", password: "password123", password_confirmation: "password123" } }
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "fresh@example.test" ], mail.to
    assert_equal I18n.t("devise.mailer.confirmation_instructions.subject"), mail.subject
    assert_not User.find_by(username: "freshsession").confirmed?
    assert_signed_in
  end

  test "the link in the confirmation email confirms the account" do
    perform_enqueued_jobs do
      post user_registration_path, params: { user: { username: "confirming", email: "confirming@example.test", password: "password123", password_confirmation: "password123" } }
    end
    token = ActionMailer::Base.deliveries.last.text_part.body.to_s[/confirmation_token=([^\s&]+)/, 1]

    get user_confirmation_path(confirmation_token: token)

    assert User.find_by(username: "confirming").confirmed?
    assert_equal I18n.t("devise.confirmations.confirmed"), flash[:notice]
  end

  test "the confirmation email is written in the visitor's language" do
    perform_enqueued_jobs do
      post user_registration_path(locale: :bs), params: { user: { username: "bosanski", email: "bosanski@example.test", password: "password123", password_confirmation: "password123" } }
    end

    assert_equal I18n.t("devise.mailer.confirmation_instructions.subject", locale: :bs), ActionMailer::Base.deliveries.last.subject
  end

  test "the username can be changed from the account page" do
    sign_in @existing_user

    put user_registration_path, params: { user: { username: "renamed_user", current_password: "password123" } }

    assert_equal "renamed_user", @existing_user.reload.username
  end

  test "deleting an account is not offered yet" do
    sign_in @existing_user

    assert_no_difference "User.count" do
      delete user_registration_path
    end
    assert_response :not_found
  end

  test "the eleventh registration from one address in an hour is refused" do
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    10.times do |i|
      post user_registration_path, params: { user: { username: "burst#{i}", email: "burst#{i}@example.test", password: "password123", password_confirmation: "password123" } }
      delete destroy_user_session_path
    end

    assert_no_difference "User.count" do
      post user_registration_path, params: { user: { username: "burst10", email: "burst10@example.test", password: "password123", password_confirmation: "password123" } }
    end
    assert_redirected_to new_user_session_path
  ensure
    Rails.cache = original
  end
end
