class RemoveUnusedActiveStorageTables < ActiveRecord::Migration[8.0]
  def up
    remove_foreign_key :active_storage_variant_records, :active_storage_blobs if foreign_key_exists?(:active_storage_variant_records, :active_storage_blobs)
    remove_foreign_key :active_storage_attachments, :active_storage_blobs if foreign_key_exists?(:active_storage_attachments, :active_storage_blobs)

    drop_table :active_storage_variant_records, if_exists: true
    drop_table :active_storage_attachments, if_exists: true
    drop_table :active_storage_blobs, if_exists: true
  end

  def down
  end
end
