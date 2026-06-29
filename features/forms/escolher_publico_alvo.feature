# language: pt
Funcionalidade: Escolher público-alvo do formulário
  Como Administrador
  Quero escolher criar um formulário para os docentes ou os discentes de uma turma
  A fim de avaliar o desempenho de uma matéria

  Contexto:
    Dado que estou autenticado como administrador
    E que selecionei o template "Avaliação Geral de Disciplina"
    E selecionei a turma "Estrutura de Dados - Turma C"

  @happy
  Cenário: Criar formulário direcionado estritamente para os discentes (alunos)
    Dado que estou na página de criação de formulários
    Quando eu seleciono o template "Avaliação Geral de Disciplina"
    E seleciono a turma "Estrutura de Dados - Turma C"
    E eu seleciono a opção de público-alvo como "Discentes"
    E clico em "Publicar formulário"
    Então o formulário deve ficar disponível apenas para os alunos matriculados na turma "Estrutura de Dados - Turma C"
    E os docentes da turma não devem ter acesso para responder a este formulário

  @happy
  Cenário: Criar formulário direcionado estritamente para os docentes (professores)
    Dado que estou na página de criação de formulários
    Quando eu seleciono o template "Avaliação Geral de Disciplina"
    E seleciono a turma "Estrutura de Dados - Turma C"
    E eu seleciono a opção de público-alvo como "Docentes"
    E clico em "Publicar formulário"
    Então o formulário deve ficar disponível apenas para os professores vinculados à turma "Estrutura de Dados - Turma C"

  @happy
  Cenário: Criar formulários distintos para docentes e discentes na mesma turma
    Dado que estou na página de criação de formulários
    Quando eu seleciono o template "Avaliação Geral de Disciplina"
    E seleciono a turma "Estrutura de Dados - Turma C"
    E eu seleciono a opção de público-alvo como "Docentes"
    E clico em "Publicar formulário"
    E volto para a página de criação de formulários
    Quando eu seleciono o template "Avaliação Geral de Disciplina"
    E seleciono a turma "Estrutura de Dados - Turma C"
    E eu seleciono a opção de público-alvo como "Discentes"
    E clico em "Publicar formulário"
    Então devem existir formulários para "Docentes" e "Discentes" na turma "Estrutura de Dados - Turma C"

  @sad
  Cenário: Tentar avançar sem definir o público-alvo do formulário
    Dado que estou na página de criação de formulários
    Quando eu seleciono o template "Avaliação Geral de Disciplina"
    E seleciono a turma "Estrutura de Dados - Turma C"
    E eu não seleciono nem "Docentes" e nem "Discentes"
    E clico em "Publicar formulário"
    Então eu devo ver o alerta "Por favor, selecione o público-alvo do formulário"
    E o formulário não deve ser publicado
