# frozen_string_literal: true

Given(/^estou na página "Gerenciamento"$/) do
  visit gerenciamento_path
end

When(/^eu acesso a página de criação de formulário$/) do
  visit new_formulario_path
end

When(/^eu tento acessar o formulário "([^"]+)"$/) do |nome|
  formulario = estado[:formularios_por_nome].fetch(nome)
  visit formulario_path(formulario)
end

When(/^eu tento exportar os resultados do formulário "([^"]+)"$/) do |nome|
  formulario = estado[:formularios_por_nome].fetch(nome)
  visit exportar_csv_formulario_path(formulario)
end

When(/^seleciono o template "([^"]+)"$/) do |titulo|
  select titulo, from: "template_id"
end

When(/^seleciono a turma "([^"]+)" da matéria "([^"]+)"$/) do |numero, materia|
  turma = turma_da_materia(numero, materia)
  check turma.nome_exibicao
end

When(/^seleciono o público-alvo "([^"]+)"$/) do |publico|
  choose publico.capitalize, allow_label_click: true
end

When(/^confirmo a criação do formulário$/) do
  click_button "Confirmar Publicação"
end

When(
  /^tento preparar um formulário para a turma "([^"]+)" da matéria "([^"]+)" usando o template "([^"]+)"$/
) do |numero, materia, titulo|
  turma = turma_da_materia(numero, materia)
  template = Template.find_by!(titulo: titulo)

  page.driver.submit(
    :post,
    preparar_formularios_path,
    { template_id: template.id, turma_ids: [ turma.id ] }
  )
end

Then(/^devo ver uma mensagem informando que o formulário foi criado com sucesso$/) do
  expect(page).to have_content("Formulário criado com sucesso para as turmas selecionadas")
end

Then(/^devo ver uma mensagem informando que não tenho permissão para gerenciar essa turma$/) do
  expect(page).to have_content("Uma ou mais turmas selecionadas são inválidas")
end

Then(/^devo ver uma mensagem informando que não tenho permissão para acessar esse formulário$/) do
  expect(page).to have_content("Você não tem permissão para acessar esse formulário.")
end

Then(/^devo ver uma mensagem informando que não tenho permissão para exportar os resultados desse formulário$/) do
  expect(page).to have_content(
    "Você não tem permissão para exportar os resultados desse formulário."
  )
end

Then(/^nenhum arquivo CSV deve ser baixado$/) do
  expect(page.response_headers.fetch("Content-Type", "")).not_to include("text/csv")
end
