# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Avaliacoes", type: :request do
  let(:departamento) { Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}") }
  let(:admin) { create_admin_usuario(departamento: departamento) }
  let(:turma) { create_turma(nome_materia: "Cálculo 1", numero: 1, departamento: departamento) }
  let(:template) { create_template_with_questoes(titulo: "Avaliação Geral", adm: admin.perfil_adm) }

  describe "GET /avaliacoes/pendentes" do
    it "exibe pendências apenas para participantes do público-alvo correto" do
      docente = create_usuario(nome: "Docente")
      discente = create_usuario(nome: "Discente")
      create_participacao(usuario: docente, turma: turma, tipo_participacao: :docente)
      create_participacao(usuario: discente, turma: turma, tipo_participacao: :discente)

      create_formulario(
        turma: turma,
        adm: admin.perfil_adm,
        template: template,
        publico_alvo: :discentes,
        criar_avaliacoes: true
      )

      sign_in_as(discente)
      get avaliacoes_pendentes_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(turma.nome_exibicao)
      expect(response.body).to include("Não respondido")

      sign_in_as(docente)
      get avaliacoes_pendentes_path

      expect(response.body).not_to include(template.titulo)
      expect(response.body).to include("Nenhum formulário pendente foi encontrado")
    end

    it "não exibe pendências de turmas em que o usuário não participa" do
      participante = create_usuario
      outro_usuario = create_usuario
      create_participacao(usuario: participante, turma: turma, tipo_participacao: :discente)

      outra_turma = create_turma(nome_materia: "Estrutura de Dados", numero: 1, departamento: departamento)
      create_participacao(usuario: outro_usuario, turma: outra_turma, tipo_participacao: :discente)
      create_formulario(
        turma: outra_turma,
        adm: admin.perfil_adm,
        template: template,
        publico_alvo: :discentes,
        criar_avaliacoes: true
      )

      sign_in_as(participante)
      get avaliacoes_pendentes_path

      expect(response.body).not_to include(outra_turma.nome_exibicao)
      expect(response.body).to include("Nenhum formulário pendente foi encontrado")
    end

    it "redireciona usuário não autenticado" do
      get avaliacoes_pendentes_path

      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /avaliacoes/:id/responder" do
    it "impede acesso à avaliação de outro participante" do
      dono = create_usuario(nome: "Dono da avaliação")
      intruso = create_usuario(nome: "Outro participante")
      participacao_dono = create_participacao(
        usuario: dono,
        turma: turma,
        tipo_participacao: :discente
      )
      create_participacao(
        usuario: intruso,
        turma: turma,
        tipo_participacao: :discente
      )
      formulario = Formularios::CreateFromTemplate.call(
        template_id: template.id,
        turma_ids: [ turma.id ],
        publico_alvo: :discentes,
        perfil_adm: admin.perfil_adm
      ).sole
      avaliacao = formulario.avaliacoes.find_by!(participacao_turma: participacao_dono)

      sign_in_as(intruso)
      get responder_avaliacao_path(avaliacao)

      expect(response).to redirect_to(avaliacoes_pendentes_path)
      expect(flash[:alert]).to eq("Avaliação não encontrada.")
    end

    it "exibe as questões copiadas após exclusão do template" do
      participante = create_usuario
      participacao = create_participacao(
        usuario: participante,
        turma: turma,
        tipo_participacao: :discente
      )
      formulario = Formularios::CreateFromTemplate.call(
        template_id: template.id,
        turma_ids: [ turma.id ],
        publico_alvo: :discentes,
        perfil_adm: admin.perfil_adm
      ).sole
      avaliacao = formulario.avaliacoes.find_by!(participacao_turma: participacao)
      enunciados = formulario.questoes.pluck(:enunciado)
      template.destroy!

      sign_in_as(participante)
      get responder_avaliacao_path(avaliacao)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(*enunciados)
    end
  end

  describe "POST /avaliacoes/:id/submeter" do
    it "rejeita opção pertencente a outra questão" do
      participante = create_usuario
      participacao = create_participacao(
        usuario: participante,
        turma: turma,
        tipo_participacao: :discente
      )
      formulario = Formularios::CreateFromTemplate.call(
        template_id: template.id,
        turma_ids: [ turma.id ],
        publico_alvo: :discentes,
        perfil_adm: admin.perfil_adm
      ).sole
      avaliacao = formulario.avaliacoes.find_by!(participacao_turma: participacao)
      questao_discursiva = formulario.questoes.discursivas.sole
      questao_objetiva = formulario.questoes.objetivas.sole
      opcao_de_outra_questao = template.questoes.objetivas.sole.opcoes.first

      sign_in_as(participante)

      expect do
        post submeter_avaliacao_path(avaliacao), params: {
          respostas: {
            questao_discursiva.id => { texto: "Resposta válida" },
            questao_objetiva.id => { opcao_id: opcao_de_outra_questao.id }
          }
        }
      end.not_to change(Resposta, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(
        "Todas as questões obrigatórias devem ser preenchidas."
      )
      expect(avaliacao.reload).to be_pendente
    end
  end
end
