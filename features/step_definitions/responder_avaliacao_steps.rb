# frozen_string_literal: true

def criar_contexto_formulario_com_questoes(nome_turma)
  usuario = usuario_contexto_resposta
  departamento = departamento_contexto_resposta
  @turma = turma_contexto_resposta(nome_turma, departamento)
  participacao = participacao_contexto_resposta(usuario, @turma)
  perfil_adm = perfil_adm_contexto_resposta(departamento)
  template = template_contexto_resposta(perfil_adm)

  @formulario = Formularios::CreateFromTemplate.call(
    template_id: template.id,
    turma_ids: [ @turma.id ],
    publico_alvo: :discentes,
    perfil_adm: perfil_adm
  ).sole
  @questao_discursiva, @questao_objetiva = @formulario.questoes.order(:id).to_a
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

def turma_contexto_resposta(nome_turma, departamento)
  materia = Materia.find_or_create_by!(nome: nome_turma, departamento: departamento) do |record|
    record.codigo = codigo_para(nome_turma)
  end

  Turma.find_or_create_by!(
    materia: materia,
    ano: Date.current.year,
    semestre: Turma.semestre_atual,
    numero: 1
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

def perfil_adm_contexto_resposta(departamento)
  usuario = usuario_com_email(
    nome: "Administrador de Avaliações",
    email: "administrador-avaliacoes-#{SecureRandom.hex(4)}@unb.br",
    senha: "Admin123"
  )

  PerfilAdm.create!(usuario: usuario, departamento: departamento)
end

def template_contexto_resposta(perfil_adm)
  Template.create!(
    adm: perfil_adm,
    titulo: "Template de Resposta #{SecureRandom.hex(3)}",
    descricao: "Template usado nos cenários de resposta",
    criado_em: Time.current,
    utilizacoes_questoes_attributes: [
      {
        numero: 1,
        questao_attributes: {
          enunciado: "Como você avalia a turma?",
          tipo: :discursiva
        }
      },
      {
        numero: 2,
        questao_attributes: {
          enunciado: "Qual nota você dá?",
          tipo: :objetiva,
          opcoes_attributes: [
            { numero: 1, texto: "Ótimo" },
            { numero: 2, texto: "Ruim" }
          ]
        }
      }
    ]
  )
end

def preencher_discursiva_resposta(texto)
  find("textarea[name='respostas[#{@questao_discursiva.id}][texto]']").set(texto)
end

def escolher_primeira_opcao_objetiva
  @opcao_escolhida = @questao_objetiva.opcoes.ordenadas.first

  within "#questao-#{@questao_objetiva.id}" do
    choose @opcao_escolhida.texto
  end
end

def parametros_respostas_validas
  {
    respostas: {
      @questao_discursiva.id.to_s => { texto: "Resposta registrada" },
      @questao_objetiva.id.to_s => { opcao_id: @questao_objetiva.opcoes.ordenadas.first.id }
    }
  }
end

def registrar_respostas_anteriores!
  resposta_discursiva = @avaliacao.respostas.build(questao: @questao_discursiva)
  resposta_discursiva.build_texto(texto: "Resposta anterior")
  resposta_discursiva.save!

  resposta_objetiva = @avaliacao.respostas.build(questao: @questao_objetiva)
  resposta_objetiva.opcoes_escolhidas.build(opcao: @questao_objetiva.opcoes.ordenadas.first)
  resposta_objetiva.save!

  @avaliacao.marcar_como_respondida!
end

Dado("que estou na página de resposta do formulário da turma {string}") do |nome_turma|
  criar_contexto_formulario_com_questoes(nome_turma)
  visit responder_avaliacao_path(@avaliacao)
end

Dado("que já respondi o formulário da turma {string} anteriormente") do |nome_turma|
  criar_contexto_formulario_com_questoes(nome_turma)
  registrar_respostas_anteriores!
  @quantidade_respostas_antes_do_reenvio = @avaliacao.respostas.count
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

Quando("eu preencho todas as questões obrigatórias") do
  preencher_discursiva_resposta("Achei a turma muito boa.")
  escolher_primeira_opcao_objetiva
end

Quando("eu deixo a questão objetiva em branco") do
  preencher_discursiva_resposta("Resposta parcial.")
end

Quando("eu deixo a questão discursiva em branco") do
  escolher_primeira_opcao_objetiva
end

Quando("confirmo o envio da avaliação") do
  click_button "Confirmar envio"
end

Quando("eu tento acessar a página de resposta do formulário da turma {string}") do |_nome_turma|
  visit responder_avaliacao_path(@avaliacao)
end

Quando("tento reenviar respostas para esse formulário") do
  page.driver.submit(:post, submeter_avaliacao_path(@avaliacao), parametros_respostas_validas)
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
        @questao_objetiva.id.to_s => { opcao_id: outra_questao.opcoes.ordenadas.first.id }
      }
    }
  )
end

Quando("envio uma opção inexistente para a questão objetiva") do
  page.driver.submit(
    :post,
    submeter_avaliacao_path(@avaliacao),
    {
      respostas: {
        @questao_discursiva.id.to_s => { texto: "Resposta válida" },
        @questao_objetiva.id.to_s => { opcao_id: 999_999 }
      }
    }
  )
end

Então("devo ver uma mensagem informando que a avaliação foi registrada com sucesso") do
  expect(page).to have_content("Avaliação registrada com sucesso.")
end

Então("as respostas devem ficar salvas na avaliação") do
  @avaliacao.reload
  expect(@avaliacao).to be_respondida
  expect(@avaliacao.respostas.count).to eq(2)
  expect(@avaliacao.respostas.find_by!(questao: @questao_discursiva).texto.texto).to eq("Achei a turma muito boa.")
  expect(@avaliacao.respostas.find_by!(questao: @questao_objetiva).opcoes).to contain_exactly(@opcao_escolhida)
end

Então("o formulário da turma {string} não deve mais aparecer na lista de pendentes") do |nome_turma|
  expect(page).not_to have_content(nome_turma)
end

Então("devo ver uma mensagem informando que todas as questões obrigatórias devem ser preenchidas") do
  expect(page).to have_content("Todas as questões obrigatórias devem ser preenchidas.")
end

Então("a avaliação não deve ser registrada") do
  @avaliacao.reload
  expect(@avaliacao).not_to be_respondida
  expect(@avaliacao.respostas).to be_empty
end

Então("devo ver uma mensagem informando que esta avaliação já foi respondida") do
  expect(page).to have_content("Esta avaliação já foi respondida.")
end

Então("nenhuma resposta adicional deve ser criada") do
  @avaliacao.reload
  expect(@avaliacao.respostas.count).to eq(@quantidade_respostas_antes_do_reenvio)
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
