require 'json'

arquivo = File.read(Rails.root.join('db', 'dados_iniciais.json'))
dados   = JSON.parse(arquivo)

def salvar_usuario_seed!(usuario_json)
  usuario = Usuario.find_or_initialize_by(matricula: usuario_json['matricula'])
  usuario.assign_attributes(
    nome: usuario_json['nome'],
    email: usuario_json['email'],
    status: usuario_json['status']
  )
  usuario.senha = usuario_json['password']
  usuario.senha_confirmation = usuario_json['password']
  usuario.save!
  usuario
end

def encontrar_turma_seed!(turma_json, contexto)
  materia = Materia.find_by(codigo: turma_json['materia_codigo'])
  raise "Matéria '#{turma_json['materia_codigo']}' não encontrada para #{contexto}." if materia.nil?

  turma = Turma.find_by(
    materia_id: materia.id,
    numero: turma_json['numero_turma'],
    ano: turma_json['ano'],
    semestre: turma_json['semestre']
  )
  return turma if turma.present?

  raise "Turma nº #{turma_json['numero_turma']} (#{turma_json['ano']}/#{turma_json['semestre']}) " \
        "da matéria '#{materia.nome}' não encontrada para #{contexto}."
end

def salvar_perfil_adm_seed!(usuario, departamento_id)
  perfil = PerfilAdm.find_or_initialize_by(id: usuario.id)
  perfil.departamento_id = departamento_id
  perfil.save!
end

def salvar_perfil_docente_seed!(usuario, departamento_id)
  perfil = PerfilDocente.find_or_initialize_by(id: usuario.id)
  perfil.departamento_id = departamento_id
  perfil.save!
end

def participacoes_seed(usuario, tipo_participacao)
  return usuario.participacoes_turma.docentes if tipo_participacao == :docente
  return usuario.participacoes_turma.discentes if tipo_participacao == :discente

  raise "Tipo de participação inválido: #{tipo_participacao}"
end

def sincronizar_participacoes_seed!(usuario, turmas_json, tipo_participacao, contexto)
  turma_ids = turmas_json.map do |turma_json|
    turma = encontrar_turma_seed!(turma_json, contexto)
    ParticipacaoTurma.find_or_create_by!(
      usuario_id: usuario.id,
      turma_id: turma.id,
      tipo_participacao: tipo_participacao
    )
    turma.id
  end

  participacoes_antigas = participacoes_seed(usuario, tipo_participacao)
  participacoes_antigas = participacoes_antigas.where.not(turma_id: turma_ids) if turma_ids.any?
  participacoes_antigas.destroy_all
end

dept_mapeamento = {}

puts "Semeando Departamentos..."
dados['departamentos'].each do |dept_json|
  dept_banco = Departamento.find_or_create_by!(nome: dept_json['nome'])
  dept_mapeamento[dept_json['id_temporario']] = dept_banco.id
end

puts "Semeando Matérias..."
dados['materias'].each do |mat_json|
  id_real = dept_mapeamento[mat_json['departamento_id_temp']]
  Materia.find_or_create_by!(codigo: mat_json['codigo']) do |m|
    m.nome           = mat_json['nome']
    m.departamento_id = id_real
  end
end

puts "Semeando Turmas..."
dados['turmas'].each do |turma_json|
  materia = Materia.find_by(codigo: turma_json['materia_codigo'])
  if materia.nil?
    puts "⚠️  Matéria #{turma_json['materia_codigo']} não encontrada."
    next
  end
  Turma.find_or_create_by!(
    numero:    turma_json['numero'],
    ano:       turma_json['ano'],
    semestre:  turma_json['semestre'],
    materia_id: materia.id
  )
end

puts "Semeando Administradores..."
dados['usuarios_admin'].each do |admin_json|
  id_real = dept_mapeamento[admin_json['departamento_id_temp']]

  usuario = salvar_usuario_seed!(admin_json)

  # PerfilAdm — sempre criado, sempre com departamento
  salvar_perfil_adm_seed!(usuario, id_real)

  case admin_json['perfil']
  when 'docente'
    # Departamento vai para o PerfilDocente
    salvar_perfil_docente_seed!(usuario, id_real)

    # Turmas lecionadas (opcional: admin-docente pode não estar lecionando nada)
    turmas_lecionadas_json = admin_json['turmas_lecionadas'] || []
    sincronizar_participacoes_seed!(usuario, turmas_lecionadas_json, :docente, "o admin #{admin_json['matricula']}")

  when 'discente'
    # PerfilDiscente não recebe departamento
    PerfilDiscente.find_or_create_by!(id: usuario.id)

    # Matrícula nas turmas — obrigatório, erro encerra o seed se falhar
    turmas_json = admin_json['turmas_matriculadas'] || []
    raise "Admin discente #{admin_json['matricula']} não tem turmas_matriculadas definidas." if turmas_json.empty?

    sincronizar_participacoes_seed!(usuario, turmas_json, :discente, "o admin #{admin_json['matricula']}")

  else
    raise "Admin #{admin_json['matricula']} tem perfil inválido ou ausente: '#{admin_json['perfil']}'."
  end
end

puts "Semeando Docentes..."
dados['usuarios_docentes'].to_a.each do |docente_json|
  id_real = dept_mapeamento[docente_json['departamento_id_temp']]
  usuario = salvar_usuario_seed!(docente_json)

  salvar_perfil_docente_seed!(usuario, id_real)
  sincronizar_participacoes_seed!(
    usuario,
    docente_json['turmas_lecionadas'] || [],
    :docente,
    "o docente #{docente_json['matricula']}"
  )
end

puts "Banco semeado com sucesso! 🎉"
