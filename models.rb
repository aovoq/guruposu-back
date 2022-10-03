require "bundler/setup"
Bundler.require

ActiveRecord::Base.establish_connection

class User < ActiveRecord::Base
  has_secure_password
  has_many :camps
end

class Camp < ActiveRecord::Base
  belongs_to :user
  has_many :camp_categories
  has_many :teams
end

class CampCategory < ActiveRecord::Base
  belongs_to :camp
end

class Team < ActiveRecord::Base
  belongs_to :user
  belongs_to :camp
  has_many :posts
  has_many :members
end

class Member < ActiveRecord::Base
    has_many :posts
    belongs_to :team
end

class Post < ActiveRecord::Base
    belongs_to :member
    belongs_to :user
    belongs_to :team
end
