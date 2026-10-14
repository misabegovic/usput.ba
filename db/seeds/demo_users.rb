# frozen_string_literal: true

# Demo accounts for development, one per role. Accounts sign in by email, and
# these are confirmed up front so nobody waits for a mail that never comes.
# Loaded by db/seeds.rb, and on its own by test/db/demo_users_seed_test.rb.

demo_users = [
  { username: "admin", email: "admin@usput.local", password: "admin123", user_type: :admin },
  { username: "curator", email: "curator@usput.local", password: "curator123", user_type: :curator },
  { username: "user", email: "user@usput.local", password: "user123", user_type: :basic }
]

demo_users.each do |user_data|
  User.find_or_create_by!(username: user_data[:username]) do |user|
    user.email = user_data[:email]
    user.password = user_data[:password]
    user.user_type = user_data[:user_type]
    user.skip_confirmation!
  end
end
