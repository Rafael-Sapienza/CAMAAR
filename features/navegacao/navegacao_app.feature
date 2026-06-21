# language: pt
Funcionalidade: Navegar pelas áreas conectadas do CAMAAR
  Como usuário autenticado
  Quero usar o menu e a pesquisa globais
  Para acessar as funcionalidades disponíveis ao meu perfil

  Contexto:
    Dado que existe um usuário administrador cadastrado no sistema
    E que estou autenticado como administrador

  @happy
  Cenário: Administrador navega entre as áreas pelo menu lateral
    Dado que estou na página inicial do CAMAAR
    Então devo ver o menu lateral e a pesquisa global
    Quando acesso a área de templates pelo menu lateral
    Então devo estar na página de templates
    Quando acesso a área de formulários pelo menu lateral
    Então devo estar na página de formulários
    Quando acesso o gerenciamento pelo menu lateral
    Então devo estar na página de gerenciamento

  @happy
  Cenário: Administrador pesquisa conteúdo do aplicativo
    Dado que existem um template e um formulário pesquisáveis chamados "Avaliação Integrada"
    E que estou na página inicial do CAMAAR
    Quando pesquiso por "integrada"
    Então devo ver o template e o formulário "Avaliação Integrada" nos resultados

  @happy
  Cenário: Participante visualiza somente as áreas disponíveis ao seu perfil
    Dado que existe um usuário participante cadastrado no sistema
    E que estou autenticado como participante
    E que estou na página inicial do CAMAAR
    Então devo ver as áreas gerais no menu lateral
    E não devo ver as áreas administrativas no menu lateral

  @sad
  Cenário: Pesquisar sem informar um termo
    Dado que estou na página inicial do CAMAAR
    Quando envio a pesquisa sem informar um termo
    Então devo ver uma orientação para informar o que desejo encontrar

  @sad
  Cenário: Pesquisa não exibe formulário de outro departamento
    Dado que existe um formulário pesquisável chamado "Avaliação Confidencial" em outro departamento
    E que estou na página inicial do CAMAAR
    Quando pesquiso por "confidencial"
    Então não devo ver o formulário de outro departamento nos resultados
