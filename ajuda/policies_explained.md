# Guia Absoluto: Arquitetura de Autorização baseada em Policies no Ruby on Rails

Este documento serve como um manual completo e definitivo para entender o ecossistema de autenticação, autorização e controle de acesso implementado em sua aplicação Rails. A arquitetura aqui descrita utiliza o padrão **Policy** (inspirado na famosa *gem* Pundit) de maneira manual e customizada, misturando metaprogramação Ruby com herança de classes.

---

## 1. Visão Geral do Padrão Policy (A Analogia do Prédio)

Para entender a arquitetura do código, esqueça temporariamente a sintaxe de programação. Pense no seu sistema Rails como um **Prédio Comercial Restrito**.

* **O Usuário (`Usuario`):** É a pessoa tentando entrar no prédio e acessar determinadas salas.
* **A Controller (`TemplatesController`):** É o funcionário da recepção que lida diretamente com os pedidos do público ("Quero ir para a sala de edição", "Quero ir para a sala de criação").
* **O Motor de Autorização (`ApplicationController`):** É o **Gerente de Segurança** do prédio. Ele não conhece as regras específicas de cada sala, mas sabe como ler manuais e chamar os guardas certos.
* **A Policy Base (`ApplicationPolicy`):** É o modelo padrão de livro de regras do condomínio.
* **A Policy Específica (`TemplatePolicy`):** É o **Manual de Regras Exclusivo** de uma sala específica (neste caso, a sala dos Templates). Ele dita exatamente quem pode entrar em qual ação da sala (index, show, update, destroy).

---

## 2. Mapa Arquitetural do Sistema

O sistema é dividido em 4 camadas que conversam de forma perfeitamente coordenada a cada requisição HTTP.

```text
       [ Requisição HTTP do Navegador ]
                     │
                     ▼
       [ TemplatesController (Action) ]
                     │
         (Chama o motor de validação)
                     ▼
       [ ApplicationController (authorize!) ]
                     │
    (Descobre dinamicamente e instancia)
                     ▼
          [ TemplatePolicy ]  ───(Herda de)───► [ ApplicationPolicy ]
                     │
       (Retorna true/false para o motor)
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
   [ Se TRUE ]               [ Se FALSE ]
Permite executar a      Dispara NotAuthorizedError
ação e altera o BD.      e expulsa o usuário.
```

---

## 3. Análise Linha por Linha dos Arquivos do Projeto

Aqui está a dissecação técnica e detalhada de cada um dos quatro arquivos estruturais do seu sistema.

### 3.1. `ApplicationController` (O Motor do Sistema)
Este arquivo define comportamentos compartilhados por todas as controllers da aplicação. Ele é responsável por capturar tentativas de invasão e gerenciar os métodos globais de descoberta de regras.

```ruby
# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Bloqueia navegadores antigos que não suportam tecnologias modernas.
  allow_browser versions: :modern
  
  # Otimiza o cache de páginas HTTP baseado nas mudanças de arquivos JavaScript/Importmap.
  stale_when_importmap_changes

  # Cria uma classe de erro customizada para o sistema de permissões.
  class NotAuthorizedError < StandardError; end

  # Monitora a aplicação. Se o erro NotAuthorizedError acontecer em qualquer controller,
  # interrompe tudo e desvia a execução para o método 'usuario_nao_autorizado'.
  rescue_from NotAuthorizedError, with: :usuario_nao_autorizado

  # Expõe esses métodos de controle para que possam ser usados dentro das Views (.html.erb)
  helper_method :current_user
  helper_method :current_administrador
  helper_method :policy

  private

  # Retorna o usuário logado com base no ID salvo na sessão do navegador.
  # Usa Memoization (||=) para garantir que o Banco de Dados seja consultado apenas uma vez por requisição.
  def current_user
    @current_user ||= Usuario.find_by(id: session[:usuario_id])
  end

  # Atalho que retorna diretamente o perfil de administrador vinculado ao usuário atual.
  # O operador &. (safe navigation) impede que o sistema quebre caso current_user seja nulo.
  def current_administrador
    current_user&.perfil_adm
  end

  # Filtro de segurança básico de autenticação. Se o usuário não estiver logado,
  # barra a navegação e o manda para a tela de login.
  def authenticate_user!
    return if current_user.present?

    redirect_to login_path, alert: "Você precisa estar logado para acessar esta página."
  end

  # Filtro de segurança focado em administradores corporativos gerais.
  def require_administrador!
    authenticate_user!
    return if performed? # Se o authenticate_user! já realizou um redirecionamento, encerra aqui.
    return if current_user&.administrador?

    redirect_to root_path, alert: "Acesso não autorizado"
  end

  # O MÉTODO CENTRAL DE CHECAGEM DE SEGURANÇA.
  # Recebe o objeto (ex: @template) e opcionalmente o nome da regra a ser testada.
  def authorize!(record, query = nil)
    # Se 'query' for nula, assume o nome da action atual do Rails adicionando uma interrogação (?).
    # Exemplo: Se você estiver executando o método 'edit' na controller, query vira "edit?".
    query ||= "#{action_name}?"

    # Instancia a Policy correspondente ao objeto e executa dinamicamente o método contido na string 'query'.
    # Se o método retornar true, a segurança é validada com sucesso.
    return true if policy(record).public_send(query)

    # Se a policy retornar false, dispara o alarme de segurança levantando a exceção.
    raise NotAuthorizedError
  end

  # Instancia uma classe Policy passando o usuário logado e o objeto específico para o construtor.
  def policy(record)
    policy_class_for(record).new(current_user, record)
  end

  # Executa a filtragem de coleções (consultas ao banco de dados) acionando a classe Scope interna da Policy.
  def policy_scope(scope)
    policy_class_for(scope).scope(current_user, scope)
  end

  # METAPROGRAMAÇÃO: Descobre dinamicamente a string do nome da classe Policy baseado no objeto recebido.
  def policy_class_for(record_or_scope)
    model_class =
      if record_or_scope.is_a?(Class)
        record_or_scope        # Se recebeu 'Template' (a classe), usa ela diretamente.
      else
        record_or_scope.class  # Se recebeu '@template' (uma instância/registro), extrai a classe dele.
      end

    # Se model_class for 'Template', a interpolação gera a string "TemplatePolicy".
    # O método '.constantize' do Rails converte essa String em uma Classe Ruby real e utilizável.
    "#{model_class.name}Policy".constantize
  end

  # Tratamento executado caso o usuário seja barrado pelas regras de autorização.
  def usuario_nao_autorizado
    redirect_back(
      fallback_location: root_path,
      alert: "Você não tem permissão para realizar esta ação."
    )
  end
end
```

---

### 3.2. `ApplicationPolicy` (O Molde de Regras Base)
Este arquivo é o modelo genérico para todas as Políticas de Segurança do sistema. Ele define a estrutura básica de inicialização dos objetos de segurança.

```ruby
# frozen_string_literal: true

class ApplicationPolicy
  # Define leitores para acessar as variáveis protegidas de instância.
  attr_reader :usuario, :record

  # Método executado sempre que damos '.new' em uma Policy.
  # Captura quem está tentando agir (usuario) e sobre qual elemento (record).
  def initialize(usuario, record)
    @usuario = usuario
    @record = record
  end

  # Método de classe utilitário para invocar a filtragem de coleções de dados do banco.
  def self.scope(usuario, scope)
    # Procura por uma classe aninhada chamada 'Scope' dentro do contexto da classe atual executando-a.
    const_get(:Scope).new(usuario, scope).resolve
  end

  # Atalho herdado por todas as outras sub-policies para validar o perfil de administrador.
  def administrador?
    usuario&.administrador?
  end

  # Atalho herdado para obter o Perfil Administrativo do usuário logado.
  def current_administrador
    usuario&.perfil_adm
  end

  # CLASSE MÃE DE ESCOPO
  # Serve para blindar consultas ao banco de dados.
  class Scope
    attr_reader :usuario, :scope

    def initialize(usuario, scope)
      @usuario = usuario
      @scope = scope
    end

    # Por padrão estrito de segurança, se uma classe filha esquecer de implementar regras de escopo,
    # retorna .none, impossibilitando a exibição de qualquer registro do banco de dados.
    def resolve
      scope.none
    end
  end
end
```

---

### 3.3. `TemplatePolicy` (O Livro de Regras Específicas do Template)
Este arquivo contém as regras de negócio reais da sua aplicação referentes ao modelo `Template`. Ele herda todas as características e atalhos da classe `ApplicationPolicy`.

```ruby
# frozen_string_literal: true

class TemplatePolicy < ApplicationPolicy
  # CLASSE FILHA DE ESCOPO (Específica para o modelo Template)
  # Herda a inicialização de ApplicationPolicy::Scope
  class Scope < ApplicationPolicy::Scope
    # Reescreve o método resolve padrão.
    def resolve
      # Se o usuário for um administrador, libera acesso total para buscar todos os registros da tabela.
      return scope.all if usuario&.administrador?

      # Se for um usuário comum, oculta completamente a listagem retornando nada.
      scope.none
    end
  end

  # Para acessar a listagem geral, precisa ser um Administrador.
  def index?
    administrador?
  end

  # Para ler os detalhes de um template, precisa ser um Administrador.
  def show?
    administrador?
  end

  # Redireciona a validação da tela 'new' diretamente para a regra de criação física.
  def new?
    create?
  end

  # Para submeter o formulário e criar um template no banco, precisa ser um Administrador.
  def create?
    administrador?
  end

  # Redireciona a validação da tela 'edit' diretamente para a regra de atualização física.
  def edit?
    update?
  end

  # Regra de atualização: Não basta ser apenas admin, precisa passar pela verificação de dono do registro.
  def update?
    dono_do_template?
  end

  # Regra de destruição: Precisa passar pela verificação se foi o criador do registro.
  def destroy?
    dono_do_template?
  end

  # Regra de uso genérico do template. Exige perfil de administrador.
  def use?
    administrador?
  end

  private

  # Regra Customizada Privada.
  def dono_do_template?
    # O usuário logado precisa ser um administrador (administrador?)
    # E (&&) o template em análise (@record) precisa confirmar que foi criado por este perfil administrador específico.
    administrador? && record.criado_por?(current_administrador)
  end
end
```

---

### 3.4. `TemplatesController` (O Manipulador de Requisições)
Esta classe gerencia o ciclo de vida das requisições web para os templates. Ela consome o motor de segurança a cada etapa crítica antes de autorizar alterações no Banco de Dados.

```ruby
# frozen_string_literal: true

class TemplatesController < ApplicationController
  # Filtro executado antes de qualquer ação. Garante que visitantes anônimos não entrem nas páginas.
  before_action :authenticate_user!
  
  # Filtro focado em carregar o registro solicitado do banco de dados antes que as ações críticas rodem.
  before_action :set_template, only: %i[show edit update destroy]

  # AÇÃO: Listar Templates
  def index
    # Valida se o usuário tem a permissão geral descrita em TemplatePolicy#index?
    authorize! Template

    # Aciona o Scope da TemplatePolicy. Como o usuário passou na validação acima,
    # 'policy_scope(Template)' se transforma internamente na query 'Template.all'.
    # O código complementa adicionando otimização de joins (.includes) e escopos de ordenação (.recentes).
    templates = policy_scope(Template)
      .includes(adm: :usuario)
      .recentes

    # Filtra e divide a lista de templates do banco em duas coleções distintas na tela:
    # 1. Templates criados especificamente pelo administrador que está navegando agora.
    @user_templates = templates.criados_por(current_administrador)
    # 2. Templates criados por outros colegas administradores do sistema.
    @other_templates = templates.criados_por_outros(current_administrador)
  end

  # AÇÃO: Exibir detalhes de um registro específico
  def show
    # Testa se o usuário logado possui a permissão 'show?' para o registro específico contido em @template.
    authorize! @template
  end

  # AÇÃO: Renderizar formulário vazio de criação
  def new
    # Cria uma instância vazia na memória associando-a ao administrador atual.
    @template = Template.new(adm: current_administrador)
    preparar_campos_do_formulario

    # Roda a verificação de segurança 'new?' (que chama 'create?') na TemplatePolicy.
    authorize! @template
  end

  # AÇÃO: Submeter dados do formulário de criação para o banco de dados
  def create
    # Instancia o objeto preenchendo-o com os parâmetros validados vindos da web.
    @template = Template.new(template_params)
    @template.adm = current_administrador

    # Garante a proteção. O usuário tem perfil para criar um template? (TemplatePolicy#create?)
    authorize! @template

    # EXECUÇÃO NO BANCO DE DADOS:
    # O método .save tenta efetivar o comando SQL 'INSERT INTO templates' físico no banco de dados.
    if @template.save
      redirect_to @template, notice: "Template criado com sucesso."
    else
      preparar_campos_do_formulario
      render :new, status: :unprocessable_entity
    end
  end

  # AÇÃO: Renderizar formulário de edição de dados existentes
  def edit
    preparar_campos_do_formulario

    # Segurança: Roda o método 'edit?' (que chama 'update?') na TemplatePolicy.
    # O sistema avalia se o administrador logado é de fato o proprietário original deste template.
    # Se não for o proprietário original, o método lança NotAuthorizedError e bloqueia a exibição da tela.
    authorize! @template
  end

  # AÇÃO: Receber alterações do formulário de edição e salvar no banco
  def update
    # Proteção idêntica à do método edit, evitando ataques via API ou URL forçada.
    authorize! @template

    # EXECUÇÃO NO BANCO DE DADOS:
    # O método .update recebe os novos parâmetros e dispara fisicamente o comando SQL 'UPDATE templates SET ... WHERE id = ...'
    if @template.update(template_params)
      redirect_to @template, notice: "Template atualizado com sucesso."
    else
      preparar_campos_do_formulario
      render :edit, status: :unprocessable_entity
    end
  end

  # AÇÃO: Excluir um registro físico
  def destroy
    # Proteção: Avalia se o usuário atual é o proprietário com permissão para remover o registro.
    authorize! @template

    # EXECUÇÃO NO BANCO DE DADOS:
    # O método .destroy dispara o comando SQL 'DELETE FROM templates WHERE id = ...' eliminando o registro da tabela.
    @template.destroy

    redirect_to templates_path, notice: "Template excluído com sucesso."
  end

  private

  # Localiza o registro solicitado na barra de navegação através do ID.
  def set_template
    @template = Template.find(params[:id])
  end

  # Método auxiliar focado em preparar objetos aninhados (Nested Attributes) de questões discursivas/opções
  # para que o formulário HTML possa renderizar os blocos de campos em branco corretamente.
  def preparar_campos_do_formulario
    utilizacoes = @template.utilizacao_questoes
    utilizacoes.build(numero: 1) if utilizacoes.empty?

    utilizacoes.each do |utilizacao|
      utilizacao.build_questao(tipo: :discursiva) if utilizacao.questao.blank?
      4.times { utilizacao.questao.opcoes.build }
    end
  end

  # Strong Parameters: Filtro de segurança nativo do Rails que define estritamente quais campos vindos do formulário web
  # são aceitos para escrita no banco de dados, bloqueando injeções maliciosas de campos extras.
  def template_params
    params
      .require(:template)
      .permit(
        :titulo,
        :descricao,
        utilizacoes_questao_attributes: [
          :id, :questao_id, :numero, :parent_id, :_destroy,
          questao_attributes: [
            :id, :enunciado, :tipo,
            opcoes_attributes: [ :id, :texto, :numero, :_destroy ]
          ]
        ]
      )
  end
end
```

---

## 4. Engenharia Avançada do Ruby Explicada

Para entender por que esse sistema funciona de forma tão enxuta, precisamos desmistificar três recursos avançados de orientação a objetos e metaprogramação nativos do Ruby que estão rodando debaixo do capô.

### 4.1. Namespacing (O Segredo das Duas Classes `Scope`)

O seu projeto possui duas classes chamadas `Scope`:
1. Uma dentro de `ApplicationPolicy`.
2. Uma dentro de `TemplatePolicy`.

Como o Ruby impede que uma apague a outra da memória do servidor? Através de **Namespacing** (Espaço de Nomes). O Ruby utiliza a estrutura de empacotamento de classes internas para dar endereços completamente únicos a elas usando o operador `::`.

Para o interpretador do Ruby, os nomes oficiais dessas duas classes são:
* `ApplicationPolicy::Scope`
* `TemplatePolicy::Scope`

#### Criando instâncias de cada uma explicitamente no código:
Caso você precisasse forçar a criação manual de objetos de cada um desses escopos isoladamente, bastaria invocar o caminho de resolução completo por extenso:

```ruby
# Instancia a classe contida na política mãe (regra geral que retorna .none)
escopo_geral = ApplicationPolicy::Scope.new(usuario_logado, Template)

# Instancia a classe contida na política filha (regra customizada que retorna .all para admins)
escopo_do_template = TemplatePolicy::Scope.new(usuario_logado, Template)
```

---

### 4.2. O Funcionamento Dinâmico de `const_get`

O método `const_get` busca uma constante (uma classe, módulo ou estrutura em maiúsculo) dentro de um determinado contexto usando apenas um nome textual ou símbolo.

Observe a chamada contida em `ApplicationPolicy`:
```ruby
def self.scope(usuario, scope)
  const_get(:Scope).new(usuario, scope).resolve
end
```

Quando a controller roda `policy_scope(Template)`, a metaprogramação descobre que a classe alvo é a classe filha `TemplatePolicy` e herda a execução do método `self.scope` para dentro dela.

1. Quando o Ruby entra em `self.scope` sendo executado dentro do contexto da classe `TemplatePolicy`, o comando `const_get(:Scope)` avalia os arredores imediatos.
2. Ele se pergunta: *"Existe alguma classe chamada Scope definida dentro desta classe atual onde estou operando?"*.
3. Como você declarou `class Scope < ApplicationPolicy::Scope` dentro de `TemplatePolicy`, ele localiza com precisão a classe `TemplatePolicy::Scope` e a instancia chamando o método `.new`.

Se você estivesse executando uma suposta classe `ProdutoPolicy`, o `const_get(:Scope)` encontraria automaticamente a classe interna `ProdutoPolicy::Scope`. Isso remove a necessidade de escrever condicionais para cada modelo do sistema.

---

### 4.3. O Poder de `constantize` e `public_send`

O motor da `ApplicationController` utiliza duas funções cruciais de metaprogramação para converter dados de navegação textuais em comandos funcionais de servidor.

#### `constantize` (De Texto para Classe)
O Rails recebe objetos e extrai seus nomes como texto para localizar arquivos.
```ruby
"TemplatePolicy".constantize # Transforma a String literal na classe estrutural executável TemplatePolicy
```

#### `public_send` (De Texto para Método)
O Ruby permite invocar ações de um objeto sem fixar o nome do método rigidamente no código fonte.
```ruby
# Se query for a string "update?", a linha abaixo:
policy(record).public_send("update?")

# É interpretada de forma idêntica a digitar isto fixo no código:
policy(record).update?
```

Graças ao `public_send`, o método `authorize!` consegue validar qualquer ação do sistema de forma universal, automatizando a segurança com uma única linha de código.

---

## 5. O Fluxo de Execução de Ponta a Ponta (Linha do Tempo)

Para sedimentar todo o aprendizado, acompanhe a linha do tempo exata de processamento interno do servidor web simulando um cenário crítico do mundo real.

### Cenário de Teste:
O usuário **Carlos** (que é um Administrador) entra em seu painel e clica no botão para **Excluir** o **Template ID #99**. No entanto, este Template de ID #99 foi originalmente criado e registrado pelo administrador **Fabiano**.

---

### A Linha do Tempo da Requisição

1. **O Clique:** O navegador envia uma requisição HTTP do tipo `DELETE` com destino ao endereço de rota `/templates/99`.
2. **O Roteador:** O Router do Rails intercepta o pacote de dados e o despacha diretamente para a controller `TemplatesController` ativando o método da action `destroy`.
3. **Filtro 1 (Autenticação):** Antes de tocar na action, o Rails roda o gancho `before_action :authenticate_user!`. O método `current_user` busca a sessão de Carlos no banco de dados e confirma que ele está logado. O fluxo avança.
4. **Filtro 2 (Carregamento):** O Rails aciona o gancho `before_action :set_template`. O banco de dados localiza o registro do Template ID #99 e o armazena na variável de instância `@template`. O fluxo avança.
5. **Entrada na Action:** A execução ganha o corpo do método `destroy` na `TemplatesController`. A primeira instrução encontrada é: `authorize! @template`.
6. **Invocação do Motor:** A execução salta temporariamente para fora da controller de templates e entra no método `authorize!` localizado na classe mãe `ApplicationController`.
7. **Montagem da Query:** Como nenhum argumento textual de método foi fornecido na chamada da função, a variável local `query` avalia a condicional e assume o valor da action atual concatenado com uma interrogação: `query = "destroy?"`.
8. **Descoberta da Policy:** O motor chama `policy_class_for(@template)`. O sistema lê a classe de `@template` (que é `Template`), monta a string `"TemplatePolicy"` e aplica o método `.constantize`. A classe real `TemplatePolicy` é retornada.
9. **Construção do Objeto de Segurança:** O método `policy(@template)` executa a instanciação da política: `TemplatePolicy.new(current_user, @template)`. Internamente na política, o usuário Carlos é fixado na variável `@usuario` e o Template #99 (criado por Fabiano) fica fixado em `@record`.
10. **O Disparo da Checagem:** O motor da `ApplicationController` executa o comando dinâmico: `policy(@template).public_send("destroy?")`. Isso força a execução imediata do método `def destroy?` localizado dentro de `TemplatePolicy`.
11. **A Execução da Regra de Negócio:**
    * Dentro de `TemplatePolicy`, o método `destroy?` delega a resposta para o método privado `dono_do_template?`.
    * O método `dono_do_template?` avalia a seguinte linha lógica: `administrador? && record.criado_por?(current_administrador)`.
    * A primeira parte (`administrador?`) retorna `true` (pois Carlos possui perfil administrativo).
    * A segunda parte analisa se o template (`record`) ID #99 foi criado pelo perfil administrativo de Carlos (`current_administrador`). Como o criador original foi o Fabiano, o modelo retorna **`false`**.
    * A operação lógica avalia `true && false`, resultando em um retorno final consolidado de **`false`**.
12. **O Alarme é Acionado:** O valor `false` retorna para o método central `authorize!` na `ApplicationController`. Como a condição de aprovação não foi alcançada, a linha abaixo é ativada: `raise NotAuthorizedError`.
13. **Interrupção Total:** O interpretador Ruby interrompe imediatamente o fluxo normal da aplicação. A execução do método `destroy` na controller é **cancelada e abortada** instantaneamente. A linha de comando subsequente `@template.destroy` **nunca chega a ser executada**, garantindo que o registro permaneça totalmente intocado no Banco de Dados.
14. **Captura do Erro e Mitigação:** A instrução `rescue_from NotAuthorizedError, with: :usuario_nao_autorizado` localizada no topo da `ApplicationController` assume o controle da aplicação. Ela chama o método `usuario_nao_autorizado`.
15. **A Resposta ao Navegador:** O método executa um comando `redirect_back`, empurrando o Carlos de volta para a tela onde ele estava originalmente e adiciona uma mensagem flash de alerta no topo do seu navegador: *"Você não tem permissão para realizar esta ação."*

A integridade do banco de dados foi preservada com sucesso através de uma arquitetura limpa, padronizada, performática e isolada.