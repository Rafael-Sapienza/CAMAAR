# frozen_string_literal: true

class Formulario < ApplicationRecord
  enum :publico_alvo, {
    docentes: 0,
    discentes: 1
  }

  belongs_to :adm,
    class_name: "PerfilAdm",
    foreign_key: :adm_id,
    inverse_of: :formularios

  belongs_to :turma,
    class_name: "Turma",
    inverse_of: :formularios

  belongs_to :template,
    class_name: "Template",
    optional: true,
    inverse_of: :formularios

  has_many :questoes,
    class_name: "Questao",
    dependent: :destroy,
    inverse_of: :formulario

  has_many :avaliacoes,
    class_name: "Avaliacao",
    dependent: :restrict_with_error,
    inverse_of: :formulario

  validates :adm, presence: true
  validates :turma, presence: true
  validates :publico_alvo,
    presence: true,
    uniqueness: {
      scope: %i[turma_id template_id],
      message: "já possui formulário para esta turma e template"
    }

  validate :adm_deve_pertencer_ao_departamento_da_turma

  before_validation :definir_criado_em

  scope :recentes, -> {
    order(criado_em: :desc, id: :desc)
  }

  scope :do_departamento, ->(departamento) {
    joins(turma: :materia)
      .where(materias: { departamento_id: departamento.id })
  }

  scope :do_semestre_atual, -> {
    joins(:turma).merge(Turma.do_semestre_atual)
  }

  scope :criados_por, ->(adm) { where(adm_id: adm&.id) }
  scope :criados_por_outros, ->(adm) { where.not(adm_id: adm&.id) }

  def participacoes_alvo
    return turma.participantes_docentes if docentes?
    return turma.participantes_discentes if discentes?

    ParticipacaoTurma.none
  end

  def criar_avaliacoes_pendentes!
    participacoes_alvo.find_each do |participacao|
      avaliacoes.find_or_create_by!(participacao_turma: participacao)
    end
  end

  def criado_por?(perfil_adm)
    adm_id == perfil_adm&.id
  end

  private

  def definir_criado_em
    self.criado_em ||= Time.current
  end

  def adm_deve_pertencer_ao_departamento_da_turma
    return if adm.blank?
    return if turma.blank?
    return if adm.departamento_id == turma.departamento_id

    errors.add(:adm, "deve pertencer ao mesmo departamento da turma")
  end
end
