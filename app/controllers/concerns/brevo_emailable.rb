# frozen_string_literal: true

module BrevoEmailable
  extend ActiveSupport::Concern

  BREVO_API_URL = URI("https://api.brevo.com/v3/smtp/email")
  REMETENTE = { "name" => "CAMAAR Support", "email" => "rafaelsapienzapinheiro@gmail.com" }.freeze

  def chamar_api_brevo(payload, contexto: "")
    api_key = brevo_api_key
    return false unless brevo_api_key_configurada?(api_key, contexto)

    response = brevo_http.request(brevo_request(payload, api_key))
    brevo_response_sucesso?(response, contexto)
  rescue StandardError => e
    Rails.logger.error "[BREVO] #{contexto} — Erro inesperado: #{e.message}"
    false
  end

  def brevo_api_key
    Rails.application.credentials.dig(:brevo, :api_key)
  end

  def brevo_api_key_configurada?(api_key, contexto)
    return true if api_key.present?

    Rails.logger.error "[BREVO] #{contexto} — Token de API não configurado."
    false
  end

  def brevo_headers(api_key)
    {
      "Accept" => "application/json",
      "api-key" => api_key,
      "Content-Type" => "application/json"
    }
  end

  def brevo_http
    Net::HTTP.new(BREVO_API_URL.host, BREVO_API_URL.port).tap do |http|
      http.use_ssl = true
    end
  end

  def brevo_request(payload, api_key)
    Net::HTTP::Post.new(BREVO_API_URL.path, brevo_headers(api_key)).tap do |request|
      request.body = payload.to_json
    end
  end

  def brevo_response_sucesso?(response, contexto)
    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info "[BREVO] #{contexto} — E-mail enviado com sucesso."
      true
    else
      Rails.logger.error "[BREVO] #{contexto} — Falha. Código: #{response.code} | Resposta: #{response.body}"
      false
    end
  end

  def enviar_email_cadastro(destinatario, token)
    url = "http://127.0.0.1:3000/cadastro/confirmar/?token=#{token}"

    payload = {
      "sender"      => REMETENTE,
      "to"          => [ { "email" => destinatario } ],
      "subject"     => "Link de cadastro do CAMAAR",
      "htmlContent" => <<~HTML
        <html>
        <body style="font-family: sans-serif; color: #333; line-height: 1.6;">
          <h2>Olá!</h2>
          <p>Seja bem-vindo(a) ao <strong>CAMAAR</strong>. Recebemos sua solicitação para realizar o primeiro acesso no sistema institucional.</p>
          <p>Para ativar sua conta e configurar sua senha de acesso com segurança, clique no botão abaixo:</p>
          <p style="margin: 25px 0;">
            <a href="#{url}" target="_blank" style="background-color: #28a745; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              Confirmar Cadastro e Criar Senha
            </a>
          </p>
          <p style="font-size: 13px; color: #666;">
            Se o botão não funcionar, copie e cole este endereço no seu navegador:<br>
            <strong>#{url}</strong>
          </p>
          <div style="margin-top: 30px; padding: 12px; background-color: #f8f9fa; border-left: 4px solid #ffc107; font-size: 13px;">
            ⚠️ <strong>Importante:</strong> Este link é válido por apenas 10 minutos.<br>
            Caso ele expire antes de você concluir a ação, basta acessar a página de cadastro do CAMAAR novamente para gerar um novo envio.
          </div>
        </body>
        </html>
      HTML
    }

    chamar_api_brevo(payload, contexto: "Cadastro")
  end

  def enviar_email_redefinicao(destinatario, token)
    url = "http://127.0.0.1:3000/redefinir-senha/confirmar/?token=#{token}"

    payload = {
      "sender"      => REMETENTE,
      "to"          => [ { "email" => destinatario } ],
      "subject"     => "Recuperação de Senha — CAMAAR",
      "htmlContent" => <<~HTML
        <html>
        <body style="font-family: sans-serif; color: #333; line-height: 1.6;">
          <h2>Olá!</h2>
          <p>Você solicitou a redefinição de senha para sua conta no sistema <strong>CAMAAR</strong>.</p>
          <p>Para escolher uma nova senha e restabelecer o seu acesso, clique no botão abaixo:</p>
          <p style="margin: 25px 0;">
            <a href="#{url}" target="_blank" style="background-color: #dc3545; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              Redefinir Minha Senha
            </a>
          </p>
          <p style="font-size: 13px; color: #666;">
            Se o botão não funcionar, copie e cole este endereço no seu navegador:<br>
            <strong>#{url}</strong>
          </p>
          <div style="margin-top: 30px; padding: 12px; background-color: #f8f9fa; border-left: 4px solid #dc3545; font-size: 13px;">
            ⚠️ <strong>Segurança:</strong> Este link é válido por apenas 10 minutos.<br>
            Se você não realizou essa solicitação, por favor, desconsidere este e-mail. Seus dados de acesso continuarão seguros e inalterados.
          </div>
        </body>
        </html>
      HTML
    }

    chamar_api_brevo(payload, contexto: "Redefinição de senha")
  end

  def enviar_email_convite_admin(destinatario, token, nome_admin)
    url = "http://127.0.0.1:3000/cadastro/confirmar/?token=#{token}"

    payload = {
      "sender"      => REMETENTE,
      "to"          => [ { "email" => destinatario } ],
      "subject"     => "Convite de Cadastro no CAMAAR — Administrador(a) #{nome_admin}",
      "htmlContent" => <<~HTML
        <html>
        <body style="font-family: sans-serif; color: #333; line-height: 1.6;">
          <h2>Olá!</h2>
          <p>O(A) Administrador(a) <strong>#{nome_admin}</strong> está te convidando para realizar o seu cadastro no sistema do <strong>CAMAAR</strong>.</p>
          <p>Para criar sua senha e ativar sua conta com segurança, clique no link abaixo:</p>
          <p style="margin: 25px 0;">
            <a href="#{url}" target="_blank" style="background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px; font-weight: bold;">
              Confirmar Cadastro e Criar Senha
            </a>
          </p>
          <p style="font-size: 13px; color: #666;">
            Se o botão não funcionar, copie e cole este endereço no seu navegador:<br>
            <strong>#{url}</strong>
          </p>
          <div style="margin-top: 30px; padding: 12px; background-color: #f8f9fa; border-left: 4px solid #ffc107; font-size: 13px;">
            ⚠️ <strong>Importante:</strong> Este link é válido por apenas 10 minutos.<br>
            Caso ele expire, não se preocupe! Acesse a página inicial do CAMAAR, vá na seção de cadastro e informe seus dados para receber um novo link por e-mail instantaneamente.
          </div>
        </body>
        </html>
      HTML
    }
    chamar_api_brevo(payload, contexto: "Convite do Administrador")
  end

  private

  def brevo_api_key
    ENV["BREVO_API_KEY"].presence || Rails.application.credentials.dig(:brevo, :api_key)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage, ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end
end
