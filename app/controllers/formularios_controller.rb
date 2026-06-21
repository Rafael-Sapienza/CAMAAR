# frozen_string_literal: true

require "csv"

class FormulariosController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_formulario!, only: %i[show exportar_csv]
  before_action :set_formulario, only: %i[show exportar_csv]

  def index
    authorize! Formulario

    formularios = Formulario
      .do_departamento(current_administrador.departamento)
      .do_semestre_atual
      .recentes
      .includes(:template, :avaliacoes, turma: :materia)

    @user_formularios = formularios.criados_por(current_administrador)
    @other_formularios = formularios.criados_por_outros(current_administrador)
  end

  def show
    authorize! @formulario
  end

  def new
    @formulario = Formulario.new(adm: current_administrador)
    authorize! @formulario

    carregar_opcoes_de_selecao
  end

  def create
    authorize! Formulario.new(adm: current_administrador)

    Formularios::CreateFromTemplate.call(
      template_id: params[:template_id],
      turma_ids: params[:turma_ids],
      publico_alvo: params[:publico_alvo],
      perfil_adm: current_administrador
    )

    redirect_to formularios_path,
      notice: "Formulário criado com sucesso para as turmas selecionadas"
  rescue Formularios::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    carregar_opcoes_de_selecao
    flash.now[:alert] = e.is_a?(ActiveRecord::RecordNotFound) ? "Template ou turma não encontrados" : e.message
    render :new, status: :unprocessable_entity
  end

  def exportar_csv
    authorize! @formulario

    avaliacoes = @formulario.avaliacoes
      .joins(:respostas)
      .distinct
      .includes(
        participacao_turma: :usuario,
        respostas: [ :questao, :texto, { opcoes_escolhidas: :opcao } ]
      )

    questoes = @formulario.questoes.order(:id)
    csv_data = CSV.generate(headers: true, col_sep: ";") do |csv|
      csv << [ "Aluno", "Matrícula", *questoes.map(&:enunciado) ]

      avaliacoes.each do |avaliacao|
        csv << linha_csv(avaliacao, questoes)
      end
    end

    send_data csv_data,
      filename: "resultados_turma_#{@formulario.turma.materia.codigo}_#{Date.current}.csv",
      type: "text/csv; charset=utf-8"
  end

  private

  def carregar_opcoes_de_selecao
    @templates_proprios = Template.where(adm_id: current_administrador.id).order(:titulo)
    @templates_outros = Template.where.not(adm_id: current_administrador.id).order(:titulo)

    @materias = materias_do_departamento
    @materia_selecionada = params[:materia_id].presence

    @somente_semestre_atual = params[:somente_semestre_atual] == "1"

    @turmas = turmas_do_departamento(
      materia_id: @materia_selecionada,
      somente_atual: @somente_semestre_atual # Passando a nova regra
    )
  end

  def materias_do_departamento
    Materia.do_departamento(current_administrador.departamento).order(:nome)
  end

  def turmas_do_departamento(materia_id: nil, somente_atual: false)
    escopo = Turma
      .do_departamento(current_administrador.departamento)
      .sem_formulario
      .includes(:materia)
      .order("materias.nome", :numero)
    escopo = escopo.do_semestre_atual if somente_atual
    escopo = escopo.where(materia_id: materia_id) if materia_id.present?
    escopo
  end

  def set_formulario
    @formulario = Formulario
      .do_departamento(current_administrador.departamento)
      .find(params[:id])
  end

  def authorize_formulario!
    authorize! Formulario
  end

  def linha_csv(avaliacao, questoes)
    usuario = avaliacao.participacao_turma.usuario
    linha = [ usuario.nome, usuario.matricula.presence || "N/A" ]

    questoes.each do |questao|
      resposta = avaliacao.respostas.find { |item| item.questao_id == questao.id }
      linha << valor_resposta_csv(resposta, questao)
    end

    linha
  end

  def valor_resposta_csv(resposta, questao)
    return "Sem resposta" if resposta.nil?
    return resposta.texto&.texto.to_s.strip if questao.discursiva?

    resposta.opcoes_escolhidas.map { |opcao_escolhida| opcao_escolhida.opcao.texto }.join(", ")
  end
end
