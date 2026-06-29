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

    criar_formularios_a_partir_do_template
    redirecionar_formulario_criado
  rescue Formularios::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    renderizar_erro_criacao_formulario(e)
  end

  def exportar_csv
    authorize! @formulario

    send_data csv_formulario,
      filename: nome_arquivo_csv,
      type: "text/csv; charset=utf-8"
  end

  private

  def criar_formularios_a_partir_do_template
    Formularios::CreateFromTemplate.call(
      template_id: params[:template_id],
      turma_ids: params[:turma_ids],
      publico_alvo: params[:publico_alvo],
      perfil_adm: current_administrador
    )
  end

  def redirecionar_formulario_criado
    redirect_to formularios_path,
      notice: "Formulário criado com sucesso para as turmas selecionadas"
  end

  def renderizar_erro_criacao_formulario(error)
    carregar_opcoes_de_selecao
    flash[:alert] = mensagem_erro_criacao_formulario(error)
    render :new, status: :unprocessable_content
  end

  def mensagem_erro_criacao_formulario(error)
    return "Template ou turma não encontrados" if error.is_a?(ActiveRecord::RecordNotFound)

    error.message
  end

  def csv_formulario
    questoes = @formulario.questoes.order(:id)

    CSV.generate(headers: true, col_sep: ";") do |csv|
      csv << cabecalho_csv(questoes)
      avaliacoes_com_respostas.each { |avaliacao| csv << linha_csv(avaliacao, questoes) }
    end
  end

  def avaliacoes_com_respostas
    @formulario.avaliacoes
      .joins(:respostas)
      .distinct
      .includes(
        participacao_turma: :usuario,
        respostas: [ :questao, :texto, { opcoes_escolhidas: :opcao } ]
      )
  end

  def cabecalho_csv(questoes)
    [ "Aluno", "Matrícula", *questoes.map(&:enunciado) ]
  end

  def nome_arquivo_csv
    "resultados_turma_#{@formulario.turma.materia.codigo}_#{Date.current}.csv"
  end

  def carregar_opcoes_de_selecao
    templates = Template.includes(adm: :usuario).recentes

    @templates_proprios = templates.criados_por(current_administrador)
    @templates_outros = templates.criados_por_outros(current_administrador)
    @template_selecionado = params[:template_id].presence

    @materias = materias_do_departamento
    @materia_selecionada = params[:materia_id].presence

    @turmas = turmas_do_departamento
    @professores = professores_do_departamento
  end

  def materias_do_departamento
    Materia.do_departamento(current_administrador.departamento).order(:nome)
  end

  def turmas_do_departamento
    Turma
      .do_departamento(current_administrador.departamento)
      .do_semestre_atual
      .includes(:materia, participacoes_turma: :usuario)
      .order("materias.nome", :numero)
  end

  def professores_do_departamento
    current_administrador
      .departamento
      .docentes
      .order(:nome)
  end

  def set_formulario
    @formulario = Formulario
      .do_departamento(current_administrador.departamento)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to formularios_path, alert: mensagem_formulario_indisponivel
  end

  def mensagem_formulario_indisponivel
    return "Você não tem permissão para exportar os resultados desse formulário." if action_name == "exportar_csv"

    "Você não tem permissão para acessar esse formulário."
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
