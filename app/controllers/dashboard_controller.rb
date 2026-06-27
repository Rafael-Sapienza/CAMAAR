# frozen_string_literal: true

require "json"

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
      @avaliacoes = avaliacoes_da_turma(params[:turma_id]) if @tipos_selecionados.include?("avaliacoes")

      if current_user.administrador? && @tipos_selecionados.include?("formularios")
        @formularios = formularios_da_turma(params[:turma_id])
      end

      return
    end

    padrao = "%#{ActiveRecord::Base.sanitize_sql_like(@termo.downcase)}%"
    @avaliacoes = pesquisar_avaliacoes(padrao) if @tipos_selecionados.include?("avaliacoes")

    return unless current_user.administrador?

    @templates = pesquisar_templates(padrao) if @tipos_selecionados.include?("templates")
    @formularios = pesquisar_formularios(padrao) if @tipos_selecionados.include?("formularios")
  end

  def gerenciamento
  end

  def enviar_solicitacoes
    depto_id = current_user.perfil_adm&.departamento_id

    if depto_id.blank?
      redirect_to gerenciamento_path, flash: { error: "Seu usuário não possui um departamento associado." } and return
    end
    turmas_do_departamento_ids = Turma.joins(:materia).where(materias: { departamento_id: depto_id }).ids
    discentes_pendentes = Usuario.joins(:participacoes_turma)
                                 .where(status: 0, participacoes_turma: { turma_id: turmas_do_departamento_ids })
    docentes_pendentes = Usuario.joins(:perfil_docente)
                                .where(status: 0, perfis_docentes: { departamento_id: depto_id })
    usuarios_pendentes = (discentes_pendentes + docentes_pendentes).uniq

    if usuarios_pendentes.empty?
      redirect_to gerenciamento_path, flash: { notice: "Não há usuários pendentes de cadastro (docentes ou discentes) neste departamento." } and return
    end

    sucessos = 0
    erros_envio = []
    usuarios_pendentes.each do |usuario|
      ActiveRecord::Base.transaction do
        token_gerado = SecureRandom.hex(16)

        usuario.tokens.create!(
          value: token_gerado,
          tipo: "cadastro",
          expires_at: 10.minutes.from_now
        )

        if enviar_email_convite_admin(usuario.email, token_gerado, current_user.nome)
          sucessos += 1
        else
          raise "Falha de comunicação com a Brevo."
        end
      rescue StandardError => e
        erros_envio << "#{usuario.nome} (Matrícula: #{usuario.matricula}): #{e.message}"
        raise ActiveRecord::Rollback
      end
    end
    if erros_envio.empty?
      redirect_to gerenciamento_path, flash: { success: "Convites enviados com sucesso para os <strong>#{sucessos}</strong> usuários do departamento!" }
    else
      redirect_to gerenciamento_path, flash: {
        error: "O envio foi concluído com instabilidades. Foram enviados #{sucessos} e-mails.",
        error_list: erros_envio
      }
    end
  end

  def importar_dados
    caminho_arquivo = Rails.root.join("db", "usuarios_sigaa.json")
    unless File.exist?(caminho_arquivo)
      redirect_to gerenciamento_path, flash: { error: "Arquivo JSON não encontrado em db/" } and return
    end
    dados = JSON.parse(File.read(caminho_arquivo))
    codigos_materias_ativos = []
    turmas_ativas_ids = []
    matriculas_ativas_json = []
    erros_importacao = []
    dados["materias"]&.each do |materia_json|
      codigo = materia_json["codigo"]

      ActiveRecord::Base.transaction do
        codigos_materias_ativos << codigo

        materia = Materia.find_or_initialize_by(codigo: codigo)
        materia.nome = materia_json["nome"]
        materia.departamento_id = materia_json["departamento_id_temp"]
        materia.save!
      end
    rescue StandardError => e
      erros_importacao << "Matéria #{materia_json['nome']} (Código: #{codigo}): #{e.message}"
    end
    dados["turmas"]&.each do |turma_json|
      ActiveRecord::Base.transaction do
        materia = Materia.find_by(codigo: turma_json["materia_codigo"])
        if materia.nil?
          raise "Matéria com código '#{turma_json['materia_codigo']}' não existe no sistema."
        end

        turma = Turma.find_or_initialize_by(
          numero: turma_json["numero"],
          ano: turma_json["ano"],
          semestre: turma_json["semestre"],
          materia_id: materia.id
        )
        turma.save!
        turmas_ativas_ids << turma.id
      end
    rescue StandardError => e
      erros_importacao << "Turma nº #{turma_json['numero']} (#{turma_json['ano']}/#{turma_json['semestre']}) da matéria '#{turma_json['materia_codigo']}': #{e.message}"
    end
    dados["usuarios_docentes"]&.each do |docente_json|
      matricula = docente_json["matricula"]
      ActiveRecord::Base.transaction do
        matriculas_ativas_json << matricula
        usuario = Usuario.find_or_initialize_by(matricula: matricula)
        usuario.nome = docente_json["nome"]
        usuario.email = docente_json["email"]
        if usuario.new_record?
          usuario.status = 0
          usuario.senha = ""
        end
        usuario.save!

        perfil = PerfilDocente.find_or_initialize_by(id: usuario.id)
        perfil.departamento_id = docente_json["departamento_id_temp"]
        perfil.save!

        turmas_docente_ids = []
        (docente_json["turmas_lecionadas"] || []).each do |mat_json|
          materia = Materia.find_by(codigo: mat_json["materia_codigo"])
          if materia.nil?
            raise "Matéria com código '#{mat_json['materia_codigo']}' não existe no sistema."
          end

          turma = Turma.find_by(
            materia_id: materia.id,
            numero: mat_json["numero_turma"],
            ano: mat_json["ano"],
            semestre: mat_json["semestre"]
          )
          if turma.nil?
            raise "Turma nº #{mat_json['numero_turma']} (#{mat_json['ano']}/#{mat_json['semestre']}) da matéria '#{materia.nome}' não foi localizada no sistema."
          end

          turmas_docente_ids << turma.id
          ParticipacaoTurma.find_or_create_by!(
            usuario_id: usuario.id,
            turma_id: turma.id,
            tipo_participacao: :docente
          )
        end
        usuario.participacoes_turma.docentes.where.not(turma_id: turmas_docente_ids).destroy_all
      end
    rescue StandardError => e
      erros_importacao << "Docente #{docente_json['nome']} (Matrícula: #{matricula}): #{e.message}"
    end
    dados["usuarios_discentes"]&.each do |discente_json|
      matricula = discente_json["matricula"]
      ActiveRecord::Base.transaction do
        matriculas_ativas_json << matricula

        usuario = Usuario.find_or_initialize_by(matricula: matricula)
        usuario.nome = discente_json["nome"]
        usuario.email = discente_json["email"]
        if usuario.new_record?
          usuario.status = 0
          usuario.senha = ""
        end
        usuario.save!
        PerfilDiscente.find_or_create_by!(id: usuario.id)
        turmas_aluno_ids = []
        discente_json["turmas_matriculadas"].each do |mat_json|
          materia = Materia.find_by(codigo: mat_json["materia_codigo"])
          if materia.nil?
            raise "Matéria com código '#{mat_json['materia_codigo']}' não existe no sistema."
          end
          turma = Turma.find_by(
            materia_id: materia.id,
            numero: mat_json["numero_turma"],
            ano: mat_json["ano"],
            semestre: mat_json["semestre"]
          )
          if turma.nil?
            raise "Turma nº #{mat_json['numero_turma']} (#{mat_json['ano']}/#{mat_json['semestre']}) da matéria '#{materia.nome}' não foi localizada no sistema."
          end

          turmas_aluno_ids << turma.id
          ParticipacaoTurma.find_or_create_by!(
            usuario_id: usuario.id,
            turma_id: turma.id,
            tipo_participacao: :discente
          )
        end
        usuario.participacoes_turma.where.not(turma_id: turmas_aluno_ids).destroy_all
      end
    rescue StandardError => e
      erros_importacao << "Discente #{discente_json['nome']} (Matrícula: #{matricula}): #{e.message}"
    end
    ActiveRecord::Base.transaction do
      Turma.where.not(id: turmas_ativas_ids).destroy_all
      Materia.where.not(codigo: codigos_materias_ativos).destroy_all
      usuarios_para_remover = Usuario.where.not(matricula: matriculas_ativas_json)
      usuarios_para_remover.each do |usuario|
        next if usuario.administrador?

        usuario.destroy!
      end
    end
    if erros_importacao.empty?
      redirect_to gerenciamento_path, flash: { success: "Dados do SIGAA importados e sincronizados com sucesso!" }
    else
      redirect_to gerenciamento_path, flash: { error: "A importação foi concluída parcialmente.", error_list: erros_importacao }
    end
  end

  def sugestoes
    termo = params[:q].to_s.strip
    return render json: [] if termo.blank?

    tipos = tipos_selecionados
    padrao = "%#{ActiveRecord::Base.sanitize_sql_like(termo.downcase)}%"
    resultados = []

    resultados += pesquisar_turmas(termo).limit(3).map do |turma|
      {
        tipo: "Turma",
        titulo: turma.materia.nome, # Envia apenas o nome (ex: Estruturas de Dados)
        subtitulo: nil, # Deixa em branco
        materia_codigo: turma.materia.codigo, # Aciona o badge azul à direita
        turma_codigo: turma.codigo_exibicao, # Aciona a turma abaixo do badge
        url: turma_suggestion_url(turma, tipos)
      }
    end

    resultados += pesquisar_materias(padrao).limit(3).map do |materia|
      {
        tipo: "Matéria",
        titulo: materia.nome,
        subtitulo: nil,
        materia_codigo: materia.codigo, # Aciona o badge azul à direita
        url: materia_suggestion_url(materia, tipos)
      }
    end

    if tipos.include?("avaliacoes")
      resultados += pesquisar_avaliacoes(padrao).limit(5).map do |avaliacao|
        turma = avaliacao.formulario.turma

        {
          tipo: "Avaliação",
          titulo: avaliacao.formulario.template&.titulo || "Avaliação",
          subtitulo: turma.nome_exibicao,
          materia_codigo: turma.materia.codigo,
          turma_codigo: turma.codigo_exibicao,
          url: responder_avaliacao_path(avaliacao)
        }
      end
    end

    if current_user.administrador?
      if tipos.include?("templates")
        resultados += pesquisar_templates(padrao).limit(5).map do |template|
          {
            tipo: "Template",
            titulo: template.titulo,
            subtitulo: template.descricao.presence || "Sem descrição",
            url: template_path(template)
          }
        end
      end

      if tipos.include?("formularios")
        resultados += pesquisar_formularios(padrao).limit(5).map do |formulario|
          {
            tipo: "Formulário",
            titulo: formulario.template&.titulo || "Template removido",
            subtitulo: formulario.turma.nome_exibicao,
            materia_codigo: formulario.turma.materia.codigo,
            turma_codigo: formulario.turma.codigo_exibicao,
            url: formulario_path(formulario)
          }
        end
      end
    end

    render json: resultados
  end

  private

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

  # Espera o último "token" do termo como identificador de turma (letra ou
  # número) e o restante como nome/código da matéria. Ex.: "CIC0001 A",
  # "Estruturas de Dados 1".
  def pesquisar_turmas(termo)
    match = termo.match(/\A(.+?)\s+([A-Za-z]|\d{1,2})\z/)
    return Turma.none unless match

    materia_termo = match[1].strip
    return Turma.none if materia_termo.blank?

    numero = Turma.numero_de_codigo_exibicao(match[2])
    padrao_materia = "%#{ActiveRecord::Base.sanitize_sql_like(materia_termo.downcase)}%"

    Turma
      .joins(:materia)
      .includes(:materia)
      .where(numero: numero)
      .where(
        "LOWER(materias.nome) LIKE :padrao OR LOWER(materias.codigo) LIKE :padrao",
        padrao: padrao_materia
      )
      .order(:numero)
  end

  # Matéria/turma não têm relação com templates, então qualquer navegação
  # a partir dessas sugestões já remove "templates" da lista de tipos e
  # marca sem_templates=1, para a topbar desabilitar esse checkbox.
  def materia_suggestion_url(materia, tipos)
    tipos_aplicaveis = tipos - [ "templates" ]
    tipos_aplicaveis = %w[avaliacoes formularios] if tipos_aplicaveis.empty?

    pesquisa_path(q: materia.nome, filtro_ativo: "1", tipos: tipos_aplicaveis, sem_templates: "1")
  end

  def turma_suggestion_url(turma, tipos)
    tipos_aplicaveis = tipos - [ "templates" ]
    tipos_aplicaveis = %w[avaliacoes formularios] if tipos_aplicaveis.empty?

    pesquisa_path(
      q: turma.nome_exibicao,
      filtro_ativo: "1",
      tipos: tipos_aplicaveis,
      sem_templates: "1",
      turma_id: turma.id
    )
  end

  def verificar_admin
    if current_user.nil? || !current_user.administrador?
      session.clear
      @current_user = nil
      redirect_to root_path, flash: { error: "Acesso restrito. Por favor, faça login como administrador." }
    end
  end
end
