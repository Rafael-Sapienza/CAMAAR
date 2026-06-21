# language: pt
Funcionalidade: Enviar convites de definição de senha
  Como Administrador
  Quero enviar convites aos usuários pendentes do meu departamento
  A fim de permitir que eles ativem suas contas

  Contexto:
    Dado que eu estou logado como Administrador
    E estou na página "Gerenciamento"

  @happy
  Cenário: Enviar convite para participante pendente
    Dado que existe um participante pendente com e-mail no departamento do administrador
    Quando eu clico no botão "Enviar solicitações de cadastro"
    Então deve ser criado um token de cadastro para o participante
    E eu devo ver uma mensagem informando que 1 convite foi enviado

  @sad
  Cenário: Falha ao enviar convite não mantém token inválido
    Dado que existe um participante pendente com e-mail no departamento do administrador
    E que o serviço de envio de convites está indisponível
    Quando eu clico no botão "Enviar solicitações de cadastro"
    Então nenhum token de cadastro deve permanecer para o participante
    E eu devo ver uma mensagem informando instabilidade no envio
