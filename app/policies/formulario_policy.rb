# frozen_string_literal: true

class FormularioPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.do_departamento(current_administrador.departamento) if administrador?

      scope.none
    end
  end

  def index?
    administrador?
  end

  def show?
    formulario_do_departamento?
  end

  def new?
    create?
  end

  def create?
    administrador?
  end

  def exportar_csv?
    show?
  end

  private

  def formulario_do_departamento?
    return false unless administrador?
    return true if record.is_a?(Class)

    record.turma.departamento_id == current_administrador.departamento_id
  end
end
