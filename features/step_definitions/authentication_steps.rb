# frozen_string_literal: true

def campo_autenticacao(nome)
  {
    "E-mail ou Matrícula" => "identificador",
    "E-mail" => "email",
    "Senha" => "senha",
    "Nova Senha" => "password",
    "Confirme a Senha" => "password_confirmation"
  }.fetch(nome)
end

def usuario_recuperacao
  estado[:usuario_recuperacao] ||= usuario_com_email(
    nome: "Usuário para recuperação",
    email: "usuario.valido@email.com",
    senha: "SenhaAtual123"
  )
end

Given(
  /^que a base de dados possui um usuário comum com e-mail "([^"]+)", matrícula "([^"]+)" e senha "([^"]+)"$/
) do |email, matricula, senha|
  estado[:usuario_comum] = usuario_participante(
    nome: "Aluno",
    email: email,
    matricula: matricula
  )
  estado[:usuario_comum].update!(senha: senha)
end

Given(/^possui um usuário administrador com matrícula "([^"]+)" e senha "([^"]+)"$/) do |matricula, senha|
  usuario = usuario_administrador
  usuario.update!(matricula: matricula, senha: senha)
  estado[:matriculas_administrativas] ||= {}
  estado[:matriculas_administrativas][matricula] = usuario.id
end

Given(/^que fui importado do SIGAA mas ainda não possuo senha cadastrada$/) do
  estado[:usuario_importado] = Usuario.create!(
    nome: "Usuário importado",
    email: "usuario.importado@unb.br",
    matricula: "IMPORTADO123",
    status: :pendente
  )
end

Given(/^que acessei o link de ativação contido no e-mail de cadastro enviado pelo sistema$/) do
  token = estado[:usuario_importado].tokens.create!(
    value: SecureRandom.hex(16),
    tipo: :cadastro,
    expires_at: 10.minutes.from_now
  )

  visit confirmar_cadastro_path(token: token.value)
end

Given(/^que estou na página de login$/) do
  visit root_path
end

Given(/^que existe um usuário ativo com o e-mail "([^"]+)"$/) do |email|
  estado[:usuario_recuperacao] = usuario_com_email(
    nome: "Usuário para recuperação",
    email: email,
    senha: "SenhaAtual123"
  )
  allow_any_instance_of(AuthController)
    .to receive(:enviar_email_redefinicao)
    .and_return(true)
end

Given(/^que solicitei a recuperação de senha e recebi o e-mail com o link de redefinição$/) do
  token = usuario_recuperacao.tokens.create!(
    value: SecureRandom.hex(16),
    tipo: :redefinicao,
    expires_at: 10.minutes.from_now
  )
  estado[:token_redefinicao] = token
end

Given(/^que solicitei a recuperação de senha e recebi o e-mail há mais de 10 minutos$/) do
  token = usuario_recuperacao.tokens.create!(
    value: SecureRandom.hex(16),
    tipo: :redefinicao,
    expires_at: 1.minute.ago
  )
  estado[:token_redefinicao] = token
end

When(/^eu preencho o campo "([^"]+)" com "([^"]+)"$/) do |campo, valor|
  fill_in campo_autenticacao(campo), with: valor
end

When(/^preencho o campo "([^"]+)" com "([^"]+)"$/) do |campo, valor|
  fill_in campo_autenticacao(campo), with: valor
end

When(/^eu deixo o campo "([^"]+)" vazio$/) do |campo|
  fill_in campo_autenticacao(campo), with: ""
end

When(/^deixo o campo "([^"]+)" vazio$/) do |campo|
  fill_in campo_autenticacao(campo), with: ""
end

When(/^preencho a nova senha com "([^"]+)"$/) do |senha|
  fill_in "password", with: senha
end

When(/^confirmo a nova senha com "([^"]+)"$/) do |senha|
  fill_in "password_confirmation", with: senha
end

When(/^eu clico em "([^"]+)"$/) do |acao|
  click_link acao
end

When(/^clico em "(Concluir Cadastro|Enviar e-mail de redefinição|Alterar Senha)"$/) do |acao|
  click_button acao
end

When(/^clico no botão "([^"]+)"$/) do |botao|
  click_button botao
end

When(/^eu acesso o link de redefinição do e-mail dentro do prazo de validade$/) do
  visit redefinir_senha_path(token: estado.fetch(:token_redefinicao).value)
end

When(/^eu tento acessar o link de redefinição contido no e-mail$/) do
  visit redefinir_senha_path(token: estado.fetch(:token_redefinicao).value)
end

Then(/^devo ser autenticado com sucesso$/) do
  expect(page).to have_current_path(avaliacoes_path)
  expect(page).to have_css('[data-controller="app-shell"]')
end

Then(/^devo visualizar a opção de gerenciamento no menu lateral$/) do
  expect(page).to have_link("Gerenciamento", href: gerenciamento_path)
end

Then(/^não devo visualizar a opção de gerenciamento no menu lateral$/) do
  expect(page).not_to have_link("Gerenciamento", href: gerenciamento_path)
end

Then(/^permaneço na página de login$/) do
  expect(page).to have_current_path(root_path)
  expect(page).to have_button("Entrar")
end

Then(/^meu usuário deve ser ativado na base de dados$/) do
  expect(estado[:usuario_importado].reload).to be_ativo
end

Then(/^o meu usuário deve continuar inativo$/) do
  expect(estado[:usuario_importado].reload).to be_pendente
end

Then(/^minha senha deve ser atualizada no sistema$/) do
  expect(usuario_recuperacao.reload.authenticate_senha("MinhaNovaSenha77")).to be_truthy
end

Then(/^devo ser redirecionado para a página de login$/) do
  expect(page).to have_current_path(root_path)
end

Then(
  /^devo ver a mensagem "(Cadastro concluído com sucesso! Faça seu login\.|E-mail enviado com sucesso!)"$/
) do |mensagem|
  expect(page).to have_content(mensagem)
end

Then(/^devo ver a mensagem de erro "([^"]+)"$/) do |mensagem|
  expect(page).to have_content(mensagem)
end

Then(/^devo ver o aviso "([^"]+)"$/) do |mensagem|
  expect(page).to have_content(mensagem)
end
