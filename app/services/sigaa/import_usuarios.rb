# frozen_string_literal: true

module SIGAA
  class ImportUsuarios
    ARQUIVO_NAO_ENCONTRADO = "Arquivo JSON não encontrado em db/"

    def self.call(caminho_arquivo:)
      new(caminho_arquivo:).call
    end

    def initialize(caminho_arquivo:)
      @caminho_arquivo = caminho_arquivo
      @codigos_materias_ativos = []
      @turmas_ativas_ids = []
      @matriculas_ativas_json = []
      @erros_importacao = []
    end

    def call
      return resultado_arquivo_inexistente unless File.exist?(@caminho_arquivo)

      dados = JSON.parse(File.read(@caminho_arquivo))
      importar_materias!(dados["materias"])
      importar_turmas!(dados["turmas"])
      importar_docentes!(dados["usuarios_docentes"])
      importar_discentes!(dados["usuarios_discentes"])
      limpar_orfaos!

      { erros: @erros_importacao, sucesso_total: @erros_importacao.empty? }
    end

    private

    attr_reader :erros_importacao

    def resultado_arquivo_inexistente
      { erros: [ ARQUIVO_NAO_ENCONTRADO ], sucesso_total: false, arquivo_inexistente: true }
    end

    def importar_materias!(materias_json)
      materias_json&.each do |materia_json|
        codigo = materia_json["codigo"]

        ActiveRecord::Base.transaction do
          @codigos_materias_ativos << codigo

          materia = Materia.find_or_initialize_by(codigo: codigo)
          materia.nome = materia_json["nome"]
          materia.departamento_id = materia_json["departamento_id_temp"]
          materia.save!
        end
      rescue StandardError => e
        @erros_importacao << "Matéria #{materia_json['nome']} (Código: #{codigo}): #{e.message}"
      end
    end

    def importar_turmas!(turmas_json)
      turmas_json&.each { |turma_json| importar_turma!(turma_json) }
    end

    def importar_turma!(turma_json)
      ActiveRecord::Base.transaction do
        turma = salvar_turma!(turma_json)
        @turmas_ativas_ids << turma.id
      end
    rescue StandardError => e
      @erros_importacao << mensagem_erro_turma(turma_json, e)
    end

    def salvar_turma!(turma_json)
      materia = localizar_materia!(turma_json["materia_codigo"])

      turma = Turma.find_or_initialize_by(
        numero: turma_json["numero"],
        ano: turma_json["ano"],
        semestre: turma_json["semestre"],
        materia_id: materia.id
      )
      turma.save!
      turma
    end

    def localizar_materia!(codigo)
      materia = Materia.find_by(codigo: codigo)
      raise "Matéria com código '#{codigo}' não existe no sistema." if materia.nil?

      materia
    end

    def importar_docentes!(docentes_json)
      docentes_json&.each { |docente_json| importar_docente!(docente_json) }
    end

    def importar_discentes!(discentes_json)
      discentes_json&.each { |discente_json| importar_discente!(discente_json) }
    end

    def importar_docente!(docente_json)
      importar_usuario_com_participacoes!(
        docente_json,
        "Docente",
        :docente
      ) do |usuario, docente_json|
        perfil = PerfilDocente.find_or_initialize_by(id: usuario.id)
        perfil.departamento_id = docente_json["departamento_id_temp"]
        perfil.save!
      end
    end

    def importar_discente!(discente_json)
      importar_usuario_com_participacoes!(
        discente_json,
        "Discente",
        :discente
      ) do |usuario, _discente_json|
        PerfilDiscente.find_or_create_by!(id: usuario.id)
      end
    end

    def importar_usuario_com_participacoes!(usuario_json, papel, tipo_participacao)
      matricula = usuario_json["matricula"]
      turmas_json = turmas_json_para(usuario_json, tipo_participacao)

      ActiveRecord::Base.transaction do
        usuario = importar_usuario!(usuario_json, matricula)
        yield(usuario, usuario_json) if block_given?

        turmas_ids = importar_participacoes!(usuario, turmas_json, tipo_participacao)
        remover_participacoes_obsoletas!(usuario, turmas_ids, tipo_participacao)
      end
    rescue StandardError => e
      @erros_importacao << "#{papel} #{usuario_json['nome']} (Matrícula: #{matricula}): #{e.message}"
    end

    def turmas_json_para(usuario_json, tipo_participacao)
      if tipo_participacao == :docente
        usuario_json["turmas_lecionadas"] || []
      else
        usuario_json["turmas_matriculadas"]
      end
    end

    def remover_participacoes_obsoletas!(usuario, turmas_ids, tipo_participacao)
      participacoes = usuario.participacoes_turma
      participacoes = participacoes.docentes if tipo_participacao == :docente
      participacoes.where.not(turma_id: turmas_ids).destroy_all
    end

    def importar_usuario!(usuario_json, matricula)
      @matriculas_ativas_json << matricula

      usuario = Usuario.find_or_initialize_by(matricula: matricula)
      usuario.nome = usuario_json["nome"]
      usuario.email = usuario_json["email"]
      if usuario.new_record?
        usuario.status = 0
        usuario.senha = ""
      end
      usuario.save!
      usuario
    end

    def importar_participacoes!(usuario, turmas_json, tipo_participacao)
      turmas_ids = []

      turmas_json.each do |mat_json|
        turma = localizar_turma!(mat_json)
        turmas_ids << turma.id
        ParticipacaoTurma.find_or_create_by!(
          usuario_id: usuario.id,
          turma_id: turma.id,
          tipo_participacao: tipo_participacao
        )
      end

      turmas_ids
    end

    def localizar_turma!(mat_json)
      materia = localizar_materia!(mat_json["materia_codigo"])

      turma = Turma.find_by(
        materia_id: materia.id,
        numero: mat_json["numero_turma"],
        ano: mat_json["ano"],
        semestre: mat_json["semestre"]
      )
      if turma.nil?
        raise "Turma nº #{mat_json['numero_turma']} (#{mat_json['ano']}/#{mat_json['semestre']}) da matéria '#{materia.nome}' não foi localizada no sistema."
      end

      turma
    end

    def limpar_orfaos!
      ActiveRecord::Base.transaction do
        Turma.where.not(id: @turmas_ativas_ids).destroy_all
        Materia.where.not(codigo: @codigos_materias_ativos).destroy_all
        Usuario.where.not(matricula: @matriculas_ativas_json).find_each do |usuario|
          next if usuario.administrador?

          usuario.destroy!
        end
      end
    end

    def mensagem_erro_turma(turma_json, erro)
      "Turma nº #{turma_json['numero']} (#{turma_json['ano']}/#{turma_json['semestre']}) da matéria '#{turma_json['materia_codigo']}': #{erro.message}"
    end
  end
end
