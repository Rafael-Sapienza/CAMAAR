# frozen_string_literal: true

def caminho_arquivo_sigaa
  Rails.root.join("db", "usuarios_sigaa.json")
end

def dados_sigaa_do_cenario
  departamento_id = adm_atual.departamento_id
  turmas = estado[:sigaa][:turmas].uniq { |turma| turma[:codigo] }

  participantes = estado[:sigaa][:participantes].dup
  estado[:sigaa][:atualizacoes].each do |matricula, alteracoes|
    next if participantes.any? { |participante| participante[:matricula] == matricula }

    usuario = Usuario.find_by!(matricula: matricula)
    participantes << {
      nome: alteracoes[:nome] || usuario.nome,
      matricula: matricula,
      email: alteracoes[:email] || usuario.email
    }
  end

  {
    "materias" => turmas.map do |turma|
      {
        "codigo" => turma[:codigo],
        "nome" => turma[:nome],
        "departamento_id_temp" => departamento_id
      }
    end,
    "turmas" => turmas.map do |turma|
      {
        "numero" => 1,
        "ano" => Date.current.year,
        "semestre" => Turma.semestres.fetch(Turma.semestre_atual),
        "materia_codigo" => turma[:codigo]
      }
    end,
    "usuarios_docentes" => [],
    "usuarios_discentes" => participantes.map do |participante|
      turma = turmas.find { |item| item[:codigo] == participante[:codigo] } || turmas.first
      matriculas = if turma
        [ { "materia_codigo" => turma[:codigo], "numero_turma" => 1 } ]
      else
        []
      end

      {
        "matricula" => participante[:matricula],
        "nome" => participante[:nome],
        "email" => participante[:email],
        "turmas_matriculadas" => matriculas
      }
    end
  }
end

def preparar_fonte_sigaa
  allow(File).to receive(:exist?).and_call_original
  allow(File).to receive(:exist?).with(caminho_arquivo_sigaa).and_return(true)
  allow(File).to receive(:read).and_call_original

  case estado[:sigaa][:erro]
  when :json_invalido
    allow(File).to receive(:read).with(caminho_arquivo_sigaa).and_return("{invalido")
  when :indisponivel
    allow(File).to receive(:read).with(caminho_arquivo_sigaa).and_raise(Errno::EIO)
  else
    allow(File).to receive(:read)
      .with(caminho_arquivo_sigaa)
      .and_return(JSON.generate(dados_sigaa_do_cenario))
  end
end

Given(/^que o sistema não possui nenhuma turma cadastrada$/) do
  Avaliacao.delete_all
  Formulario.delete_all
  ParticipacaoTurma.delete_all
  Turma.delete_all
end

Given(/^que o sistema não possui nenhum participante cadastrado$/) do
  participantes = Usuario.joins(:perfil_discente).where.not(id: usuario_atual.id)
  ParticipacaoTurma.where(usuario: participantes).delete_all
  participantes.find_each(&:destroy!)
end

Given(/^que o sistema possui a turma "([^"]+)" \(([^)]+)\) cadastrada$/) do |nome, codigo|
  materia = materia_com_nome(
    nome,
    departamento_nome: adm_atual.departamento.nome,
    codigo: codigo
  )

  Turma.find_or_create_by!(
    materia: materia,
    ano: Date.current.year,
    semestre: Turma.semestre_atual,
    numero: 1
  )
end

Given(/^que o sistema não possui o usuário "([^"]+)" \(([^)]+)\) cadastrado$/) do |_nome, matricula|
  Usuario.find_by(matricula: matricula)&.destroy!
end

Given(/^que o SIGAA contém a turma "([^"]+)" \(([^)]+)\)$/) do |nome, codigo|
  estado[:sigaa][:turmas] << { nome: nome, codigo: codigo }
end

Given(
  /^que o SIGAA contém as turmas "([^"]+)" \(([^)]+)\), "([^"]+)" \(([^)]+)\) e "([^"]+)" \(([^)]+)\)$/
) do |nome1, codigo1, nome2, codigo2, nome3, codigo3|
  estado[:sigaa][:turmas].concat(
    [
      { nome: nome1, codigo: codigo1 },
      { nome: nome2, codigo: codigo2 },
      { nome: nome3, codigo: codigo3 }
    ]
  )
end

Given(/^esta turma contém o participante "([^"]+)" \(([^)]+)\)$/) do |nome, matricula|
  estado[:sigaa][:participantes] << {
    nome: nome,
    matricula: matricula,
    email: "#{matricula}@unb.br"
  }
end

Given(
  /^que o usuário "([^"]+)" \(([^)]+)\) já existe no sistema com o e-mail "([^"]+)"$/
) do |nome, matricula, email|
  usuario_participante(nome: nome, email: email, matricula: matricula)
end

Given(
  /^que o usuário "([^"]+)" \(([^)]+)\) já existe no sistema com o nome "([^"]+)"$/
) do |_nome_original, matricula, nome|
  usuario_participante(
    nome: nome,
    email: "#{matricula}@unb.br",
    matricula: matricula
  )
end

Given(
  /^que o usuário "([^"]+)" \(([^)]+)\) já existe no sistema com o e-mail "([^"]+)" e o nome "([^"]+)"$/
) do |_nome_original, matricula, email, nome|
  usuario_participante(nome: nome, email: email, matricula: matricula)
end

Given(
  /^a fonte de dados externa indica que o e-mail de "([^"]+)" agora é "([^"]+)"$/
) do |matricula, email|
  estado[:sigaa][:atualizacoes][matricula] ||= {}
  estado[:sigaa][:atualizacoes][matricula][:email] = email
end

Given(
  /^a fonte de dados externa indica que o nome de "([^"]+)" agora é "([^"]+)"$/
) do |matricula, nome|
  estado[:sigaa][:atualizacoes][matricula] ||= {}
  estado[:sigaa][:atualizacoes][matricula][:nome] = nome
end

Given(
  /^a fonte de dados externa indica que o e-mail de "([^"]+)" agora é "([^"]+)" e o nome agora é "([^"]+)"$/
) do |matricula, email, nome|
  estado[:sigaa][:atualizacoes][matricula] = { email: email, nome: nome }
end

Given(/^que o SIGAA retorna um arquivo JSON inválido$/) do
  estado[:sigaa][:erro] = :json_invalido
end

Given(/^que o SIGAA está indisponível$/) do
  estado[:sigaa][:erro] = :indisponivel
end

Given(/^que existe um participante pendente com e-mail no departamento do administrador$/) do
  materia = materia_com_nome(
    "Estruturas de Dados",
    departamento_nome: adm_atual.departamento.nome,
    codigo: "CIC0001"
  )
  turma = Turma.create!(
    materia: materia,
    numero: 1,
    ano: Date.current.year,
    semestre: Turma.semestre_atual
  )
  participante = Usuario.create!(
    nome: "Participante pendente",
    email: "participante.pendente@unb.br",
    matricula: "PENDENTE001",
    status: :pendente
  )
  PerfilDiscente.create!(usuario: participante)
  ParticipacaoTurma.create!(
    usuario: participante,
    turma: turma,
    tipo_participacao: :discente
  )

  estado[:participante_pendente] = participante
  allow_any_instance_of(DashboardController)
    .to receive(:enviar_email_convite_admin)
    .and_return(true)
end

Given(/^que o serviço de envio de convites está indisponível$/) do
  allow_any_instance_of(DashboardController)
    .to receive(:enviar_email_convite_admin)
    .and_return(false)
end

When(/^eu clico no botão "Importar dados"$/) do
  estado[:snapshot_sigaa] = {
    turmas: Turma.order(:id).pluck(:id, :updated_at),
    usuarios: Usuario.order(:id).pluck(:id, :nome, :email, :updated_at)
  }
  preparar_fonte_sigaa
  click_button "Importar dados"
end

When(/^eu clico no botão "Enviar solicitações de cadastro"$/) do
  click_button "Enviar solicitações de cadastro"
end

Then(/^a turma "([^"]+)" \(([^)]+)\) deve ser cadastrada no sistema$/) do |nome, codigo|
  expect(Materia.exists?(nome: nome, codigo: codigo)).to be(true)
end

Then(/^o usuário "([^"]+)" \(([^)]+)\) deve ser cadastrado no sistema$/) do |_nome, matricula|
  expect(Usuario.exists?(matricula: matricula)).to be(true)
end

Then(/^o usuário "([^"]+)" deve estar matriculado na turma "([^"]+)"$/) do |nome, turma|
  usuario = Usuario.find_by!(nome: nome)
  materia = Materia.find_by!(nome: turma)

  expect(usuario.turmas.joins(:materia).where(materias: { id: materia.id })).to exist
end

Then(/^as 3 matérias devem ser cadastradas no sistema$/) do
  expect(Materia.where(codigo: estado[:sigaa][:turmas].pluck(:codigo))).to have_attributes(count: 3)
end

Then(/^as 3 turmas devem ser cadastradas no sistema$/) do
  codigos = estado[:sigaa][:turmas].pluck(:codigo)
  expect(Turma.joins(:materia).where(materias: { codigo: codigos })).to have_attributes(count: 3)
end

Then(/^nenhuma matéria ou turma deve ser duplicada$/) do
  expect(Materia.distinct.count(:codigo)).to eq(Materia.count)
  expect(Turma.distinct.count(:id)).to eq(Turma.count)
end

Then(/^nenhuma nova turma deve ser cadastrada no sistema$/) do
  expect(Turma.count).to eq(estado[:snapshot_sigaa][:turmas].size)
end

Then(/^nenhum novo usuário deve ser cadastrado no sistema$/) do
  expect(Usuario.count).to eq(estado[:snapshot_sigaa][:usuarios].size)
end

Then(/^nenhuma turma existente deve ser alterada no sistema$/) do
  expect(Turma.order(:id).pluck(:id, :updated_at)).to eq(
    estado[:snapshot_sigaa][:turmas]
  )
end

Then(/^nenhum usuário existente deve ser alterado no sistema$/) do
  expect(Usuario.order(:id).pluck(:id, :nome, :email, :updated_at)).to eq(
    estado[:snapshot_sigaa][:usuarios]
  )
end

Then(/^nenhum usuário duplicado deve ser criado$/) do
  expect(Usuario.distinct.count(:email)).to eq(Usuario.count)
end

Then(/^o e-mail do usuário "([^"]+)" deve ser atualizado para "([^"]+)"$/) do |matricula, email|
  expect(Usuario.find_by!(matricula: matricula).email).to eq(email)
end

Then(/^o nome do usuário "([^"]+)" deve ser atualizado para "([^"]+)"$/) do |matricula, nome|
  expect(Usuario.find_by!(matricula: matricula).nome).to eq(nome)
end

Then(/^deve ser criado um token de cadastro para o participante$/) do
  token = estado[:participante_pendente].tokens.sole
  expect(token.tipo).to eq("cadastro")
  expect(token.expires_at).to be > Time.current
end

Then(/^nenhum token de cadastro deve permanecer para o participante$/) do
  expect(estado[:participante_pendente].tokens).to be_empty
end

Then(/^eu devo ver uma mensagem informando que 1 convite foi enviado$/) do
  expect(page).to have_content("Convites enviados com sucesso para os 1 usuários")
end

Then(/^eu devo ver uma mensagem informando instabilidade no envio$/) do
  expect(page).to have_content("O envio foi concluído com instabilidades")
end

Then(/^eu devo ver a mensagem de sucesso "([^"]+)"$/) do |mensagem|
  expect(page).to have_content(mensagem)
end

Then(/^eu devo ver a mensagem de erro "([^"]+)"$/) do |mensagem|
  expect(page).to have_content(mensagem)
end
