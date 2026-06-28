# frozen_string_literal: true

module Dashboard
  class SuggestionBuilder
    include Rails.application.routes.url_helpers

    def self.call(termo:, tipos:, current_user:, **searchers)
      new(termo:, tipos:, current_user:, **searchers).call
    end

    def initialize(termo:, tipos:, current_user:, **searchers)
      @termo = termo
      @tipos = tipos
      @current_user = current_user
      @searchers = searchers
    end

    def call
      return [] if @termo.blank?

      @padrao = "%#{ActiveRecord::Base.sanitize_sql_like(@termo.downcase)}%"

      []
        .concat(sugestoes_de_turmas)
        .concat(sugestoes_de_materias)
        .concat(sugestoes_de_avaliacoes)
        .concat(sugestoes_de_templates)
        .concat(sugestoes_de_formularios)
    end

    private

    def sugestoes_de_turmas
      @searchers[:pesquisar_turmas].call(@termo).limit(3).map do |turma|
        {
          tipo: "Turma",
          titulo: turma.materia.nome,
          subtitulo: nil,
          materia_codigo: turma.materia.codigo,
          turma_codigo: turma.codigo_exibicao,
          url: turma_suggestion_url(turma)
        }
      end
    end

    def sugestoes_de_materias
      @searchers[:pesquisar_materias].call(@padrao).limit(3).map do |materia|
        {
          tipo: "Matéria",
          titulo: materia.nome,
          subtitulo: nil,
          materia_codigo: materia.codigo,
          url: materia_suggestion_url(materia)
        }
      end
    end

    def sugestoes_de_avaliacoes
      return [] unless @tipos.include?("avaliacoes")

      @searchers[:pesquisar_avaliacoes].call(@padrao).limit(5).map { |avaliacao| sugestao_de_avaliacao(avaliacao) }
    end

    def sugestoes_de_templates
      return [] unless @current_user.administrador? && @tipos.include?("templates")

      @searchers[:pesquisar_templates].call(@padrao).limit(5).map { |template| sugestao_de_template(template) }
    end

    def sugestoes_de_formularios
      return [] unless @current_user.administrador? && @tipos.include?("formularios")

      @searchers[:pesquisar_formularios].call(@padrao).limit(5).map { |formulario| sugestao_de_formulario(formulario) }
    end

    def sugestao_de_avaliacao(avaliacao)
      turma = avaliacao.formulario.turma
      sugestao_com_turma("Avaliação", avaliacao.formulario.template&.titulo || "Avaliação", turma)
        .merge(url: responder_avaliacao_path(avaliacao))
    end

    def sugestao_de_template(template)
      {
        tipo: "Template",
        titulo: template.titulo,
        subtitulo: template.descricao.presence || "Sem descrição",
        url: template_path(template)
      }
    end

    def sugestao_de_formulario(formulario)
      turma = formulario.turma
      sugestao_com_turma("Formulário", formulario.template&.titulo || "Template removido", turma)
        .merge(url: formulario_path(formulario))
    end

    def sugestao_com_turma(tipo, titulo, turma)
      {
        tipo: tipo,
        titulo: titulo,
        subtitulo: turma.nome_exibicao,
        materia_codigo: turma.materia.codigo,
        turma_codigo: turma.codigo_exibicao
      }
    end

    def materia_suggestion_url(materia)
      tipos_aplicaveis = tipos_sem_templates

      pesquisa_path(q: materia.nome, filtro_ativo: "1", tipos: tipos_aplicaveis, sem_templates: "1")
    end

    def turma_suggestion_url(turma)
      tipos_aplicaveis = tipos_sem_templates

      pesquisa_path(
        q: turma.nome_exibicao,
        filtro_ativo: "1",
        tipos: tipos_aplicaveis,
        sem_templates: "1",
        turma_id: turma.id
      )
    end

    def tipos_sem_templates
      tipos_aplicaveis = @tipos - [ "templates" ]
      tipos_aplicaveis.empty? ? %w[avaliacoes formularios] : tipos_aplicaveis
    end
  end
end
