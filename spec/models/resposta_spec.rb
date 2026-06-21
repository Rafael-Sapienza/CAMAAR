# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resposta, type: :model do
  let(:departamento) { Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}") }
  let(:admin) { create_admin_usuario(departamento: departamento) }
  let(:turma) do
    create_turma(
      nome_materia: "Engenharia de Software",
      numero: 1,
      departamento: departamento
    )
  end
  let(:template) do
    create_template_with_questoes(
      titulo: "Avaliação da disciplina",
      adm: admin.perfil_adm
    )
  end
  let(:participante) { create_usuario }
  let!(:participacao) do
    create_participacao(
      usuario: participante,
      turma: turma,
      tipo_participacao: :discente
    )
  end
  let(:formulario) do
    Formularios::CreateFromTemplate.call(
      template_id: template.id,
      turma_ids: [ turma.id ],
      publico_alvo: :discentes,
      perfil_adm: admin.perfil_adm
    ).sole
  end
  let(:avaliacao) { formulario.avaliacoes.find_by!(participacao_turma: participacao) }
  let(:questao_discursiva) { formulario.questoes.discursivas.sole }

  def resposta_discursiva(questao)
    described_class.new(avaliacao: avaliacao, questao: questao).tap do |resposta|
      resposta.build_texto(texto: "A disciplina foi bem conduzida.")
    end
  end

  it "aceita questão copiada para o formulário" do
    expect(resposta_discursiva(questao_discursiva)).to be_valid
  end

  it "rejeita questão que não pertence ao formulário" do
    questao_do_template = template.questoes.discursivas.sole
    resposta = resposta_discursiva(questao_do_template)

    expect(resposta).not_to be_valid
    expect(resposta.errors[:questao]).to include("não pertence ao formulário")
  end

  it "permanece válida quando o template de origem é excluído" do
    questao_discursiva
    template.destroy!

    expect(resposta_discursiva(questao_discursiva)).to be_valid
  end
end
