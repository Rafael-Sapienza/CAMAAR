# Manual Definitivo de Rotas e Controllers no Ruby on Rails

Este guia prático foi desenhado para explicar profundamente o funcionamento do roteamento e das controladoras no ecossistema Rails, detalhando a comunicação entre a URL, o objeto `params`, os métodos de resposta da controladora e a renderização das Views.

---

## 1. Convenções de Pastas e Nomes (Tráfego Web)

O Rails conecta as URLs digitadas no navegador aos arquivos Ruby do seu projeto através de locais e nomes estritos. 

### Estrutura de Pastas Obrigatória:
```text
seu_projeto/
├── config/
│   └── routes.rb         # OBRIGATÓRIO: O mapa de tráfego de todo o seu site.
└── app/
    └── controllers/      # OBRIGATÓRIO: Onde moram as classes das suas controladoras.
        └── movies_controller.rb # Exemplo de arquivo de controller.
```

### Regras de Nomenclatura para Controllers:
* **No arquivo de Rotas (`config/routes.rb`):** Você se refere ao controller em letras minúsculas e no plural (ex: `'movies'`).
* **No nome do arquivo físico:** Deve ser escrito em minúsculo, no plural e terminar com `_controller.rb` (ex: `movies_controller.rb`).
* **No nome da Classe Ruby:** Deve ser escrito em *CamelCase*, no plural e terminar com a palavra `Controller` (ex: `class MoviesController < ApplicationController`).

---

## 2. O Mecanismo de Rotas (The Router)

O arquivo de rotas funciona como um direcionador de tráfego. Ele intercepta a requisição HTTP (o clique do usuário) e decide qual gerente (Controller) e qual tarefa (Action/Método) vai resolver o problema.

### 2.1 O Método Manual Desestruturado
A forma mais explícita e poderosa de mapear uma rota na mão segue o padrão clássico:

```ruby
get '/movies/:id/new' => 'movies#new', :as => 'new_movie'
```

Vamos desestruturar cada campo para entender o que ele faz:

1. **`get` (O Verbo HTTP):** Determina que esta rota só responde a requisições de leitura de página. Se o navegador tentar disparar um envio de formulário (`POST`) ou exclusão (`DELETE`) nesta URL, o Rails bloqueará o acesso.
2. **`'/movies/:id/new'` (O Caminho da URL):** É o endereço que aparecerá no navegador. O trecho **`:id`** (com dois pontos na frente) avisa ao Rails que ali haverá uma variável dinâmica (um número ou texto que muda a cada filme).
3. **`=> 'movies#new'` (O Destino):** Define quem processará o clique. O texto antes do `#` aponta para a classe `MoviesController`. O texto após o `#` aponta para o método (Action) `def new` dentro dessa classe.
4. **`:as => 'new_movie'` (O Helper/Apelido):** Cria um atalho na memória do Ruby. Isso gera um método chamado `new_movie_path` para você usar no seu código, impedindo que você tenha que digitar a URL inteira na mão no futuro.

#### Exemplo prático do Helper `:as` na View (HTML):
Em vez de escrever uma tag de link estática e perigosa no seu HTML, você usa o helper gerado pelo `:as`:

```erb
<a href="/movies/7/new">Avaliar Filme</a>

<%= link_to "Avaliar Filme", new_movie_path(id: 7) %>
```

---

### 2.2 O Método Automático (`resources`)
Para poupar digitação nas operações padrão de um sistema (criar, ler, editar, deletar), o Rails criou o atalho `resources`. 

Ao escrever apenas uma linha no seu arquivo `config/routes.rb`:
```ruby
resources :movies
```

O Rails cria automaticamente **7 rotas manuais equivalentes**. Veja a tabela exata de equivalência de código por baixo dos panos:

```ruby
# ESCREVER "resources :movies" É EXATAMENTE O MESMO QUE DIGITAR ESTAS 7 LINHAS:
get    '/movies'          => 'movies#index',   :as => 'movies'
get    '/movies/new'      => 'movies#new',     :as => 'new_movie'
post   '/movies'          => 'movies#create'
get    '/movies/:id'      => 'movies#show',    :as => 'movie'
get    '/movies/:id/edit' => 'movies#edit',    :as => 'edit_movie'
patch  '/movies/:id'      => 'movies#update'
delete '/movies/:id'      => 'movies#destroy'
```

---

## 3. Como o Controller Funciona e Recebe Parâmetros

O Controller atua como o intermediário. Ele recebe o comando da Rota, extrai os dados necessários, pede para a Model buscar as informações no banco e entrega tudo mastigado para a View (o HTML).

### 3.1 A Mágica do Objeto `params`
Antes de a requisição tocar no seu Controller, o Rails limpa a URL e empacota todas as variáveis em um dicionário chamado `params`. Ele coleta informações de duas origens diferentes:

#### Origem 1: Parâmetros de Rota Fixa (Marcados com `:`)
Se a rota contiver elementos dinâmicos, o Rails captura a posição exata do texto.
* Se a rota for: `get '/movies/:id1/new/:id2' => 'movies#new'`
* E o usuário acessar: `/movies/42/new/99`
* O `params` chegará preenchido antes do método rodar:
  * `params[:id1]` receberá o valor `"42"`
  * `params[:id2]` receberá o valor `"99"`

#### Origem 2: Parâmetros de Interrogação (Query Strings `?`)
O arquivo de rotas ignora tudo o que vem após o ponto de interrogação `?` na URL na hora de decidir para onde enviar o tráfego, mas o Rails **não descarta** esses dados; ele os insere no mesmo objeto `params`.
* Se o usuário acessar: `/movies/42/new?cupom=PROMO&origem=google`
* O `params` conterá tanto os dados da rota quanto os da interrogação:
  * `params[:id]` -> `"42"`
  * `params[:cupom]` -> `"PROMO"`
  * `params[:origem]` -> `"google"`

---

### 3.2 O Ciclo de Vida Invisível da Instanciação

Uma dúvida muito comum é: se usamos variáveis de instância (`@movie`) no controller, onde a classe do controller está sendo instanciada (onde ocorre o `.new`)?

Isso é controlado internamente pelo Rails. **Uma instância novinha da sua controladora é criada a cada novo clique do usuário e destruída logo em seguida.**

O fluxo completo acontece nesta ordem cronológica:

1. **O clique:** O usuário digita a URL `/movies/7/new` no navegador.
2. **O mapeamento:** O arquivo de rotas lê o padrão e diz: *"Quem resolve é a action `new` do controller `movies`"*.
3. **A Instanciação Oculta:** O Rails executa em seus bastidores o código:
   ```ruby
   instancia = MoviesController.new
   instancia.process(:new)
   ```
4. **O Isolamento:** O método `new` roda de forma isolada, garantindo que as requisições de outros usuários na internet não misturem os dados da memória.
5. **A Cópia para a View:** O Rails varre as variáveis de instância (todas as que começam com `@`) criadas no método e as copia para dentro da View (`new.html.erb`).
6. **A Morte da Instância:** O HTML final é renderizado e enviado ao navegador do usuário. A instância do `MoviesController` que foi criada para aquele clique é **destruída da memória**.

---

## 4. Métodos de Resposta: `redirect_to`, `render` e `head`

Toda Action de um controller precisa terminar fornecendo uma resposta para o navegador do usuário. O Rails possui três métodos integrados (*built-in*) fundamentais para controlar esse fluxo.



### 4.1 `redirect_to` (O Redirecionador)
O `redirect_to` diz ao navegador do usuário: *"Abandone a página atual imediatamente e vá para este outro endereço"*. O navegador limpa a tela, altera a URL visível na barra de endereços e faz uma **nova requisição HTTP do zero** para o servidor.

#### Exemplo usando Strings Literais ou Helpers de URL:
```ruby
def logout
  # Força o navegador a ir para a URL principal do site (/), gerando um novo ciclo
  redirect_to root_path
end

def ir_para_link_externo
  # Também aceita strings de caminhos absolutos
  redirect_to "[https://www.google.com](https://www.google.com)"
end
```

#### Como ele consegue receber um Objeto Ruby diretamente? (`redirect_to @movie`)
Quando você escreve `redirect_to @movie`, você está passando um pedaço de dados guardado na memória. O Rails consegue traduzir isso em uma URL através de regras de **Reflexão de Código (Roteamento Polimórfico)**. Ele faz o seguinte fluxo automático:

1. Pergunta ao objeto qual é a sua classe. Resposta: `Movie`.
2. Converte textualmente em minúsculo e adiciona o sufixo `_path`, descobrindo o helper: `movie_path`.
3. Olha dentro do objeto e extrai o valor guardado no atributo `id` (por exemplo, `7`).
4. Reescreve internamente o seu código executando: `redirect_to movie_path(7)`, o que gera a string URL final `"/movies/7"`.

---

### 4.2 `render` (O Desenhista)
O `render` **não altera a URL** no navegador e **não faz uma nova requisição**. Ele simplesmente atua como um desenhista: pega um arquivo de template HTML que já está no seu projeto, injeta nele as variáveis que você criou no controller e desenha a resposta na tela atual do usuário.

* **Principal utilidade:** Reexibir formulários quando o usuário erra alguma validação do banco (ex: deixa o título em branco), permitindo que os dados digitados permaneçam na tela para correção.

#### Exemplo concreto de uso combinado:
```ruby
def create
  @movie = Movie.new(params[:movie])
  
  if @movie.save
    # DEU CERTO: Redireciona o usuário usando o objeto. 
    # A URL muda para /movies/7 e uma página limpa de sucesso é carregada.
    redirect_to @movie
  else
    # FALHOU: O render desenha o formulário da tela 'new' imediatamente.
    # A URL continua sendo /movies, a tela NÃO limpa e o usuário não perde o que digitou.
    render :new
  end
end
```

---

### 4.3 `head` (O Silencioso)
O `head` **não renderiza nenhuma tela HTML** e **não redireciona**. Ele apenas responde ao navegador enviando um cabeçalho de status HTTP seco. É muito utilizado em APIs ou em ações internas disparadas por JavaScript/AJAX no seu site, onde o sistema só precisa saber se a ação deu certo ou errado.

#### Exemplo concreto de uso:
```ruby
def destruir_via_ajax
  @movie = Movie.find(params[:id])
  @movie.destroy
  
  # Responde apenas com o código HTTP 204 No Content.
  # Indica que o filme foi deletado e o navegador não precisa recarregar nem mudar de página.
  head :no_content
end
```

---

## 5. O Objeto `session` (Persistência de Dados)

O protocolo da Web (HTTP) é "desmemoriado" (*stateless*). Ele não sabe se o usuário que clicou na página de produtos é o mesmo que acabou de fazer login. 

O `session` é um dicionário (Hash) inteligente que o Rails oferece para **guardar dados que sobrevivem a múltiplos cliques e páginas**. O Rails criptografa esses dados e os armazena nos *cookies* do navegador do usuário de forma segura.

* **Principal caso de uso:** Sistema de Autenticação (Saber quem está logado).

### Exemplo Prático de Login e Uso da Session:

```ruby
class SessionsController < ApplicationController
  # Método que recebe o formulário de login
  def create
    user = User.find_by(email: params[:email])
    
    if user && user.authenticate(params[:password])
      # MÁGICA: Guardamos o ID do usuário na session do navegador.
      # Esse dado ficará guardado lá até o usuário fechar o navegador ou deslogar.
      session[:user_id] = user.id
      
      redirect_to root_path
    end
  end

  # Método de Logout
  def destroy
    # Apaga o dado da session, deslogando o usuário
    session[:user_id] = nil
    redirect_to root_path
  end
end
```

Agora, em **qualquer outro controller** do seu sistema (como o `MoviesController`), você pode checar se o usuário está logado lendo esse dicionário:

```ruby
class MoviesController < ApplicationController
  def edit
    # Se a session estiver vazia, impede o usuário de editar o filme
    if session[:user_id].nil?
      redirect_to login_path
    else
      @movie = Movie.find(params[:id])
    end
  end
end
```

---

## 6. O Objeto `flash` (Mensagens Temporárias)

O `flash` é um tipo especial de `session`, mas com um ciclo de vida estritamente curto: **os dados guardados nele duram apenas até a próxima requisição (o próximo clique) e depois se auto-destroem**.

* **Principal caso de uso:** Enviar mensagens de sucesso ou erro ("Filme criado com sucesso!", "Senha incorreta").

Como o `redirect_to` limpa a tela atual e faz uma requisição totalmente nova, as variáveis de instância normais (como `@mensagem`) morrem. O `flash` serve justamente para "levar" a mensagem de sucesso através do redirecionamento.

### Exemplo Prático de Fluxo com `flash`:

```ruby
class MoviesController < ApplicationController
  def create
    @movie = Movie.new(params[:movie])
    if @movie.save
      # Guardamos a mensagem no flash antes do redirecionamento
      flash[:notice] = "O filme foi cadastrado com sucesso!"
      redirect_to movie_path(@movie)
    else
      # Se usarmos 'render', não há um novo clique (nova requisição).
      # Para mensagens que devem aparecer no mesmo clique, usamos 'flash.now'
      flash.now[:alert] = "Não foi possível salvar o filme. Verifique os campos."
      render :new
    end
  end
end
```

### Como isso é exibido para o usuário na View?
Geralmente, os desenvolvedores colocam um código no arquivo de layout principal do site (`app/views/layouts/application.html.erb`) para capturar e exibir qualquer mensagem do `flash` automaticamente no topo da página:

```erb
<% if flash[:notice] %>
  <div class="alerta-sucesso"><%= flash[:notice] %></div>
<% end %>

<% if flash[:alert] %>
  <div class="alerta-erro"><%= flash[:alert] %></div>
<% end %>
```
*Quando o usuário clicar em qualquer outro link depois de ver essa mensagem, o `flash` se limpa sozinho, impedindo que a mensagem fique grudada na tela para sempre.*

---

## Resumo Comparativo dos 3 Dicionários do Controller

| Objeto | De onde vêm os dados? | Quanto tempo duram? | Para que serve? |
| :--- | :--- | :--- | :--- |
| **`params`** | Da URL (`:id` ou `?`) ou de formulários. | **Apenas na requisição atual**. | Identificar IDs e dados enviados pelo usuário. |
| **`flash`** | Definido manualmente no código do Controller. | **Até a próxima requisição** (some após o próximo clique). | Mostrar avisos de sucesso/erro após redirecionamentos. |
| **`session`** | Definido manualmente no código do Controller. | **Permanente** (Até fechar o navegador ou limpar o código). | Manter o usuário logado e lembrar suas preferências. |