require 'faker'

class FakeDataGenerator
  def initialize(users_count, stories_count, categories_count)
    @users_count = users_count
    @stories_count = stories_count
    @categories_count = categories_count
  end

  def generate
    # Users and Moderators
    users = []
    0.upto(@users_count).each do |i|
      name = Faker::Name.name
      password = Faker::Internet.password
      create_args = {
        email: Faker::Internet.email(name: name),
        password: password,
        password_confirmation: password,
        username: Faker::Internet.user_name(specifier: name, separators: %w(_)),
        created_at: (User::NEW_USER_DAYS + 1).days.ago,
      }
      create_args.merge!(is_moderator: true) if i % 7 == 0
      users << User.create!(create_args)
    end

    # Categories
    categories = []
    @categories_count.times do
      categories << Category.create!(category: Faker::Lorem.word.capitalize)
    end

    # Stories
    @stories_count.times do |i|
      user = users[Random.rand(@users_count-1)]
      title = Faker::Lorem.sentence(word_count: 3)
      category = categories[Random.rand(@categories_count)]
      tag_name = title.split(' ').first.downcase
      tag = Tag.find_by tag: tag_name
      tag ||= Tag.create! tag: tag_name, category: category
      if i.even?
        Story.create! user: user, title: title, url: Faker::Internet.url, tags_a: [tag.tag]
      else
        Story.create! user: user,
          title: title,
          description: Faker::Lorem.paragraphs(number: 3).join("\n\n"),
          tags_a: [tag.tag]
      end
    end

    # User-deleted stories. The stories are created here and deleted after
    # adding comments.
    deleted_stories = []
    (@stories_count / 10).times do
      user = users[Random.rand(@users_count-1)]
      title = Faker::Lorem.sentence(word_count: 3)
      category = categories[Random.rand(@categories_count-1)]
      tag_name = title.split(' ').first.downcase
      tag = Tag.find_by tag: tag_name
      tag ||= Tag.create! tag: tag_name, category: category
      deleted_story = Story.create! user: user,
        title: title,
        tags_a: [tag.tag],
        description: Faker::Lorem.paragraphs(number: 1),
        editor: user
      deleted_stories << deleted_story
    end

    # Comments
    Story.all.each do |x|
      Random.rand(1..3).times do |i|
        c = Comment.create! user: users[Random.rand(@users_count-1)],
          comment: Faker::Lorem.sentence(word_count: Random.rand(30..50)),
          story_id: x.id
        # Replies to comments
        if i.odd?
          Comment.create! user: x.user,
            comment: Faker::Lorem.sentence(word_count: Random.rand(30..50)),
            story_id: x.id,
            parent_comment_id: c.id
        end
      end
    end

    # Delete the stories marked for deletion before adding comments.
    deleted_stories.each do |story|
      story.update(is_deleted: true)
    end

    # Hats
    (@users_count / 2).times do |i|
      suffixes = ["Developer", "Founder", "User", "Contributor", "Creator"]
      Hat.create! user: users[i + 1],
        granted_by_user: users[0],
        hat: Faker::Lorem.word.capitalize + " " + suffixes[Random.rand(5)],
        link: Faker::Internet.url
    end

    ### Moderation ###

    # Comments (delete/undelete)
    Comment.all.each_with_index do |comment, i|
      comment_mod = users.detect(&:is_moderator)
      if i % 7 == 0
        comment.delete_for_user(comment_mod, Faker::Lorem.paragraphs(number: 1))
        comment.undelete_for_user(comment_mod) if i.even?
      end
    end
  end
end

desc 'Generates fake data for testing purposes'
task fake_data: :environment do
  fail "Refusing to add fake-data to a non-development environment" unless Rails.env.development?

  record_count = User.count + Tag.count + Story.count + Comment.count
  if record_count > 3 # more than would be created by db:seed
    warn "Database has #{record_count} records, are you sure you want to add more? [y to continue]"
    fail "Cancelled" if STDIN.gets.chomp != 'y'
  end

  FakeDataGenerator.new(20, 200, 5).generate
end
