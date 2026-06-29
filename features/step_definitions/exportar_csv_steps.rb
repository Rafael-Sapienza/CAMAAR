# frozen_string_literal: true

def administrador_csv
  usuario_atual || estado[:usuario_administrador] || usuario_administrador
end

def departamento_csv
  administrador_csv.perfil_adm.departamento
end

# -------------------------------------------------------
# Cenário 1: Formulário com Respostas (@happy)
# -------------------------------------------------------

Given('que existe um formulário com respostas para a turma {string}') do |nome_turma|
  materia = Materia.find_or_create_by!(nome: nome_turma, departamento: departamento_csv) { |m| m.codigo = "COD#{rand(1000)}" }
  @turma = Turma.find_or_create_by!(materia: materia, ano: 2026, semestre: :primeiro) { |t| t.numero = 1 }

  @questao = Questao.create!(enunciado: "Avalie o professor", tipo: :discursiva)

  template = Template.create!(
    adm: administrador_csv.perfil_adm,
    titulo: "Template Padrão",
    utilizacoes_questoes_attributes: [
      { questao_id: @questao.id, numero: 1 }
    ]
  )

  aluno = Usuario.create!(
    nome: "João Respondedor",
    email: "joao#{rand(1000)}@teste.com",
    matricula: "MAT#{rand(10000..99999)}",
    senha: "password123",
    status: :ativo
  )
  PerfilDiscente.create!(usuario: aluno)
  part = ParticipacaoTurma.create!(usuario: aluno, turma: @turma, tipo_participacao: :discente)

  @formulario = Formularios::CreateFromTemplate.call(
    template_id: template.id,
    turma_ids: [ @turma.id ],
    publico_alvo: :discentes,
    perfil_adm: administrador_csv.perfil_adm
  ).sole
  @questao = @formulario.questoes.sole
  avaliacao = @formulario.avaliacoes.find_by!(participacao_turma: part)
  avaliacao.marcar_como_respondida!

  resposta = Resposta.new(avaliacao: avaliacao, questao: @questao)
  resposta.build_texto(texto: "Ótima aula!")
  resposta.save!(validate: false)
end

When('eu acesso a página de relatórios do meu departamento') do
  visit formularios_path

  within(".template-form__card", text: @formulario.turma.nome_exibicao) do
    find(".template-form__card-link").click
  end

  expect(page).to have_current_path(formulario_path(@formulario))
end

When('solicito a exportação do formulário da turma {string}') do |_nome_turma|
  click_link "Exportar CSV"
end

Then('o download do arquivo CSV deve ser iniciado') do
  expect(page.response_headers["Content-Type"]).to include "text/csv"
  expect(page.response_headers["Content-Disposition"]).to include "attachment"
end

Then('o CSV deve conter os dados esperados das avaliações') do
  expect(page.body).to include("João Respondedor")
  expect(page.body).to include("Avalie o professor")
  expect(page.body).to include("Ótima aula!")
end

# -------------------------------------------------------
# Cenário 2: Formulário sem Respostas (@happy)
# -------------------------------------------------------

Given('que existe um formulário sem respostas para a turma {string} do meu departamento') do |nome_turma|
  materia = Materia.find_or_create_by!(nome: nome_turma, departamento: departamento_csv) { |m| m.codigo = "COD#{rand(1000)}" }
  @turma = Turma.find_or_create_by!(materia: materia, ano: 2026, semestre: :primeiro) { |t| t.numero = 1 }

  @questao = Questao.create!(enunciado: "Avalie a infraestrutura", tipo: :discursiva)

  template = Template.create!(
    adm: administrador_csv.perfil_adm,
    titulo: "Template Vazio",
    utilizacoes_questoes_attributes: [
      { questao_id: @questao.id, numero: 1 }
    ]
  )

  @formulario_vazio = Formularios::CreateFromTemplate.call(
    template_id: template.id,
    turma_ids: [ @turma.id ],
    publico_alvo: :discentes,
    perfil_adm: administrador_csv.perfil_adm
  ).sole
end

When('eu solicito a exportação do formulário da turma {string}') do |_nome_turma|
  visit formulario_path(@formulario_vazio)
  click_link "Exportar CSV"
end

Then('o arquivo CSV deve conter apenas a linha de cabeçalho') do
  linhas = page.body.split("\n")
  expect(linhas.size).to eq(1)
  expect(linhas.first).to include("Aluno;Matrícula;Avalie a infraestrutura")
end

# -------------------------------------------------------
# Cenário 3: Tentativa de Acesso por Não-Administrador (@sad)
# -------------------------------------------------------

When('eu tento acessar a rota de exportação de resultados em CSV') do
  depto = Departamento.find_or_create_by!(nome: "Departamento Teste")
  materia = Materia.find_or_create_by!(nome: "Matéria", departamento: depto) { |m| m.codigo = "MAT001" }
  turma = Turma.find_or_create_by!(materia: materia, ano: 2026, semestre: :primeiro) { |t| t.numero = 1 }

  admin_dono = Usuario.find_or_create_by!(email: "dono#{rand(1000)}@t.com") do |u|
    u.nome = "Dono"
    u.matricula = "DONO#{rand(10000..99999)}"
    u.senha = "password123"
    u.status = :ativo
  end
  perf = PerfilAdm.create!(usuario: admin_dono, departamento: depto)

  questao = Questao.create!(enunciado: "Questao Sad", tipo: :discursiva)
  template = Template.create!(
    adm: perf,
    titulo: "Template Sad",
    utilizacoes_questoes_attributes: [
      { questao_id: questao.id, numero: 1 }
    ]
  )

  form = Formulario.create!(adm: perf, turma: turma, publico_alvo: :discentes, template: template)

  visit exportar_csv_formulario_path(form)
end

Then('devo ver uma mensagem informando que apenas administradores possuem acesso a este recurso') do
  expect(page).to have_content("Você já está conectado no sistema. Se quiser sair, faça log out")
end
