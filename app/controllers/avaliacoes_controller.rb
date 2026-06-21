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

    if todas_obrigatorias_preenchidas?
      salvar_respostas_e_finalizar
    else
      flash.now[:alert] = "Todas as questões obrigatórias devem ser preenchidas."
      render :responder, status: :unprocessable_entity
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

  def todas_obrigatorias_preenchidas?
    respostas_params = params[:respostas] || {}

    @questoes.all? do |questao|
      resposta = respostas_params[questao.id.to_s] || {}

      if questao.discursiva?
        resposta["texto"].to_s.strip.present?
      else
        Array(resposta["opcao_id"]).any?(&:present?)
      end
    end
  end

  def salvar_respostas_e_finalizar
    ActiveRecord::Base.transaction do
      respostas_params = params[:respostas] || {}

      @questoes.each do |questao|
        resposta_data = respostas_params[questao.id.to_s] || {}
        resposta = Resposta.find_or_initialize_by(avaliacao: @avaliacao, questao: questao)

        if questao.discursiva?
          resposta.build_texto(texto: resposta_data["texto"].to_s.strip)
        else
          opcao_id = resposta_data["opcao_id"].to_s
          opcao    = questao.opcoes.find(opcao_id)
          resposta.opcoes_escolhidas.build(opcao: opcao)
        end

        resposta.save!
      end

      @avaliacao.marcar_como_respondida!
    end

    redirect_to avaliacoes_pendentes_path,
      notice: "Avaliação registrada com sucesso."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    flash.now[:alert] = "Todas as questões obrigatórias devem ser preenchidas."
    render :responder, status: :unprocessable_entity
  end
end
