# Manual Definitivo de Rotas e Controllers no Ruby on Rails

Este guia prático foi desenhado para explicar profundamente o funcionamento do roteamento e das controladoras no ecossistema Rails, detalhando a comunicação entre a URL, o objeto `params`, a instanciação de classes e a renderização das Views.

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
A forma mais explícita e poderosa de mapear uma rota na mão segue o padrão:

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

## 4. Exemplo Concreto de Integração Completa

Aqui está o código real de como a Rota e o Controller trabalham de forma casada.

### O Arquivo de Rotas:
```ruby
# config/routes.rb
Rails.application.routes.draw do
  get '/movies/:id/new' => 'movies#new', :as => 'new_movie'
end
```

### O Arquivo do Controller:
```ruby
# app/controllers/movies_controller.rb
class MoviesController < ApplicationController

  # Este é o método acionado pelo 'movies#new' da rota
  def new
    # 1. Capturando o ID que veio mapeado nos dois pontos (:id) da rota
    id_do_filme = params[:id] # Se acessou /movies/7/new, recebe "7"
    
    # 2. Capturando um parâmetro opcional que veio após a interrogação (?)
    termo_busca = params[:busca] # Se acessou ?busca=avatar, recebe "avatar"

    # 3. Solicitando que a Model busque o registro correspondente no banco de dados
    # Usamos o '@' para transformar em variável de instância e permitir que a View a leia
    @movie = Movie.find(id_do_filme)
    @termo_pesquisado = termo_busca

    # 4. Renderização Automática:
    # O Rails encerra o método e renderiza o arquivo: app/views/movies/new.html.erb
  end

end
```