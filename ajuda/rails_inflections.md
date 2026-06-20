# 🇧🇷 Guia: Ensinando Português ao Rails (Inflexões e Migrations)

Por padrão, o Ruby on Rails utiliza as regras gramaticais da língua inglesa para fazer suas automações de **Singular (Model)** para **Plural (Tabela)**. 

Quando usamos nomes em português como `Usuario` ou `PerfilAdm`, o Rails se confunde ao tentar pluralizá-los. Para resolver isso mantendo toda a "mágica" do framework ativa (sem precisar configurar tabelas manualmente em cada arquivo), nós podemos ensinar as regras do português diretamente para o dicionário do Rails através das **Inflexões**.

---

## Passo 1: Configurar as Inflexões (O Dicionário do Rails)

O Rails possui um arquivo específico para adicionarmos regras gramaticais customizadas. 

Abra o arquivo `config/initializers/inflections.rb`. Vá até o final dele e cole o seguinte código:

```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  # Sintaxe: inflect.irregular 'nome_no_singular', 'nome_no_plural'
  inflect.irregular 'usuario', 'usuarios'
  inflect.irregular 'perfil_adm', 'perfis_adm'
end
```

> 💡 **Nota:** Usamos o escopo `:en` porque o Rails roda originalmente em inglês. O que estamos fazendo é expandir esse dicionário padrão com os nossos termos em português.

---

## Passo 2: Criar e Configurar a Migration Manual

Agora que o Rails já entende que o plural de `usuario` é `usuarios` e de `perfil_adm` é `perfis_adm`, nós podemos criar a nossa migration utilizando um nome genérico e estruturando as tabelas no padrão universal do banco de dados (**letras minúsculas e no plural**).

Se você gerou a migration com o nome genérico `BuildDbAuth`:

```ruby
class BuildDbAuth < ActiveRecord::Migration[8.1]
  def change
    # 1. Tabela de Usuários (sempre no plural)
    create_table :usuarios do |t|
      t.string :matricula
      t.string :email
      t.string :password_digest # Obrigatório para o sistema de criptografia nativo (has_secure_password)

      t.timestamps # Cria automaticamente as colunas created_at e updated_at
    end

    # 2. Tabela de Perfis de Admin (sempre no plural)
    create_table :perfis_adm do |t|
      # t.references cria automaticamente a chave estrangeira (FK) 'usuario_id' apontando para a tabela 'usuarios'
      t.references :usuario, null: false, foreign_key: true

      t.timestamps
    end
  end
end
```

Após salvar o arquivo, vá ao seu terminal e aplique as alterações executando:
```bash
rails db:migrate
```

---

## 3. Como os Models ficam elegantes após essa configuração

A maior vantagem de ensinar português para o Rails é que os seus arquivos de Model (em `app/models/`) não precisam de nenhuma linha de código configurando nomes de tabelas (`self.table_name`). A automação do framework volta a funcionar perfeitamente:

```ruby
# app/models/usuario.rb
class Usuario < ApplicationRecord
  has_secure_password # Ativa a criptografia que usa o password_digest
  
  # O Rails usa o inflector, descobre que o plural é 'perfis_adm' e acha a tabela correta sozinho!
  has_one :perfil_adm
end
```

```ruby
# app/models/perfil_adm.rb
class PerfilAdm < ApplicationRecord
  # O Rails deduz que deve buscar a FK 'usuario_id' na tabela 'perfis_adm'
  belongs_to :usuario
end
```

---

## 📅 Resumo de Boas Práticas para o seu Projeto
Sempre que você criar um modelo novo em português cujo plural fuja da regra padrão do inglês (adicionar apenas um "s"), basta abrir o arquivo `config/initializers/inflections.rb` e cadastrar a palavra lá. 

### Exemplos comuns para o futuro:
* `inflect.irregular 'sessao', 'sessoes'`
* `inflect.irregular 'administrador', 'administradores'`
* `inflect.irregular 'funcao', 'funcoes'`