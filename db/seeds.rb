require 'json'

arquivo = File.read(Rails.root.join('db', 'dados_iniciais.json'))
dados   = JSON.parse(arquivo)

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

  usuario = Usuario.find_or_create_by!(matricula: admin_json['matricula']) do |u|
    u.nome               = admin_json['nome']
    u.email              = admin_json['email']
    u.senha              = admin_json['password']
    u.senha_confirmation = admin_json['password']
    u.status             = admin_json['status']
  end

  # PerfilAdm — sempre criado, sempre com departamento
  PerfilAdm.find_or_create_by!(id: usuario.id) do |p|
    p.departamento_id = id_real
  end

  case admin_json['perfil']
  when 'docente'
    # Departamento vai para o PerfilDocente
    PerfilDocente.find_or_create_by!(id: usuario.id) do |p|
      p.departamento_id = id_real
    end

    # Turmas lecionadas (opcional: admin-docente pode não estar lecionando nada)
    turmas_lecionadas_json = admin_json['turmas_lecionadas'] || []

    turmas_lecionadas_json.each do |mat_json|
      materia = Materia.find_by(codigo: mat_json['materia_codigo'])
      raise "Matéria '#{mat_json['materia_codigo']}' não encontrada para o admin #{admin_json['matricula']}." if materia.nil?

      turma = Turma.find_by(
        materia_id: materia.id,
        numero: mat_json['numero_turma'],
        ano: mat_json['ano'],
        semestre: mat_json['semestre']
      )
      raise "Turma nº #{mat_json['numero_turma']} (#{mat_json['ano']}/#{mat_json['semestre']}) da matéria '#{materia.nome}' não encontrada para o admin #{admin_json['matricula']}." if turma.nil?

      ParticipacaoTurma.find_or_create_by!(usuario_id: usuario.id, turma_id: turma.id, tipo_participacao: :docente)
    end

  when 'discente'
    # PerfilDiscente não recebe departamento
    PerfilDiscente.find_or_create_by!(id: usuario.id)

    # Matrícula nas turmas — obrigatório, erro encerra o seed se falhar
    turmas_json = admin_json['turmas_matriculadas'] || []
    raise "Admin discente #{admin_json['matricula']} não tem turmas_matriculadas definidas." if turmas_json.empty?

    turmas_json.each do |mat_json|
      materia = Materia.find_by(codigo: mat_json['materia_codigo'])
      raise "Matéria '#{mat_json['materia_codigo']}' não encontrada para o admin #{admin_json['matricula']}." if materia.nil?

      turma = Turma.find_by(
        materia_id: materia.id,
        numero: mat_json['numero_turma'],
        ano: mat_json['ano'],
        semestre: mat_json['semestre']
      )
      raise "Turma nº #{mat_json['numero_turma']} (#{mat_json['ano']}/#{mat_json['semestre']}) da matéria '#{materia.nome}' não encontrada para o admin #{admin_json['matricula']}." if turma.nil?

      ParticipacaoTurma.find_or_create_by!(usuario_id: usuario.id, turma_id: turma.id, tipo_participacao: :discente)
    end

  else
    raise "Admin #{admin_json['matricula']} tem perfil inválido ou ausente: '#{admin_json['perfil']}'."
  end
end

puts "Banco semeado com sucesso! 🎉"
