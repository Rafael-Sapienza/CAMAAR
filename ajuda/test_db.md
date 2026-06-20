# 🛠️ Como Funciona o Banco de Dados de Testes no Ruby on Rails (com Cucumber)

Quando desenvolvemos em Ruby on Rails, um dos conceitos mais importantes é o **Isolamento de Ambientes**. O Rails possui três ambientes padrão: `development`, `production` e `test`. Cada um deles possui seu próprio banco de dados independente.

---

## 1. O Isolamento Total do Ambiente de Testes

A partir do momento em que você digita `cucumber` no seu terminal, o Rails altera uma "chave geral" interna. Ele configura uma variável de ambiente chamada `RAILS_ENV` com o valor `"test"`.

Essa chave diz para o **Active Record** (o ORM do Rails): 
> *"Esqueça que o banco de desenvolvimento existe por hoje. Qualquer consulta, criação ou deleção a partir de agora deve ir única e exclusivamente para o banco de testes."*

Por isso, não importa quem chama quem:
* O arquivo de **Steps** escrevendo `User.create!`.
* O **Capybara** clicando em um botão na tela.
* A sua **Controller** buscando dados com `User.find_by`.
* O seu **Model** processando validações.

**Tudo roda dentro do banco de dados de testes.** O seu banco de desenvolvimento (`seu_projeto_development`) fica 100% intacto, protegido e intocado.

---

## 2. O Fluxo de uma Requisição durante o Teste

O Cucumber (o robô que testa a aplicação) e o Rails conversam através do banco de testes de forma sincronizada:

```text
[ ARQUIVO DE STEPS ]
  │
  ▼ (Dado que o usuário existe...)
1. Executa User.create!(...) ───► [ BANCO DE DADOS DE TESTE ]
                                           ▲
[ CAPYBARA (ROBÔ) ]                        │
  │                                        │
  ▼ (Quando preencho e clico em Entrar)    │ 3. A Controller busca o
2. Dispara a requisição web                │    usuário aqui para validar
  │                                        │    a senha.
  ▼                                        │
[ SUA CONTROLLER (sessions#create) ] ──────┘
```

1. **Preparação (Mundo dos Steps):** No passo `Dado`, você insere o usuário diretamente no banco de testes para "preparar o terreno".
2. **Ação (Mundo do Capybara):** O robô simula o preenchimento do formulário no navegador e clica em "Entrar". Isso dispara uma requisição real para a sua Controller.
3. **Execução (Mundo do Rails):** A sua Controller recebe a requisição e busca o usuário no banco. Como o Rails está no modo de teste, a Controller procura no banco de testes, encontra o usuário que você criou no passo 1, e o login funciona!

---

## 3. O Banco Não Fica Poluído? (O Mecanismo de Transaction)

Você pode criar quantos usuários quiser nos seus passos de teste, pois o banco **nunca vai acumular lixo**. 

Por padrão, o ambiente de testes do Rails roda cada cenário do Cucumber dentro de uma **Transação de Banco de Dados** (`Database Transaction`):

```text
[Inicia o Cenário] ──► Abre Transação ──► Cria Dados (Steps) ──► Roda o Teste ──► [Fim do Cenário] ──► ROLLBACK (Apaga Tudo)
```

Ao final de cada cenário, o Cucumber dá um **Rollback** (desfaz tudo). O próximo cenário sempre começará com o banco de dados 100% limpo e vazio.

---

## 4. Comandos Essenciais para o Banco de Testes

O Rails gerencia a configuração do banco de testes através do arquivo `config/database.yml`. No entanto, você precisa rodar alguns comandos para criar e sincronizar esse banco antes de sair testando.

### Se for a primeira vez rodando o projeto:
Antes de mais nada, o banco de dados de teste precisa existir fisicamente no seu computador. Para criá-lo, rode:
```bash
rails db:create RAILS_ENV=test
```
*(Nota: O comando `rails db:create` padrão geralmente já cria os bancos de desenvolvimento e teste de uma vez só, mas o comando acima garante a criação específica do de teste).*

### Para sincronizar as tabelas e alterações (No dia a dia):
Sempre que você criar uma tabela ou coluna nova no desenvolvimento (usando *Migrations*), você precisa espelhar essa estrutura para o banco de testes usando:
```bash
rails db:test:prepare
```

#### O que o `rails db:test:prepare` faz por baixo dos panos?
1. Lê o arquivo `db/schema.rb` (que é o mapa atual do seu banco de desenvolvimento após você ter rodado o `rails db:migrate`).
2. Vai até o seu banco de testes, limpa a estrutura antiga e recria todas as tabelas e colunas idênticas às de desenvolvimento.

> 💡 *Dica:* Muitas versões do Rails e do Cucumber já rodam o `db:test:prepare` de forma automática quando você digita `cucumber`. Mas se o teste falhar acusando que uma tabela ou coluna nova não existe, rodar este comando manualmente resolve o problema na hora!