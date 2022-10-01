ActiveRecord::Base.establish_connection

class Camp < ActiveRecord::Base
   belongs_to :user
   has_many :camp_categories
end

class CampCategory < ActiveRecord::Base
   belongs_to :camp
end
