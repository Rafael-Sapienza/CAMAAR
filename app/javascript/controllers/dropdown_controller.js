import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.open = false
  }

  toggle() {
    this.open = !this.open
    this.element.classList.toggle("is-open", this.open)
  }

  close() {
    this.open = false
    this.element.classList.remove("is-open")
  }
}