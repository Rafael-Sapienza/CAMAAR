# frozen_string_literal: true

require "csv"

class FormulariosController < ApplicationController
  before_action :authenticate_user!
  before_action :require_administrador!, except: :exportar_csv
  before_action :require_administrador_para_exportacao!, only: :exportar_csv
  before_action :set_formulario, only: %i[show exportar_csv]

  def index
    @formularios = Formulario
      .do_departamento(current_administrador.departamento)
      .do_semestre_atual
      .recentes
      .includes(:template, turma: :materia)
  end

  def show
  end

  def new
    @templates = policy_scope(Template).recentes
    @template_selecionado = @templates.find_by(id: params[:template_id])
    @turmas = Turma
      .do_departamento(current_administrador.departamento)
      .do_semestre_atual
      .sem_formulario
      .includes(:materia)
  end

  def preparar
    Formularios::CreateFromTemplate.validate_preparacao!(
      template_id: params[:template_id],
      turma_ids: params[:turma_ids],
      perfil_adm: current_administrador
    )

    session[:formulario_preparacao] = {
      "template_id" => params[:template_id].to_i,
      "turma_ids" => Array(params[:turma_ids]).map(&:to_i)
    }

    redirect_to publicar_formularios_path
  rescue Formularios::Error => e
    redirect_to new_formulario_path, alert: e.message
  end

  def publicar
    preparacao = session[:formulario_preparacao]
    unless preparacao
      redirect_to new_formulario_path
      return
    end

    @template = Template.find(preparacao["template_id"])
    @turmas = Turma.where(id: preparacao["turma_ids"]).includes(:materia)
  end

  def create
    preparacao = session[:formulario_preparacao]
    unless preparacao
      redirect_to new_formulario_path, alert: "Selecione um template e as turmas antes de publicar"
      return
    end

    Formularios::CreateFromTemplate.call(
      template_id: preparacao["template_id"],
      turma_ids: preparacao["turma_ids"],
      publico_alvo: params[:publico_alvo],
      perfil_adm: current_administrador
    )

    session.delete(:formulario_preparacao)

    redirect_to new_formulario_path,
      notice: "Formulário criado com sucesso para as turmas selecionadas"
  rescue Formularios::Error => e
    if e.message == Formularios::CreateFromTemplate::SEM_PUBLICO_ALVO
      redirect_to publicar_formularios_path, alert: e.message
    else
      session.delete(:formulario_preparacao)
      redirect_to new_formulario_path, alert: e.message
    end
  end

  def exportar_csv
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

  def require_administrador_para_exportacao!
    return if current_user&.administrador?

    redirect_to avaliacoes_pendentes_path,
      alert: "Apenas administradores possuem acesso a este recurso"
  end

  def set_formulario
    @formulario = Formulario
      .do_departamento(current_administrador.departamento)
      .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    mensagem = if action_name == "exportar_csv"
      "Você não tem permissão para exportar os resultados desse formulário."
    else
      "Você não tem permissão para acessar esse formulário."
    end

    redirect_to formularios_path,
      alert: mensagem
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
