# 🛠️ Guia Definitivo: Configurando Migrations Manualmente no Rails

Por padrão, o Rails tenta adivinhar o que você quer fazer no banco de dados através do nome que você dá à migration (como `AddRoleToUsers`). No entanto, você é totalmente livre para usar um **nome genérico** e escrever toda a lógica na mão dentro do método `change`.

Isso é extremamente útil para alterações complexas, renomeações ou quando você quer ter controle total sobre o seu banco de dados.

---

## 1. Criando uma Migration com Nome Genérico

Para começar, basta rodar o gerador com um nome que não siga os padrões `Add...`, `Remove...` ou `Create...`. 

```bash
rails generate migration ModificarEstruturaDosUsuarios
```

O Rails criará um arquivo dentro da pasta `db/migrate/` com o método `change` completamente vazio:

```ruby
class ModificarEstruturaDosUsuarios < ActiveRecord::Migration[7.1]
  def change
    # É aqui que a mágica manual acontece!
  end
end
```

---

## 2. O "Cardápio" de Métodos do `change`

Dentro do método `change`, você pode utilizar as seguintes funções do Active Record para manipular suas tabelas e colunas:

| O que você quer fazer? | Comando do Rails | Exemplo Prático |
| :--- | :--- | :--- |
| **Criar uma tabela** | `create_table :nome` | `create_table :produtos do \|t\| t.string :nome end` |
| **Adicionar coluna** | `add_column :tabela, :coluna, :tipo` | `add_column :users, :telefone, :string` |
| **Remover coluna** | `remove_column :tabela, :coluna, :tipo` | `remove_column :users, :idade, :integer` |
| **Renomear coluna** | `rename_column :tabela, :antigo, :novo` | `rename_column :users, :nome_completo, :name` |
| **Mudar tipo da coluna** | `change_column :tabela, :coluna, :novo_tipo`| `change_column :users, :matricula, :string` |
| **Adicionar Índice (Index)** | `add_index :tabela, :coluna` | `add_index :users, :email, unique: true` |

---

## 3. Quais tipos de dados o Rails aceita nas colunas?

Na hora de criar ou alterar uma coluna, você precisa passar o tipo dela. O Rails traduz esses tipos automaticamente para a linguagem do banco de dados que você estiver usando (SQLite, PostgreSQL, MySQL, etc.).

Aqui estão os tipos mais comuns que você pode usar:

### Textos e Caracteres
* `:string` -> Usado para textos curtos (nomes, e-mails, títulos). Tem um limite padrão de 255 caracteres na maioria dos bancos.
* `:text` -> Usado para textos longos (comentários, descrições de produtos, artigos de blog). Não tem limite estrito de tamanho.

### Números
* `:integer` -> Números inteiros, positivos ou negativos (ex: `10`, `-5`, `23200000`).
* `:bigint` -> Números inteiros extremamente grandes (usado automaticamente pelo Rails para os IDs das tabelas).
* `:float` -> Números com casas decimais imprecisas (útil para coordenadas geográficas como latitude/longitude).
* `:decimal` -> Números com casas decimais **exatas**. **Sempre use este tipo para dinheiro/preços** (ex: `t.decimal :preco, precision: 8, scale: 2` para aceitar valores até R$ 999.999,99).

### Datas e Horas
* `:datetime` ou `:timestamp` -> Guarda o dia, mês, ano, hora, minuto e segundo (usado nos campos automáticos `created_at` e `updated_at`).
* `:date` -> Guarda apenas o dia, mês e ano (ex: data de nascimento).
* `:time` -> Guarda apenas a hora, minuto e segundo (ex: horário de uma aula).

### Outros Tipos Importantes
* `:boolean` -> Aceita apenas dois valores: `true` (verdadeiro) ou `false` (falso). Excelente para flags como `ativo` ou `admin`.
* `:references` ou `:belongs_to` -> Cria uma chave estrangeira para conectar uma tabela a outra (ex: `t.references :user` dentro da tabela de posts cria a coluna `user_id`).
* `:json` ou `:jsonb` -> Permite guardar estruturas de dados complexas (como hashes/dicionários) diretamente em uma coluna (muito usado no PostgreSQL).

---

## 4. Exemplo Completo de uma Migration Manual

Aqui está como ficaria o arquivo final juntando vários desses conceitos:

```ruby
class ModificarEstruturaDosUsuarios < ActiveRecord::Migration[7.1]
  def change
    # 1. Adicionando uma coluna de texto curta e uma booleana com valor padrão
    add_column :users, :cpf, :string
    add_column :users, :ativo, :boolean, default: true

    # 2. Renomeando um campo que foi escrito errado anteriormente
    rename_column :users, :senha_digest, :password_digest

    # 3. Mudar o tipo da matrícula de número para texto (caso existam letras)
    change_column :users, :matricula, :string

    # 4. Adicionar um índice para que a busca por e-mail seja ultra rápida e única
    add_index :users, :email, unique: true
  end
end
```

Depois de configurar o arquivo do seu jeito, basta salvar e rodar o comando clássico no terminal:
```bash
rails db:migrate
```