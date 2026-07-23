// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.css"
import "@fontsource/inter/variable.css";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//
import "phoenix_html"
import "alpinejs"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

let Hooks = {}

Hooks.VkContainerLog = {
  updated() {
    var logsDiv = document.getElementById("clogsholder")
    if (logsDiv) {
      logsDiv.scrollTop = logsDiv.scrollHeight
    }
  }
}

let csrfMeta = document.querySelector("meta[name='csrf-token']")
let csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : null

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken }
})

liveSocket.connect()
window.liveSocket = liveSocket
// liveSocket.enableDebug()

var themeToggleDarkIcon = document.getElementById("theme-toggle-dark-icon")
var themeToggleLightIcon = document.getElementById("theme-toggle-light-icon")
var themeToggleBtn = document.getElementById("theme-toggle")

// Theme toggle only exists on pages that include the main layout controls
if (themeToggleDarkIcon && themeToggleLightIcon && themeToggleBtn) {
  if (
    localStorage.getItem("color-theme") === "dark" ||
    (!("color-theme" in localStorage) &&
      window.matchMedia("(prefers-color-scheme: dark)").matches)
  ) {
    themeToggleLightIcon.classList.remove("hidden")
  } else {
    themeToggleDarkIcon.classList.remove("hidden")
  }

  themeToggleBtn.addEventListener("click", function () {
    themeToggleDarkIcon.classList.toggle("hidden")
    themeToggleLightIcon.classList.toggle("hidden")

    if (localStorage.getItem("color-theme")) {
      if (localStorage.getItem("color-theme") === "light") {
        document.documentElement.classList.add("dark")
        localStorage.setItem("color-theme", "dark")
      } else {
        document.documentElement.classList.remove("dark")
        localStorage.setItem("color-theme", "light")
      }
    } else {
      if (document.documentElement.classList.contains("dark")) {
        document.documentElement.classList.remove("dark")
        localStorage.setItem("color-theme", "light")
      } else {
        document.documentElement.classList.add("dark")
        localStorage.setItem("color-theme", "dark")
      }
    }
  })
<<<<<<< HEAD
}
=======
}
>>>>>>> refs/remotes/origin/main
