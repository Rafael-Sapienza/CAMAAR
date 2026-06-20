# Manual Definitivo de Configuração de Banco de Dados no Ruby on Rails

Este guia foi projetado para servir como um material de consulta rápida e profunda sobre o funcionamento do banco de dados no ecossistema Rails. Ele aborda a estrutura de pastas, o ciclo de vida das migrations, atualizações estruturais e a carga inicial de dados (seeds), explicando o comportamento de cada comando por baixo dos panos.

---

## 1. Estrutura de Pastas (Convention over Configuration)

A filosofia do Rails exige que os arquivos estruturais do banco de dados fiquem em locais estritos. O comando `rails db:migrate` sempre procurará os arquivos nestes caminhos exatos na raiz do projeto:

```text
seu_projeto/
└── db/
    ├── migrate/          # OBRIGATÓRIO: Histórico cronológico de todas as migrations.
    ├── schema.rb         # AUTOMÁTICO: O retrato falado atual do banco. Nunca edite manualmente!
    ├── seeds.rb          # OBRIGATÓRIO: Script principal para inserção de dados iniciais.
    └── development.sqlite3 # AUTOMÁTICO: Arquivo físico do banco local (apenas se usar SQLite).
```

---

## 2. Como o Rails Identifica a Tabela Alvo?

Quando você executa `rails generate migration NomeDaMigration`, o Rails não está conectado ao banco de dados para adivinhar suas intenções. Ele utiliza **Mapeamento de Padrões por Expressões Regulares (RegEx)** baseando-se estritamente no formato do nome que você escreveu em *CamelCase*.

### Os Três Padrões Reconhecidos automaticamente:

1. **Padrão de Criação (`Create[NomeDaTabela]`)**
   * **Exemplo:** `CreateProducts`
   * **Como o Rails lê:** Identifica o prefixo `Create`. Ele assume que o restante do texto no plural (`Products`) será o nome da nova tabela e gera automaticamente o bloco `create_table :products`.

2. **Padrão de Adição (`Add[Iniciais]To[NomeDaTabela]`)**
   * **Exemplo:** `AddCategoryToProducts`
   * **Como o Rails lê:** Identifica o sufixo `ToProducts`. Ele extrai a palavra após o `To`, converte para letras minúsculas (`products`) e prepara o método `add_column :products, ...`.

3. **Padrão de Remoção (`Remove[Iniciais]From[NomeDaTabela]`)**
   * **Exemplo:** `RemovePriceFromProducts`
   * **Como o Rails lê:** Identifica o sufixo `FromProducts`. Ele extrai a palavra após o `From`, descobre que a tabela alvo é `products` e prepara o método `remove_column :products, ...`.

### O que acontece se eu usar um nome genérico?
Se você rodar um comando como `rails generate migration MudarRegrasDeNegocio`, o Rails não encontrará nenhuma palavra-chave como `Create`, `To` ou `From`. 

O comando funcionará e gerará o arquivo com o carimbo de data e hora normalmente, mas o método `change` virá **completamente vazio**. Nesses cenários, você precisará abrir o arquivo e digitar manualmente o nome da tabela que deseja afetar, utilizando métodos do ActiveRecord como `change_table :nome_da_tabela`.

---

## 3. Exemplo Prático: Codificando o método `change` manualmente

Se você gerou uma migration genérica e precisa apontar para uma tabela específica (por exemplo, a tabela `products`), você deve abrir o arquivo em branco e utilizar o bloco `change_table`.

Aqui está um exemplo real de como o método `change` deve ser codificado para adicionar colunas, remover colunas ou alterar propriedades de tabelas existentes de uma só vez. Nesse caso, usamos para alterar a tabela `product`:

```ruby
class MudarRegrasDeNegocio < ActiveRecord::Migration[7.1]
  def change
    # Informamos explicitamente ao Rails qual tabela queremos alterar
    change_table :products do |t|
      # 1. Adicionando uma nova coluna
      t.string :sku_code

      # 2. Removendo uma coluna antiga existente
      t.remove :old_barcode_field

      # 3. Adicionando um índice para buscas mais rápidas
      t.index :sku_code
    end
  end
end
```

Se você preferir não usar o bloco `change_table`, você também pode passar o nome da tabela como o primeiro argumento de métodos individuais do ActiveRecord diretamente dentro do `change`:

```ruby
class MudarRegrasDeNegocio < ActiveRecord::Migration[7.1]
  def change
    add_column :products, :sku_code, :string
    remove_column :products, :old_barcode_field, :string
    add_index :products, :sku_code
  end
end
```

---

## 4. Passo a Passo: Gerando e Criando as Tabelas

O ciclo de criação de tabelas segue uma ordem lógica onde o terminal sempre prepara a estrutura para que você, opcionalmente, edite o código Ruby antes de impactar o banco.

### Passo 4.1: `rails db:create` (A Fundação)
* **Como deve ser escrito:** Apenas `rails db:create`.
* **O que faz por baixo dos panos:** Conecta-se ao gerenciador de banco de dados configurado em `config/database.yml` e cria o schema vazio. 
    * Se usar **SQLite**, cria o arquivo físico `db/development.sqlite3`.
    * Se usar **PostgreSQL/MySQL**, envia um comando interno de criação para o servidor do banco (não gera arquivos no projeto).

### Passo 4.2: `rails generate migration` (A Planta)
* **Como deve ser escrito:** O comando aceita o formato `rails generate migration NomeDaMigration campos:tipos`.
* **Exemplo prático de geração automatizada (Padrão Create):**
```bash
rails generate migration CreateProducts name:string price:decimal
```
* **O que ele gera:** Um arquivo em `db/migrate/` com o prefixo de carimbo de tempo (ex: `20260613113000_create_products.rb`) preenchido com o método `create_table`:
```ruby
class CreateProducts < ActiveRecord::Migration[7.1]
  def change
    create_table :products do |t|
      t.string :name
      t.decimal :price

      t.timestamps # Cria automaticamente created_at e updated_at
    end
  end
end
```

### Passo 4.3: Ajustar o Código Ruby (Opcional)
Antes de enviar a tabela para o banco de dados, você pode abrir o arquivo gerado e adicionar restrições explícitas (ex: impedir campos em branco ou definir limites numéricos):
```ruby
t.string :name, null: false
t.decimal :price, precision: 10, scale: 2
```

### Passo 4.4: `rails db:migrate` (A Construção de Fato)
* **Como deve ser escrito:** Apenas `rails db:migrate`.
* **O que faz por baixo dos panos:** O Rails lê a pasta `db/migrate/` em ordem cronológica. Ele verifica uma tabela interna no banco chamada `schema_migrations` para saber quais arquivos já foram rodados no passado. Ele executa apenas as migrations inéditas e, ao terminar, reescreve o arquivo `db/schema.rb`.

---

## 5. Atualizar ou Alterar Migrations (É possível?)

**Sim, é perfeitamente possível**, mas você deve seguir regras estritas dependendo do estágio do seu desenvolvimento para não quebrar o projeto.

### Cenário A: A migration foi gerada, mas você AINDA NÃO rodou `rails db:migrate`
Como as alterações ainda são apenas um arquivo de texto local no seu computador, você pode abrir o arquivo correspondente em `db/migrate/`, modificar as colunas ou tipos diretamente no código Ruby, salvar o arquivo e rodar normalmente no terminal:
```bash
rails db:migrate
```

### Cenário B: Você JÁ rodou `rails db:migrate`, mas quer corrigir algo localmente
Se você executou o comando e percebeu um erro de digitação imediatamente, você pode desfazer a alteração no banco usando o rollback.
* **Como deve ser escrito:** `rails db:rollback` (para desfazer a última) ou `rails db:rollback STEP=X` (onde X é o número de migrations que quer voltar).
* **O que faz por baixo dos panos:** O Rails faz o caminho inverso do método `change`. Ele destrói a tabela ou remove a coluna que acabou de criar no banco de dados. 
* **O fluxo de correção:**
    1. Rode `rails db:rollback`
    2. Abra o arquivo da migration em `db/migrate/` e faça as correções no texto.
    3. Salve o arquivo.
    4. Execute `rails db:migrate` novamente.

### Cenário C: A migration já foi enviada para o Git (GitHub/GitLab) ou para Produção
> 🚨 **A REGRA DE OURO:** Se outros desenvolvedores do time já baixaram o seu código ou se ele já foi aplicado no servidor de produção, **você nunca altera o arquivo original e nunca usa rollback.** Fazer isso corrompe o controle de versão dos seus colegas.

A solução correta é criar uma **nova migration cumulativa** utilizando os padrões textuais que o Rails reconhece:

#### 1. Para Adicionar uma Coluna a uma tabela existente:
Use o padrão `Add[Coluna]To[Tabela]` informando o campo e tipo:
```bash
rails generate migration AddCategoryToProducts category:string
```
* **O que faz por baixo dos panos:** O Rails identifica o padrão textualmente e auto-escreve a instrução:
```ruby
def change
  add_column :products, :category, :string
end
```

#### 2. Para Remover uma Coluna de uma tabela existente:
Use o padrão `Remove[Coluna]From[Tabela]`:
```bash
rails generate migration RemovePriceFromProducts price:decimal
```
* **O que faz por baixo dos panos:** O Rails identifica os termos textuais e auto-escreve a instrução de exclusão:
```ruby
def change
  remove_column :products, :price, :decimal
end
```

Após gerar o arquivo de correção por qualquer um dos padrões acima, aplique as mudanças com:
```bash
rails db:migrate
```

---

## 6. Configurar e Popular as Seeds (A Mobília)

O arquivo de seeds serve para preencher o banco de dados com registros essenciais (ex: o primeiro usuário Admin do sistema) ou massa de testes para desenvolvimento.

### Passo 6.1: Escrever o arquivo `db/seeds.rb`
Este arquivo aceita código Ruby puro em conjunto com os métodos do *ActiveRecord* (seus Models).

```ruby
# db/seeds.rb

puts "== Limpando base de dados antiga =="
# Boa prática: Evita duplicar os registros caso o comando de seed seja rodado várias vezes
Product.destroy_all 

puts "== Criando registros iniciais =="
Product.create!(name: "Notebook Pro", price: 7499.90, category: "Eletrônicos")
Product.create!(name: "Teclado Mecânico", price: 349.00, category: "Periféricos")

puts "== Seeds plantadas com sucesso! Total de produtos: #{Product.count} =="
```

### Passo 6.2: Executar as Seeds
* **Como deve ser escrito:** `rails db:seed`
* **O que faz por baixo dos panos:** O Rails executa o arquivo `db/seeds.rb` linha por linha dentro do contexto da sua aplicação, salvando as instâncias criadas no banco de dados ativo.

### Dica Avançada: Organização Modular para Projetos Grandes
Caso o arquivo `seeds.rb` fique muito extenso, você pode criar uma pasta livre chamada `db/seeds/` e fracionar seus arquivos por contexto (ex: `usuarios.rb`, `produtos.rb`). No arquivo principal `db/seeds.rb`, basta usar o método `load` do Ruby para chamá-los:

```ruby
# db/seeds.rb
load Rails.root.join('db', 'seeds', 'usuarios.rb')
load Rails.root.join('db', 'seeds', 'produtos.rb')
```

---

## Cheat Sheet (Tabela de Referência Rápida)

| Comando | Formato de Escrita | O que faz exatamente? |
| :--- | :--- | :--- |
| **Criar Banco** | `rails db:create` | Cria o arquivo ou o schema vazio no servidor de banco. |
| **Apagar Banco** | `rails db:drop` | Apaga o banco por completo. |
| **Resetar Banco** | `rails db:reset` | Reseta o banco. |
| **Nova Tabela** | `rails generate migration Create[TabelasPlural] campo:tipo` | Gera arquivo com carimbo de tempo configurado para criar tabela. |
| **Nova Coluna** | `rails generate migration Add[Coluna]To[TabelaPlural] campo:tipo` | Gera arquivo estruturado para injetar coluna em tabela existente. |
| **Remover Coluna** | `rails generate migration Remove[Coluna]From[TabelaPlural] campo:tipo` | Gera arquivo estruturado para deletar coluna de tabela existente. |
| **Migration Vazia** | `rails generate migration NomeCustomizado` | Cria arquivo com bloco em branco para lógicas ou scripts manuais. |
| **Aplicar Mudanças** | `rails db:migrate` | Executa migrations pendentes cronologicamente e atualiza o `schema.rb`. |
| **Desfazer Última** | `rails db:rollback` | Executa o inverso da última migration rodada (mecanismo de segurança). |
| **Popular Banco** | `rails db:seed` | Executa o script do arquivo `db/seeds.rb` para salvar dados. |
| **Reset Total** | `rails db:setup` | Atalho combo que roda `db:create`, `db:schema:load` e `db:seed`. |