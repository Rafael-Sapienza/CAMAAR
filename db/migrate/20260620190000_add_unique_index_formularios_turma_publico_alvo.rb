# frozen_string_literal: true

class AddUniqueIndexFormulariosTurmaPublicoAlvo < ActiveRecord::Migration[8.1]
  def change
    add_index :formularios, %i[turma_id publico_alvo], unique: true
  end
end
