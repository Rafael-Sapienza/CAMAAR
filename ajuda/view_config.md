# Manual Definitivo de Views e Front-End no Ruby on Rails

Este guia explica o funcionamento da camada de visualização (View) no ecossistema Rails, detalhando o ciclo de vida da renderização, a conexão estrita entre Views e Controllers, a unificação de estilos via Asset Pipeline, a diferença sintática entre ERB e HAML, e as exceções de renderização de layouts.

---

## 1. A Estrutura de Pastas e a Arquitetura do Layout

O Rails possui convenções rígidas para organizar o código visual. Ele separa o esqueleto estrutural (Layouts) e os conteúdos específicos (Views) dos arquivos de estilização estáticos (Assets).

### Estrutura de Pastas Obrigatória:
```text
seu_projeto/
├── app/
│   ├── views/            # OBRIGATÓRIO: Onde ficam as telas do seu site.
│   │   ├── layouts/
│   │   │   └── application.html.erb # A "casca" ou moldura global do site.
│   │   └── movies/       # Pasta correspondente à controladora (MoviesController)
│   │       ├── index.html.erb  # Miolo da página de listagem de filmes.
│   │       └── new.html.erb    # Miolo da página de formulário de cadastro.
│   │
│   └── assets/           # OBRIGATÓRIO: Onde ficam os arquivos estáticos de design.
│       ├── stylesheets/
│       │   └── application.css # Arquivo manifesto global do CSS.
│       └── images/       # Diretório para imagens, logotipos e ícones.
```

### 1.1 O Mecanismo de Montagem com `<%= yield %>`
As views específicas (como `index.html.erb`) não são documentos HTML completos. Elas não possuem as tags `<html>`, `<head>` ou `<body>`, contendo apenas o miolo do conteúdo. 

O arquivo enviado ao navegador é sempre o `app/views/layouts/application.html.erb`. Quando uma página é solicitada, o Rails remove a tag `<%= yield %>` desse layout e injeta o HTML da view atual exatamente naquele lugar.



---

## 2. Como o Rails conecta uma View a uma Controladora específica?

Diferente de outros frameworks onde você precisa importar ou declarar manualmente qual arquivo HTML pertence a qual arquivo de código, o Rails faz essa conexão de forma 100% automática baseando-se em **Convenção sobre Configuração** (Convention over Configuration).

A conexão ocorre através de duas regras estritas de **Nomes de Pastas** e **Nomes de Arquivos**:

1. **O Nome da Pasta:** Dentro de `app/views/`, o Rails procura por uma pasta que tenha **exatamente o mesmo nome** do seu controller (sem a palavra `_controller`).
   * Se o seu controller se chama `MoviesController`, a pasta de suas views obrigatoriamente deve ser `app/views/movies/`.
2. **O Nome do Arquivo:** Dentro dessa pasta, o Rails procura por um arquivo que tenha **exatamente o mesmo nome do método (Action)** que foi executado.
   * Se a rota chamou o método `def index` dentro do `MoviesController`, o Rails irá procurar pelo arquivo `index.html.erb` dentro da pasta `app/views/movies/`.

### Exemplo do Fluxo Automático:
Quando o método termina de rodar e não encontra nenhum comando de interrupção (como um `redirect_to`), o Rails faz a busca invisível:

```text
MoviesController#show ───> Procura por: app/views/movies/show.html.erb
MoviesController#new  ───> Procura por: app/views/movies/new.html.erb
```
Se você errar uma única letra no nome da pasta ou do arquivo, o Rails se perderá e exibirá um erro de tela azul (`Template is missing`).

---

## 3. O Funcionamento do CSS: O Asset Pipeline

No Rails, você não conecta manualmente um arquivo CSS a uma View específica utilizando tags `<link rel="stylesheet">` em cada página. O framework gerencia isso globalmente através do **Asset Pipeline**.

### 3.1 Como a Unificação Acontece por Baixo dos Panos
1. Você pode criar múltiplos arquivos CSS para organizar seu código dentro da pasta `app/assets/stylesheets/` (ex: `movies.css`, `login.css`, `buttons.css`).
2. O arquivo principal `application.css` funciona como um "manifesto". Ele contém comentários especiais chamados diretivas:
   ```css
   /* app/assets/stylesheets/application.css */
   /*
    *= require_tree .
    *= require_self
    */
   ```
   A linha `*= require_tree .` diz ao Rails: *"Vasculhe esta pasta por inteiro, sugue o código de todos os arquivos .css que encontrar e junte-os comigo em um único bloco de texto"*.
3. No arquivo de layout (`application.html.erb`), no cabeçalho `<head>`, existe a tag:
   ```erb
   <%= stylesheet_link_tag "application" %>
   ```
4. O Rails transforma essa linha em uma tag HTML tradicional apontando para o blocão unificado:
   ```html
   <link rel="stylesheet" href="/assets/application.css" />
   ```

**Conclusão Prática:** Como o navegador baixa todo o CSS do site de uma vez só no cabeçalho do layout, **todas as suas Views herdam e têm acesso a todos os estilos automaticamente**. Você só precisa declarar as classes correspondentes no seu HTML (ex: `<div class="card-filme">`), independentemente de em qual arquivo `.css` você escreveu aquela regra original.

---

## 4. Customizando a Casca: Pulando o Layout Padrão (`layout false`)

Imagine que você está criando uma tela de **Login** ou uma página de **Manutenção** e quer que ela seja completamente limpa, sem a barra de navegação global, sem o rodapé do site e sem carregar os estilos gerais que estão na estrutura do layout padrão.

Você pode avisar a sua controladora para **ignorar a casca padrão** usando a palavra-chave `layout`:

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  
  # Diz ao Rails para NÃO usar o arquivo 'application.html.erb' para NENHUMA action deste controller
  layout false

  def new
    # Quando o Rails chegar aqui, ele vai quebrar o comportamento padrão.
    # Ele vai renderizar APENAS o HTML seco que estiver escrito dentro do arquivo:
    # app/views/sessions/new.html.erb, sem injetá-lo em lugar nenhum!
  end
end
```
> 💡 **Dica Avançada:** Se você quiser desativar o layout apenas para uma tela específica (em vez de desligar para o controller inteiro), você pode declarar isso direto na action usando o método `render`:
> ```ruby
> def tela_limpa
>   render layout: false
> end
> ```

---

## 5. Formatos de View: ERB vs HAML

O Rails aceita diferentes processadores de texto para injetar lógica Ruby no HTML.

### 5.1 ERB (Embedded Ruby)
O ERB se assemelha diretamente ao HTML tradicional. Qualquer HTML válido é um ERB válido. Ele adiciona apenas duas tags fundamentais para comunicação com as variáveis vindas da controladora:

* **Tag de Execução Invisível (`<% %>`):** Executa lógica Ruby (condicionais, loops), mas não renderiza texto diretamente na tela.
  ```erb
  <% if @movie.year > 2020 %>
    <span class="badge">Lançamento Recente</span>
  <% end %>
  ```
* **Tag de Impressão Visível (`<%= %>`):** Executa o código Ruby e imprime/desenha o resultado textual diretamente no HTML final.
  ```erb
  <h1>Título: <%= @movie.title %></h1>
  ```

### 5.2 HAML (HTML Abstraction Markup Language)
O HAML é uma alternativa direta ao ERB. Ele remove totalmente os sinais de menor e maior (`< >`) e as tags de fechamento (como `</div>`). Ele utiliza **indentação obrigatória** (espaçamentos) e símbolos curtos para inferir a estrutura do HTML.

#### Comparação de Sintaxe Concreta:

* **No formato ERB (`show.html.erb`):**
  ```erb
  <div class="card-filme">
    <h1><%= @movie.title %></h1>
    <p><%= @movie.description %></p>
  </div>
  ```

* **No formato HAML (`show.html.haml`):**
  ```haml
  .card-filme
    %h1= @movie.title
    %p= @movie.description
  ```

---

## 6. Como a View dispara cada Requisição HTTP (REST)

Nativamente, os navegadores web só conseguem processar dois verbos HTTP via HTML puro: `GET` (links e digitação de URLs) e `POST` (envio de formulários tradicionais). Para operar com a arquitetura RESTful (`PATCH` e `DELETE`), o Rails injeta automações na View.

### 6.1 Requisição GET (Leitura e Exibição)
Disparada por links de navegação comuns através do helper `link_to`.
```erb
<%= link_to "Ver Detalhes", movie_path(id: 7), method: :get %>
```

### 6.2 Requisição POST (Envio de Novos Dados)
Utilizada para submeter formulários com dados inéditos para a Action `create`.
```erb
<%= form_with model: @movie, url: movies_path, method: :post do |form| %>
  <%= form.text_field :title %>
  <%= form.submit "Salvar Filme" %>
<% end %>
```

### 6.3 Requisição PATCH / PUT (Atualização de Dados Existentes)
Utilizada para editar um registro que já existe no banco de dados.
```erb
<%= form_with model: @movie, url: movie_path(@movie), method: :patch do |form| %>
  <%= form.text_field :title %>
  <%= form.submit "Atualizar Informações" %>
<% end %>
```

### 6.4 Requisição DELETE (Exclusão)
Para deletar registros, o Rails modernos (versão 7+) utiliza o framework JavaScript **Turbo**, gerando a requisição destrutiva em segundo plano a partir de um link.
```erb
<%= link_to "Excluir Filme", movie_path(@movie), data: { turbo_method: :delete, turbo_confirm: "Tem certeza?" } %>
```

---

## Resumo Operacional da Camada de View

| Ação na Interface | Helper Rails Utilizado | Verbo HTTP Gerado | Action Alvo no Controller |
| :--- | :--- | :--- | :--- |
| **Clicar para ir a uma página** | `link_to "Texto", rota_path` | `GET` | `def index` ou `def show` |
| **Submeter novo cadastro** | `form_with model: @objeto, method: :post` | `POST` | `def create` |
| **Submeter edição de dados** | `form_with model: @objeto, method: :patch` | `PATCH` | `def update` |
| **Clicar no botão de remover** | `link_to "Deletar", rota_path, data: { turbo_method: :delete }` | `DELETE` | `def destroy` |