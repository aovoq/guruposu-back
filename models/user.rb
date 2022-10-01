ActiveRecord::Base.establish_connection

class User < ActiveRecord::Base
   has_secure_password
   has_many :camps
end
