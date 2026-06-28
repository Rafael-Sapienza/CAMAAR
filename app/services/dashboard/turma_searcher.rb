# frozen_string_literal: true

module Dashboard
  class TurmaSearcher
    def self.call(termo)
      new(termo).call
    end

    def initialize(termo)
      @termo = termo.to_s.strip
    end

    def call
      match = @termo.match(/\A(.+?)\s+([A-Za-z]|\d{1,2})\z/)
      return Turma.none unless match

      materia_termo = match[1].strip
      return Turma.none if materia_termo.blank?

      buscar_por_materia_e_numero(materia_termo, Turma.numero_de_codigo_exibicao(match[2]))
    end

    private

    def buscar_por_materia_e_numero(materia_termo, numero)
      padrao_materia = "%#{ActiveRecord::Base.sanitize_sql_like(materia_termo.downcase)}%"

      Turma
        .joins(:materia)
        .includes(:materia)
        .where(numero: numero)
        .where(
          "LOWER(materias.nome) LIKE :padrao OR LOWER(materias.codigo) LIKE :padrao",
          padrao: padrao_materia
        )
        .order(:numero)
    end
  end
end
