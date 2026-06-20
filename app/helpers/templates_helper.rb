module TemplatesHelper
  def letra_da_opcao(numero)
    return "" if numero.blank?

    numero = numero.to_i
    resultado = ""

    while numero.positive?
      numero -= 1
      resultado.prepend((97 + (numero % 26)).chr)
      numero /= 26
    end

    resultado
  end
end
