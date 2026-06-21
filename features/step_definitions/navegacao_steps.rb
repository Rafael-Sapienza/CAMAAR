# frozen_string_literal: true

Dado("que estou na página inicial do CAMAAR") do
  visit avaliacoes_path
end

Dado("que existem um template e um formulário pesquisáveis chamados {string}") do |titulo|
  template = template_com_titulo(titulo, adm: adm_atual)
  turma = turma_com_identificador(
    "Engenharia de Software",
    departamento_nome: adm_atual.departamento.nome
  )
  @formulario_pesquisavel = formulario_para_turma(
    turma,
    template: template,
    adm: adm_atual
  )
  @template_pesquisavel = template
end

Dado("que existe um formulário pesquisável chamado {string} em outro departamento") do |titulo|
  outro_admin = usuario_administrador(departamento: "Departamento Externo")
  template = template_com_titulo(titulo, adm: outro_admin.perfil_adm)
  turma = turma_com_identificador(
    "Cálculo 1",
    departamento_nome: outro_admin.perfil_adm.departamento.nome
  )
  @formulario_de_outro_departamento = formulario_para_turma(
    turma,
    template: template,
    adm: outro_admin.perfil_adm
  )
end

Quando("acesso a área de templates pelo menu lateral") do
  click_link "Templates"
end

Quando("acesso a área de formulários pelo menu lateral") do
  click_link "Formulários"
end

Quando("acesso o gerenciamento pelo menu lateral") do
  click_link "Gerenciamento"
end

Quando("pesquiso por {string}") do |termo|
  fill_in "Pesquisar no CAMAAR", with: termo
  click_button "Pesquisar"
end

Quando("envio a pesquisa sem informar um termo") do
  fill_in "Pesquisar no CAMAAR", with: ""
  click_button "Pesquisar"
end

Então("devo ver o menu lateral e a pesquisa global") do
  expect(page).to have_css('[data-controller="app-shell"]')
  expect(page).to have_css(
    'button.hamburger-btn[aria-label="Abrir ou fechar menu"]' \
      '[data-action="app-shell#toggleSidebar"]'
  )
  expect(page).to have_field("Pesquisar no CAMAAR")
end

Então("devo estar na página de templates") do
  expect(page).to have_current_path(templates_path)
end

Então("devo estar na página de formulários") do
  expect(page).to have_current_path(formularios_path)
end

Então("devo estar na página de gerenciamento") do
  expect(page).to have_current_path(gerenciamento_path)
end

Então("devo ver o template e o formulário {string} nos resultados") do |titulo|
  expect(page).to have_current_path(pesquisa_path, ignore_query: true)
  expect(page).to have_link(titulo, href: template_path(@template_pesquisavel))
  expect(page).to have_link(titulo, href: formulario_path(@formulario_pesquisavel))
end

Então("devo ver as áreas gerais no menu lateral") do
  within("#app-sidebar") do
    expect(page).to have_link("Início")
    expect(page).to have_link("Avaliações pendentes")
  end
end

Então("não devo ver as áreas administrativas no menu lateral") do
  within("#app-sidebar") do
    expect(page).to have_no_link("Templates")
    expect(page).to have_no_link("Formulários")
    expect(page).to have_no_link("Gerenciamento")
  end
end

Então("devo ver uma orientação para informar o que desejo encontrar") do
  expect(page).to have_current_path(pesquisa_path, ignore_query: true)
  expect(page).to have_content("Informe o que deseja encontrar no campo de pesquisa.")
end

Então("não devo ver o formulário de outro departamento nos resultados") do
  expect(page).to have_no_link(
    @formulario_de_outro_departamento.template.titulo,
    href: formulario_path(@formulario_de_outro_departamento)
  )
end
