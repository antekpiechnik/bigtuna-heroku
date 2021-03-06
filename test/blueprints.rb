require "machinist/active_record"

Sham.define do
  name { Faker::Name.name }
  email { Faker::Internet.user_name + "@example.org" }
  commit(:unique => false) { "a" * 40 }
end

Project.blueprint do
  name { Sham.name }
  max_builds { 3 }
  vcs_type { "git" }
  vcs_source { "test/files/repo" }
  vcs_branch { "master" }
end

Build.blueprint do
  project { Project.make }
  scheduled_at { Time.now }
  commit { Sham.commit }
end
