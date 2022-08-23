require 'faker'
10.times do
  Question.create(
    title: Faker::Lorem.sentence,
    )
end
