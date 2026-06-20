# frozen_string_literal: true

class AddResponidaToAvaliacoes < ActiveRecord::Migration[8.1]
  def change
    add_column :avaliacoes, :responida, :integer, null: false, default: 0
  end
end
