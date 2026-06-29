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
    return redirecionar_erro_login if campos_login_invalidos?

    usuario = buscar_usuario_por_identificador(params[:identificador])
    return redirecionar_login_invalido if usuario_invalido?(usuario)
    return redirecionar_conta_inativa if conta_inativa?(usuario)
    return redirecionar_login_sucesso(usuario) if senha_valida?(usuario)

    redirecionar_senha_incorreta
  end

  def processar_solicitacao_cadastro
    return redirecionar_erro_email_cadastro_invalido unless email_valido?(params[:email])

    usuario = Usuario.find_by(matricula: params[:matricula])
    return redirecionar_validacao_solicitacao_cadastro(usuario) if validacao_solicitacao_cadastro?(usuario)

    token_gerado = criar_token_cadastro(usuario)
    return redirecionar_sucesso_email_cadastro if enviar_email_cadastro(usuario.email, token_gerado)

    redirecionar_erro_email_cadastro
  end

  def confirmar_cadastro
    processar_confirmacao_senha("cadastro")
  end

  def processar_redefinicao_senha
    processar_solicitacao_redefinicao_senha
  end

  def confirmar_redefinicao_senha
    processar_confirmacao_senha("redefinicao")
  end

  private

  def campos_login_invalidos?
    params[:identificador].blank? || params[:senha].blank?
  end

  def redirecionar_erro_login
    mensagem = if params[:identificador].blank? && params[:senha].blank?
                 "Informe sua matrícula ou e-mail e sua senha."
    elsif params[:identificador].blank?
                 "Informe sua matrícula ou e-mail."
    else
                 "Informe sua senha."
    end

    redirecionar_com_erro(root_path, mensagem)
  end

  def usuario_invalido?(usuario)
    usuario.nil?
  end

  def conta_inativa?(usuario)
    !usuario.ativo?
  end

  def senha_valida?(usuario)
    usuario.authenticate_senha(params[:senha])
  end

  def redirecionar_login_invalido
    redirect_to root_path, flash: { error: "Matrícula ou e-mail inválido." }
  end

  def redirecionar_conta_inativa
    redirect_to root_path,
      flash: { error: "Esta conta ainda não foi ativada. Por favor, realize o Primeiro Acesso." }
  end

  def redirecionar_login_sucesso(usuario)
    session[:usuario_id] = usuario.id
    redirect_to avaliacoes_path, flash: { success: "Login realizado com sucesso! Seja bem-vindo." }
  end

  def redirecionar_senha_incorreta
    redirect_to root_path, flash: { error: "Senha incorreta." }
  end

  def redirecionar_erro_email_cadastro_invalido
    redirecionar_com_erro(cadastro_path, "Por favor, insira um formato de e-mail válido.")
  end

  def redirecionar_matricula_inexistente
    redirecionar_com_erro(cadastro_path, "Matrícula não encontrada no sistema institucional.")
  end

  def redirecionar_email_institucional_incorreto
    redirecionar_com_erro(
      cadastro_path,
      "O e-mail informado não corresponde ao e-mail institucional desta matrícula."
    )
  end

  def redirecionar_matricula_ativa
    redirecionar_com_erro(
      cadastro_path,
      "Esta matrícula já possui um cadastro ativo. Caso tenha esquecido sua senha, utilize a redefinição."
    )
  end

  def validacao_solicitacao_cadastro?(usuario)
    usuario_invalido?(usuario) || !email_corresponde_ao_institucional?(usuario) || !conta_inativa?(usuario)
  end

  def redirecionar_validacao_solicitacao_cadastro(usuario)
    return redirecionar_matricula_inexistente if usuario_invalido?(usuario)
    return redirecionar_email_institucional_incorreto unless email_corresponde_ao_institucional?(usuario)

    redirecionar_matricula_ativa
  end

  def senha_confirmacao_valida?
    return false if params[:senha].blank? || params[:senha_confirmacao].blank?
    return false if params[:senha].length < TAMANHO_MINIMO_SENHA

    params[:senha] == params[:senha_confirmacao]
  end

  def processar_confirmacao_senha(tipo_operacao)
    return redirecionar_erro_confirmacao_senha(tipo_operacao) unless senha_confirmacao_valida?

    token_registro = buscar_token_valido(params[:token], tipo_operacao)
    return redirecionar_token_invalido(tipo_operacao) if token_registro.nil?

    usuario = token_registro.usuario
    preparar_usuario_para_confirmacao(usuario, tipo_operacao)
    return concluir_confirmacao(usuario, token_registro, tipo_operacao) if usuario.save

    redirecionar_erro_salvamento_confirmacao(usuario, tipo_operacao)
  end

  def processar_solicitacao_redefinicao_senha
    return erro_solicitacao_redefinicao_senha unless email_valido?(params[:email])

    usuario = Usuario.find_by(email: params[:email])
    return erro_email_nao_cadastrado if usuario.nil?

    token_gerado = criar_token_redefinicao(usuario)
    return redirecionar_sucesso_redefinicao_senha if enviar_email_redefinicao(params[:email], token_gerado)

    redirecionar_erro_redefinicao_senha
  end

  def preparar_usuario_para_confirmacao(usuario, tipo_operacao)
    usuario.senha = params[:senha]
    usuario.senha_confirmation = params[:senha_confirmacao]
    return unless tipo_operacao == "cadastro"

    usuario.status = :ativo
  end

  def concluir_confirmacao(usuario, token_registro, tipo_operacao)
    token_registro.destroy
    return redirect_to root_path, flash: { success: "Cadastro concluído com sucesso! Faça seu login." } if tipo_operacao == "cadastro"

    redirect_to root_path,
      flash: { success: "Sua senha foi alterada com sucesso! Insira suas novas credenciais para acessar." }
  end

  def redirecionar_erro_salvamento_confirmacao(usuario, tipo_operacao)
    return redirect_to confirmar_cadastro_path(token: params[:token]),
      flash: { error: usuario.errors.full_messages.to_sentence } if tipo_operacao == "cadastro"

    redirect_to redefinir_senha_path(token: params[:token]),
      flash: { error: usuario.errors.full_messages.to_sentence }
  end

  def redirecionar_erro_confirmacao_senha(tipo_operacao)
    if params[:senha].blank? || params[:senha_confirmacao].blank?
      return redirecionar_com_erro(
        caminho_confirmacao_senha(tipo_operacao),
        "Os campos de senha são obrigatórios."
      )
    end

    if params[:senha].length < TAMANHO_MINIMO_SENHA
      return redirecionar_com_erro(
        caminho_confirmacao_senha(tipo_operacao),
        mensagem_senha_curta(tipo_operacao)
      )
    end

    redirecionar_com_erro(
      caminho_confirmacao_senha(tipo_operacao),
      "As senhas não coincidem. Digite novamente."
    )
  end

  def caminho_confirmacao_senha(tipo_operacao)
    return redefinir_senha_path(token: params[:token]) if tipo_operacao == "redefinicao"

    confirmar_cadastro_path(token: params[:token])
  end

  def mensagem_senha_curta(tipo_operacao)
    return "A nova senha deve conter pelo menos #{TAMANHO_MINIMO_SENHA} caracteres." if tipo_operacao == "redefinicao"

    "A senha deve conter pelo menos #{TAMANHO_MINIMO_SENHA} caracteres."
  end

  def redirecionar_token_invalido(tipo_operacao)
    mensagem = if tipo_operacao == "redefinicao"
                 "O link de redefinição é inválido, expirou ou não corresponde a esta operação."
    else
                 "O link de confirmação é inválido, expirou ou não corresponde a esta operação."
    end

    redirecionar_com_erro(root_path, mensagem)
  end

  def concluir_cadastro(usuario, token_registro)
    token_registro.destroy
    redirect_to root_path, flash: { success: "Cadastro concluído com sucesso! Faça seu login." }
  end

  def redirecionar_erro_salvamento_cadastro(usuario)
    redirect_to confirmar_cadastro_path(token: params[:token]),
      flash: { error: usuario.errors.full_messages.to_sentence }
  end

  def criar_token_redefinicao(usuario)
    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: "redefinicao",
      expires_at: 10.minutes.from_now
    )
    token_gerado
  end

  def erro_solicitacao_redefinicao_senha
    redirecionar_com_erro(solicitar_redef_senha_path, "Por favor, insira um formato de e-mail válido.")
  end

  def erro_email_nao_cadastrado
    redirecionar_com_erro(solicitar_redef_senha_path, "Este e-mail não está cadastrado no sistema.")
  end

  def redirecionar_sucesso_redefinicao_senha
    redirect_to root_path, flash: { success: mensagem_email_enviado("10 minutos") }
  end

  def redirecionar_erro_redefinicao_senha
    redirect_to solicitar_redef_senha_path,
      flash: { error: "Houve um erro técnico ao tentar enviar o e-mail de recuperação. Tente novamente mais tarde." }
  end

  def concluir_redefinicao_senha(usuario, token_registro)
    token_registro.destroy
    redirect_to root_path,
      flash: { success: "Sua senha foi alterada com sucesso! Insira suas novas credenciais para acessar." }
  end

  def redirecionar_erro_salvamento_redefinicao(usuario)
    redirect_to redefinir_senha_path(token: params[:token]),
      flash: { error: usuario.errors.full_messages.to_sentence }
  end

  def email_corresponde_ao_institucional?(usuario)
    usuario.email.to_s.downcase.strip == params[:email].to_s.downcase.strip
  end

  def criar_token_cadastro(usuario)
    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: "cadastro",
      expires_at: 10.minutes.from_now
    )
    token_gerado
  end

  def redirecionar_sucesso_email_cadastro
    redirect_to root_path, flash: { success: mensagem_email_enviado("10 minutos") }
  end

  def redirecionar_erro_email_cadastro
    redirect_to cadastro_path,
      flash: { error: "Houve um erro técnico ao tentar enviar o e-mail. Tente novamente mais tarde." }
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
