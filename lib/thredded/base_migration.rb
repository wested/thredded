# frozen_string_literal: true

module Thredded
  class BaseMigration < (Thredded.rails_gte_51? ? ActiveRecord::Migration[5.1] : ActiveRecord::Migration)
    protected

    def user_id_type
      Thredded.user_class.columns.find { |c| c.name == Thredded.user_class.primary_key }.sql_type
    end

    def column_type(table, column_name)
      column_name = column_name.to_s
      columns(table).find { |c| c.name == column_name }.sql_type
    end

    # @return [Integer, nil] the maximum number of codepoints that can be indexed for a primary key or index.
    def max_key_length
      return nil unless connection.adapter_name =~ /mysql|maria/i
      # Conservatively assume that innodb_large_prefix is **disabled**.
      # If it were enabled, the maximum key length would instead be 768 utf8mb4 characters.
      191
    end
  end
end
