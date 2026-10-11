// The header turns solid once the page scrolls; the burger opens the
// small-screen menu, a native <dialog>; and the sun/moon button flips the
// site between the dark mill and limestone by day, remembered for next time.
const nav = document.querySelector("[data-nav]")
const menu = document.getElementById("mobile-menu")
const burger = document.querySelector("[data-menu-open]")

if (nav) {
  const update = () => nav.classList.toggle("is-scrolled", window.scrollY > 80)
  update()
  window.addEventListener("scroll", update, { passive: true })
}

if (menu && burger) {
  const close = () => menu.close()
  burger.addEventListener("click", () => {
    menu.showModal()
    burger.setAttribute("aria-expanded", "true")
  })
  menu.addEventListener("close", () => burger.setAttribute("aria-expanded", "false"))
  menu.querySelector("[data-menu-close]")?.addEventListener("click", close)
  // A click on the backdrop lands on the dialog itself, outside its content.
  menu.addEventListener("click", (event) => { if (event.target === menu) close() })
  menu.querySelectorAll("a").forEach((link) => link.addEventListener("click", close))
}

document.querySelectorAll("[data-theme-toggle]").forEach((button) => {
  button.addEventListener("click", () => {
    const next = document.documentElement.dataset.theme === "light" ? "dark" : "light"
    document.documentElement.dataset.theme = next
    try { localStorage.setItem("theme", next) } catch {}
  })
})
