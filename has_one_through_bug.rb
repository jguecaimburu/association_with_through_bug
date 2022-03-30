begin
  require "bundler/inline"
rescue LoadError => e
  $stderr.puts "Bundler version 1.10 or later is required. Please update your Bundler"
  raise e
end

gemfile(true) do
  source "https://rubygems.org"

  git_source(:github) { |repo| "https://github.com/#{repo}.git" }

  gem "activerecord", "~> 6.1.3.1"
  gem "sqlite3"
end

require "active_record"
require "minitest/autorun"
require "logger"

# This connection will do for database-independent bug reports.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :posts, force: true

  create_table :users, force: true

  create_table :sources, force: true do |t|
    t.boolean :online, null: false, default: true
  end

  create_table :comments, force: true do |t|
    t.references :post
    t.references :user
    t.references :source
  end
end

class Post < ActiveRecord::Base
  has_many :comments
  has_many :online_comments, ->{ joins(:source).where(sources: {online: true}) }, class_name: "Comment"
  has_many :online_users, through: :online_comments, source: :user
end

class User < ActiveRecord::Base
end

class Source < ActiveRecord::Base
end

class Comment < ActiveRecord::Base
  belongs_to :source
  belongs_to :post
  belongs_to :user
end

class BugTest < Minitest::Test
  def test_association
    Comment.create!(post: Post.create!, source: Source.create!(online: true), user: User.create!)
    post = Post.first!
    assert_equal post.online_comments, [Comment.first!]
    assert_equal post.online_users, [User.first!] # Fails with `ActiveRecord::StatementInvalid: SQLite3::SQLException: no such column: sources.online: SELECT "users".* FROM "users" INNER JOIN "comments" ON "users"."id" = "comments"."user_id" WHERE "comments"."post_id" = ? AND "sources"."online" = ?`
  end
end
