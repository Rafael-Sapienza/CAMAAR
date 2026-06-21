# frozen_string_literal: true

def administrador_formularios
  @admin ||= usuario_atual || estado[:usuario_administrador] || usuario_administrador
  @departamento = @admin.perfil_adm.departamento
  @admin
end

def preparar_sessao_formulario(template:, turmas:)
  page.driver.post preparar_formularios_path,
    template_id: template.id,
    turma_ids: turmas.map(&:id)
end

Dado("que existem formulários criados para o semestre atual") do
  administrador_formularios
  @template = criar_template_com_questoes(titulo: "Avaliação de Disciplina")
  @turma_a = criar_turma(nome_materia: "Estrutura de Dados", numero: 1)
  @turma_b = criar_turma(nome_materia: "Banco de Dados", numero: 2)
  @formularios = [
    criar_formulario_publicado(turma: @turma_a, template: @template, publico_alvo: :docentes),
    criar_formulario_publicado(turma: @turma_b, template: @template, publico_alvo: :discentes)
  ]
end

Dado("que nenhum formulário foi gerado para o semestre vigente") do
  administrador_formularios
  turma_passado = criar_turma(
    nome_materia: "Disciplina Anterior",
    numero: 1,
    ano: Date.current.year - 1,
    semestre: :segundo
  )
  criar_formulario_publicado(turma: turma_passado, publico_alvo: :docentes)
  expect(Formulario.do_semestre_atual.count).to eq(0)
end

Dado("que existe um template cadastrado chamado {string}") do |titulo|
  administrador_formularios
  @template = criar_template_com_questoes(titulo: titulo)
end

Dado("que existem as turmas {string} e {string} cadastradas no semestre atual") do |nome_turma_a, nome_turma_b|
  @turma_a = criar_turma_do_nome_exibicao(nome_turma_a)
  @turma_b = criar_turma_do_nome_exibicao(nome_turma_b)
end

Dado("que estou na página de criação de formulários") do
  visit new_formulario_path
end

Dado("que estou visualizando o template cadastrado chamado {string}") do |titulo|
  @template = Template.find_by!(titulo: titulo)
  visit template_path(@template)
end

Dado("que selecionei o template {string}") do |titulo|
  administrador_formularios
  @template = criar_template_com_questoes(titulo: titulo)
end

Dado("selecionei a turma {string}") do |nome_turma|
  @turma = criar_turma_do_nome_exibicao(nome_turma)
  preparar_sessao_formulario(template: @template, turmas: [ @turma ])
end

Dado("que estou na etapa de definição de público-alvo") do
  visit publicar_formularios_path
end

Quando("eu seleciono o template {string}") do |titulo|
  select titulo, from: "template_id"
end

Quando("solicito criar um formulário a partir desse template") do
  click_link "Usar em Formulário"
end

Quando("seleciono as turmas {string} e {string}") do |nome_turma_a, nome_turma_b|
  check nome_turma_a
  check nome_turma_b
end

Quando("não seleciono nenhuma turma") do
  page.all('input[name="turma_ids[]"]').each do |checkbox|
    checkbox.set(false) if checkbox.checked?
  end
end

Quando(/^clico em "(Continuar|Confirmar Publicação)"$/) do |botao|
  click_button botao
end

Quando("seleciono a opção de público-alvo como {string}") do |publico_alvo|
  choose publico_alvo, allow_label_click: true
end

Quando("eu seleciono a opção de público-alvo como {string}") do |publico_alvo|
  choose publico_alvo, allow_label_click: true
end

Quando("eu não seleciono nem {string} e nem {string}") do |_, _|
  page.all('input[name="publico_alvo"]').each do |radio|
    radio.set(false) if radio.checked?
  end
end

Quando("confirmo a publicação do formulário") do
  click_button "Confirmar Publicação"
end

Quando("tento confirmar a publicação sem selecionar template e turmas") do
  page.driver.submit(
    :post,
    formularios_path,
    { publico_alvo: "docentes" }
  )
end

Quando("eu acesso o painel de gerenciamento de formulários") do
  visit formularios_path
end

Quando("eu acesso a página de formulários criados") do
  visit formularios_path
end

Então("o formulário deve ser gerado com sucesso para ambas as turmas") do
  expect(Formulario.count).to eq(2)

  formulario_a = @turma_a.reload.formularios.sole
  formulario_b = @turma_b.reload.formularios.sole

  expect(formulario_a).to be_present
  expect(formulario_b).to be_present
  expect(formulario_a.template).to eq(@template)
  expect(formulario_b.template).to eq(@template)

  questoes_template = questoes_ordenadas_do_template(@template)

  [ formulario_a, formulario_b ].each do |formulario|
    questoes_formulario = formulario.questoes.order(:id)
    expect(questoes_formulario.count).to eq(questoes_template.count)
    expect(questoes_formulario.pluck(:enunciado)).to eq(questoes_template.map(&:enunciado))
  end
end

Então("devo estar na página de criação de formulários com o template {string} selecionado") do |titulo|
  expect(page).to have_current_path(
    new_formulario_path(template_id: @template.id)
  )
  expect(page).to have_select("template_id", selected: titulo)
end

Então("eu devo ver uma lista com todos os formulários criados, exibindo o template base, a turma e o público-alvo de cada um") do
  expect(page).to have_css("table tbody tr", count: @formularios.size)

  @formularios.each do |formulario|
    expect(page).to have_content(formulario.template.titulo)
    expect(page).to have_content(formulario.turma.nome_exibicao)
    publico_label = formulario.docentes? ? "Docentes" : "Discentes"
    expect(page).to have_content(publico_label)
  end
end

Então("cada formulário listado deve exibir um botão {string}") do |texto_botao|
  expect(page).to have_button(texto_botao, count: @formularios.size)
end

Então("eu devo ver a listagem vazia") do
  expect(page).not_to have_css("table tbody tr")
end

Então("a mensagem {string} deve ser exibida na tela") do |mensagem|
  expect(page).to have_content(mensagem)
end

Então(/^devo ver a mensagem "Formulário criado com sucesso para as turmas selecionadas"$/) do
  expect(page).to have_content("Formulário criado com sucesso para as turmas selecionadas")
end

Então("eu devo ver uma mensagem de erro dizendo {string}") do |mensagem|
  expect(page).to have_content(mensagem)
end

Então("eu devo ver o alerta {string}") do |mensagem|
  expect(page).to have_content(mensagem)
end

Então("nenhum formulário deve ser gerado") do
  expect(Formulario.count).to eq(0)
end

Então("o formulário não deve ser publicado") do
  expect(Formulario.count).to eq(0)
end

Então("o formulário deve ficar disponível apenas para os alunos matriculados na turma {string}") do |nome_turma|
  turma = turma_por_referencia(nome_turma)
  formulario = turma.reload.formularios.sole
  expect(formulario.publico_alvo).to eq("discentes")

  discente = usuario_participante(email: "discente-formulario@unb.br")
  ParticipacaoTurma.create!(usuario: discente, turma: turma, tipo_participacao: :discente)
  formulario.criar_avaliacoes_pendentes!

  login_como(discente)
  visit avaliacoes_pendentes_path
  expect(page).to have_content(turma.nome_exibicao)
end

Então("os docentes da turma não devem ter acesso para responder a este formulário") do
  turma = @turma || turma_por_referencia("Estrutura de Dados - Turma C")
  docente = usuario_docente(email: "docente-formulario@unb.br", departamento: turma.departamento)
  ParticipacaoTurma.create!(usuario: docente, turma: turma, tipo_participacao: :docente)

  login_como(docente)
  visit avaliacoes_pendentes_path
  expect(page).not_to have_content(@template.titulo)
end

Então("o formulário deve ficar disponível apenas para os professores vinculados à turma {string}") do |nome_turma|
  turma = turma_por_referencia(nome_turma)
  formulario = turma.reload.formularios.sole
  expect(formulario.publico_alvo).to eq("docentes")

  docente = usuario_docente(email: "docente-formulario@unb.br", departamento: turma.departamento)
  ParticipacaoTurma.create!(usuario: docente, turma: turma, tipo_participacao: :docente)
  formulario.criar_avaliacoes_pendentes!

  login_como(docente)
  visit avaliacoes_pendentes_path
  expect(page).to have_content(turma.nome_exibicao)
end

def criar_formulario_publicado(turma:, template: nil, publico_alvo: :docentes)
  template ||= criar_template_com_questoes(titulo: "Avaliação de teste")
  Formulario.create!(
    adm: administrador_formularios.perfil_adm,
    turma: turma,
    template: template,
    publico_alvo: publico_alvo
  )
end

def criar_turma_do_nome_exibicao(nome_exibicao)
  materia_nome, codigo = nome_exibicao.split(" - Turma ", 2)
  criar_turma(nome_materia: materia_nome, numero: Turma.numero_de_codigo_exibicao(codigo))
end

def turma_por_referencia(nome)
  return @turma if @turma && nome.include?(@turma.materia.nome)

  if nome.include?(" - Turma ")
    criar_turma_do_nome_exibicao(nome)
  else
    Turma.joins(:materia).find_by!(materias: { nome: nome })
  end
end
