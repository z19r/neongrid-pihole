/* NEON//GRID add-ons for Pi-hole v6 (loaded from footer.lp by neongrid.sh).
   1. neon chart palette  2. hacker ticker  3. Konami / "1337" -> 1337 mode
   Does nothing unless the neongrid CSS is the active theme. */
(function () {
  "use strict";
  var root = document.documentElement;
  var css = getComputedStyle(root);
  if (!css.getPropertyValue("--ng-active").trim()) return;
  var calm = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // 1. Charts: Pi-hole reads THEME_COLORS on every refresh
  var palette = css.getPropertyValue("--chart-palette").split(",");
  globalThis.THEME_COLORS = palette.map(function (s) {
    return s.trim();
  });
  if (window.Chart && Chart.defaults) {
    Chart.defaults.font.family = css.getPropertyValue("--chart-font").trim();
    Chart.defaults.color = css.getPropertyValue("--ng-dim").trim();
    Chart.defaults.borderColor = css.getPropertyValue("--ng-line").trim();
  }

  // 2. Ticker
  var QUIPS = [
    "rm -rf /ads/* ... done. nom nom nom",
    "trackers detected: {b}. trackers yeeted: {b}.",
    "the cake is a lie. the ad was too.",
    "dns sinkhole status: h4ngry",
    "ping 127.0.0.1 -- there's no place like home",
    "packets sorted by vibe. vibe: immaculate",
    "{b} requests sent to the shadow realm",
    "hack the planet. block the pixels.",
    "sudo make me a sandwich (no ads)",
    "↑↑↓↓←→←→BA for a good time",
    "uptime > your attention span. ads: 0",
    "all your queries are belong to us",
    "spinning up the flux capacitor... 1.21 gigablocks",
  ];
  var content = document.querySelector(".content-wrapper > .content");
  if (content) {
    var t = document.createElement("div");
    t.id = "ng-ticker";
    t.setAttribute("aria-hidden", "true");
    content.prepend(t);
    var i = Math.floor(Math.random() * QUIPS.length);
    var typer = null;
    var show = function () {
      var el = document.getElementById("blocked_queries");
      var b = (el && el.textContent.trim().replace(/^-+$/, "")) || "1337";
      var line = QUIPS[i++ % QUIPS.length].replace(/\{b\}/g, b);
      clearInterval(typer);
      if (calm) {
        t.textContent = line;
        return;
      }
      var n = 0;
      typer = setInterval(function () {
        t.textContent = line.slice(0, ++n);
        if (n >= line.length) clearInterval(typer);
      }, 28);
    };
    show();
    setInterval(show, 9000);
  }

  // 3. 1337 mode: Konami code or typing "1337" outside inputs
  var KONAMI =
    "ArrowUp ArrowUp ArrowDown ArrowDown ArrowLeft ArrowRight " +
    "ArrowLeft ArrowRight b a";
  var keys = [];
  var raf = 0;
  function toast(msg) {
    var d = document.createElement("div");
    d.className = "ng-toast";
    d.textContent = msg;
    document.body.appendChild(d);
    setTimeout(function () {
      d.remove();
    }, 2200);
  }
  function rain(on) {
    var c = document.getElementById("ng-rain");
    if (!on || calm) {
      cancelAnimationFrame(raf);
      if (c) c.remove();
      return;
    }
    c = document.createElement("canvas");
    c.id = "ng-rain";
    document.body.appendChild(c);
    var g = c.getContext("2d");
    var glyphs = "01337ｱｲｳｴｵｶｷｸｹｺ#$%&@PIHOLE".split("");
    var cols = [];
    var fit = function () {
      c.width = innerWidth;
      c.height = innerHeight;
      cols = Array(Math.ceil(c.width / 16)).fill(0);
    };
    fit();
    addEventListener("resize", fit);
    var tick = function () {
      // fade old glyphs toward transparent so the UI stays visible
      g.globalCompositeOperation = "destination-out";
      g.fillStyle = "rgba(0,0,0,0.1)";
      g.fillRect(0, 0, c.width, c.height);
      g.globalCompositeOperation = "source-over";
      g.font = "15px monospace";
      cols.forEach(function (y, x) {
        g.fillStyle = Math.random() < 0.5 ? "#ff2bd6" : "#00f0ff";
        g.fillText(glyphs[(Math.random() * glyphs.length) | 0], x * 16, y);
        cols[x] = y > c.height && Math.random() > 0.975 ? 0 : y + 16;
      });
      raf = requestAnimationFrame(tick);
    };
    tick();
  }
  function set1337(on) {
    root.classList.toggle("ng-1337", on);
    rain(on);
    try {
      localStorage.setItem("ng-1337", on ? "1" : "");
    } catch (e) {}
  }
  addEventListener("keydown", function (e) {
    if (/INPUT|TEXTAREA|SELECT/.test(e.target.tagName)) return;
    keys.push(e.key);
    keys = keys.slice(-10);
    var s = keys.join(" ");
    if (s.endsWith(KONAMI) || keys.slice(-4).join("") === "1337") {
      keys = [];
      var on = !root.classList.contains("ng-1337");
      set1337(on);
      toast(on ? "ACCESS GRANTED // 1337 MODE" : "1337 MODE OFFLINE");
    }
  });
  if (localStorage.getItem("ng-1337")) set1337(true);
})();
