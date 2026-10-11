// A CMS form posts to the Forms plugin without leaving the page: its
// thank-you in place of the button, or each field's error beside it.
const FALLBACK = "We couldn't reach the server. Check your connection and try again, or give us a call."
const MESSAGES = {
  captcha_failed: "The spam check didn't go through. Please wait a moment and send it again.",
  rate_limited: "That's a lot of tries in a short time. Please wait a few minutes and send it again.",
  not_found: "This form isn't taking answers right now. Please call us instead.",
}

function showErrors(form, errors) {
  for (const [name, messages] of Object.entries(errors)) {
    const el = form.querySelector(`[data-error-for="${CSS.escape(name)}"]`)
    if (!el) continue
    // The CMS says "is required"; the field's label makes it a sentence.
    el.textContent = [].concat(messages).map((message) => `${el.dataset.label ?? name} ${message}.`).join(" ")
    el.hidden = false
  }
}

async function submit(event) {
  const form = event.currentTarget
  event.preventDefault()
  if (!form.checkValidity()) return form.reportValidity()

  const status = form.querySelector("[data-form-status]")
  const button = form.querySelector('button[type="submit"]')
  const data = new FormData(form)
  const say = (text, ok) => {
    status.textContent = text
    status.classList.toggle("is-error", !ok)
    status.hidden = false
  }
  const done = () => {
    form.reset()
    say(form.dataset.success, true)
    button.remove()
  }
  form.querySelectorAll("[data-error-for]").forEach((el) => { el.hidden = true; el.textContent = "" })

  // A bot filled the hidden field: pretend it worked. (One that skips this script still posts it, and the CMS drops it.)
  if (String(data.get(form.dataset.honeypot) ?? "").trim()) return done()

  button.disabled = true
  say("Sending…", true)
  try {
    const response = await fetch(form.action, { method: "POST", body: data, headers: { Accept: "application/json" } })
    const body = await response.json().catch(() => ({}))
    if (response.ok) return done()
    showErrors(form, body.errors ?? {})
    say(MESSAGES[body.error] ?? (body.errors ? "Please check the highlighted fields." : FALLBACK), false)
  } catch {
    say(FALLBACK, false)
  } finally {
    if (button.isConnected) button.disabled = false
    // A Turnstile token is good once: the next try needs a fresh one.
    const widget = form.querySelector(".cf-turnstile")
    if (widget) window.turnstile?.reset(widget)
  }
}

document.querySelectorAll("form[data-form]").forEach((form) => form.addEventListener("submit", submit))
