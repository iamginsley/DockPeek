// The interactive Dock in the hero: hover previews, Aero Peek, click to minimize and closing,
// like the real app. Plays a short demo on its own until someone tries it.
(() => {
  const screen = document.getElementById("screen");
  const preview = document.getElementById("preview");
  const menuApp = document.getElementById("menu-app");
  const icons = [...screen.querySelectorAll(".app")];
  const windows = [...screen.querySelectorAll(".win")];
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const SHOW_DELAY = 150;
  const HIDE_DELAY = 250;
  const PEEK_DELAY = 400;

  // Front to back; the first entry is on top.
  let order = windows.filter((w) => !w.classList.contains("min")).reverse();
  let frontApp = "web";
  let openApp = null;
  let showTimer, hideTimer, peekTimer;
  let touched = false;

  const windowsOf = (app) => windows.filter((w) => w.dataset.app === app && !w.hidden);
  const iconOf = (app) => icons.find((i) => i.dataset.app === app);

  function render() {
    order.forEach((w, index) => { w.style.zIndex = String(order.length - index); });
    windows.forEach((w) => w.classList.toggle("front", w === order[0]));
    icons.forEach((icon) => icon.style.setProperty("--running", windowsOf(icon.dataset.app).length ? "1" : "0"));
    menuApp.textContent = iconOf(frontApp)?.dataset.name ?? "Finder";
  }

  function bringToFront(win) {
    win.classList.remove("min");
    order = [win, ...order.filter((w) => w !== win)];
    frontApp = win.dataset.app;
    render();
  }

  function minimize(win) {
    win.classList.add("min");
    order = order.filter((w) => w !== win);
    frontApp = order[0]?.dataset.app ?? null;
    render();
  }

  function close(win) {
    endPeek();
    win.classList.add("min");
    order = order.filter((w) => w !== win);
    setTimeout(() => { win.hidden = true; render(); if (openApp) showPreview(openApp); }, 300);
    if (frontApp === win.dataset.app && !order.some((w) => w.dataset.app === frontApp)) frontApp = order[0]?.dataset.app ?? null;
    render();
    // An empty desk is no fun: bring everything back after a moment.
    if (windows.every((w) => w.hidden || w === win)) setTimeout(reset, 1600);
  }

  function reset() {
    windows.forEach((w) => { w.hidden = false; });
    windows.filter((w) => w.id !== "w-web-2").forEach((w) => w.classList.remove("min"));
    order = windows.filter((w) => !w.classList.contains("min")).reverse();
    frontApp = "web";
    render();
  }

  // MARK: Preview panel

  function showPreview(app) {
    const list = windowsOf(app);
    if (!list.length) return hidePreview();
    openApp = app;
    preview.replaceChildren(...list.map(card));
    preview.setAttribute("aria-label", `Fenster von ${iconOf(app).dataset.name}`);
    // Centered above the icon, kept inside the screen.
    const icon = iconOf(app).getBoundingClientRect();
    const box = screen.getBoundingClientRect();
    const width = preview.offsetWidth;
    const left = Math.min(Math.max(icon.left + icon.width / 2 - box.left - width / 2, 8), box.width - width - 8);
    preview.style.left = `${left}px`;
    preview.classList.add("open");
    icons.forEach((i) => i.classList.toggle("active", i.dataset.app === app));
  }

  function hidePreview() {
    clearTimeout(showTimer);
    openApp = null;
    preview.classList.remove("open");
    icons.forEach((i) => i.classList.remove("active"));
    endPeek();
  }

  function card(win) {
    const minimized = win.classList.contains("min");
    const button = document.createElement("button");
    button.className = "card-win" + (minimized ? " minimized" : "");
    button.style.setProperty("--c", iconOf(win.dataset.app).style.getPropertyValue("--c"));
    button.setAttribute("aria-label", win.dataset.title + (minimized ? ", minimiert" : ""));

    const title = document.createElement("div");
    title.className = "title";
    const dot = document.createElement("i");
    dot.className = "dot";
    const name = document.createElement("span");
    name.textContent = win.dataset.title;
    const x = document.createElement("span");
    x.className = "x";
    x.textContent = "✕";
    x.setAttribute("aria-hidden", "true"); // the real app offers closing as a VoiceOver action
    title.append(dot, name, x);

    // The thumbnail is a scaled copy of the window itself.
    const thumb = document.createElement("div");
    thumb.className = "thumb";
    thumb.style.aspectRatio = `${win.offsetWidth} / ${win.offsetHeight}`;
    const copy = win.cloneNode(true);
    copy.removeAttribute("id");
    copy.classList.remove("min", "front", "peeked");
    copy.hidden = false;
    copy.setAttribute("aria-hidden", "true");
    thumb.append(copy);
    if (minimized) {
      const badge = document.createElement("span");
      badge.className = "badge";
      badge.textContent = "Minimiert";
      thumb.append(badge);
    }
    button.append(title, thumb);

    button.addEventListener("click", (event) => {
      touched = true;
      if (event.target === x) { close(win); return; }
      hidePreview();
      bringToFront(win);
    });
    button.addEventListener("auxclick", (event) => {
      if (event.button === 1) { event.preventDefault(); touched = true; close(win); }
    });
    button.addEventListener("mouseenter", () => schedulePeek(win));
    button.addEventListener("focus", () => schedulePeek(win));
    button.addEventListener("mouseleave", endPeek);
    button.addEventListener("blur", endPeek);
    return button;
  }

  // MARK: Aero Peek

  function schedulePeek(win) {
    clearTimeout(peekTimer);
    // Like the app: a minimized window has no place to show, so no frosting.
    if (win.classList.contains("min")) return endPeek();
    const peeking = screen.classList.contains("peeking");
    peekTimer = setTimeout(() => {
      windows.forEach((w) => w.classList.toggle("peeked", w === win));
      screen.classList.add("peeking");
    }, peeking ? 0 : PEEK_DELAY);
  }

  function endPeek() {
    clearTimeout(peekTimer);
    screen.classList.remove("peeking");
    windows.forEach((w) => w.classList.remove("peeked"));
  }

  // MARK: Dock icons

  for (const icon of icons) {
    const app = icon.dataset.app;
    const enter = () => {
      clearTimeout(hideTimer);
      clearTimeout(showTimer);
      if (openApp) { showPreview(app); return; } // moving along the Dock switches right away
      showTimer = setTimeout(() => showPreview(app), SHOW_DELAY);
    };
    icon.addEventListener("mouseenter", () => { touched = true; screen.classList.add("used"); enter(); });
    icon.addEventListener("focus", () => { touched = true; screen.classList.add("used"); showPreview(app); });
    icon.addEventListener("mouseleave", () => { hideTimer = setTimeout(hidePreview, HIDE_DELAY); });
    icon.addEventListener("click", () => {
      touched = true;
      const mine = order.filter((w) => w.dataset.app === app);
      if (frontApp === app && mine.length) {
        // Click minimizes: the app in front puts its front window away.
        hidePreview();
        minimize(mine[0]);
      } else {
        const next = mine[0] ?? windowsOf(app)[0];
        if (next) bringToFront(next);
        if (window.matchMedia("(hover: none)").matches) showPreview(app);
      }
    });
  }

  preview.addEventListener("mouseenter", () => clearTimeout(hideTimer));
  preview.addEventListener("mouseleave", () => { hideTimer = setTimeout(hidePreview, HIDE_DELAY); });
  document.addEventListener("keydown", (event) => { if (event.key === "Escape") hidePreview(); });
  screen.addEventListener("click", (event) => {
    if (!event.target.closest(".app, .preview")) hidePreview();
  });

  render();

  // MARK: Demo until someone tries it

  if (reduceMotion) return;
  const steps = [
    [1400, () => showPreview("web")],
    [1200, () => { const first = preview.querySelector(".card-win"); first?.classList.add("hover"); schedulePeek(windowsOf("web")[0]); }],
    [2200, () => { endPeek(); showPreview("notes"); }],
    [2200, () => hidePreview()],
    [2600, () => {}],
  ];
  let step = 0;
  (function play() {
    if (touched) return;
    const [delay, action] = steps[step];
    setTimeout(() => {
      if (touched) return;
      action();
      step = (step + 1) % steps.length;
      play();
    }, delay);
  })();
})();
