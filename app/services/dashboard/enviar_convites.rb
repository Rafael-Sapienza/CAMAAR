# frozen_string_literal: true

module Dashboard
  class EnviarConvites
    SEM_PENDENTES = "Não há usuários pendentes de cadastro (docentes ou discentes) neste departamento."

    def self.call(depto_id:, admin_nome:, enviar_email:)
      new(depto_id:, admin_nome:, enviar_email:).call
    end

    def initialize(depto_id:, admin_nome:, enviar_email:)
      @depto_id = depto_id
      @admin_nome = admin_nome
      @enviar_email = enviar_email
    end

    def call
      usuarios = usuarios_pendentes
      return { sem_pendentes: true } if usuarios.empty?

      sucessos = 0
      erros = []
      usuarios.each do |usuario|
        erro = enviar_convite_para(usuario)
        erro.nil? ? sucessos += 1 : erros << erro
      end

      { sucessos: sucessos, erros: erros }
    end

    private

    def usuarios_pendentes
      turmas_ids = Turma.joins(:materia).where(materias: { departamento_id: @depto_id }).ids
      discentes = Usuario.joins(:participacoes_turma)
                         .where(status: 0, participacoes_turma: { turma_id: turmas_ids })
      docentes = Usuario.joins(:perfil_docente)
                        .where(status: 0, perfis_docentes: { departamento_id: @depto_id })
      (discentes + docentes).uniq
    end

    def enviar_convite_para(usuario)
      erro = nil
      ActiveRecord::Base.transaction do
        token_gerado = SecureRandom.hex(16)
        usuario.tokens.create!(value: token_gerado, tipo: "cadastro", expires_at: 10.minutes.from_now)
        raise "Falha de comunicação com a Brevo." unless @enviar_email.call(usuario.email, token_gerado, @admin_nome)
      rescue StandardError => e
        erro = "#{usuario.nome} (Matrícula: #{usuario.matricula}): #{e.message}"
        raise ActiveRecord::Rollback
      end
      erro
    end
  end
end
