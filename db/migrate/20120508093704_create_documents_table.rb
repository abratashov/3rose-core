class CreateDocumentsTable < ActiveRecord::Migration
  def up
    create_table :documents do |t|
      t.integer :id
      t.string  :document_id
      t.integer :category_id
      t.string  :filename
      t.integer :pages
      t.integer :status

      t.timestamps
    end
  end

  def down
    drop_table :documents
  end
end
