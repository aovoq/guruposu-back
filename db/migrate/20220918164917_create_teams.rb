class CreateTeams < ActiveRecord::Migration[6.1]
  def change
    create_table :teams do |t|
      t.string :alphabet
      t.string :name
      t.string :description
      t.string :color
      t.string :unique_id
      t.integer :created_user_id
      t.integer :mentor_user_id
      t.integer :camp_id

      t.timestamps
    end
  end
end
