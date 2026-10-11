// The week's specials open on today, in Plainwell's time zone (the pub's
// day, not the visitor's). The server picked a day when it drew the page,
// and a cached page can outlive it, so pick again on the real clock: move
// the "Today" badge and open that day, if it has a special.
import { select } from "oldmill/tabs"

document.querySelectorAll("[data-specials]").forEach((tabs) => {
  const today = new Intl.DateTimeFormat("en-US", { timeZone: tabs.dataset.timeZone, weekday: "long" }).format(new Date())
  tabs.querySelectorAll("[data-tab]").forEach((tab) => {
    const badge = tab.querySelector("[data-today]")
    if (badge) badge.hidden = tab.dataset.day !== today
  })
  const tab = tabs.querySelector(`[data-tab][data-day="${today}"]`)
  if (tab) select(tabs, tab)
})
