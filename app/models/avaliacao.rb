# frozen_string_literal: true

class Avaliacao < ApplicationRecord
  enum :responida, {
    nao_respondido: 0,
    respondido: 1
  }

  belongs_to :participacao_turma,
    class_name: "ParticipacaoTurma",
    inverse_of: :avaliacoes

  belongs_to :formulario,
    class_name: "Formulario",
    inverse_of: :avaliacoes

  has_many :respostas,
    class_name: "Resposta",
    dependent: :destroy,
    inverse_of: :avaliacao

  validates :participacao_turma, presence: true
  validates :formulario, presence: true

  validates :participacao_turma_id,
    uniqueness: {
      scope: :formulario_id,
      message: "já possui avaliação para este formulário"
    }

  validate :participacao_deve_ser_da_turma_do_formulario
  validate :participacao_deve_corresponder_ao_publico_alvo

  scope :respondidas, -> { where(responida: :respondido) }
  scope :pendentes, -> { where(responida: :nao_respondido) }

  def respondida?
    respondido?
  end

  def pendente?
    nao_respondido?
  end

  def marcar_como_respondida!
    update!(responida: :respondido, respondido_em: Time.current)
  end

  private

  def participacao_deve_ser_da_turma_do_formulario
    return if participacao_turma.blank?
    return if formulario.blank?
    return if participacao_turma.turma_id == formulario.turma_id

    errors.add(:participacao_turma, "deve pertencer à turma do formulário")
  end

  def participacao_deve_corresponder_ao_publico_alvo
    return if participacao_turma.blank?
    return if formulario.blank?
    return if participacao_turma.corresponde_ao_publico?(formulario.publico_alvo)

    errors.add(:participacao_turma, "não corresponde ao público-alvo do formulário")
  end
end
