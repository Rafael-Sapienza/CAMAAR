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
    executar_criacao
  rescue Formularios::Error, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    render_erro_criacao(e)
  end

  def exportar_csv
    authorize! @formulario

    send_data montar_csv(@formulario),
      filename: nome_arquivo_csv(@formulario),
      type: "text/csv; charset=utf-8"
  end

  private

  def executar_criacao
    Formularios::CreateFromTemplate.call(
      template_id: params[:template_id],
      turma_ids: params[:turma_ids],
      publico_alvo: params[:publico_alvo],
      perfil_adm: current_administrador
    )

    redirect_to formularios_path,
      notice: "Formulário criado com sucesso para as turmas selecionadas"
  end

  def render_erro_criacao(erro)
    carregar_opcoes_de_selecao
    flash[:alert] = erro.is_a?(ActiveRecord::RecordNotFound) ? "Template ou turma não encontrados" : erro.message
    render :new, status: :unprocessable_content
  end

  def montar_csv(formulario)
    questoes = formulario.questoes.order(:id)

    CSV.generate(headers: true, col_sep: ";") do |csv|
      csv << [ "Aluno", "Matrícula", *questoes.map(&:enunciado) ]

      avaliacoes_com_respostas(formulario).each do |avaliacao|
        csv << linha_csv(avaliacao, questoes)
      end
    end
  end

  def avaliacoes_com_respostas(formulario)
    formulario.avaliacoes
      .respondidas
      .includes(
        participacao_turma: :usuario,
        respostas: [ :questao, :texto, { opcoes_escolhidas: :opcao } ]
      )
  end

  def nome_arquivo_csv(formulario)
    "resultados_turma_#{formulario.turma.materia.codigo}_#{Date.current}.csv"
  end

  def carregar_opcoes_de_selecao
    templates = Template.includes(adm: :usuario).recentes

    @templates_proprios = templates.criados_por(current_administrador)
    @templates_outros = templates.criados_por_outros(current_administrador)
    @template_selecionado = params[:template_id].presence

    @materias = materias_do_departamento
    @materia_selecionada = params[:materia_id].presence

    @turmas = turmas_do_departamento(materia_id: @materia_selecionada)
  end

  def materias_do_departamento
    Materia.do_departamento(current_administrador.departamento).order(:nome)
  end

  def turmas_do_departamento(materia_id: nil)
    escopo = Turma
      .do_departamento(current_administrador.departamento)
      .do_semestre_atual
      .includes(:materia)
      .order("materias.nome", :numero)

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
