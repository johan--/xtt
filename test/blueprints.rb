user_time = Time.utc 2007, 1, 1
User.class_eval do
  blueprint do
    login           { "normal-user-#{rand(500)}" }
    aasm_state      "active"
    # site         { Site.make }
    # name           { Faker::Name.name }
    email           { Faker::Internet.email(login.gsub(/[^\w]/, '').downcase) }
    time_zone       "UTC"
    permalink       "normal-user"
    remember_token  { "foo-bar" }
    remember_token_expires_at { user_time + 5.days }
    activated_at    { user_time - 4.days }
    created_at      { activated_at }
    updated_at      { activated_at }
    activation_code  '8f24789ae988411ccf33ab0c30fe9106fab32e9b'
    salt             '7e3041ebc2fc05a40c60028e2c4901a81035d3cd'
    crypted_password '00742970dc9e6319f8019fd54864d3ea740f04b1'
  end
end

Project.blueprint do
  name { "Project #{rand(100)}" }
  user
  code { "abc#{rand(500)}" }
  # permalink { "Project-#{rand(100)}" }
end

Membership.blueprint do
  user
  project
end

UserContext.blueprint do
  user
  name { "My context #{rand(100)}" }
end

Status.blueprint do
  user
  message    "Default"
  aasm_state "processed"
  hours      { 5 }
  created_at { user_time - 2.days }
end
