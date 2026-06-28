# frozen_string_literal: true

class DashboardController < ApplicationController
  include BrevoEmailable
  before_action :verificar_usuario, only: %i[index pesquisar sugestoes]
  before_action :verificar_admin, only: %i[gerenciamento importar_dados enviar_solicitacoes]

  def index
    @avaliacoes_pendentes = avaliacoes_do_usuario.limit(6)
  end

  def pesquisar
    @termo = params[:q].to_s.strip
    @avaliacoes = Avaliacao.none
    @templates = Template.none
    @formularios = Formulario.none
    @tipos_selecionados = tipos_selecionados

    return if @termo.blank?

    if params[:turma_id].present?
      pesquisar_por_turma(params[:turma_id])
    else
      pesquisar_por_termo
    end
  end

  def gerenciamento
  end

  def enviar_solicitacoes
    depto_id = current_user.perfil_adm&.departamento_id

    if depto_id.blank?
      redirect_to gerenciamento_path, flash: { error: "Seu usuário não possui um departamento associado." } and return
    end

    resultado = Dashboard::EnviarConvites.call(
      depto_id: depto_id,
      admin_nome: current_user.nome,
      enviar_email: method(:enviar_email_convite_admin)
    )

    flash = if resultado[:sem_pendentes]
              { notice: Dashboard::EnviarConvites::SEM_PENDENTES }
    else
              montar_flash_resultado(resultado[:sucessos], resultado[:erros])
    end

    redirect_to gerenciamento_path, flash: flash
  end

  def importar_dados
    resultado = SIGAA::ImportUsuarios.call(caminho_arquivo: Rails.root.join("db", "usuarios_sigaa.json"))

    if resultado[:arquivo_inexistente]
      redirect_to gerenciamento_path, flash: { error: SIGAA::ImportUsuarios::ARQUIVO_NAO_ENCONTRADO } and return
    end

    if resultado[:sucesso_total]
      redirect_to gerenciamento_path, flash: { success: "Dados do SIGAA importados e sincronizados com sucesso!" }
    else
      redirect_to gerenciamento_path, flash: { error: "A importação foi concluída parcialmente.", error_list: resultado[:erros] }
    end
  end

  def sugestoes
    resultados = Dashboard::SuggestionBuilder.call(
      termo: params[:q],
      tipos: tipos_selecionados,
      current_user: current_user,
      pesquisar_turmas: method(:pesquisar_turmas),
      pesquisar_materias: method(:pesquisar_materias),
      pesquisar_avaliacoes: method(:pesquisar_avaliacoes),
      pesquisar_templates: method(:pesquisar_templates),
      pesquisar_formularios: method(:pesquisar_formularios)
    )

    render json: resultados
  end

  private

  def pesquisar_por_turma(turma_id)
    @avaliacoes = avaliacoes_da_turma(turma_id) if @tipos_selecionados.include?("avaliacoes")

    return unless current_user.administrador? && @tipos_selecionados.include?("formularios")

    @formularios = formularios_da_turma(turma_id)
  end

  def pesquisar_por_termo
    padrao = "%#{ActiveRecord::Base.sanitize_sql_like(@termo.downcase)}%"
    @avaliacoes = pesquisar_avaliacoes(padrao) if @tipos_selecionados.include?("avaliacoes")

    return unless current_user.administrador?

    @templates = pesquisar_templates(padrao) if @tipos_selecionados.include?("templates")
    @formularios = pesquisar_formularios(padrao) if @tipos_selecionados.include?("formularios")
  end

  def montar_flash_resultado(sucessos, erros_envio)
    if erros_envio.empty?
      { success: "Convites enviados com sucesso para os <strong>#{sucessos}</strong> usuários do departamento!" }
    else
      {
        error: "O envio foi concluído com instabilidades. Foram enviados #{sucessos} e-mails.",
        error_list: erros_envio
      }
    end
  end

  # Sem o filtro aberto, assume as 3 categorias. Com o filtro aberto, usa
  # exatamente o que está marcado. "sem_templates" força a exclusão mesmo
  # que "templates" venha marcado por algum motivo (defesa, não deveria
  # acontecer já que o checkbox fica desabilitado nesse caso).
  def tipos_selecionados
    tipos = if params[:filtro_ativo].present?
              Array(params[:tipos])
    else
              %w[avaliacoes templates formularios]
    end

    tipos -= [ "templates" ] if params[:sem_templates] == "1"
    tipos
  end

  def verificar_usuario
    return if current_user.present?

    redirect_to root_path,
      flash: { error: "Acesso restrito. Por favor, faça login para continuar." }
  end

  def avaliacoes_do_usuario
    Avaliacao
      .pendentes
      .joins(:participacao_turma)
      .where(participacoes_turmas: { usuario_id: current_user.id })
      .includes(formulario: [ :template, { turma: :materia } ])
      .order(created_at: :desc)
  end

  def avaliacoes_da_turma(turma_id)
    avaliacoes_do_usuario
      .joins(:formulario)
      .where(formularios: { turma_id: turma_id })
  end

  def formularios_da_turma(turma_id)
    Formulario
      .do_departamento(current_administrador.departamento)
      .where(turma_id: turma_id)
      .includes(:template, turma: :materia)
      .recentes
  end

  def pesquisar_avaliacoes(padrao)
    avaliacoes_do_usuario
      .joins(formulario: [ :template, { turma: :materia } ])
      .where(
        "LOWER(templates.titulo) LIKE :padrao OR LOWER(materias.nome) LIKE :padrao OR LOWER(materias.codigo) LIKE :padrao",
        padrao: padrao
      )
  end

  def pesquisar_templates(padrao)
    policy_scope(Template)
      .where(
        "LOWER(templates.titulo) LIKE :padrao OR " \
          "LOWER(COALESCE(templates.descricao, '')) LIKE :padrao",
        padrao: padrao
      )
      .recentes
  end

  def pesquisar_formularios(padrao)
    Formulario
      .do_departamento(current_administrador.departamento)
      .joins(:template, turma: :materia)
      .where(
        "LOWER(templates.titulo) LIKE :padrao OR LOWER(materias.nome) LIKE :padrao OR LOWER(materias.codigo) LIKE :padrao",
        padrao: padrao
      )
      .includes(:template, turma: :materia)
      .recentes
  end

  def pesquisar_materias(padrao)
    Materia.where(
      "LOWER(nome) LIKE :padrao OR LOWER(codigo) LIKE :padrao",
      padrao: padrao
    ).order(:nome)
  end

  def pesquisar_turmas(termo)
    Dashboard::TurmaSearcher.call(termo)
  end

  def verificar_admin
    if current_user.nil? || !current_user.administrador?
      session.clear
      @current_user = nil
      redirect_to root_path, flash: { error: "Acesso restrito. Por favor, faça login como administrador." }
    end
  end
end
