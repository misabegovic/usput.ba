# frozen_string_literal: true

require "application_system_test_case"

# The event browser renders under usput's content security policy and shows
# what the admin decided.
class EventBrowserSystemTest < ApplicationSystemTestCase
  test "an admin reads a decision in the event browser" do
    admin = User.create!(username: "sys_events_admin", email: "sys_events_admin@example.com",
                         password: "password123", user_type: :admin).tap(&:confirm)
    traveller = User.create!(username: "sys_events_traveller", email: "sys_events_traveller@example.com",
                             password: "password123").tap(&:confirm)
    DecisionLog.publish(UserBlocked, traveller, by: admin)

    sign_in_as "sys_events_admin"
    visit "/event-store"

    assert_text "UserBlocked"
  ensure
    traveller&.destroy
    admin&.destroy
  end
end
