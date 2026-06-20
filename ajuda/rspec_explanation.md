# Manual de Testes no Rails: Cucumber Tradicional e RSpec (Guia Avançado)

Este guia prático ensina como estruturar, organizar e implementar testes de comportamento (BDD) utilizando o **Cucumber tradicional** com Expressões Regulares (Regex) e RSpec, abordando a organização em subpastas e os conceitos de Isolamento de Testes: Dublês, Stubs, Mocks e Costuras (*Seams*).

---

## 1. Organização Avançada de Pastas (Features e Steps)

Conforme uma aplicação Rails cresce, colocar todos os arquivos soltos nas pastas principais gera caos. O Cucumber permite e incentiva o uso de **subpastas (diretórios recursivos)** tanto para organizar as especificações de negócio quanto para os arquivos de código Ruby.

### Estrutura de Pastas Recomendada para Projetos Reais:
```text
seu_projeto/
└── features/                         # Pasta raiz do Cucumber (fora da pasta spec)
    ├── movies/                       # Módulo/Subpasta para o contexto de filmes
    │   ├── cadastro_de_filmes.feature
    │   └── busca_de_filmes.feature
    │
    ├── users/                        # Módulo/Subpasta para o contexto de usuários
    │   ├── login.feature
    │   └── perfil.feature
    │
    └── step_definitions/             # OBRIGATÓRIO: Onde moram as traduções em Ruby
        ├── movies/                   # Subpasta para organizar os códigos de filmes
        │   ├── cadastro_steps.rb
        │   └── busca_steps.rb
        │
        ├── users/                    # Subpasta para organizar os códigos de usuários
        │   └── usuarios_steps.rb
        │
        └── global_steps.rb           # Passos genéricos reutilizáveis por todo o sistema
```

### 1.1 Como o Cucumber localiza os arquivos automaticamente?
Quando você executa os testes, o motor do Cucumber faz uma varredura automática utilizando o conceito de **busca recursiva** (`**/*.rb` e `**/*.feature`). 



* **Para as Features:** O Cucumber entra em cada subpasta de `features/`, executa todos os arquivos `.feature` e compila os resultados.
* **Para os Steps:** O Cucumber lê todos os arquivos `.rb` dentro de `step_definitions/` (independentemente da subpasta em que estejam) e os unifica em um **"cérebro global de passos"**.

> ⚠️ **Regra de Ouro da Ambiguidade:** Como os passos são unificados globalmente, as frases mapeadas no Ruby nunca podem ser idênticas em arquivos diferentes (ex: ter o mesmo `Dado(/^que eu estou na home$/)` escrito no arquivo de filmes e no de usuários causará um erro de conflito/ambiguidade). Use arquivos como `global_steps.rb` para reaproveitar frases comuns.

---

## 2. Mapeamento Gherkin para Ruby usando Regex

No Cucumber tradicional, a conexão entre a linha escrita em português e o bloco de código Ruby ocorre através de **Expressões Regulares (Regex)** delimitadas por `/^...$/`. O símbolo `^` marca o início exato da frase e `$` marca o fim, blindando o teste contra falsos positivos.

### 2.1 O Arquivo de Feature (`features/movies/cadastro_de_filmes.feature`)
```gherkin
Funcionalidade: Cadastro de Filmes
  Como um administrador do sistema
  Quero cadastrar um novo filme

  Cenário: Cadastro com sucesso de um filme de ficção
    Dado que eu estou na página de novo filme
    Quando eu preencho o campo "Título" com "Inception"
    E eu preencho o campo "Ano" com "2010"
    E clico no botão "Salvar"
    Então eu devo ver a mensagem "Cadastrado com sucesso!"
```

### 2.2 O Arquivo de Steps (`features/step_definitions/movies/cadastro_steps.rb`)
Para capturar os parâmetros dinâmicos que o usuário digitou entre aspas na feature, utilizamos o padrão coringa de Regex `\"([^\"]*)\"`. O texto capturado é enviado na ordem exata como argumento para as variáveis do bloco do Ruby:

```ruby
# Mapeia o "Dado que..." estático
Dado(/^que eu estou na página de novo filme$/) do
  visit new_movie_path # Helper de rota embutido do Rails
end

# Mapeia o "Quando eu preencho..." 
# MÁGICA: Este único passo serve para Título, Ano ou qualquer outro campo!
Quando(/^eu preencho o campo "([^"]*)" com "([^"]*)"$/) do |campo, valor|
  fill_in campo, with: valor # O Capybara localiza o input HTML pelo nome e digita o valor
end

# Mapeia o "E clico no botão..." (O Cucumber interpreta o "E" usando o contexto do último "Quando")
Quando(/^clico no botão "([^"]*)"$/) do |botao|
  click_button botao # Capybara simula o clique no botão do formulário
end

# Mapeia o "Então eu devo ver..." (A validação/Expectation do RSpec)
Então(/^eu devo ver a mensagem "([^"]*)"$/) do |mensagem_esperada|
  # RSpec valida se o texto HTML final renderizado na tela contém a mensagem
  expect(page).to have_content(mensagem_esperada)
end
```

---

## 3. Comandos Práticos de Execução no Terminal

Graças à organização em subpastas, você ganha o superpoder de filtrar quais testes quer rodar no terminal, economizando tempo de desenvolvimento:

```bash
# Executar ABSOLUTAMENTE TODOS os testes do projeto:
bundle exec cucumber

# Executar apenas as features do contexto de FILMES:
bundle exec cucumber features/movies/

# Executar apenas um arquivo de feature ESPECÍFICO:
bundle exec cucumber features/movies/cadastro_de_filmes.feature

# Executar apenas um cenário específico (filtrando pela linha exata do arquivo):
bundle exec cucumber features/movies/cadastro_de_filmes.feature:6
```

---

## 4. Conceitos Cruciais de Isolamento de Testes

Enquanto as features testam o fluxo de ponta a ponta (sistema real), testes de unidade precisam isolar componentes para evitar dependências lentas ou externas (como APIs de pagamento, gateways de e-mail ou envio de SMS). Para isso, o RSpec fornece os **Dublês de Teste**.

### 4.1 Dublês (Test Doubles)
Um **Double** é um objeto "fantasminha". Você cria um objeto genérico que finge ser uma instância de uma classe real na memória RAM, sem precisar tocar ou persistir dados no banco de dados real.
```ruby
filme_falso = double("Filme")
```

### 4.2 Stubs (Substitutos de Resposta)
O **Stub** é o ato de treinar um objeto (seja um dublê ou uma classe real) para responder a um determinado método com uma resposta estática e fixa. É usado para blindar testes contra falhas de APIs externas.
```ruby
Dado(/^que a API de câmbio está ativa$/) do
  servico_cambio_duble = double("ServicoCambio")
  
  # ISSO É UM STUB: Sempre que alguém chamar .cotacao_dolar, responda 5.50 imediatamente
  allow(servico_cambio_duble).to receive(:cotacao_dolar).and_return(5.50)
end
```

### 4.3 Mocks e Expectations (Verificação de Comportamento)
Enquanto o *Stub* fornece dados passivos, o **Mock** atua como um fiscal para rastrear se uma ação vital **realmente aconteceu**. No RSpec, nós configuramos uma **Expectation** (Expectativa) antes do código principal ser executado.
```ruby
Então(/^o sistema deve disparar um e-mail de notificação$/) do
  # EXPECTATION: Configurada ANTES da ação. Garante que a classe Notificador receberá o método :enviar
  expect(Notificador).to receive(:enviar).once

  # Dispara a rotina do controller que deve disparar o e-mail
  @movies_controller.finalizar_cadastro
end
```

---

## 5. Arquitetura Baseada em Seams (Costuras)

O conceito de **Seam (Costura)**, cunhado por Michael Feathers, dita que para conseguir isolar seus testes usando *Stubs* e *Mocks*, o design do seu código precisa ser flexível.

> 💡 **Definição:** Uma Costura é um lugar no seu código onde você pode alterar o comportamento do sistema sem precisar modificar o arquivo de texto daquela classe. A forma mais elegante de abrir uma costura é via **Injeção de Dependência**.

### Exemplo de Código SEM Costura (Gengiveiro/Chumbado):
```ruby
class Carrinho
  def finalizar
    # O validador está preso rigidamente aqui dentro.
    # O Cucumber NÃO TEM COMO substituir isso por um validador fake.
    validador = GatewayDePagamentoReal.new 
    validador.cobrar
  end
end
```

### Exemplo de Código COM Costura (Pronto para Testes):
```ruby
class Carrinho
  # Abrimos uma costura através do parâmetro do Inicializador (Injeção de Dependência)
  def initialize(validador = GatewayDePagamentoReal.new)
    @validador = validador
  end

  def finalizar
    @validador.cobrar
  end
end
```

### Como o Cucumber/RSpec usa a Costura na Prática:
Graças à abertura arquitetada no inicializador, podemos neutralizar transações financeiras reais nos ambientes de testes de forma totalmente limpa:

```ruby
Quando(/^eu finalizo a compra com um cartão de simulação$/) do
  # 1. Criamos um dublê com um comportamento stub pré-combinado
  cartao_fake = double("ValidadorFinancas")
  allow(cartao_fake).to receive(:cobrar).and_return(true)

  # 2. Injetamos o dublê de testes diretamente na COSTURA (o inicializador)
  @carrinho = Carrinho.new(cartao_fake)
  @resultado = @carrinho.finalizar
end

Então(/^a compra deve ser processada com sucesso$/) do
  expect(@resultado).to ue(true)
end
```

---

## Resumo de Comandos e Sintaxes do Cucumber Tradicional

| Termo / Código | O que significa na prática? |
| :--- | :--- |
| **`features/**/*.feature`** | Localização de cenários descritivos humanos em subpastas. |
| **`step_definitions/**/*.rb`** | Localização das definições de passos em código Ruby estruturado. |
| **`/^...$/`** | Expressão Regular para garantir casamento exato de caracteres do início ao fim. |
| **`\"([^\"]*)\"`** | Expressão Regular padrão para capturar textos de dentro das aspas do Gherkin. |
| **`allow(obj).to receive`** | **Stub:** Força um método a devolver uma resposta fake fixa. |
| **`expect(obj).to receive`** | **Mock/Expectation:** Garante/Valida que um método foi obrigatoriamente chamado. |
| **`Costura (Seam)`** | Técnica de design de código para permitir a entrada de Dublês via injeção. |