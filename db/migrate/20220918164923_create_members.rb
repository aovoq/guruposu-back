class CreateMembers < ActiveRecord::Migration[6.1]
  def change
    create_table :members do |t|
      t.string :name
      t.integer :pass
      t.string :icon_url
      t.integer :team_id

      t.timestamps
    end

    create_table :team_members do |t|
      t.integer :team_id
      t.integer :member_id

      t.timestamps
    end

  end
end
