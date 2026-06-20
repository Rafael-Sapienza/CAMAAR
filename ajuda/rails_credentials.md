# 🔐 Guia Definitivo: Rails Credentials com Editor NANO

Antes de tudo, se der esse erro:
  rafael@notebookRafael:~/EngSoft/CAMAAR_Rafael$ EDITOR="nano" rails credentials:edit
  Editing config/credentials.yml.enc...
  Couldn't decrypt config/credentials.yml.enc. Perhaps you passed the wrong key?
Significa que os arquivos **config/credentials.yml.enc** e **config/master.key** ficaram dessincronizados.
Rode esse comando:
  rm config/master.key config/credentials.yml.enc

O sistema de **Credentials** do Rails é o padrão moderno para gerenciar chaves de API, senhas e credenciais sensíveis sem expô-las no GitHub. 

Ele utiliza **criptografia simétrica** através de dois arquivos essenciais:
1. `config/credentials.yml.enc`: O "baú" criptografado onde ficam suas senhas. **Pode ir para o GitHub** (está seguro).
2. `config/master.key`: A chave mestra que tranca/destranca o baú. **NUNCA pode ir para o GitHub**.

---

## 🧭 Sobrevivência no Editor NANO (Comandos Básicos)

Como o ambiente WSL pode ter problemas para abrir editores gráficos como o VS Code, o `nano` é a ferramenta perfeita, pois roda 100% dentro do terminal.

Ao abrir o arquivo com o Nano, use estes comandos para se guiar:
* **Setas do teclado**: Movem o cursor para cima, baixo, esquerda e direita.
* **Digitação**: Funciona normalmente. Use `Backspace` ou `Delete` para apagar texto.
* **Salvar as alterações**: Pressione **`Ctrl + O`** e depois aperte **`Enter`** para confirmar o nome do arquivo.
* **Sair do editor**: Pressione **`Ctrl + X`** (se você alterou algo e não salvou, ele perguntará se deseja salvar: aperte `Y` para Sim ou `N` para Não, e depois `Enter`).

---

## 🛠️ Passo a Passo: Gerenciando as Credenciais

### 1. Abrindo o arquivo para edição
Para forçar o Rails a abrir o cofre usando o editor Nano dentro do terminal, use o seguinte comando:

```bash
EDITOR="nano" rails credentials:edit
```

### 2. Sintaxe interna do arquivo (Formato YAML)
O arquivo utiliza a sintaxe YAML, que depende estritamente de **espaçamentos (indentação)**. Não use a tecla `Tab`, use **2 espaços** para criar subníveis.

#### Exemplo concreto de preenchimento (Múltiplas chaves):
Ao abrir o arquivo, apague os exemplos padrões do Rails (se houver) e estruture suas chaves assim:

```yaml
brevo:
  api_key: "xkeysib-seu-token-longo-e-secreto-aqui"

stripe:
  public_key: "pk_test_123"
  secret_key: "sk_test_456"

production:
  database:
    password: "SenhaSuperSeguraDoBancoDeProducao"
```

*Para fechar e salvar no Nano:* Aperte `Ctrl + O`, depois `Enter`, e saia com `Ctrl + X`. O Rails re-criptografará o arquivo `.enc` automaticamente na saída.

---

## 💻 Como Chamar as Chaves no Código Ruby

Para acessar os valores salvos dentro dos seus Controllers, Models ou Concerns, utiliza-se o método `Rails.application.credentials.dig(...)`. 

Passe os blocos como símbolos (com `:` na frente), separando cada nível por vírgula:

### Exemplos práticos:

#### Caso 1: Buscando a API Key do Brevo
```ruby
# Substitua a string pura que estava no seu código por:
chave_brevo = Rails.application.credentials.dig(:brevo, :api_key)
```

#### Caso 2: Buscando uma chave em subnível mais profundo (ex: banco de produção)
```ruby
# Navegando por múltiplos níveis no YAML
senha_db = Rails.application.credentials.dig(:production, :database, :password)
```

> **💡 Dica de Ouro:** O método `.dig` é seguro. Se você errar o nome de alguma chave ou se ela não existir, ele retornará `nil` em vez de estourar um erro que derruba a aplicação.

---

## 🚨 Checklist de Segurança Crucial (Evite Vazamentos)

Antes de dar o `git push` para o GitHub, faça essa dupla checagem:

1. **Verifique o seu `.gitignore`:**
   Abra o arquivo `.gitignore` na raiz do seu projeto e certifique-se de que a linha abaixo está presente:
   ```text
   /config/master.key
   ```
2. **Confirme o status do Git:**
   Rode no terminal:
   ```bash
   git status
   ```
   O arquivo `config/credentials.yml.enc` **deve** aparecer na lista de arquivos modificados/adicionados. O arquivo `config/master.key` **NÃO PODE** aparecer de jeito nenhum.

---

## 🚀 Como funciona em Produção (Deploy no Render/Heroku)

Como o arquivo `config/master.key` não vai para o GitHub, quando você enviar o projeto para a nuvem (Render, Heroku, etc.), o servidor de produção não conseguirá abrir o cofre por padrão.

Para resolver isso sem enviar o arquivo físico:
1. Abra o arquivo `config/master.key` na sua máquina e copie o código alfanumérico que está dentro dele.
2. Vá no painel do seu provedor de hospedagem (Render/Heroku), na seção **Environment Variables** (Variáveis de ambiente) do seu aplicativo.
3. Adicione uma variável com o nome exato de **`RAILS_MASTER_KEY`** e cole o código que você copiou como valor.

O Rails detectará essa variável automaticamente na nuvem e usará o valor dela para descriptografar as credenciais em tempo de execução!