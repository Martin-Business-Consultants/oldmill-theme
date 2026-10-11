// Tabs (the menu's sections, the specials' days): a click or the arrow keys
// pick one and show its panel. Each [data-tabs] is its own set.
export function select(tabs, tab) {
  tabs.querySelectorAll("[data-tab]").forEach((other) => {
    const on = other === tab
    other.setAttribute("aria-selected", String(on))
    other.tabIndex = on ? 0 : -1
    const panel = document.getElementById(other.getAttribute("aria-controls"))
    if (panel) panel.hidden = !on
  })
}

document.querySelectorAll("[data-tabs]").forEach((tabs) => {
  const all = () => [...tabs.querySelectorAll("[data-tab]")]
  all().forEach((tab) => {
    tab.addEventListener("click", () => select(tabs, tab))
    tab.addEventListener("keydown", (event) => {
      const list = all()
      const step = { ArrowRight: 1, ArrowLeft: -1 }[event.key]
      const index = event.key === "Home" ? 0 : event.key === "End" ? list.length - 1 : step && (list.indexOf(tab) + step + list.length) % list.length
      if (index === undefined || index === null) return
      event.preventDefault()
      select(tabs, list[index])
      list[index].focus()
    })
  })
})
