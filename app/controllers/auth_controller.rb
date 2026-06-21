# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

class AuthController < ApplicationController
  include BrevoEmailable

  TAMANHO_MINIMO_SENHA = 8

  before_action :impedir_se_logado,
    only: %i[solicitar_cadastro cadastrar solicitar_redef_senha redefinir_senha]
  before_action :validar_token_via_url, only: %i[cadastrar redefinir_senha]

  def index
    return unless current_user.present?

    redirect_to avaliacoes_path,
      flash: { notice: "Você já está conectado no sistema. Se quiser sair, faça log out" }
  end

  def solicitar_cadastro
  end

  def cadastrar
  end

  def solicitar_redef_senha
  end

  def redefinir_senha
  end

  def logout
    session.clear
    @current_user = nil

    redirect_to root_path, flash: { success: "Sessão encerrada com sucesso." }
  end

  def login
    if params[:identificador].blank? && params[:senha].blank?
      return redirecionar_com_erro(root_path, "Informe sua matrícula ou e-mail e sua senha.")
    end

    return redirecionar_com_erro(root_path, "Informe sua matrícula ou e-mail.") if params[:identificador].blank?
    return redirecionar_com_erro(root_path, "Informe sua senha.") if params[:senha].blank?

    usuario = buscar_usuario_por_identificador(params[:identificador])

    if usuario.nil?
      redirect_to root_path, flash: { error: "Matrícula ou e-mail inválido." }
      return
    end

    unless usuario.ativo?
      redirect_to root_path,
        flash: { error: "Esta conta ainda não foi ativada. Por favor, realize o Primeiro Acesso." }
      return
    end

    if usuario.authenticate_senha(params[:senha])
      session[:usuario_id] = usuario.id
      redirect_to avaliacoes_path, flash: { success: "Login realizado com sucesso! Seja bem-vindo." }
    else
      redirect_to root_path, flash: { error: "Senha incorreta." }
    end
  end

  def processar_solicitacao_cadastro
    unless email_valido?(params[:email])
      return redirecionar_com_erro(cadastro_path, "Por favor, insira um formato de e-mail válido.")
    end

    usuario = Usuario.find_by(matricula: params[:matricula])
    return redirecionar_com_erro(cadastro_path, "Matrícula não encontrada no sistema institucional.") if usuario.nil?

    if usuario.email.to_s.downcase.strip != params[:email].to_s.downcase.strip
      return redirecionar_com_erro(
        cadastro_path,
        "O e-mail informado não corresponde ao e-mail institucional desta matrícula."
      )
    end

    if usuario.ativo?
      return redirecionar_com_erro(
        cadastro_path,
        "Esta matrícula já possui um cadastro ativo. Caso tenha esquecido sua senha, utilize a redefinição."
      )
    end

    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: "cadastro",
      expires_at: 10.minutes.from_now
    )

    if enviar_email_cadastro(usuario.email, token_gerado)
      redirect_to root_path, flash: { success: mensagem_email_enviado("10 minutos") }
    else
      redirect_to cadastro_path,
        flash: { error: "Houve um erro técnico ao tentar enviar o e-mail. Tente novamente mais tarde." }
    end
  end

  def confirmar_cadastro
    if params[:senha].blank? || params[:senha_confirmacao].blank?
      return redirecionar_com_erro(
        confirmar_cadastro_path(token: params[:token]),
        "Os campos de senha são obrigatórios."
      )
    end

    if params[:senha].length < TAMANHO_MINIMO_SENHA
      return redirecionar_com_erro(
        confirmar_cadastro_path(token: params[:token]),
        "A senha deve conter pelo menos #{TAMANHO_MINIMO_SENHA} caracteres."
      )
    end

    if params[:senha] != params[:senha_confirmacao]
      return redirecionar_com_erro(
        confirmar_cadastro_path(token: params[:token]),
        "As senhas não coincidem. Digite novamente."
      )
    end

    token_registro = buscar_token_valido(params[:token], "cadastro")
    if token_registro.nil?
      return redirecionar_com_erro(
        root_path,
        "O link de confirmação é inválido, expirou ou não corresponde a esta operação."
      )
    end

    usuario = token_registro.usuario
    usuario.senha = params[:senha]
    usuario.senha_confirmation = params[:senha_confirmacao]
    usuario.status = :ativo

    if usuario.save
      token_registro.destroy
      redirect_to root_path, flash: { success: "Cadastro concluído com sucesso! Faça seu login." }
    else
      redirect_to confirmar_cadastro_path(token: params[:token]),
        flash: { error: usuario.errors.full_messages.to_sentence }
    end
  end

  def processar_redefinicao_senha
    unless email_valido?(params[:email])
      return redirecionar_com_erro(solicitar_redef_senha_path, "Por favor, insira um formato de e-mail válido.")
    end

    usuario = Usuario.find_by(email: params[:email])
    return redirecionar_com_erro(solicitar_redef_senha_path, "Este e-mail não está cadastrado no sistema.") if usuario.nil?

    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: "redefinicao",
      expires_at: 10.minutes.from_now
    )

    if enviar_email_redefinicao(params[:email], token_gerado)
      redirect_to root_path, flash: { success: mensagem_email_enviado("10 minutos") }
    else
      redirect_to solicitar_redef_senha_path,
        flash: { error: "Houve um erro técnico ao tentar enviar o e-mail de recuperação. Tente novamente mais tarde." }
    end
  end

  def confirmar_redefinicao_senha
    if params[:senha].blank? || params[:senha_confirmacao].blank?
      return redirecionar_com_erro(
        redefinir_senha_path(token: params[:token]),
        "Os campos de senha são obrigatórios."
      )
    end

    if params[:senha].length < TAMANHO_MINIMO_SENHA
      return redirecionar_com_erro(
        redefinir_senha_path(token: params[:token]),
        "A nova senha deve conter pelo menos #{TAMANHO_MINIMO_SENHA} caracteres."
      )
    end

    if params[:senha] != params[:senha_confirmacao]
      return redirecionar_com_erro(
        redefinir_senha_path(token: params[:token]),
        "As senhas não coincidem. Digite novamente."
      )
    end

    token_registro = buscar_token_valido(params[:token], "redefinicao")
    if token_registro.nil?
      return redirecionar_com_erro(
        root_path,
        "O link de redefinição é inválido, expirou ou não corresponde a esta operação."
      )
    end

    usuario = token_registro.usuario
    usuario.senha = params[:senha]
    usuario.senha_confirmation = params[:senha_confirmacao]

    if usuario.save
      token_registro.destroy
      redirect_to root_path,
        flash: { success: "Sua senha foi alterada com sucesso! Insira suas novas credenciais para acessar." }
    else
      redirect_to redefinir_senha_path(token: params[:token]),
        flash: { error: usuario.errors.full_messages.to_sentence }
    end
  end

  private

  def impedir_se_logado
    return unless current_user.present?

    redirect_to avaliacoes_path,
      flash: { error: "Você já está logado em outra sessão. Faça o logout antes de poder terminar essa ação." }
  end

  def validar_token_via_url
    tipo_esperado = action_name == "cadastrar" ? "cadastro" : "redefinicao"
    token = buscar_token_valido(params[:token], tipo_esperado)

    redirect_to root_path, flash: { error: "Token inválido ou expirado." } if token.nil?
  end

  def buscar_usuario_por_identificador(identificador)
    identificador = identificador.to_s.strip

    if email_valido?(identificador)
      Usuario.find_by(email: identificador)
    else
      Usuario.find_by(matricula: identificador)
    end
  end

  def email_valido?(email)
    email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
    email.present? && email.match?(email_regex)
  end

  def buscar_token_valido(valor, tipo_esperado)
    token = Token.find_by(value: valor, tipo: tipo_esperado)
    return nil if token.nil? || token.expires_at < Time.current

    token
  end

  def redirecionar_com_erro(caminho, mensagem)
    redirect_to caminho, flash: { error: mensagem }
  end

  def mensagem_email_enviado(validade)
    <<~HTML
      E-mail enviado com sucesso! Caso não o veja na caixa de entrada, cheque sua caixa de spam.
      <p style="color: #856404; background-color: #fff3cd; border: 1px solid #ffeeba; border-radius: 4px; padding: 8px; font-size: 12px; text-align: center; margin-top: 10px; margin-bottom: 0; font-family: sans-serif;">
        ⚠️ O link enviado terá validade de <strong>#{validade}</strong>.
      </p>
    HTML
  end
end
