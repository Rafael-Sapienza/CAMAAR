# 📖 Documentação do Sistema e Guia de Configuração

Esta documentação é destinada a orientar os avaliadores no processo de configuração e validação do sistema. O documento reúne o guia prático para parametrização de credenciais em ambiente de testes, além de detalhar o funcionamento dos fluxos e a arquitetura de povoamento de dados adotada.

---

## 🛠️ 1. Povoamento Inicial e Arquitetura do Banco (Seeding)

Como o escopo original do projeto não previa uma História de Usuário (US) para a criação e cadastro de administradores, adotou-se uma abordagem pragmática de engenharia de software para garantir a segurança e a viabilidade do sistema.

* **O Arquivo `seeds.rb`:** A única forma de gerar usuários administradores no sistema é através do script de inicialização (`rails db:seed`). 
* **Fonte de Dados (`db/dados_iniciais.json`):** Este arquivo é lido pelo seed e povoa o banco de dados com:
  * Usuários administradores iniciais (docentes ou discentes).
  * Configurações de departamentos, matrículas e turmas.
* **Imutabilidade de Departamentos:** Por regra de design, os departamentos inseridos via seed são considerados **imutáveis**. Uma vez adicionados, não podem ser editados ou removidos diretamente pela interface do sistema.

---

## 🔐 2. Autenticação e Interface do Usuário

### Fluxo de Login
* O login exige a inserção da **matrícula ou e-mail** junto com a **senha**.
* Uma vez autenticado o usuário, o sistema adapta a interface dinamicamente com base no nível de permissão identificado.

### Níveis de Acesso e Interface
* **Visão Administrativa:** Caso o usuário logado seja um administrador, a barra lateral de navegação exibirá a aba exclusiva de **Gerenciamento**. Para usuários comuns, essa aba permanece ocultada.
* **Menu de Perfil Comum:** Independentemente do nível de acesso, a interface apresenta um **botão roxo circular** no canto superior direito da tela com a inicial do nome do usuário. Ao clicar nesse botão, um menu suspenso exibe:
  * Matrícula do usuário.
  * E-mail cadastrado.
  * Opção de **Sair do sistema (Log out)**.

---

## 🔄 3. Sincronização e Importação de Dados do SIGAA

Dentro da aba de Gerenciamento, o administrador possui o controle sobre a atualização da base de dados geral da aplicação.

### Como Funciona a Importação
Ao acionar o botão **"Importar Dados do Sigaa"**, o sistema invoca a função `importar_dados` na controladora, realizando uma operação completa de sincronização baseada no arquivo `db/usuarios_sigaa.json`:

1. **Atualização:** Atualizam-se os registros antigos caso algum de seus atributos tenha sofrido modificação.
2. **Criação:** Inserem-se novos registros que ainda não existiam na importação anterior.
3. **Remoção:** Deletam-se do sistema os registros que foram removidos do arquivo JSON.

> 💡 **Observação:** Como a função realiza a leitura sempre do mesmo arquivo local (`db/usuarios_sigaa.json`), torna-se possível simular alterações, edições ou exclusões do SIGAA, bastando editar este arquivo JSON e acionar novamente o comando de importação.

### Tolerância a Falhas e Resiliência
A função de importação foi projetada para ser flexível e tolerante a falhas parciais:
* **Atualização Máxima:** Se o arquivo JSON contiver erros pontuais (por exemplo, um docente associado a um departamento inexistente), o sistema **não abortará** a operação. Serão salvos e atualizados todos os dados válidos possíveis.
* **Feedback Visual:** Em caso de inconsistências, o sistema exibirá um alerta detalhado na tela indicando a exata natureza e localização do problema (ex: *"Aluno matriculado em turma inexistente"*). Em caso de sucesso integral, uma mensagem de êxito será exibida.

---

## 📧 4. Fluxo de Cadastro de Alunos, Convites e Redefinição

No estado inicial, o sistema conta apenas com os administradores gerados no seed. Para a integração dos alunos do SIGAA ao ecossistema ativo, o seguinte fluxo é executado:

### Convites por E-mail (Ação do Admin)
1. O administrador acessa a aba de gerenciamento e aciona a opção **"Enviar Solicitação de Cadastro"**.
2. O sistema dispara e-mails automáticos contendo links parametrizados com tokens de segurança.
3. **Regra de Negócio (Escopo):** Um administrador restringe-se ao gerenciamento de turmas vinculadas ao próprio departamento. Portanto, os e-mails são disparados **apenas** para os alunos das turmas pertencentes ao departamento daquele administrador específico.
4. O corpo do e-mail é padronizado com a seguinte informação: *"O administrador [Nome do Admin] está te convidando para realizar cadastro"*.

### Ciclo de Vida do Token de Cadastro
* **Validade:** Cada token gerado expira estritamente após **10 minutos**.
* **Expiração:** Se o link com token expirado for acessado, ocorre um redirecionamento automático para a tela de login. Contudo, o fluxo não é bloqueado: o cadastro pode ser feito manualmente acionando o campo correspondente na tela inicial.
* **Sucesso:** Caso o token seja válido, o link direciona o usuário para a seção de definição de senha. Após a digitação e a confirmação correta da senha, o status do usuário é alterado de **Pendente** para **Ativo**.
* **Segurança:** Assim que o cadastro é concluído, o token utilizado é **imediatamente invalidado**, impedindo reutilizações.

### Cadastro Manual e Redefinição de Senha
* **Cadastro Manual via Login:** Na tela de login, existe a possibilidade de realizar o cadastro informando Matrícula e E-mail. Se os dados coincidirem exatamente com o registro importado do SIGAA, um e-mail com token de validação é enviado para liberar o acesso.
* **Redefinição de Senha:** Caso ocorra esquecimento da senha, a opção de redefinição solicita o e-mail do usuário e envia um link tokenizado. Assim que a nova senha é registrada, o token expira automaticamente.

---

## 📨 5. Integração de E-mails com Brevo e Testes (Aviso aos Corretores)

O sistema possui disparos de e-mail reais integrados à API da **Brevo**. 

* **Para Testar o Envio Real:** Recomenda-se que os avaliadores alterem alguns registros no arquivo `db/usuarios_sigaa.json`, inserindo **e-mails reais** de controle para verificar o recebimento dos convites e dos tokens de redefinição.
* **Ambiente de Testes Automatizados:** Nos testes executados via **RSpec**, a rotina de envio de e-mails foi completamente **mockada**. Isso garante a celeridade da suíte de testes e evita o consumo da franquia de disparos da API real.

---

## 🔐 6. Guia de Configuração para os Avaliadores: Rails Credentials com Editor NANO

Para que o sistema consiga disparar e-mails utilizando a API do Brevo durante a avaliação, é necessária a configuração das credenciais criptografadas do Rails.

Se, ao tentar editar as credenciais, surgir o seguinte erro:
```text
Editing config/credentials.yml.enc...
Couldn't decrypt config/credentials.yml.enc. Perhaps you passed the wrong key?
```
Isso indica que os arquivos `config/credentials.yml.enc` e `config/master.key` perderam a sincronia. O problema é resolvido removendo-os antes de iniciar o procedimento abaixo:
```bash
rm config/master.key config/credentials.yml.enc
```

### 🧭 Sobrevivência no Editor NANO (Comandos Básicos)
Como ambientes WSL ou terminais remotos podem apresentar limitações com editores gráficos, utiliza-se o `nano` diretamente no terminal:
* **Setas do teclado:** Movem o cursor.
* **Ctrl + O + Enter:** Salva as alterações feitas no arquivo.
* **Ctrl + X:** Sai do editor (caso haja alterações não salvas, digita-se `Y` para sim ou `N` para não, seguido de `Enter`).

### 🛠️ Passo a Passo: Gerenciando as Credenciais

#### 1. Abrindo o arquivo para edição
O comando abaixo força o Rails a abrir o arquivo de credenciais utilizando o editor Nano no terminal:
```bash
EDITOR="nano" rails credentials:edit
```

#### 2. Estrutura interna do arquivo (Formato YAML)
O arquivo utiliza a sintaxe YAML (sensível a espaços). **A tecla Tab não deve ser utilizada**, recorrendo-se sempre a **2 espaços** para definir a hierarquia. Os exemplos padrões devem ser apagados para a inclusão da chave gerada na Brevo, conforme a estrutura abaixo:

```yaml
brevo:
  api_key: "INSIRA_AQUI_O_TOKEN_DA_BREVO"
```
*Para salvar e sair:* Pressiona-se `Ctrl + O`, depois `Enter`, finalizando com `Ctrl + X`. O Rails criptografará o arquivo de forma automática na saída.

### 💻 Como o código consome essa chave
Nos Controllers ou Mailers da aplicação, o acesso ao token seguro é feito de forma resiliente pelo método `.dig`:

```ruby
chave_brevo = Rails.application.credentials.dig(:brevo, :api_key)
```
> 💡 *Nota:* O método `.dig` é seguro. Caso a chave não exista ou contenha erros de digitação, haverá o retorno de `nil` em vez de interromper a execução da aplicação com uma exceção.

### 🚨 Checklist de Segurança Crucial (Evite Vazamentos)
Antes de realizar qualquer commit ou envio ao repositório, deve-se verificar a segurança da chave mestra:
1. Certificar-se de que o arquivo `.gitignore` contenha a seguinte linha:
```text
   /config/master.key
   ```
2. Executar `git status` no terminal. O arquivo `config/credentials.yml.enc` **deve** constar na lista de arquivos prontos para commit, enquanto o arquivo `config/master.key` **nunca** deve ser listado.

---

## 🚀 Como funciona em Produção (Deploy)
Em ambientes de produção (como Render ou Heroku), nos quais o arquivo `master.key` não é enviado, deve-se copiar o conteúdo em texto puro de dentro do arquivo `config/master.key` local e criar uma Variável de Ambiente (Environment Variable) no painel de hospedagem com os seguintes dados:

* **Key:** `RAILS_MASTER_KEY`
* **Value:** `[conteúdo_da_master_key_local]`

O Rails detectará essa variável dinamicamente e descriptografará as credenciais em tempo de execução.