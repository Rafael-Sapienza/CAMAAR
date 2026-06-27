# frozen_string_literal: true

def criar_contexto_formulario_com_questoes(nome_turma)
  usuario = usuario_contexto_resposta
  depto = departamento_contexto_resposta
  @turma = turma_contexto_resposta(nome_turma, depto)
  perf_adm = perfil_adm_contexto_resposta(depto)
  template = template_contexto_resposta(perf_adm)
  participacao = participacao_contexto_resposta(usuario, @turma)

  criar_formulario_contexto_resposta(template, perf_adm)
  definir_questoes_contexto_resposta
  @avaliacao = @formulario.avaliacoes.find_by!(participacao_turma: participacao)
end

def usuario_contexto_resposta
  usuario = usuario_atual || estado[:usuario_participante] || usuario_participante
  definir_usuario_atual(usuario)
  usuario
end

def departamento_contexto_resposta
  Departamento.find_or_create_by!(nome: "Departamento Geral")
end

def turma_contexto_resposta(nome_turma, depto)
  materia = materia_contexto_resposta(nome_turma, depto)
  Turma.find_or_create_by!(materia: materia, ano: 2026, semestre: :primeiro) do |t|
    t.numero = rand(1..100)
  end
end

def materia_contexto_resposta(nome_turma, depto)
  Materia.find_or_create_by!(nome: nome_turma, departamento: depto) do |m|
    m.codigo = "COD#{rand(1000..9999)}"
  end
end

def perfil_adm_contexto_resposta(depto)
  adm = Usuario.create!(
    nome: "Administrador",
    email: "administrador#{rand(10000)}@t.com",
    matricula: "ADM#{rand(10000..99999)}",
    senha: "password123",
    status: :ativo
  )
  PerfilAdm.create!(usuario: adm, departamento: depto)
end

def template_contexto_resposta(perf_adm)
  questao_discursiva, questao_objetiva = questoes_contexto_resposta

  Template.create!(
    adm: perf_adm,
    titulo: "Template #{rand(1000)}",
    utilizacoes_questoes_attributes: [
      { questao_id: questao_discursiva.id, numero: 1 },
      { questao_id: questao_objetiva.id, numero: 2 }
    ]
  )
end

def questoes_contexto_resposta
  [
    questao_discursiva_contexto_resposta,
    questao_objetiva_contexto_resposta
  ]
end

def questao_discursiva_contexto_resposta
  Questao.create!(
    enunciado: "Como você avalia a turma?",
    tipo: :discursiva
  )
end

def questao_objetiva_contexto_resposta
  Questao.create!(
    enunciado: "Qual nota você dá?",
    tipo: :objetiva,
    opcoes_attributes: [
      { numero: 1, texto: "Ótimo" },
      { numero: 2, texto: "Ruim" }
    ]
  )
end

def participacao_contexto_resposta(usuario, turma)
  PerfilDiscente.find_or_create_by!(usuario: usuario)
  ParticipacaoTurma.find_or_create_by!(
    usuario: usuario,
    turma: turma,
    tipo_participacao: :discente
  )
end

def criar_formulario_contexto_resposta(template, perf_adm)
  @formulario = Formularios::CreateFromTemplate.call(
    template_id: template.id,
    turma_ids: [ @turma.id ],
    publico_alvo: :discentes,
    perfil_adm: perf_adm
  ).sole
end

def definir_questoes_contexto_resposta
  @questao_discursiva, @questao_objetiva = @formulario.questoes.order(:id).to_a
end

Dado('que estou na página de resposta do formulário da turma {string}') do |nome_turma|
  criar_contexto_formulario_com_questoes(nome_turma)
  visit responder_avaliacao_path(@avaliacao)
end

Dado('que já respondi o formulário da turma {string} anteriormente') do |nome_turma|
  criar_contexto_formulario_com_questoes(nome_turma)
  @avaliacao.marcar_como_respondida!
end

Dado("que existe uma avaliação pendente pertencente a outro participante") do
  participante_atual = usuario_atual
  outro_participante = usuario_participante(
    nome: "Outro participante",
    email: "outro-participante@unb.br",
    matricula: "OUTRO001"
  )
  definir_usuario_atual(outro_participante)
  criar_contexto_formulario_com_questoes("Cálculo 1")
  @avaliacao_alheia = @avaliacao
  definir_usuario_atual(participante_atual)
end

Dado("que o template de origem do formulário foi excluído") do
  @formulario.template.destroy!
  @formulario.reload
end

Quando('eu preencho todas as questões obrigatórias') do
  fill_in "respostas[#{@questao_discursiva.id}][texto]", with: "Achei a turma muito boa."

  primeira_opcao = @questao_objetiva.opcoes.ordenadas.first
  within "#questao-#{@questao_objetiva.id}" do
    choose primeira_opcao.texto
  end
end

Quando('eu deixo uma questão obrigatória em branco') do
  fill_in "respostas[#{@questao_discursiva.id}][texto]", with: "Resposta parcial."
end

Quando('confirmo o envio da avaliação') do
  click_button "Confirmar envio"
end

Quando('eu tento acessar a página de resposta do formulário da turma {string}') do |_nome_turma|
  visit responder_avaliacao_path(@avaliacao)
end

Quando("tento acessar essa avaliação pela URL") do
  visit responder_avaliacao_path(@avaliacao_alheia)
end

Quando("envio uma opção pertencente a outra questão") do
  outra_questao = Questao.create!(
    formulario: @formulario,
    enunciado: "Questão fora da resposta",
    tipo: :objetiva,
    opcoes_attributes: [
      { numero: 1, texto: "Opção externa A" },
      { numero: 2, texto: "Opção externa B" }
    ]
  )

  page.driver.submit(
    :post,
    submeter_avaliacao_path(@avaliacao),
    {
      respostas: {
        @questao_discursiva.id.to_s => { texto: "Resposta válida" },
        @questao_objetiva.id.to_s => { opcao_id: outra_questao.opcoes.first.id }
      }
    }
  )
end

Então('devo ver uma mensagem informando que a avaliação foi registrada com sucesso') do
  expect(page).to have_content("Avaliação registrada com sucesso.")
end

Então('o formulário da turma {string} não deve mais aparecer na lista de pendentes') do |nome_turma|
  expect(page).not_to have_content(nome_turma)
end

Então('devo ver uma mensagem informando que todas as questões obrigatórias devem ser preenchidas') do
  expect(page).to have_content("Todas as questões obrigatórias devem ser preenchidas.")
end

Então('a avaliação não deve ser registrada') do
  @avaliacao.reload
  expect(@avaliacao.respondida?).to be false
end

Então('devo ver uma mensagem informando que esta avaliação já foi respondida') do
  expect(page).to have_content("Esta avaliação já foi respondida.")
end

Então("devo ver uma mensagem informando que a avaliação não foi encontrada") do
  expect(page).to have_content("Avaliação não encontrada.")
  expect(page).to have_current_path(avaliacoes_pendentes_path)
end

Então("devo continuar vendo as questões copiadas para o formulário") do
  expect(@formulario.template).to be_nil
  expect(page).to have_content(@questao_discursiva.enunciado)
  expect(page).to have_content(@questao_objetiva.enunciado)
end
