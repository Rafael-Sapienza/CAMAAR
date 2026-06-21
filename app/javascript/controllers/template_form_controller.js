import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questions", "questionTemplate", "optionTemplate"]

  connect() {
    this.renumberAll()
  }

  addQuestion(event) {
    event.preventDefault()

    const questionIndex = this.uniqueIndex()
    const fragment = this.htmlToFragment(
      this.questionTemplateTarget.innerHTML.replaceAll(
        "NEW_QUESTION",
        questionIndex,
      ),
    )
    const question = fragment.querySelector("[data-template-form-question]")

    question.dataset.templateFormQuestionIndex = questionIndex
    this.questionsTarget.append(fragment)
    this.renumberAll()
  }

  addOption(event) {
    event.preventDefault()

    const question = event.target.closest("[data-template-form-question]")
    if (!question) return

    const optionIndex = this.uniqueIndex()
    const questionIndex = question.dataset.templateFormQuestionIndex
    const fragment = this.htmlToFragment(
      this.optionTemplateTarget.innerHTML
        .replaceAll("NEW_QUESTION", questionIndex)
        .replaceAll("NEW_OPTION", optionIndex),
    )
    const option = fragment.querySelector("[data-template-form-option]")

    question.querySelector("[data-template-form-options]").append(fragment)
    this.renumberOptions(question)
  }

  moveQuestionUp(event) {
    event.preventDefault()

    const question = event.target.closest("[data-template-form-question]")
    if (!question) return

    this.moveElementUp(question)
    this.renumberAll()
  }

  moveQuestionDown(event) {
    event.preventDefault()

    const question = event.target.closest("[data-template-form-question]")
    if (!question) return

    this.moveElementDown(question)
    this.renumberAll()
  }

  moveOptionUp(event) {
    event.preventDefault()

    const option = event.target.closest("[data-template-form-option]")
    const question = event.target.closest("[data-template-form-question]")
    if (!option || !question) return

    this.moveElementUp(option)
    this.renumberOptions(question)
  }

  moveOptionDown(event) {
    event.preventDefault()

    const option = event.target.closest("[data-template-form-option]")
    const question = event.target.closest("[data-template-form-question]")
    if (!option || !question) return

    this.moveElementDown(option)
    this.renumberOptions(question)
  }

  destroyQuestion(event) {
    event.preventDefault()

    const question = event.target.closest("[data-template-form-question]")
    if (!question) return

    const idField = question.querySelector("[data-template-form-utilizacao-id]")
    const destroyField = question.querySelector("[data-template-form-question-destroy]")

    if (!idField?.value) {
      question.remove()
      this.renumberAll()
      return
    }

    this.submitDestroy([
      [idField.name, idField.value],
      [destroyField.name, "1"],
    ])
  }

  destroyOption(event) {
    event.preventDefault()

    const option = event.target.closest("[data-template-form-option]")
    const question = event.target.closest("[data-template-form-question]")
    if (!option || !question) return

    const utilizationIdField = question.querySelector(
      "[data-template-form-utilizacao-id]",
    )
    const questionIdField = question.querySelector("[data-template-form-questao-id]")
    const optionIdField = option.querySelector("[data-template-form-opcao-id]")
    const destroyField = option.querySelector("[data-template-form-option-destroy]")

    if (!optionIdField?.value) {
      option.remove()
      this.renumberOptions(question)
      return
    }

    this.submitDestroy([
      [utilizationIdField.name, utilizationIdField.value],
      [questionIdField.name, questionIdField.value],
      [optionIdField.name, optionIdField.value],
      [destroyField.name, "1"],
    ])
  }

  uniqueIndex() {
    if (!this.index) this.index = Date.now()

    this.index += 1
    return this.index.toString()
  }

  htmlToFragment(html) {
    const template = document.createElement("template")
    template.innerHTML = html.trim()

    return template.content
  }

  moveElementUp(element) {
    const previous = element.previousElementSibling
    if (!previous) return

    previous.before(element)
  }

  moveElementDown(element) {
    const next = element.nextElementSibling
    if (!next) return

    next.after(element)
  }

  renumberAll() {
    this.questionElements.forEach((question, index) => {
      const number = index + 1

      question.querySelector("[data-template-form-question-number]").value = number
      question.querySelector("[data-template-form-question-position]").textContent =
        number
      this.renumberOptions(question)
    })
  }

  renumberOptions(question) {
    this.optionElements(question).forEach((option, index) => {
      const number = index + 1

      option.querySelector("[data-template-form-option-number]").value = number
      option.querySelector("[data-template-form-option-position]").textContent =
        this.optionLetter(number)
    })
  }

  optionLetter(number) {
    let result = ""
    let current = number

    while (current > 0) {
      current -= 1
      result = String.fromCharCode(97 + (current % 26)) + result
      current = Math.floor(current / 26)
    }

    return result
  }

  get questionElements() {
    return [...this.questionsTarget.children].filter((element) =>
      element.matches("[data-template-form-question]"),
    )
  }

  optionElements(question) {
    const options = question.querySelector("[data-template-form-options]")
    if (!options) return []

    return [...options.children].filter((element) =>
      element.matches("[data-template-form-option]"),
    )
  }

  submitDestroy(fields) {
    const form = document.createElement("form")
    form.hidden = true
    form.method = "post"
    form.action = this.element.action

    this.appendMethodOverride(form)
    this.appendAuthenticityToken(form)
    fields.forEach(([name, value]) => this.appendHiddenField(form, name, value))

    document.body.append(form)
    form.requestSubmit()
  }

  appendMethodOverride(form) {
    const methodOverride = this.element.querySelector("input[name='_method']")
    if (!methodOverride) return

    this.appendHiddenField(form, methodOverride.name, methodOverride.value)
  }

  appendAuthenticityToken(form) {
    const token =
      this.element.querySelector("input[name='authenticity_token']")?.value ||
      document.querySelector("meta[name='csrf-token']")?.content
    if (!token) return

    this.appendHiddenField(form, "authenticity_token", token)
  }

  appendHiddenField(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value

    form.append(input)
  }
}
