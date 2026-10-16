// Every form the theme draws (website/shared/_form): posted to the Forms
// plugin without leaving the page, its answer shown in place. The spam check
// Settings › Forms has set up (Turnstile or reCAPTCHA) loads when a form comes
// into view; the visit's attribution (UTM tags, click ids, the landing page)
// goes into the fields a form keeps for it. A form that sent dispatches
// "oldmill:submitted" and pushes "form_submit" to a dataLayer if there is one.
const ATTRIBUTION_KEY = "oldmill_attribution"
const PARAMS = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "gclid", "fbclid", "msclkid"]
const MESSAGES = {
  captcha_failed: "We couldn't check you're not a robot. Please try again.",
  rate_limited: "That's a lot of tries in a short time. Please wait a few minutes and send it again.",
  not_found: "This form isn't taking answers right now.",
  network: "That didn't send: check your connection and try again."
}

// The visit's first touch, kept for the session.
const attribution = (() => {
  try {
    const kept = JSON.parse(sessionStorage.getItem(ATTRIBUTION_KEY) || "null")
    if (kept) return kept
    const query = new URLSearchParams(location.search)
    const found = { landing_path: location.pathname, referrer: document.referrer }
    PARAMS.forEach((name) => { if (query.get(name)) found[name] = query.get(name) })
    sessionStorage.setItem(ATTRIBUTION_KEY, JSON.stringify(found))
    return found
  } catch { return {} }
})()

const scripts = {}
const load = (src) => (scripts[src] ??= new Promise((resolve, reject) => {
  const script = Object.assign(document.createElement("script"), { src, async: true, onload: resolve, onerror: reject })
  document.head.append(script)
}))

const PROVIDERS = {
  turnstile: {
    src: "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit",
    ready: () => window.turnstile,
    render: (el, options) => window.turnstile.render(el, options),
    reset: (id) => window.turnstile?.reset(id)
  },
  recaptcha: {
    src: "https://www.google.com/recaptcha/api.js?render=explicit",
    ready: () => window.grecaptcha?.render,
    render: (el, options) => window.grecaptcha.render(el, options),
    reset: (id) => window.grecaptcha?.reset(id)
  }
}

const widgets = new WeakMap()
const mountCaptcha = async (form) => {
  const el = form.querySelector("[data-captcha]")
  const provider = PROVIDERS[el?.dataset.captcha]
  if (!provider || widgets.has(form)) return
  widgets.set(form, null)
  await load(provider.src)
  while (!provider.ready()) await new Promise((resolve) => setTimeout(resolve, 50))
  const theme = el.dataset.theme === "auto" ? undefined : el.dataset.theme
  widgets.set(form, provider.render(el, { sitekey: el.dataset.sitekey, theme }))
}
const resetCaptcha = (form) => {
  const provider = PROVIDERS[form.querySelector("[data-captcha]")?.dataset.captcha]
  const id = widgets.get(form)
  if (provider && id != null) provider.reset(id)
}

const say = (form, text, kind) => {
  const status = form.querySelector(".form__status")
  if (!status) return
  status.textContent = text
  status.dataset.kind = kind
  status.hidden = !text
}

const showErrors = (form, errors) => {
  form.querySelectorAll(".form__error").forEach((el) => el.remove())
  form.querySelectorAll("[aria-invalid]").forEach((el) => el.removeAttribute("aria-invalid"))
  Object.entries(errors || {}).forEach(([name, messages]) => {
    const input = form.querySelector(`[name="${CSS.escape(name)}"], [name="${CSS.escape(name)}[]"]`)
    if (!input) return
    input.setAttribute("aria-invalid", "true")
    const note = Object.assign(document.createElement("p"), { className: "form__error", textContent: [].concat(messages).join(", ") })
    input.closest(".form__field")?.append(note)
  })
  form.querySelector("[aria-invalid]")?.focus()
}

const forms = document.querySelectorAll("form[data-form]")
const watcher = "IntersectionObserver" in window
  ? new IntersectionObserver((entries) => entries.forEach((entry) => {
    if (entry.isIntersecting) { watcher.unobserve(entry.target); mountCaptcha(entry.target) }
  }), { rootMargin: "200px" })
  : null

forms.forEach((form) => {
  form.querySelectorAll("input[data-attribution]").forEach((input) => {
    if (!input.value && attribution[input.dataset.attribution]) input.value = attribution[input.dataset.attribution]
  })
  if (watcher) watcher.observe(form)
  else form.addEventListener("focusin", () => mountCaptcha(form), { once: true })

  form.addEventListener("submit", async (event) => {
    event.preventDefault()
    if (!form.reportValidity()) return
    const button = form.querySelector("[type=submit]")
    button.disabled = true
    say(form, "Sending…", "pending")
    try {
      const response = await fetch(form.action, { method: "POST", body: new FormData(form), headers: { Accept: "application/json" } })
      const answer = await response.json().catch(() => ({}))
      if (response.ok) {
        form.reset()
        showErrors(form, {})
        say(form, answer.success_message || form.dataset.success, "sent")
        form.dispatchEvent(new CustomEvent("oldmill:submitted", { bubbles: true, detail: { form: form.dataset.form } }))
        window.dataLayer?.push({ event: "form_submit", form: form.dataset.form })
      } else if (answer.error === "invalid") {
        say(form, "Please check the fields marked below.", "error")
        showErrors(form, answer.errors)
      } else {
        say(form, MESSAGES[answer.error] || MESSAGES.network, "error")
      }
    } catch {
      say(form, MESSAGES.network, "error")
    } finally {
      button.disabled = false
      resetCaptcha(form)
    }
  })
})
