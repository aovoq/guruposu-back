class CreatePosts < ActiveRecord::Migration[6.1]
  def change
    create_table :posts do |t|
      t.string :body
      t.string :image_urls, array: true, default: []
      t.integer :team_id
      t.integer :member_id
      t.integer :user_id

      t.timestamps null: false
    end
  end
end
