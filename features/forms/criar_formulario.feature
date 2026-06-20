# language: pt
Funcionalidade: Criar formulário a partir de template
  Como Administrador
  Quero criar um formulário baseado em um template para as turmas que eu escolher
  A fim de avaliar o desempenho das turmas no semestre atual

  Contexto:
    Dado que estou autenticado como administrador
    E que existe um template cadastrado chamado "Avaliação de Desempenho Docente"
    E que existem as turmas "Métodos de Desenvolvimento de Software - Turma A" e "Interação Humano Computador - Turma B" cadastradas no semestre atual

  @happy
  Cenário: Criar formulário para múltiplas turmas com sucesso
    Dado que estou na página de criação de formulários
    Quando eu seleciono o template "Avaliação de Desempenho Docente"
    E seleciono as turmas "Métodos de Desenvolvimento de Software - Turma A" e "Interação Humano Computador - Turma B"
    E clico em "Continuar"
    E seleciono a opção de público-alvo como "Docentes"
    E confirmo a publicação do formulário
    Então o formulário deve ser gerado com sucesso para ambas as turmas
    E devo ver a mensagem "Formulário criado com sucesso para as turmas selecionadas"

  @happy
  Cenário: Iniciar criação de formulário pela visualização do template
    Dado que estou visualizando o template cadastrado chamado "Avaliação de Desempenho Docente"
    Quando solicito criar um formulário a partir desse template
    Então devo estar na página de criação de formulários com o template "Avaliação de Desempenho Docente" selecionado
    Quando seleciono as turmas "Métodos de Desenvolvimento de Software - Turma A" e "Interação Humano Computador - Turma B"
    E clico em "Continuar"
    E seleciono a opção de público-alvo como "Docentes"
    E confirmo a publicação do formulário
    Então o formulário deve ser gerado com sucesso para ambas as turmas
    E devo ver a mensagem "Formulário criado com sucesso para as turmas selecionadas"

  @sad
  Cenário: Tentar criar formulário sem selecionar nenhuma turma
    Dado que estou na página de criação de formulários
    Quando eu seleciono o template "Avaliação de Desempenho Docente"
    E não seleciono nenhuma turma
    E seleciono a opção de público-alvo como "Docentes"
    E clico em "Publicar formulário"
    Então eu devo ver uma mensagem de erro dizendo "É necessário selecionar pelo menos uma turma"
    E nenhum formulário deve ser gerado

  @sad
  Cenário: Tentar publicar formulário sem concluir a preparação
    Quando tento confirmar a publicação sem selecionar template e turmas
    Então eu devo ver uma mensagem de erro dizendo "Selecione um template e as turmas antes de publicar"
    E nenhum formulário deve ser gerado
