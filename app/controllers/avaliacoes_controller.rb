# frozen_string_literal: true

class AvaliacoesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_avaliacao, only: %i[responder submeter]

  # GET /avaliacoes/pendentes
  def pendentes
    @avaliacoes_pendentes = Avaliacao
      .pendentes
      .joins(:participacao_turma)
      .where(participacoes_turmas: { usuario_id: current_user.id })
      .includes(formulario: { turma: :materia })
  end

  # GET /avaliacoes/:id/responder
  def responder
    if @avaliacao.respondida?
      redirect_to avaliacoes_pendentes_path,
        alert: "Esta avaliação já foi respondida."
      return
    end

    @formulario = @avaliacao.formulario
    @questoes   = questoes_do_formulario
  end

  # POST /avaliacoes/:id/submeter
  def submeter
    if @avaliacao.respondida?
      redirect_to avaliacoes_pendentes_path,
        alert: "Esta avaliação já foi respondida."
      return
    end

    @formulario = @avaliacao.formulario
    @questoes   = questoes_do_formulario

    if respostas_completas?
      finalizar_avaliacao
    elsif @questoes.empty?
      flash.now[:alert] = "Este formulário não possui questões para responder."
      render :responder, status: :unprocessable_content
    else
      flash.now[:alert] = "Todas as questões obrigatórias devem ser preenchidas."
      render :responder, status: :unprocessable_content
    end
  end

  private

  def set_avaliacao
    participacao_ids = ParticipacaoTurma
                         .where(usuario: current_user)
                         .pluck(:id)

    @avaliacao = Avaliacao.find_by!(id: params[:id],
                                    participacao_turma_id: participacao_ids)
  rescue ActiveRecord::RecordNotFound
    redirect_to avaliacoes_pendentes_path, alert: "Avaliação não encontrada."
  end

  def questoes_do_formulario
    @formulario.questoes.includes(:opcoes).order(:id)
  end

  def respostas_completas?
    Avaliacoes::SalvarRespostas.todas_obrigatorias_preenchidas?(@questoes, params[:respostas])
  end

  def finalizar_avaliacao
    Avaliacoes::SalvarRespostas.call(
      avaliacao: @avaliacao,
      questoes: @questoes,
      respostas_params: params[:respostas]
    )

    redirect_to avaliacoes_pendentes_path,
      notice: "Avaliação registrada com sucesso."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound
    flash.now[:alert] = "Todas as questões obrigatórias devem ser preenchidas."
    render :responder, status: :unprocessable_content
  end
end
