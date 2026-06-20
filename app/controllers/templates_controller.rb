# frozen_string_literal: true

class TemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_template, only: %i[show edit update destroy]

  def index
    authorize! Template

    templates = policy_scope(Template)
      .includes(adm: :usuario)
      .recentes

    @user_templates = templates.criados_por(current_administrador)
    @other_templates = templates.criados_por_outros(current_administrador)
  end

  def show
    authorize! @template
  end

  def new
    @template = Template.new(adm: current_administrador)
    preparar_campos_do_template

    authorize! @template
  end

  def create
    @template = Template.new(template_params)
    @template.adm = current_administrador

    authorize! @template

    if @template.save
      redirect_to @template, notice: "Template criado com sucesso."
    else
      preparar_campos_do_template

      render :new, status: :unprocessable_entity
    end
  end

  def edit
    preparar_campos_do_template

    authorize! @template
  end

  def update
    authorize! @template

    template_atualizado = atualizar_template_com_reordenacao

    if template_atualizado
      redirect_to @template, notice: "Template atualizado com sucesso."
    else
      preparar_campos_do_template

      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! @template

    @template.destroy

    redirect_to templates_path, notice: "Template excluído com sucesso."
  end

  private

  def set_template
    @template = Template.find(params[:id])
  end

  def preparar_campos_do_template
    utilizacoes = @template.utilizacoes_questoes
    utilizacoes.build(numero: 1) if utilizacoes.empty?

    utilizacoes.each do |utilizacao|
      utilizacao.build_questao(tipo: nil) if utilizacao.questao.blank?
    end
  end

  def atualizar_template_com_reordenacao
    template_atualizado = false

    Template.transaction do
      preparar_reordenacao_de_registros_persistidos
      template_atualizado = @template.update(template_params)

      raise ActiveRecord::Rollback unless template_atualizado
    end

    template_atualizado
  end

  def preparar_reordenacao_de_registros_persistidos
    utilizacoes_attributes = nested_attributes_values(
      params.dig(:template, :utilizacoes_questoes_attributes)
    )

    preparar_reordenacao_de_utilizacoes(utilizacoes_attributes)
    preparar_reordenacao_de_opcoes(utilizacoes_attributes)
  end

  def preparar_reordenacao_de_utilizacoes(utilizacoes_attributes)
    ids = utilizacoes_attributes
      .reject { |attributes| destroy_attribute?(attributes) }
      .filter_map { |attributes| persisted_id_with_number(attributes) }

    UtilizacaoQuestao
      .where(template_id: @template.id, id: ids)
      .find_each
      .with_index(1) do |utilizacao, index|
        utilizacao.update_columns(numero: -index)
      end
  end

  def preparar_reordenacao_de_opcoes(utilizacoes_attributes)
    opcao_ids = utilizacoes_attributes.flat_map do |utilizacao_attributes|
      questao_attributes = utilizacao_attributes[:questao_attributes] ||
        utilizacao_attributes["questao_attributes"]
      opcoes_attributes = nested_attributes_values(
        questao_attributes&.dig(:opcoes_attributes) ||
          questao_attributes&.dig("opcoes_attributes")
      )

      opcoes_attributes
        .reject { |attributes| destroy_attribute?(attributes) }
        .filter_map { |attributes| persisted_id_with_number(attributes) }
    end

    Opcao.where(id: opcao_ids).find_each.with_index(1) do |opcao, index|
      opcao.update_columns(numero: -index)
    end
  end

  def nested_attributes_values(attributes)
    return [] if attributes.blank?
    return attributes.values if attributes.respond_to?(:values)

    Array(attributes)
  end

  def destroy_attribute?(attributes)
    ActiveModel::Type::Boolean.new.cast(attributes[:_destroy] || attributes["_destroy"])
  end

  def persisted_id_with_number(attributes)
    id = attributes[:id] || attributes["id"]
    numero = attributes[:numero] || attributes["numero"]

    id if id.present? && numero.present?
  end

  def template_params
    params
      .require(:template)
      .permit(
        :titulo,
        :descricao,
        utilizacoes_questoes_attributes: [
          :id,
          :questao_id,
          :numero,
          :parent_id,
          :_destroy,
          questao_attributes: [
            :id,
            :enunciado,
            :tipo,
            opcoes_attributes: [
              :id,
              :texto,
              :numero,
              :_destroy
            ]
          ]
        ]
      )
  end
end
