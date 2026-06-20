# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormularioPolicy do
  let(:departamento) { Departamento.create!(nome: "DCC #{SecureRandom.hex(2)}") }
  let(:admin) { create_admin_usuario(departamento: departamento) }
  let(:usuario) { create_usuario }
  let(:formulario) { Formulario.new(adm: admin.perfil_adm) }

  describe "#create?" do
    it "permite administrador" do
      expect(described_class.new(admin, formulario).create?).to be(true)
    end

    it "nega usuário sem perfil de administrador" do
      expect(described_class.new(usuario, formulario).create?).to be(false)
    end

    it "nega visitante não autenticado" do
      expect(described_class.new(nil, formulario).create?).to be_falsy
    end
  end

  describe "#new?" do
    it "delega para create?" do
      policy = described_class.new(admin, formulario)
      expect(policy.new?).to eq(policy.create?)
    end
  end
end
