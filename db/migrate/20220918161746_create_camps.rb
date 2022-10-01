class CreateCamps < ActiveRecord::Migration[6.1]
  def change
    create_table :camps do |t|
      t.string :name
      t.string :location
      t.date :start_date
      t.date :end_date
      t.string :description
      t.integer :user_id
      t.integer :camp_category_id
      t.boolean :archived, default: false

      t.timestamps
   end

   create_table :camp_categories do |t|
      t.string :name
      t.string :image_url

      t.timestamps
    end
  end
end
