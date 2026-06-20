# frozen_string_literal: true

class ChangeUniqueIndexFormulariosTurmaTemplatePublicoAlvo < ActiveRecord::Migration[8.1]
  def change
    remove_index :formularios, column: %i[turma_id publico_alvo]
    add_index :formularios, %i[turma_id template_id publico_alvo], unique: true
  end
end
