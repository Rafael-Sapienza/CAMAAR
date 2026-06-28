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
    erro = validar_credenciais_preenchidas
    return redirecionar_com_erro(root_path, erro) if erro

    usuario = buscar_usuario_por_identificador(params[:identificador])
    autenticar_usuario(usuario)
  end

  def processar_solicitacao_cadastro
    unless email_valido?(params[:email])
      return redirecionar_com_erro(cadastro_path, "Por favor, insira um formato de e-mail válido.")
    end

    usuario, erro = validar_matricula_email_correspondem
    return redirecionar_com_erro(cadastro_path, erro) if erro

    solicitar_token_por_email(
      usuario: usuario,
      tipo: "cadastro",
      email_destino: usuario.email,
      enviar_email: ->(email, token) { enviar_email_cadastro(email, token) },
      sucesso_path: root_path,
      erro_path: cadastro_path,
      erro_envio: "Houve um erro técnico ao tentar enviar o e-mail. Tente novamente mais tarde."
    )
  end

  def confirmar_cadastro
    confirmar_senha_com_token(
      tipo: "cadastro",
      path_com_token: confirmar_cadastro_path(token: params[:token]),
      mensagem_tamanho: "A senha deve conter pelo menos #{TAMANHO_MINIMO_SENHA} caracteres.",
      mensagem_token_invalido: "O link de confirmação é inválido, expirou ou não corresponde a esta operação.",
      ativar_usuario: true,
      mensagem_sucesso: "Cadastro concluído com sucesso! Faça seu login."
    )
  end

  def processar_redefinicao_senha
    return redirecionar_com_erro(solicitar_redef_senha_path, "Por favor, insira um formato de e-mail válido.") unless email_valido?(params[:email])

    usuario = Usuario.find_by(email: params[:email])
    return redirecionar_com_erro(solicitar_redef_senha_path, "Este e-mail não está cadastrado no sistema.") if usuario.nil?

    enviar_token_redefinicao(usuario)
  end

  def confirmar_redefinicao_senha
    confirmar_senha_com_token(
      tipo: "redefinicao",
      path_com_token: redefinir_senha_path(token: params[:token]),
      mensagem_tamanho: "A nova senha deve conter pelo menos #{TAMANHO_MINIMO_SENHA} caracteres.",
      mensagem_token_invalido: "O link de redefinição é inválido, expirou ou não corresponde a esta operação.",
      ativar_usuario: false,
      mensagem_sucesso: "Sua senha foi alterada com sucesso! Insira suas novas credenciais para acessar."
    )
  end

  private

  def validar_credenciais_preenchidas
    if params[:identificador].blank? && params[:senha].blank?
      "Informe sua matrícula ou e-mail e sua senha."
    elsif params[:identificador].blank?
      "Informe sua matrícula ou e-mail."
    elsif params[:senha].blank?
      "Informe sua senha."
    end
  end

  def autenticar_usuario(usuario)
    return redirecionar_com_erro(root_path, "Matrícula ou e-mail inválido.") if usuario.nil?
    return redirecionar_com_erro(root_path, "Esta conta ainda não foi ativada. Por favor, realize o Primeiro Acesso.") unless usuario.ativo?

    if usuario.authenticate_senha(params[:senha])
      iniciar_sessao(usuario)
    else
      redirecionar_com_erro(root_path, "Senha incorreta.")
    end
  end

  def iniciar_sessao(usuario)
    session[:usuario_id] = usuario.id
    redirect_to avaliacoes_path, flash: { success: "Login realizado com sucesso! Seja bem-vindo." }
  end

  def validar_matricula_email_correspondem
    usuario = Usuario.find_by(matricula: params[:matricula])
    return resultado_validacao(nil, "Matrícula não encontrada no sistema institucional.") if usuario.nil?
    return resultado_validacao(nil, "O e-mail informado não corresponde ao e-mail institucional desta matrícula.") unless emails_correspondem?(usuario)
    return resultado_validacao(nil, "Esta matrícula já possui um cadastro ativo. Caso tenha esquecido sua senha, utilize a redefinição.") if usuario.ativo?

    [ usuario, nil ]
  end

  def resultado_validacao(usuario, mensagem)
    [ usuario, mensagem ]
  end

  def emails_correspondem?(usuario)
    usuario.email.to_s.downcase.strip == params[:email].to_s.downcase.strip
  end

  def enviar_token_redefinicao(usuario)
    solicitar_token_por_email(
      usuario: usuario,
      tipo: "redefinicao",
      email_destino: params[:email],
      enviar_email: ->(email, token) { enviar_email_redefinicao(email, token) },
      sucesso_path: root_path,
      erro_path: solicitar_redef_senha_path,
      erro_envio: "Houve um erro técnico ao tentar enviar o e-mail de recuperação. Tente novamente mais tarde."
    )
  end

  def solicitar_token_por_email(usuario:, tipo:, email_destino:, enviar_email:, sucesso_path:, erro_path:, erro_envio:)
    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: tipo,
      expires_at: 10.minutes.from_now
    )

    if enviar_email.call(email_destino, token_gerado)
      redirect_to sucesso_path, flash: { success: mensagem_email_enviado("10 minutos") }
    else
      redirect_to erro_path, flash: { error: erro_envio }
    end
  end

  def validar_parametros_senha!(path_com_token:, mensagem_tamanho:)
    return invalidar_senha(path_com_token, "Os campos de senha são obrigatórios.") if senhas_vazias?
    return invalidar_senha(path_com_token, mensagem_tamanho) if params[:senha].length < TAMANHO_MINIMO_SENHA
    return invalidar_senha(path_com_token, "As senhas não coincidem. Digite novamente.") if senhas_diferentes?

    true
  end

  def senhas_vazias?
    params[:senha].blank? || params[:senha_confirmacao].blank?
  end

  def senhas_diferentes?
    params[:senha] != params[:senha_confirmacao]
  end

  def invalidar_senha(path, mensagem)
    redirecionar_com_erro(path, mensagem)
    false
  end

  def confirmar_senha_com_token(tipo:, path_com_token:, mensagem_tamanho:, mensagem_token_invalido:,
                                ativar_usuario:, mensagem_sucesso:)
    return unless validar_parametros_senha!(path_com_token:, mensagem_tamanho:)

    token_registro = buscar_token_valido(params[:token], tipo)
    return redirecionar_com_erro(root_path, mensagem_token_invalido) if token_registro.nil?

    finalizar_confirmacao_senha(token_registro, path_com_token:, ativar_usuario:, mensagem_sucesso:)
  end

  def finalizar_confirmacao_senha(token_registro, path_com_token:, ativar_usuario:, mensagem_sucesso:)
    usuario = token_registro.usuario
    atribuir_senha(usuario, ativar_usuario:)

    if usuario.save
      token_registro.destroy
      redirect_to root_path, flash: { success: mensagem_sucesso }
    else
      redirect_to path_com_token, flash: { error: usuario.errors.full_messages.to_sentence }
    end
  end

  def atribuir_senha(usuario, ativar_usuario:)
    usuario.senha = params[:senha]
    usuario.senha_confirmation = params[:senha_confirmacao]
    usuario.status = :ativo if ativar_usuario
  end

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
