# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard e navegação", type: :request do
  let(:departamento) { Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}") }
  let(:admin) { create_admin_usuario(departamento: departamento) }

  describe "GET /avaliacoes" do
    it "renderiza a navegação compartilhada e liga os controles da topbar" do
      sign_in_as(admin)

      get avaliacoes_path

      pagina = Nokogiri::HTML(response.body)

      expect(response).to have_http_status(:ok)
      expect(pagina.at_css('[data-controller="app-shell"]')).to be_present
      expect(pagina.at_css('[data-action="app-shell#toggleSidebar"]')).to be_present
      expect(pagina.at_css("form.search-container")[:action]).to eq(pesquisa_path)
      expect(response.body).to include(templates_path)
      expect(response.body).to include(formularios_path)
      expect(response.body).to include(gerenciamento_path)
    end

    it "mostra avaliações pendentes reais do usuário" do
      participante = create_usuario(nome: "Participante")
      turma = create_turma(
        nome_materia: "Projeto de Software",
        numero: 1,
        departamento: departamento
      )
      create_participacao(
        usuario: participante,
        turma: turma,
        tipo_participacao: :discente
      )
      formulario = create_formulario(
        turma: turma,
        template: create_template_with_questoes(
          titulo: "Avaliação de Projeto",
          adm: admin.perfil_adm
        ),
        adm: admin.perfil_adm,
        publico_alvo: :discentes,
        criar_avaliacoes: true
      )
      avaliacao = formulario.avaliacoes.sole

      sign_in_as(participante)
      get avaliacoes_path

      expect(response.body).to include("Avaliação de Projeto")
      expect(response.body).to include(turma.nome_exibicao)
      expect(response.body).to include(responder_avaliacao_path(avaliacao))
    end
  end

  describe "GET /pesquisa" do
    it "encontra templates e formulários disponíveis para o administrador" do
      template = create_template_with_questoes(
        titulo: "Avaliação Integrada",
        adm: admin.perfil_adm
      )
      turma = create_turma(
        nome_materia: "Engenharia Integrada",
        numero: 1,
        departamento: departamento
      )
      formulario = create_formulario(
        turma: turma,
        template: template,
        adm: admin.perfil_adm
      )

      sign_in_as(admin)
      get pesquisa_path, params: { q: "integrada" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(template_path(template))
      expect(response.body).to include(formulario_path(formulario))
    end

    it "encontra somente avaliações pendentes pertencentes ao participante" do
      participante = create_usuario(nome: "Participante")
      turma = create_turma(
        nome_materia: "Compiladores",
        numero: 1,
        departamento: departamento
      )
      create_participacao(
        usuario: participante,
        turma: turma,
        tipo_participacao: :discente
      )
      formulario = create_formulario(
        turma: turma,
        template: create_template_with_questoes(
          titulo: "Avaliação de Compiladores",
          adm: admin.perfil_adm
        ),
        adm: admin.perfil_adm,
        publico_alvo: :discentes,
        criar_avaliacoes: true
      )

      sign_in_as(participante)
      get pesquisa_path, params: { q: "compiladores" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(
        responder_avaliacao_path(formulario.avaliacoes.sole)
      )
      expect(response.body).not_to include(template_path(formulario.template))
    end
  end
end
