/* Shared suite chrome: adapted from tgilbert14/NEON-Small-Mammal-Tracker-App@78aed45 (2026-06-18); the copies have diverged since.
   =========================================================================
   app.js: count-up stat counters, loading overlay, Shiny message wiring
   ========================================================================= */

// ---- animated count-up for the hero stat band ----------------------------
function animateCount(el) {
  if (el.dataset.animated === "1") return;
  el.dataset.animated = "1";
  // A freshly-rendered hero counter means a site just finished loading, the
  // most reliable signal to dismiss the loading overlay (no reliance on a
  // custom Shiny message, which doesn't always register in time).
  if (typeof smtLoadDone === "function") smtLoadDone({ site: window.__plantSite || "" });
  const target = parseFloat(el.getAttribute("data-target")) || 0;
  const suffix = el.dataset.suffix || "";          // e.g. "d", "m", "g"
  const isFloat = !Number.isInteger(target);
  const fmt = (v) => (isFloat ? v.toFixed(1) : Math.round(v).toLocaleString()) + suffix;
  // reduced-motion: snap to the final value, no animation
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
    el.textContent = fmt(target); return;
  }
  const dur = 900;
  const start = performance.now();
  function tick(now) {
    const t = Math.min(1, (now - start) / dur);
    const eased = 1 - Math.pow(1 - t, 3); // easeOutCubic
    el.textContent = fmt(target * eased);
    if (t < 1) requestAnimationFrame(tick);
    else el.textContent = fmt(target);
  }
  requestAnimationFrame(tick);
}

function runCounters() {
  document.querySelectorAll(".count-up").forEach(animateCount);
}

// Re-run whenever Shiny injects fresh stat cards.
const heroObserver = new MutationObserver(() => runCounters());
document.addEventListener("DOMContentLoaded", function () {
  const host = document.body;
  heroObserver.observe(host, { childList: true, subtree: true });
  runCounters();
});

// ---- loading overlay (opaque, indeterminate) -----------------------------
// A site load is one synchronous blocking call whose duration we can't know,
// so we show an INDETERMINATE animated bar (no fake %) on an OPAQUE backdrop -
// it just spins until the server signals it's done. No number to "stall" at,
// and you don't see half-rendered data through it.
var smtSafetyTimer = null;
function smtLoadStart(label) {
  var ov = document.getElementById("loadOverlay");
  if (!ov) return;
  // Raise the overlay IMMEDIATELY, synchronously, on the click. A site load is
  // 1–3s of BLOCKING work on the worker (decompress + clean + leaderboard + the
  // Overview tab's plotly renders). A server-sent "show" message can't paint
  // until that block ends, by then it's too late, so the only honest feedback
  // is to show it client-side right now. (Loads are never truly instant, so the
  // old 250ms defer just hid the feedback during exactly the freeze it's for.)
  var siteText = label || "";
  if (!siteText) {
    var sel = document.getElementById("site");
    if (sel && sel.options && sel.selectedIndex >= 0) siteText = sel.options[sel.selectedIndex].text;
  }
  var siteEl = document.getElementById("loadSite");
  if (siteEl) siteEl.textContent = siteText;
  var note = ov.querySelector(".load-note");
  if (note) note.textContent = "Building the diversity profiles, cover maps, and charts.";
  var recovery = document.getElementById("loadRecovery");
  if (recovery) recovery.style.display = "none";
  ov.style.display = "flex";
  ov.setAttribute("aria-busy", "true");
  // Bring the hero into view once, when this load finishes (PD-21).
  window.__smtPendingReveal = true;
  var status = document.getElementById("appStatus");
  if (status) status.textContent = "Loading site…";
  if (navigator.vibrate) { try { navigator.vibrate(12); } catch (e) {} }  // tactile "got it"
  clearTimeout(smtSafetyTimer);
  smtSafetyTimer = setTimeout(function () {
    var lateNote = document.querySelector(".load-note");
    if (lateNote) lateNote.textContent = "This is taking longer than expected. The app will keep waiting for an explicit server response.";
    var reload = document.getElementById("loadRecovery");
    if (reload) reload.style.display = "inline-flex";
  }, 13000);
}
function smtLoadDone(message) {
  clearTimeout(smtSafetyTimer);
  var ov = document.getElementById("loadOverlay");
  if (ov) { ov.style.display = "none"; ov.setAttribute("aria-busy", "false"); }
  var site = message && message.site ? String(message.site) : "";
  var status = document.getElementById("appStatus");
  if (status) {
    status.textContent = site ? site + " ready" : "App connected";
    status.dataset.appReady = "true";
    status.dataset.siteReady = site ? "true" : "false";
  }
  if (!site) return;
  // Keep the address on the loaded site so a refresh or a shared link reopens
  // it (PD-32). replaceState only: Back keeps its ordinary meaning.
  smtSetSiteParam(site);
  // animateCount calls this once per hero counter, so the scroll and focus run
  // once per load, gated by the flag smtLoadStart raised (PD-21). behavior
  // 'auto' because smooth scrollIntoView no-ops inside bslib fill containers.
  if (window.__smtPendingReveal) {
    window.__smtPendingReveal = false;
    var target = document.getElementById("main-content") || document.querySelector(".hero-band");
    if (target) {
      try { target.scrollIntoView({ behavior: "auto", block: "start" }); } catch (e) { target.scrollIntoView(); }
      try { target.focus({ preventScroll: true }); } catch (e) {}
    }
  }
}

// ?site=<code> mirrors the loaded site; null removes it (change site).
function smtSetSiteParam(site) {
  try {
    if (!window.history || typeof history.replaceState !== "function") return;
    var u = new URL(window.location.href);
    if (site && /^[A-Za-z0-9]{4}$/.test(site)) u.searchParams.set("site", site.toUpperCase());
    else u.searchParams.delete("site");
    if (u.href !== window.location.href) history.replaceState(history.state, "", u.href);
  } catch (e) {}
}
document.addEventListener("click", function (event) {
  if (event.target.closest && event.target.closest("#changeSite")) smtSetSiteParam(null);
});

function smtMarkConnected() {
  var status = document.getElementById("appStatus");
  if (!status) return;
  status.textContent = "App connected";
  status.dataset.appReady = "true";
}
var smtDeepLinkSent = false;
function smtHandleShinyConnected() {
  smtMarkConnected();
  if (smtDeepLinkSent || !window.Shiny) return;
  var requested = new URLSearchParams(window.location.search).get("site");
  requested = requested ? requested.trim().toUpperCase() : "";
  if (!/^[A-Z0-9]{4}$/.test(requested)) return;
  smtDeepLinkSent = true;
  smtLoadStart(requested + " · loading");
  Shiny.setInputValue("pickSite", requested, { priority: "event" });
}

function smtHandleShinyDisconnected() {
  var status = document.getElementById("appStatus");
  if (!status) return;
  status.textContent = "Connection lost";
  status.dataset.appReady = "false";
  status.dataset.siteReady = "false";
}

// Shiny emits lifecycle notifications through jQuery. A native
// addEventListener() callback does not receive Shiny's synthetic
// `shiny:connected` event, which can leave both the readiness receipt and
// deep-link site selection stuck even though the socket itself is healthy.
// app.js loads after jQuery in Shiny's dependency order; keep a native
// fallback for static/non-Shiny harnesses that dispatch a real DOM event.
if (window.jQuery) {
  window.jQuery(document).on("shiny:connected", smtHandleShinyConnected);
  window.jQuery(document).on("shiny:disconnected", smtHandleShinyDisconnected);
} else {
  document.addEventListener("shiny:connected", smtHandleShinyConnected);
  document.addEventListener("shiny:disconnected", smtHandleShinyDisconnected);
}

// (The site report card is now a server-side PDF streamed by a Shiny
//  downloadHandler, output$reportPdf, via the hero downloadLink, so the old
//  browser-print path (smtPrintReport) has been removed.)

// ---- dismiss any open info popover (click-outside + Esc) -----------------
// bslib/Bootstrap popovers don't close on an outside click by default, so make
// every "ⓘ" popover dismissible the way users expect.
function smtClosePopovers() {
  document.querySelectorAll(".popover").forEach(function (pop) {
    var trig = pop.id ? document.querySelector('[aria-describedby="' + pop.id + '"]') : null;
    if (trig && window.bootstrap && bootstrap.Popover) {
      var inst = bootstrap.Popover.getInstance(trig);
      if (inst) { inst.hide(); return; }
    }
    pop.remove(); // fallback: just remove the floating popover
  });
}
document.addEventListener("click", function (e) {
  if (e.target.closest(".popover") || e.target.closest(".info-dot") ||
      e.target.closest("bslib-popover")) return;        // clicking inside/trigger -> leave it
  if (document.querySelector(".popover")) smtClosePopovers();
});
document.addEventListener("keydown", function (e) {
  if (e.key === "Escape") smtClosePopovers();
});

// Re-fit one Leaflet widget. A render that arrived while the container was
// 0 px wide (a ?site= deep link hides the picker before it draws) is parked in
// leaflet's pendingRenderData, and only the widget's own resize() replays it;
// invalidateSize alone leaves the map blank (PD-19). invalidateSize on a hidden
// map is skipped: with an open popup it recurses (PD-20).
function smtRefitLeaflet(el) {
  try {
    if (!el || !el.id || !window.HTMLWidgets) return;
    var widget = HTMLWidgets.find("#" + el.id);
    if (!widget) return;
    var w = el.offsetWidth, h = el.offsetHeight;
    if (typeof widget.resize === "function" && w > 0 && h > 0) widget.resize(w, h);
    var map = typeof widget.getMap === "function" ? widget.getMap() : null;
    if (map && typeof map.invalidateSize === "function" && w > 0) map.invalidateSize({ pan: false });
  } catch (e) {}
}

// ---- Shiny custom message handlers ---------------------------------------
document.addEventListener("DOMContentLoaded", function () {
  if (window.Shiny) {
    Shiny.addCustomMessageHandler("countUp", function (_message) {
      // small delay so the freshly-rendered DOM is in place
      setTimeout(runCounters, 60);
    });
    Shiny.addCustomMessageHandler("loadDone", function (message) { smtLoadDone(message); });
    // server-triggered overlay (e.g. a click on the national picker map, which
    // has no inline onclick to call smtLoadStart directly)
    Shiny.addCustomMessageHandler("smtLoadStart", function (msg) {
      smtLoadStart(msg && msg.label);
    });
    // A Leaflet map that initialised inside a hidden tab/container (the Plot-map
    // tab, or the picker map re-shown after "change site") can paint blank until
    // it recomputes its size. Dispatching 'resize' makes every Leaflet map
    // invalidateSize. The server kicks this after re-showing the splash.
    Shiny.addCustomMessageHandler("kickMaps", function (_message) {
      var kick = function () {
        document.querySelectorAll(".leaflet.html-widget, .leaflet").forEach(function (el) {
          smtRefitLeaflet(el);
        });
        try { window.dispatchEvent(new Event("resize")); } catch (e) {}
      };
      requestAnimationFrame(kick);
      [80, 250, 500, 900].forEach(function (t) { setTimeout(kick, t); });
    });
  }
});

// Re-fit any Leaflet map the moment its tab becomes visible (hidden-init blank fix).
document.addEventListener("shown.bs.tab", function () {
  setTimeout(function () {
    document.querySelectorAll(".leaflet.html-widget, .leaflet").forEach(function (el) {
      smtRefitLeaflet(el);
    });
    try { window.dispatchEvent(new Event("resize")); } catch (e) {}
  }, 60);
});

// DT escapes every data column and renders only the Action column as HTML.
// Keep the plot id in a data attribute and dispatch through one delegated
// listener instead of interpolating source strings into inline JavaScript.
document.addEventListener("click", function (event) {
  var button = event.target.closest(".plot-table-open[data-plot-id]");
  if (!button || !window.Shiny) return;
  Shiny.setInputValue("qcCardRequest", button.dataset.plotId, { priority: "event" });
});

// QC flags: one delegated handler for every [data-qc-flag] header. A native
// <button> fires click on Enter and Space by itself; any other element that
// carries the attribute gets the same keys here.
function smtOpenQcFlag(el) {
  if (!el || !window.Shiny || !el.dataset || !el.dataset.qcFlag) return;
  Shiny.setInputValue("qcFlagOpen", el.dataset.qcFlag, { priority: "event" });
}
document.addEventListener("click", function (event) {
  var el = event.target.closest && event.target.closest("[data-qc-flag]");
  if (el) smtOpenQcFlag(el);
});
document.addEventListener("keydown", function (event) {
  if (event.key !== "Enter" && event.key !== " " && event.key !== "Spacebar") return;
  var el = event.target.closest && event.target.closest("[data-qc-flag]");
  if (!el || el.tagName === "BUTTON") return;
  event.preventDefault();
  smtOpenQcFlag(el);
});

// DataTables can measure a zero-width container when rendered inside a closed
// <details>. Recalculate once the accessible table is disclosed.
document.addEventListener("toggle", function (event) {
  var details = event.target;
  if (!details.matches || !details.matches(".lab-table-details") || !details.open) return;
  setTimeout(function () {
    var table = details.querySelector("table.dataTable");
    if (table && window.jQuery && jQuery.fn.dataTable && jQuery.fn.dataTable.isDataTable(table)) {
      jQuery(table).DataTable().columns.adjust().draw(false);
    }
    try { window.dispatchEvent(new Event("resize")); } catch (_error) {}
  }, 60);
}, true);

// ---- mascot celebration: the sprout hops up + fades on a happy moment -------
// This app has no confetti (no rarity/legendary find), so mascotCheer is wired
// to nothing yet; it's exposed on window so a future celebration can call it.
function mascotCheer(big) {
  try {
    if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    var src = document.querySelector("#loadOverlay .mascot");
    if (!src) return;
    var wrap = document.createElement("div");
    wrap.className = "mascot-cheer";
    wrap.appendChild(src.cloneNode(true));
    document.body.appendChild(wrap);
    setTimeout(function () { if (wrap.parentNode) wrap.parentNode.removeChild(wrap); }, 1700);
  } catch (e) {}
}
window.mascotCheer = mascotCheer;

// ---- first-visit: the splash mascot waves hello once (localStorage-gated) ----
document.addEventListener("DOMContentLoaded", function () {
  try {
    if (localStorage.getItem("smtMascotSeen") === "1") return;
    var g = document.querySelector(".splash-guide");
    if (g) {
      g.classList.add("wave");
      localStorage.setItem("smtMascotSeen", "1");
      setTimeout(function () { g.classList.remove("wave"); }, 3300);
    }
  } catch (e) {}
});
