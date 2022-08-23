class CreateQuestions < ActiveRecord::Migration[6.1]
  def change
    create_table :questions do |t|
      t.text :question
      t.text :context
      t.text :answer
      t.integer :ask_count, :default => 0

      t.timestamps
    end
  end
end
