module Formularios
  class CreateFromTemplate
    SEM_TURMAS = "É necessário selecionar pelo menos uma turma"
    SEM_QUESTOES = "O template deve possuir pelo menos uma questão"
    TURMAS_INVALIDAS = "Uma ou mais turmas selecionadas são inválidas"
    TURMA_COM_FORMULARIO = "Uma ou mais turmas selecionadas já possuem formulário para este template e público-alvo"
    TURMA_DEPARTAMENTO_INCOMPATIVEL = "Uma ou mais turmas selecionadas pertencem a outro departamento"
    SEM_PUBLICO_ALVO = "Por favor, selecione o público-alvo do formulário"

    def self.call(template_id:, turma_ids:, publico_alvo:, perfil_adm:)
      new(template_id:, turma_ids:, publico_alvo:, perfil_adm:).call
    end

    def self.validate_preparacao!(template_id:, turma_ids:, perfil_adm:)
      new(template_id:, turma_ids:, publico_alvo: :docentes, perfil_adm:).validate_preparacao!
    end

    def initialize(template_id:, turma_ids:, publico_alvo:, perfil_adm:)
      @template_id = template_id
      @turma_ids = Array(turma_ids).map(&:to_i).uniq.reject(&:zero?)
      @publico_alvo = publico_alvo
      @perfil_adm = perfil_adm
    end

    def validate_preparacao!
      validate_turma_ids!
      validate_template!
      validate_turmas!
      validate_turmas_do_departamento!
      validate_turmas_disponiveis_para_template!
    end

    def call
      validate_preparacao!
      validate_publico_alvo!

      formularios = []

      ActiveRecord::Base.transaction do
        turmas.each do |turma|
          formulario = Formulario.create!(
            adm: perfil_adm,
            template: template,
            turma: turma,
            publico_alvo: publico_alvo
          )

          copy_questoes_from_template!(formulario)
          formulario.criar_avaliacoes_pendentes!
          formularios << formulario
        end
      end

      formularios
    end

    private

    attr_reader :template_id, :turma_ids, :publico_alvo, :perfil_adm

    def validate_turma_ids!
      raise Error, SEM_TURMAS if turma_ids.empty?
    end

    def validate_template!
      raise Error, SEM_QUESTOES if template.utilizacoes_questoes.raizes.none?
    end

    def validate_turmas!
      raise Error, TURMAS_INVALIDAS if turmas.count != turma_ids.size
    end

    def validate_turmas_do_departamento!
      return if perfil_adm.blank?

      incompativeis = turmas.reject { |turma| turma.departamento_id == perfil_adm.departamento_id }
      raise Error, TURMA_DEPARTAMENTO_INCOMPATIVEL if incompativeis.any?
    end

    def validate_turmas_disponiveis_para_template!
      conflitos = Formulario.where(
        turma_id: turma_ids,
        template_id: template_id,
        publico_alvo: publico_alvo
      )
      raise Error, TURMA_COM_FORMULARIO if conflitos.exists?
    end

    def validate_publico_alvo!
      raise Error, SEM_PUBLICO_ALVO if publico_alvo.blank?
      raise Error, SEM_PUBLICO_ALVO unless Formulario.publico_alvos.key?(publico_alvo.to_s)
    end

    def template
      @template ||= Template.find(template_id)
    end

    def turmas
      @turmas ||= Turma
        .do_departamento(perfil_adm.departamento)
        .do_semestre_atual
        .where(id: turma_ids)
    end

    def copy_questoes_from_template!(formulario)
      template.utilizacoes_questoes.raizes.ordenadas.each do |utilizacao|
        questao_origem = utilizacao.questao

        questao = formulario.questoes.build(
          enunciado: questao_origem.enunciado,
          tipo: questao_origem.tipo
        )

        questao_origem.opcoes.ordenadas.each do |opcao|
          questao.opcoes.build(numero: opcao.numero, texto: opcao.texto)
        end

        questao.save!
      end
    end
  end
end
