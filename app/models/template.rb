# frozen_string_literal: true

class Template < ApplicationRecord
  belongs_to :adm,
    class_name: "PerfilAdm",
    foreign_key: :adm_id,
    inverse_of: :templates

  has_many :utilizacoes_questoes,
    class_name: "UtilizacaoQuestao",
    foreign_key: :template_id,
    inverse_of: :template,
    dependent: :destroy

  has_many :questoes, through: :utilizacoes_questoes, source: :questao

  has_many :formularios,
    class_name: "Formulario",
    foreign_key: :template_id,
    inverse_of: :template,
    dependent: :nullify

  accepts_nested_attributes_for :utilizacoes_questoes,
    allow_destroy: true,
    reject_if: :utilizacao_questao_em_branco?

  before_validation :normalizar_titulo
  before_validation :preencher_criado_em

  validates :adm, presence: true

  validates :titulo,
    presence: true,
    length: { maximum: 255 },
    uniqueness: { scope: :adm_id, case_sensitive: false }

  validates :descricao, length: { maximum: 2_000 }, allow_blank: true

  validates :criado_em, presence: true

  validate :deve_ter_ao_menos_uma_questao

  scope :recentes, -> { order(criado_em: :desc, id: :desc) }
  scope :criados_por, ->(adm) { where(adm_id: adm&.id) }
  scope :criados_por_outros, ->(adm) { where.not(adm_id: adm&.id) }

  def criado_por?(perfil_adm)
    perfil_adm.present? && adm_id == perfil_adm.id
  end

  def questoes_ordenadas
    utilizacoes_questoes.includes(:questao, :opcoes).ordenadas
  end

  private

  def normalizar_titulo
    self.titulo = titulo.to_s.strip if titulo.present?
  end

  def preencher_criado_em
    self.criado_em ||= Time.current
  end

  def deve_ter_ao_menos_uma_questao
    questoes_validas = utilizacoes_questoes.reject(&:marked_for_destruction?)
    return if questoes_validas.any?

    errors.add(:utilizacoes_questoes, "deve conter ao menos uma questão")
  end

  def utilizacao_questao_em_branco?(attributes)
    return false if attributes["id"].present?
    return false if attributes["questao_id"].present?

    questao_attributes = attributes["questao_attributes"] || {}
    return false if questao_attributes["enunciado"].present?

    opcoes_attributes = questao_attributes["opcoes_attributes"] || {}
    opcoes = opcoes_attributes.respond_to?(:values) ? opcoes_attributes.values : opcoes_attributes

    opcoes.none? do |opcao_attributes|
      opcao_attributes["texto"].present?
    end
  end
end
