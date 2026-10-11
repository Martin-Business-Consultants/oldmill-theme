// The site's motion, with the Web Animations API and IntersectionObserver:
//   data-fade          the header's entrance on load, staggered
//   data-reveal        fades up when scrolled into view
//   data-reveal-group  the same, staggering its children
// Anything already on screen when a reveal is set up is left alone, and
// nothing moves for a visitor who asks for reduced motion.
const ease = "cubic-bezier(0.22, 1, 0.36, 1)"
const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
const up = (distance) => [{ opacity: 0, translate: `0 ${distance}px` }, { opacity: 1, translate: "0 0" }]
const belowFold = (el) => el.getBoundingClientRect().top > window.innerHeight * 0.92

function whenSeen(el, callback) {
  const observer = new IntersectionObserver((entries) => {
    if (entries.some((entry) => entry.isIntersecting)) {
      observer.disconnect()
      callback()
    }
  }, { threshold: 0.12 })
  observer.observe(el)
}

if (!reduced) {
  document.querySelectorAll("[data-fade]").forEach((el, i) => {
    el.animate(up(24), { duration: 800, delay: i * 100, easing: ease, fill: "backwards" })
  })

  document.querySelectorAll("[data-reveal]").forEach((el) => {
    if (!belowFold(el)) return
    const hidden = el.animate([{ opacity: 0 }], { fill: "forwards" })
    whenSeen(el, () => { hidden.cancel(); el.animate(up(24), { duration: 800, easing: ease, fill: "backwards" }) })
  })

  document.querySelectorAll("[data-reveal-group]").forEach((group) => {
    if (!belowFold(group)) return
    const children = [...group.children]
    const hidden = children.map((el) => el.animate([{ opacity: 0 }], { fill: "forwards" }))
    whenSeen(group, () => {
      hidden.forEach((animation) => animation.cancel())
      children.forEach((el, i) => el.animate(up(24), { duration: 700, delay: i * 80, easing: ease, fill: "backwards" }))
    })
  })
}
