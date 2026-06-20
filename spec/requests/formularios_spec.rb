require "rails_helper"

RSpec.describe "Formularios", type: :request do
  let(:departamento) { Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}") }
  let(:admin) { create_admin_usuario(departamento: departamento) }
  let(:usuario) { create_usuario }
  let(:template) { create_template_with_questoes(titulo: "Avaliação Docente", adm: admin.perfil_adm) }
  let(:turma_a) { create_turma(nome_materia: "MDS", numero: 1, departamento: departamento) }
  let(:turma_b) { create_turma(nome_materia: "IHC", numero: 2, departamento: departamento) }

  def criar_formulario_params(template_id: template.id, turma_ids: [ turma_a.id, turma_b.id ], publico_alvo: "docentes")
    {
      template_id: template_id,
      turma_ids: turma_ids,
      publico_alvo: publico_alvo
    }
  end

  describe "GET /formularios" do
    it "exibe formulários do departamento e semestre atual para admin" do
      formulario_a = create_formulario(
        turma: turma_a,
        adm: admin.perfil_adm,
        template: template,
        publico_alvo: :docentes
      )
      formulario_b = create_formulario(
        turma: turma_b,
        adm: admin.perfil_adm,
        template: template,
        publico_alvo: :discentes
      )

      sign_in_as(admin)
      get formularios_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(formulario_a.template.titulo)
      expect(response.body).to include(formulario_a.turma.nome_exibicao)
      expect(response.body).to include("Docentes")
      expect(response.body).to include(formulario_b.turma.nome_exibicao)
      expect(response.body).to include("Discentes")
      expect(response.body).to include("Gerar Relatório de Respostas")
      expect(response.body).to include(formulario_path(formulario_a))
    end

    it "exibe mensagem quando não há formulários no semestre atual" do
      sign_in_as(admin)
      get formularios_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nenhum formulário criado para este semestre")
    end

    it "não exibe formulários de outro departamento" do
      outro_departamento = Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}")
      outra_turma = create_turma(nome_materia: "OUT", numero: 1, departamento: outro_departamento)
      outro_admin = create_admin_usuario(departamento: outro_departamento)
      outro_template = create_template_with_questoes(titulo: "Formulário Externo", adm: outro_admin.perfil_adm)
      create_formulario(
        turma: outra_turma,
        adm: outro_admin.perfil_adm,
        template: outro_template
      )

      formulario_local = create_formulario(
        turma: turma_a,
        adm: admin.perfil_adm,
        template: template
      )

      sign_in_as(admin)
      get formularios_path

      expect(response.body).to include(formulario_local.template.titulo)
      expect(response.body).not_to include("Formulário Externo")
    end

    it "não exibe formulários de semestres anteriores" do
      turma_passada = create_turma(
        nome_materia: "LEG",
        numero: 3,
        departamento: departamento,
        ano: Date.current.year - 1,
        semestre: :segundo
      )
      create_formulario(
        turma: turma_passada,
        adm: admin.perfil_adm,
        template: template,
        publico_alvo: :docentes
      )

      formulario_atual = create_formulario(
        turma: turma_a,
        adm: admin.perfil_adm,
        template: template
      )

      sign_in_as(admin)
      get formularios_path

      expect(response.body).to include(formulario_atual.turma.nome_exibicao)
      expect(response.body).not_to include(turma_passada.nome_exibicao)
    end

    it "lista formulário cujo template de origem foi removido" do
      formulario = create_formulario(
        turma: turma_a,
        adm: admin.perfil_adm,
        template: template
      )
      template.destroy!

      sign_in_as(admin)
      get formularios_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Template removido")
      expect(response.body).to include(formulario.turma.nome_exibicao)
    end

    it "bloqueia usuário não administrador" do
      sign_in_as(usuario)

      get formularios_path

      expect(response).to redirect_to("/")
      expect(flash[:alert]).to eq("Acesso não autorizado")
    end
  end

  describe "GET /formularios/:id" do
    it "exibe o relatório de um formulário do departamento" do
      formulario = create_formulario(
        turma: turma_a,
        adm: admin.perfil_adm,
        template: template
      )

      sign_in_as(admin)
      get formulario_path(formulario)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(template.titulo)
      expect(response.body).to include(turma_a.nome_exibicao)
      expect(response.body).to include(exportar_csv_formulario_path(formulario))
    end

    it "impede acesso a formulário de outro departamento" do
      outro_departamento = Departamento.create!(nome: "Outro #{SecureRandom.hex(2)}")
      outra_turma = create_turma(
        nome_materia: "Externa",
        numero: 1,
        departamento: outro_departamento
      )
      formulario_externo = create_formulario(turma: outra_turma)

      sign_in_as(admin)
      get formulario_path(formulario_externo)

      expect(response).to redirect_to(formularios_path)
      expect(flash[:alert]).to eq(
        "Você não tem permissão para acessar esse formulário."
      )
    end
  end

  describe "GET /formularios/new" do
    it "pré-seleciona o template recebido pela URL" do
      sign_in_as(admin)

      get new_formulario_path(template_id: template.id)

      pagina = Nokogiri::HTML(response.body)
      opcao_selecionada = pagina.at_css("select#template_id option[selected]")

      expect(response).to have_http_status(:ok)
      expect(opcao_selecionada["value"]).to eq(template.id.to_s)
      expect(opcao_selecionada.text).to eq(template.titulo)
    end
  end

  describe "POST /formularios/preparar" do
    it "grava sessão e redireciona para publicação quando dados válidos" do
      sign_in_as(admin)

      preparar_formulario

      expect(response).to redirect_to(publicar_formularios_path)
      follow_redirect!
      expect(response.body).to include("Avaliação Docente")
      expect(response.body).to include(turma_a.nome_exibicao)
    end

    it "retorna erro quando nenhuma turma é selecionada" do
      sign_in_as(admin)

      expect do
        preparar_formulario(turma_ids: [])
      end.not_to change(Formulario, :count)

      expect(response).to redirect_to(new_formulario_path)
      follow_redirect!
      expect(response.body).to include("É necessário selecionar pelo menos uma turma")
    end
  end

  describe "GET /formularios/publicar" do
    it "redireciona para new quando sessão está vazia" do
      sign_in_as(admin)

      get publicar_formularios_path

      expect(response).to redirect_to(new_formulario_path)
    end
  end

  describe "POST /formularios" do
    it "cria formulários após wizard completo com público-alvo" do
      sign_in_as(admin)
      preparar_formulario

      expect do
        post formularios_path, params: { publico_alvo: "docentes" }
      end.to change(Formulario, :count).by(2)

      expect(response).to redirect_to(new_formulario_path)
      follow_redirect!
      expect(response.body).to include("Formulário criado com sucesso para as turmas selecionadas")
    end

    it "retorna erro quando público-alvo não é informado" do
      sign_in_as(admin)

      expect do
        post formularios_path, params: criar_formulario_params(turma_ids: [ turma_a.id ], publico_alvo: "")
      end.not_to change(Formulario, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Por favor, selecione o público-alvo do formulário")
    end

    it "bloqueia usuário não administrador" do
      sign_in_as(usuario)

      post formularios_path, params: criar_formulario_params

      expect(response).to redirect_to("/")
      expect(flash[:alert]).to eq("Você não tem permissão para realizar esta ação.")
      expect(Formulario.count).to eq(0)
    end
  end
end
