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
    inicializar_pesquisa

    return if @termo.blank?
    return pesquisar_por_turma if params[:turma_id].present?

    pesquisar_por_termo
  end

  def gerenciamento
  end

  def enviar_solicitacoes
    depto_id = current_user.perfil_adm&.departamento_id

    if depto_id.blank?
      redirect_to gerenciamento_path, flash: { error: "Seu usuário não possui um departamento associado." } and return
    end

    usuarios_pendentes = usuarios_pendentes_do_departamento(depto_id)

    if usuarios_pendentes.empty?
      redirect_to gerenciamento_path, flash: { notice: "Não há usuários pendentes de cadastro (docentes ou discentes) neste departamento." } and return
    end

    resultado = enviar_convites_pendentes(usuarios_pendentes)
    redirecionar_envio_solicitacoes(resultado[:sucessos], resultado[:erros_envio])
  end

  def importar_dados
    caminho_arquivo = caminho_arquivo_sigaa
    unless File.exist?(caminho_arquivo)
      redirect_to gerenciamento_path, flash: { error: "Arquivo JSON não encontrado em db/" } and return
    end

    dados = JSON.parse(File.read(caminho_arquivo))
    contexto = contexto_importacao_sigaa

    importar_materias_sigaa(dados, contexto)
    importar_turmas_sigaa(dados, contexto)
    importar_docentes_sigaa(dados, contexto)
    importar_discentes_sigaa(dados, contexto)
    sincronizar_remocoes_sigaa(contexto)
    redirecionar_importacao_sigaa(contexto[:erros_importacao])
  end

  def sugestoes
    termo = params[:q].to_s.strip
    return render json: [] if termo.blank?

    render json: sugestoes_do_termo(termo)
  end

  private

  def usuarios_pendentes_do_departamento(depto_id)
    turmas_do_departamento_ids = Turma.joins(:materia).where(materias: { departamento_id: depto_id }).ids
    discentes_pendentes = Usuario.joins(:participacoes_turma)
                                 .where(status: 0, participacoes_turma: { turma_id: turmas_do_departamento_ids })
    docentes_pendentes = Usuario.joins(:perfil_docente)
                                .where(status: 0, perfis_docentes: { departamento_id: depto_id })

    (discentes_pendentes + docentes_pendentes).uniq
  end

  def enviar_convites_pendentes(usuarios_pendentes)
    resultado = { sucessos: 0, erros_envio: [] }

    usuarios_pendentes.each do |usuario|
      resultado[:sucessos] += 1 if enviar_convite_pendente(usuario, resultado[:erros_envio])
    end

    resultado
  end

  def enviar_convite_pendente(usuario, erros_envio)
    enviado = false

    ActiveRecord::Base.transaction do
      token_gerado = criar_token_cadastro!(usuario)

      if enviar_email_convite_admin(usuario.email, token_gerado, current_user.nome)
        enviado = true
      else
        raise "Falha de comunicação com a Brevo."
      end
    rescue StandardError => e
      erros_envio << "#{usuario.nome} (Matrícula: #{usuario.matricula}): #{e.message}"
      raise ActiveRecord::Rollback
    end

    enviado
  end

  def criar_token_cadastro!(usuario)
    token_gerado = SecureRandom.hex(16)
    usuario.tokens.create!(
      value: token_gerado,
      tipo: "cadastro",
      expires_at: 10.minutes.from_now
    )
    token_gerado
  end

  def redirecionar_envio_solicitacoes(sucessos, erros_envio)
    if erros_envio.empty?
      redirect_to gerenciamento_path, flash: { success: "Convites enviados com sucesso para os <strong>#{sucessos}</strong> usuários pendentes do departamento!" }
    else
      redirect_to gerenciamento_path, flash: {
        error: "O envio foi concluído com instabilidades. Foram enviados #{sucessos} e-mails.",
        error_list: erros_envio
      }
    end
  end

  def caminho_arquivo_sigaa
    Rails.root.join("db", "usuarios_sigaa.json")
  end

  def contexto_importacao_sigaa
    {
      codigos_materias_ativos: [],
      turmas_ativas_ids: [],
      matriculas_ativas_json: [],
      erros_importacao: []
    }
  end

  def importar_materias_sigaa(dados, contexto)
    dados["materias"]&.each do |materia_json|
      importar_materia_sigaa(materia_json, contexto)
    end
  end

  def importar_materia_sigaa(materia_json, contexto)
    codigo = materia_json["codigo"]

    ActiveRecord::Base.transaction do
      contexto[:codigos_materias_ativos] << codigo
      materia = Materia.find_or_initialize_by(codigo: codigo)
      materia.nome = materia_json["nome"]
      materia.departamento_id = materia_json["departamento_id_temp"]
      materia.save!
    end
  rescue StandardError => e
    contexto[:erros_importacao] << "Matéria #{materia_json['nome']} (Código: #{codigo}): #{e.message}"
  end

  def importar_turmas_sigaa(dados, contexto)
    dados["turmas"]&.each do |turma_json|
      importar_turma_sigaa(turma_json, contexto)
    end
  end

  def importar_turma_sigaa(turma_json, contexto)
    ActiveRecord::Base.transaction do
      materia = encontrar_materia_sigaa!(turma_json["materia_codigo"])
      turma = salvar_turma_sigaa!(turma_json, materia)
      contexto[:turmas_ativas_ids] << turma.id
    end
  rescue StandardError => e
    contexto[:erros_importacao] << "Turma nº #{turma_json['numero']} (#{turma_json['ano']}/#{turma_json['semestre']}) da matéria '#{turma_json['materia_codigo']}': #{e.message}"
  end

  def salvar_turma_sigaa!(turma_json, materia)
    turma = Turma.find_or_initialize_by(
      numero: turma_json["numero"],
      ano: turma_json["ano"],
      semestre: turma_json["semestre"],
      materia_id: materia.id
    )
    turma.save!
    turma
  end

  def importar_docentes_sigaa(dados, contexto)
    dados["usuarios_docentes"]&.each do |docente_json|
      importar_docente_sigaa(docente_json, contexto)
    end
  end

  def importar_docente_sigaa(docente_json, contexto)
    matricula = docente_json["matricula"]

    ActiveRecord::Base.transaction do
      contexto[:matriculas_ativas_json] << matricula
      usuario = salvar_usuario_importado_sigaa!(docente_json, matricula)
      salvar_perfil_docente_sigaa!(usuario, docente_json)
      turmas_docente_ids = importar_participacoes_docente_sigaa!(usuario, docente_json)
      usuario.participacoes_turma.docentes.where.not(turma_id: turmas_docente_ids).destroy_all
    end
  rescue StandardError => e
    contexto[:erros_importacao] << "Docente #{docente_json['nome']} (Matrícula: #{matricula}): #{e.message}"
  end

  def salvar_perfil_docente_sigaa!(usuario, docente_json)
    perfil = PerfilDocente.find_or_initialize_by(id: usuario.id)
    perfil.departamento_id = docente_json["departamento_id_temp"]
    perfil.save!
  end

  def importar_participacoes_docente_sigaa!(usuario, docente_json)
    turmas_docente_ids = []
    (docente_json["turmas_lecionadas"] || []).each do |mat_json|
      importar_participacao_sigaa!(usuario, mat_json, :docente, turmas_docente_ids)
    end
    turmas_docente_ids
  end

  def importar_discentes_sigaa(dados, contexto)
    dados["usuarios_discentes"]&.each do |discente_json|
      importar_discente_sigaa(discente_json, contexto)
    end
  end

  def importar_discente_sigaa(discente_json, contexto)
    matricula = discente_json["matricula"]

    ActiveRecord::Base.transaction do
      contexto[:matriculas_ativas_json] << matricula
      usuario = salvar_usuario_importado_sigaa!(discente_json, matricula)
      PerfilDiscente.find_or_create_by!(id: usuario.id)
      turmas_aluno_ids = importar_participacoes_discente_sigaa!(usuario, discente_json)
      usuario.participacoes_turma.where.not(turma_id: turmas_aluno_ids).destroy_all
    end
  rescue StandardError => e
    contexto[:erros_importacao] << "Discente #{discente_json['nome']} (Matrícula: #{matricula}): #{e.message}"
  end

  def importar_participacoes_discente_sigaa!(usuario, discente_json)
    turmas_aluno_ids = []
    discente_json["turmas_matriculadas"].each do |mat_json|
      importar_participacao_sigaa!(usuario, mat_json, :discente, turmas_aluno_ids)
    end
    turmas_aluno_ids
  end

  def salvar_usuario_importado_sigaa!(usuario_json, matricula)
    usuario = Usuario.find_or_initialize_by(matricula: matricula)
    usuario.nome = usuario_json["nome"]
    usuario.email = usuario_json["email"]
    inicializar_usuario_importado_sigaa(usuario)
    usuario.save!
    usuario
  end

  def inicializar_usuario_importado_sigaa(usuario)
    return unless usuario.new_record?

    usuario.status = 0
    usuario.senha = ""
  end

  def importar_participacao_sigaa!(usuario, mat_json, tipo_participacao, turmas_ids)
    turma = encontrar_turma_sigaa!(mat_json)
    turmas_ids << turma.id
    ParticipacaoTurma.find_or_create_by!(
      usuario_id: usuario.id,
      turma_id: turma.id,
      tipo_participacao: tipo_participacao
    )
  end

  def encontrar_materia_sigaa!(codigo)
    materia = Materia.find_by(codigo: codigo)
    raise "Matéria com código '#{codigo}' não existe no sistema." if materia.nil?

    materia
  end

  def encontrar_turma_sigaa!(mat_json)
    materia = encontrar_materia_sigaa!(mat_json["materia_codigo"])
    turma = Turma.find_by(
      materia_id: materia.id,
      numero: mat_json["numero_turma"],
      ano: mat_json["ano"],
      semestre: mat_json["semestre"]
    )
    if turma.nil?
      raise "Turma nº #{mat_json['numero_turma']} (#{mat_json['ano']}/#{mat_json['semestre']}) da matéria '#{materia.nome}' não foi localizada no sistema."
    end

    turma
  end

  def sincronizar_remocoes_sigaa(contexto)
    ActiveRecord::Base.transaction do
      Turma.where.not(id: contexto[:turmas_ativas_ids]).destroy_all
      Materia.where.not(codigo: contexto[:codigos_materias_ativos]).destroy_all
      remover_usuarios_importacao_sigaa(contexto[:matriculas_ativas_json])
    end
  end

  def remover_usuarios_importacao_sigaa(matriculas_ativas_json)
    Usuario.where.not(matricula: matriculas_ativas_json).each do |usuario|
      next if usuario.administrador?

      usuario.destroy!
    end
  end

  def redirecionar_importacao_sigaa(erros_importacao)
    if erros_importacao.empty?
      redirect_to gerenciamento_path, flash: { success: "Dados do SIGAA importados e sincronizados com sucesso!" }
    else
      redirect_to gerenciamento_path, flash: { error: "A importação foi concluída parcialmente.", error_list: erros_importacao }
    end
  end

  def inicializar_pesquisa
    @termo = params[:q].to_s.strip
    @avaliacoes = Avaliacao.none
    @templates = Template.none
    @formularios = Formulario.none
    @tipos_selecionados = tipos_selecionados
  end

  def pesquisar_por_turma
    turma_id = params[:turma_id]
    @avaliacoes = avaliacoes_da_turma(turma_id) if tipo_selecionado?("avaliacoes")
    @formularios = formularios_da_turma(turma_id) if administrador_com_tipo?("formularios")
  end

  def pesquisar_por_termo
    padrao = padrao_pesquisa
    @avaliacoes = pesquisar_avaliacoes(padrao) if tipo_selecionado?("avaliacoes")

    return unless current_user.administrador?

    @templates = pesquisar_templates(padrao) if tipo_selecionado?("templates")
    @formularios = pesquisar_formularios(padrao) if tipo_selecionado?("formularios")
  end

  def padrao_pesquisa
    "%#{ActiveRecord::Base.sanitize_sql_like(@termo.downcase)}%"
  end

  def tipo_selecionado?(tipo)
    @tipos_selecionados.include?(tipo)
  end

  def administrador_com_tipo?(tipo)
    current_user.administrador? && tipo_selecionado?(tipo)
  end

  def sugestoes_do_termo(termo)
    tipos = tipos_selecionados
    padrao = "%#{ActiveRecord::Base.sanitize_sql_like(termo.downcase)}%"

    sugestoes_basicas(termo, padrao, tipos) +
      sugestoes_avaliacoes(padrao, tipos) +
      sugestoes_administrador(padrao, tipos)
  end

  def sugestoes_basicas(termo, padrao, tipos)
    sugestoes_turmas(termo, tipos) + sugestoes_materias(padrao, tipos)
  end

  def sugestoes_turmas(termo, tipos)
    pesquisar_turmas(termo).limit(3).map do |turma|
      {
        tipo: "Turma",
        titulo: turma.materia.nome,
        subtitulo: nil,
        materia_codigo: turma.materia.codigo,
        turma_codigo: turma.codigo_exibicao,
        url: turma_suggestion_url(turma, tipos)
      }
    end
  end

  def sugestoes_materias(padrao, tipos)
    pesquisar_materias(padrao).limit(3).map do |materia|
      {
        tipo: "Matéria",
        titulo: materia.nome,
        subtitulo: nil,
        materia_codigo: materia.codigo,
        url: materia_suggestion_url(materia, tipos)
      }
    end
  end

  def sugestoes_avaliacoes(padrao, tipos)
    return [] unless tipos.include?("avaliacoes")

    pesquisar_avaliacoes(padrao).limit(5).map do |avaliacao|
      sugestao_avaliacao(avaliacao)
    end
  end

  def sugestao_avaliacao(avaliacao)
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

  def sugestoes_administrador(padrao, tipos)
    return [] unless current_user.administrador?

    sugestoes_templates(padrao, tipos) + sugestoes_formularios(padrao, tipos)
  end

  def sugestoes_templates(padrao, tipos)
    return [] unless tipos.include?("templates")

    pesquisar_templates(padrao).limit(5).map do |template|
      {
        tipo: "Template",
        titulo: template.titulo,
        subtitulo: template.descricao.presence || "Sem descrição",
        url: template_path(template)
      }
    end
  end

  def sugestoes_formularios(padrao, tipos)
    return [] unless tipos.include?("formularios")

    pesquisar_formularios(padrao).limit(5).map do |formulario|
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
