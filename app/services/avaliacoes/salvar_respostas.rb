# frozen_string_literal: true

module Avaliacoes
  class SalvarRespostas
    def self.todas_obrigatorias_preenchidas?(questoes, respostas_params)
      new(questoes:, respostas_params:).todas_obrigatorias_preenchidas?
    end

    def self.call(avaliacao:, questoes:, respostas_params:)
      new(avaliacao:, questoes:, respostas_params:).call
    end

    def initialize(avaliacao: nil, questoes:, respostas_params:)
      @avaliacao = avaliacao
      @questoes = questoes
      @respostas_params = normalizar_respostas_params(respostas_params)
    end

    def todas_obrigatorias_preenchidas?
      @questoes.any? && @questoes.all? { |questao| resposta_preenchida?(questao) }
    end

    def call
      ActiveRecord::Base.transaction do
        @questoes.each { |questao| persistir_resposta(questao) }
        @avaliacao.marcar_como_respondida!
      end
    end

    private

    def normalizar_respostas_params(params)
      return {} if params.blank?

      hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      hash.stringify_keys
    end

    def resposta_preenchida?(questao)
      resposta = dados_resposta(questao)

      if questao.discursiva?
        resposta["texto"].to_s.strip.present?
      else
        Array(resposta["opcao_id"]).any?(&:present?)
      end
    end

    def persistir_resposta(questao)
      resposta_data = dados_resposta(questao)
      resposta = Resposta.find_or_initialize_by(avaliacao: @avaliacao, questao: questao)

      if questao.discursiva?
        atribuir_texto(resposta, resposta_data)
      else
        atribuir_opcao(resposta, questao, resposta_data)
      end

      resposta.save!
    end

    def atribuir_texto(resposta, resposta_data)
      texto_valor = resposta_data["texto"].to_s.strip

      if resposta.texto.present?
        resposta.texto.texto = texto_valor
      else
        resposta.build_texto(texto: texto_valor)
      end
    end

    def atribuir_opcao(resposta, questao, resposta_data)
      opcao = questao.opcoes.find(resposta_data["opcao_id"].to_s)

      resposta.opcoes_escolhidas.destroy_all
      resposta.opcoes_escolhidas.build(opcao: opcao)
    end

    def dados_resposta(questao)
      chave = questao.id.to_s
      bruto = @respostas_params[chave] || @respostas_params[questao.id] || {}
      bruto.respond_to?(:to_unsafe_h) ? bruto.to_unsafe_h : bruto.to_h
    end
  end
end
