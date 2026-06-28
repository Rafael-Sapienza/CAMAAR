# frozen_string_literal: true

require "net/http"

module Brevo
  class Client
    BREVO_API_URL = URI("https://api.brevo.com/v3/smtp/email")

    def self.enviar(payload, contexto: "", api_key: nil)
      new(api_key:).enviar(payload, contexto:)
    end

    def initialize(api_key: nil)
      @api_key = api_key
    end

    def enviar(payload, contexto: "")
      key = @api_key || brevo_api_key
      return log_erro(contexto, "Token de API não configurado.") unless key.present?

      registrar_resultado(contexto, executar_requisicao(payload, key))
    rescue StandardError => e
      log_erro(contexto, "Erro inesperado: #{e.message}")
    end

    private

    def registrar_resultado(contexto, response)
      if response.is_a?(Net::HTTPSuccess)
        Rails.logger.info "[BREVO] #{contexto} — E-mail enviado com sucesso."
        true
      else
        log_erro(contexto, "Falha. Código: #{response.code} | Resposta: #{response.body}")
      end
    end

    def log_erro(contexto, mensagem)
      Rails.logger.error "[BREVO] #{contexto} — #{mensagem}"
      false
    end

    def executar_requisicao(payload, api_key)
      headers = {
        "Accept" => "application/json",
        "api-key" => api_key,
        "Content-Type" => "application/json"
      }

      http = Net::HTTP.new(BREVO_API_URL.host, BREVO_API_URL.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(BREVO_API_URL.path, headers)
      request.body = payload.to_json
      http.request(request)
    end

    def brevo_api_key
      ENV["BREVO_API_KEY"].presence || Rails.application.credentials.dig(:brevo, :api_key)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end
  end
end
