# language: pt
Funcionalidade: Responder questionário da turma
  Como Participante de uma turma
  Quero responder o questionário sobre a turma em que estou matriculado
  A fim de submeter minha avaliação da turma

  Contexto:
    Dado que existe um usuário participante cadastrado no sistema

  @happy
  Cenário: Participante responde todas as questões obrigatórias com sucesso
    Dado que estou autenticado como participante
    E que estou na página de resposta do formulário da turma "Cálculo 1"
    Quando eu preencho todas as questões obrigatórias
    E confirmo o envio da avaliação
    Então devo ver uma mensagem informando que a avaliação foi registrada com sucesso
    E as respostas devem ficar salvas na avaliação
    E o formulário da turma "Cálculo 1" não deve mais aparecer na lista de pendentes

  @sad
  Cenário: Participante tenta enviar avaliação sem responder questão objetiva
    Dado que estou autenticado como participante
    E que estou na página de resposta do formulário da turma "Cálculo 1"
    Quando eu deixo a questão objetiva em branco
    E confirmo o envio da avaliação
    Então devo ver uma mensagem informando que todas as questões obrigatórias devem ser preenchidas
    E a avaliação não deve ser registrada

  @sad
  Cenário: Participante tenta enviar avaliação sem responder questão discursiva
    Dado que estou autenticado como participante
    E que estou na página de resposta do formulário da turma "Cálculo 1"
    Quando eu deixo a questão discursiva em branco
    E confirmo o envio da avaliação
    Então devo ver uma mensagem informando que todas as questões obrigatórias devem ser preenchidas
    E a avaliação não deve ser registrada

  @sad
  Cenário: Participante tenta responder formulário já respondido
    Dado que estou autenticado como participante
    E que já respondi o formulário da turma "Cálculo 1" anteriormente
    Quando eu tento acessar a página de resposta do formulário da turma "Cálculo 1"
    Então devo ver uma mensagem informando que esta avaliação já foi respondida

  @sad
  Cenário: Participante tenta reenviar formulário já respondido pela requisição
    Dado que estou autenticado como participante
    E que já respondi o formulário da turma "Cálculo 1" anteriormente
    Quando tento reenviar respostas para esse formulário
    Então devo ver uma mensagem informando que esta avaliação já foi respondida
    E nenhuma resposta adicional deve ser criada

  @sad
  Cenário: Participante tenta acessar avaliação de outro participante pela URL
    Dado que estou autenticado como participante
    E que existe uma avaliação pendente pertencente a outro participante
    Quando tento acessar essa avaliação pela URL
    Então devo ver uma mensagem informando que a avaliação não foi encontrada

  @sad
  Cenário: Participante tenta enviar opção pertencente a outra questão
    Dado que estou autenticado como participante
    E que estou na página de resposta do formulário da turma "Cálculo 1"
    Quando envio uma opção pertencente a outra questão
    Então devo ver uma mensagem informando que todas as questões obrigatórias devem ser preenchidas
    E a avaliação não deve ser registrada

  @sad
  Cenário: Participante tenta enviar opção inexistente para questão objetiva
    Dado que estou autenticado como participante
    E que estou na página de resposta do formulário da turma "Cálculo 1"
    Quando envio uma opção inexistente para a questão objetiva
    Então devo ver uma mensagem informando que todas as questões obrigatórias devem ser preenchidas
    E a avaliação não deve ser registrada

  @happy
  Cenário: Participante responde formulário após exclusão do template de origem
    Dado que estou autenticado como participante
    E que estou na página de resposta do formulário da turma "Cálculo 1"
    E que o template de origem do formulário foi excluído
    Quando eu tento acessar a página de resposta do formulário da turma "Cálculo 1"
    Então devo continuar vendo as questões copiadas para o formulário
