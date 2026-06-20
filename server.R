# ===========================================================================
# NEON Plant Diversity Explorer — server.R
# ===========================================================================
server <- function(input, output, session) {

  is_dark <- function() identical(input$colorMode, "dark")

  # ---- shared plotly styling (ported from the mammal flagship) ------------
  plotly_theme <- function(p, legend = TRUE) {
    dark <- is_dark()
    ink  <- if (dark) "#e8eef2" else "#1f2a30"
    grid <- if (dark) "rgba(220,230,240,0.10)" else "rgba(31,42,48,0.08)"
    zero <- if (dark) "rgba(220,230,240,0.22)" else "rgba(31,42,48,0.15)"
    lin  <- if (dark) "#3a4759" else "#d6ddd4"
    legc <- if (dark) "#c3cedd" else "#344049"
    p %>% plotly::layout(
      paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
      font = list(color = ink, family = "Rubik"),
      xaxis = list(gridcolor = grid, zerolinecolor = zero, linecolor = lin),
      yaxis = list(gridcolor = grid, zerolinecolor = zero, linecolor = lin),
      legend = list(bgcolor = "rgba(0,0,0,0)", orientation = "h", y = -0.2, font = list(color = legc)),
      margin = list(l = 55, r = 30, t = 48, b = 44),
      hoverlabel = list(bgcolor = "rgba(31,92,61,0.96)", bordercolor = DDL$gold,
        font = list(color = "#ffffff", family = "Rubik", size = 13))) %>%
      plotly::config(displayModeBar = FALSE, responsive = TRUE)
  }
  note_plot <- function(msg, icon = "\U0001F33F") {
    plotly::plot_ly(type = "scatter", mode = "markers") %>%
      plotly::layout(paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
        xaxis = list(visible = FALSE), yaxis = list(visible = FALSE),
        annotations = list(list(text = paste0(icon, "<br>", msg), showarrow = FALSE,
          font = list(color = if (is_dark()) "#9fb0c4" else "#6b7a85", size = 15), align = "center"))) %>%
      plotly::config(displayModeBar = FALSE)
  }
  ctx_for <- function() rv$ctx %||% ""

  # ---- core reactive state -----------------------------------------------
  rv <- reactiveValues(occ = NULL, snap = NULL, ground = NULL, lb = NULL, pal = NULL,
                       label = NULL, site = NULL, plot = NULL, ctx = NULL, is_demo = FALSE)

  # ---- pickers ------------------------------------------------------------
  observe({
    ch <- plant_state_choices()
    sel <- if ("AZ" %in% ch) "AZ" else NULL
    updateSelectInput(session, "stateSel", choices = ch, selected = sel)
  })
  observeEvent(input$stateSel, {
    updateSelectInput(session, "site", choices = plant_sites_in_state(input$stateSel))
  }, ignoreInit = FALSE)

  output$siteBio <- renderUI({
    req(input$site); b <- site_bio(input$site); if (is.null(b)) return(NULL)
    div(class = "site-bio", bs_icon("info-circle-fill"), span(b))
  })

  output$siteCards <- renderUI({
    if (is.null(SITE_INDEX) || !nrow(SITE_INDEX)) return(NULL)
    div(class = "site-cards",
      lapply(seq_len(nrow(site_table)), function(i) {
        r <- site_table[i, ]
        tags$a(class = "site-card", href = "#",
          onclick = sprintf("smtLoadStart('%s — loading…');Shiny.setInputValue('pickSite','%s',{priority:'event'});return false;",
                            gsub("'", "", r$name), r$site),
          div(class = "sc-emoji", "\U0001F33E"),
          div(class = "sc-body",
            div(class = "sc-name", tags$b(r$site), sprintf(" · %s", r$name)),
            div(class = "sc-meta", sprintf("%s · %s species · %s%% introduced cover",
              r$state, r$richness, ifelse(is.na(r$pct_introduced), "—", r$pct_introduced)))))
      }))
  })

  shinyjs::hide("mainTabsWrap")

  # ---- ingest -------------------------------------------------------------
  ingest <- function(b, label, is_demo = FALSE) {
    if (is.null(b) || is.null(b$occ) || !nrow(b$occ)) {
      session$sendCustomMessage("loadDone", list())
      showNotification("No plant data found for that site.", type = "warning"); return(invisible())
    }
    rv$occ    <- b$occ
    rv$snap   <- latest_snapshot(b$occ)        # one survey per plot — the honest snapshot
    rv$ground <- b$ground
    rv$lb     <- plot_summary(rv$snap)
    rv$pal    <- make_species_pal(b$occ)
    rv$label  <- label
    rv$site   <- b$meta$site
    rv$is_demo <- is_demo
    rv$plot   <- NULL
    yrs <- range(b$occ$year, na.rm = TRUE)
    rv$ctx <- paste0(b$meta$site, " · ", if (yrs[1] == yrs[2]) yrs[1] else paste0(yrs[1], "–", yrs[2]))

    shinyjs::show("mainTabsWrap"); shinyjs::show("plotPickerWrap"); shinyjs::hide("splash")
    pl <- rv$lb$plotID
    updateSelectizeInput(session, "plotSel",
      choices = c("Pick a plot…" = "", setNames(pl, sprintf("%s · %d species", short_plot(pl), rv$lb$richness))),
      selected = "", server = TRUE)
    nav_select("tabs", "overview")
    session$sendCustomMessage("countUp", list())
    session$sendCustomMessage("loadDone", list())
    invisible(TRUE)
  }

  load_site <- function(site) {
    if (is.null(site) || site == "") { session$sendCustomMessage("loadDone", list()); return() }
    b <- load_site_bundle(site)
    if (is.null(b)) { session$sendCustomMessage("loadDone", list())
      showNotification("That site isn't bundled in this demo.", type = "error"); return() }
    row <- site_table[site_table$site == site, ]
    ingest(b, sprintf("%s · %s", site, if (nrow(row)) row$name else site))
  }
  observeEvent(input$loadBtn, load_site(input$site))
  observeEvent(input$pickSite, load_site(input$pickSite))
  observeEvent(input$demoBtn,  ingest(load_demo(), DEMO_META$label, is_demo = TRUE))
  observeEvent(input$demoBtn2, ingest(load_demo(), DEMO_META$label, is_demo = TRUE))

  # national site-picker map on the splash: dot size = richness, colour = % introduced; tap to load
  local({
    mx <- suppressWarnings(max(site_table$pct_introduced, na.rm = TRUE)); if (!is.finite(mx)) mx <- 100
    pip_pal <- leaflet::colorNumeric("YlOrBr", domain = c(0, mx), na.color = "#c9d3bb")
    picked_site <- mapPickerServer("picker", site_table = site_table, radius_metric = "richness",
      color_fn = function(st) pip_pal(st$pct_introduced),
      label_fn = function(r) sprintf("<b>%s</b> · %s, %s<br><b>%s</b> species · <b>%s</b> introduced cover · %s plots",
        r$site, r$name %||% r$site, r$state %||% "", r$richness %||% "?",
        if (is.finite(r$pct_introduced)) paste0(round(r$pct_introduced), "%") else "n/a", r$n_plots %||% "?"))
    # load in the MAIN server context so ingest()'s shinyjs::hide("splash") isn't namespaced
    observeEvent(picked_site(), { s <- picked_site(); if (!is.null(s) && nzchar(s)) load_site(s) }, ignoreInit = TRUE)
  })

  # ---- selecting a plot (the funnel) -------------------------------------
  pick_plot <- function(p, navigate = FALSE) {
    if (is.null(p) || is.na(p) || p == "") return()
    if (is.null(rv$lb) || !(p %in% rv$lb$plotID)) return()   # ignore a stale plot after a site switch
    rv$plot <- p
    if (!identical(input$plotSel, p)) updateSelectizeInput(session, "plotSel", selected = p)
    if (navigate) nav_select("tabs", "plot")
  }
  observeEvent(input$plotSel, if (nzchar(input$plotSel %||% "")) pick_plot(input$plotSel, navigate = TRUE), ignoreInit = TRUE)
  # the scatter pin chip ("Open plot profile") -> select the plot + jump to its profile
  observeEvent(input$qcCardRequest,
    if (nzchar(input$qcCardRequest %||% "")) pick_plot(input$qcCardRequest, navigate = TRUE), ignoreInit = TRUE)

  # help dialog (no mammal confirm.js dependency)
  observeEvent(input$help, {
    showModal(modalDialog(easyClose = TRUE, title = tagList(bs_icon("question-circle"), " How it works"),
      tags$ul(
        tags$li(HTML("Pick a <b>site</b> (or open the Santa Rita demo). Numbers describe the <b>most recent survey</b> of each plot.")),
        tags$li(HTML("<b>Diversity</b> — the nested species-area curve (1→400 m²), the Hill profile, and a Chao2 estimate of undetected species.")),
        tags$li(HTML("<b>Native vs Invasive</b> — how much cover is introduced, which species, and where invasion has a foothold at the finest scale.")),
        tags$li(HTML("<b>Diversity Lab</b> — every plot as a dot; <b>tap one</b> to pin its card, then “Open plot profile” for the full, downloadable drill-down.")),
        tags$li(HTML("Cover is an <b>ocular estimate</b> and layers overlap, so cover figures are a relative index, not a share of ground."))),
      footer = modalButton("Got it")))
  })
  observeEvent(input$surpriseBtn, { lb <- rv$lb; req(lb); pick_plot(sample(lb$plotID, 1), navigate = TRUE) })

  # nav buttons
  observeEvent(input$goDiversity, nav_select("tabs", "diversity"))
  observeEvent(input$goInvasive,  nav_select("tabs", "invasive"))
  observeEvent(input$goLab,       nav_select("tabs", "lab"))
  observeEvent(input$goPlot,      { if (is.null(rv$plot) && !is.null(rv$lb)) rv$plot <- rv$lb$plotID[1]; nav_select("tabs", "plot") })
  observeEvent(input$goMap,       nav_select("tabs", "map"))
  # the four hero KPI cards are nav doors -> the tab that explains each metric
  observeEvent(input$heroNav, {
    tab <- input$heroNav; if (!is.null(tab) && nzchar(tab)) nav_select("tabs", tab)
  })

  # ---- hero stats ---------------------------------------------------------
  output$heroStats <- renderUI({
    lb <- rv$lb; snap <- rv$snap; if (is.null(lb) || is.null(snap)) return(NULL)
    sp <- species_level_only(snap)
    n_sp <- dplyr::n_distinct(sp$scientificName)
    n_intro <- dplyr::n_distinct(sp$scientificName[sp$nativity == "Introduced"])
    site_intro <- site_invasion(snap)
    ucs <- unknown_cover_share(snap)
    # each KPI is a nav door — clicking jumps to the tab that explains it
    hero <- function(v, l, suf = "", icon, tone, ttl = NULL, nav = NULL, sub = NULL)
      div(class = paste0("hero-stat hero-", tone, if (!is.null(nav)) " hero-clickable" else ""), title = ttl,
        onclick = if (!is.null(nav)) sprintf("Shiny.setInputValue('heroNav','%s',{priority:'event'});", nav),
        div(class = "hs-icon", bs_icon(icon)),
        div(div(class = "hs-v count-up", `data-target` = v, `data-suffix` = suf, "0"),
            div(class = "hs-l", l),
            if (!is.null(sub)) div(class = "hs-sub", sub)))
    div(class = "hero-band",
      div(class = "hero-title", bs_icon("broadcast"), tags$b(rv$label)),
      div(class = "hero-grid",
        hero(n_sp, "species", icon = "flower3", tone = "navy", nav = "diversity"),
        hero(nrow(lb), "plots", icon = "grid-3x3", tone = "pine", nav = "map"),
        hero(if (is.na(site_intro)) 0 else site_intro, "% introduced cover", icon = "shield-exclamation", tone = "terra", nav = "invasive",
             ttl = "Share of vegetative cover that is introduced. Cover is an ocular estimate and plant layers overlap, so this is a relative index — not a percent of ground.",
             sub = if (!is.na(ucs)) sprintf("%.0f%% of cover is unknown status", ucs)),
        hero(n_intro, "introduced species", icon = "exclamation-triangle", tone = "gold", nav = "invasive")))
  })

  # ---- OVERVIEW -----------------------------------------------------------
  output$coverBar <- renderPlotly({
    occ <- rv$snap; req(occ)
    psc <- plot_species_cover(occ); if (is.null(psc)) return(note_plot("No cover data to summarise"))
    nat1 <- psc %>% dplyr::group_by(.data$scientificName) %>%
      dplyr::summarise(nativity = mode_chr(.data$nativity), .groups = "drop")   # one status per species
    agg <- psc %>% dplyr::group_by(.data$scientificName) %>%
      dplyr::summarise(cover = sum(.data$mean_cover), .groups = "drop") %>%
      dplyr::left_join(nat1, by = "scientificName") %>%
      dplyr::arrange(dplyr::desc(.data$cover)) %>% head(20)
    agg$scientificName <- factor(agg$scientificName, levels = rev(agg$scientificName))
    cols <- NATIVITY_COLS[agg$nativity]
    plot_ly(agg, x = ~cover, y = ~scientificName, type = "bar", orientation = "h",
      marker = list(color = unname(cols)),
      hovertemplate = paste0("%{y}<br>", agg$nativity, " · %{x:.1f} relative cover<extra></extra>")) %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE, xaxis = list(title = "Relative cover (summed across plots)"),
        yaxis = list(title = ""), margin = list(l = 200))
  })
  output$overviewInsight <- renderUI({
    occ <- rv$snap; req(occ); psc <- plot_species_cover(occ); req(!is.null(psc))
    top <- psc %>% dplyr::group_by(.data$scientificName, .data$nativity) %>%
      dplyr::summarise(c = sum(.data$mean_cover), .groups = "drop") %>% dplyr::arrange(dplyr::desc(.data$c))
    dom <- top$scientificName[1]; dom_nat <- top$nativity[1]
    insight_banner("stars", tone = if (dom_nat == "Introduced") "terra" else "pine",
      HTML(sprintf("<b><i>%s</i></b> is the most dominant plant across the site (%s). The site holds <span class='ci-hero'>%d</span> plant species across %d plots.",
        dom, tolower(dom_nat), dplyr::n_distinct(species_level_only(occ)$scientificName), nrow(rv$lb))))
  })
  output$siteInsights <- renderUI({
    occ <- rv$snap; lb <- rv$lb; req(occ, lb)
    sa <- species_area_site(occ); ch <- chao2(occ); wl <- invasive_watchlist(occ); ur <- unknown_rate(occ)
    pts <- c()
    if (!is.null(sa)) pts <- c(pts, sprintf("In the latest survey, a 1 m² quadrat holds about <b>%.0f</b> species; the full 400 m² plot reaches <b>%.0f</b>.", sa$richness[sa$area_m2==1], sa$richness[sa$area_m2==400]))
    if (!is.null(ch)) pts <- c(pts, sprintf("Across the plots, <b>%d</b> species were recorded; Chao2 estimates at least <b>%.0f</b> are present%s.", ch$S_obs, ch$chao2, if (ch$unstable) " (a rough floor)" else ""))
    if (!is.null(wl) && nrow(wl)) pts <- c(pts, sprintf("The most widespread introduced plant is <b><i>%s</i></b>, in <b>%d</b> of %d plots.", wl$scientificName[1], wl$n_plots[1], nrow(lb)))
    pts <- c(pts, sprintf("Native status is unknown for %.0f%% of species — read the native/invasive numbers with that in mind.", ur))
    div(class = "insight-list", lapply(pts, function(t) div(class = "il-item", bs_icon("dot"), HTML(t))))
  })
  output$groundBar <- renderPlotly({
    g <- ground_summary(rv$ground); if (is.null(g)) return(note_plot("No ground-cover data"))
    g <- head(g, 10); g$otherVariables <- factor(g$otherVariables, levels = rev(g$otherVariables))
    plot_ly(g, x = ~mean_cover, y = ~otherVariables, type = "bar", orientation = "h",
      marker = list(color = "#8a6d4b"),
      hovertemplate = "%{y}<br>%{x:.0f}% mean cover<extra></extra>") %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE, xaxis = list(title = "Mean 1 m² cover (%)"),
        yaxis = list(title = ""), margin = list(l = 150))
  })

  # ---- DIVERSITY ----------------------------------------------------------
  output$saPlot <- renderPlotly({
    occ <- rv$snap; req(occ); sa <- species_area_site(occ); if (is.null(sa)) return(note_plot("Not enough data for a species–area curve"))
    # the curve is a MEAN across n plots per area — carry its spread (±1 sd) as a
    # band and surface n so the reader sees how many plots back each point.
    sa$sd[!is.finite(sa$sd)] <- 0
    sa$n  <- ifelse(is.finite(sa$n), sa$n, 0)
    sa$nlab <- paste0("mean of ", sa$n, " plot", ifelse(sa$n == 1, "", "s"))
    plot_ly(sa, x = ~area_m2, y = ~richness, type = "scatter", mode = "lines+markers",
      line = list(color = DDL$green, width = 3), marker = list(color = DDL$green2, size = 9),
      error_y = list(type = "data", array = sa$sd, color = "rgba(46,125,50,0.35)", thickness = 1.4, width = 4),
      text = sa$nlab,
      hovertemplate = "%{x} m²<br>%{y:.0f} species (±%{error_y.array:.1f})<br>%{text}<extra></extra>") %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(xaxis = list(title = "Area sampled (m², log)", type = "log",
        tickvals = c(1,10,100,400), ticktext = c("1","10","100","400")),
        yaxis = list(title = "Mean species richness"))
  })
  output$saInsight <- renderUI({
    occ <- rv$snap; req(occ); sa <- species_area_site(occ); req(!is.null(sa))
    slope <- (sa$richness[sa$area_m2==400] - sa$richness[sa$area_m2==100])
    n400 <- sa$n[sa$area_m2==400]; if (!length(n400) || !is.finite(n400)) n400 <- 0
    shape <- if (n400 < 5)
        sprintf(" Based on just <b>%.0f</b> plot%s, so read the shape as a rough floor, not a firm curve.", n400, ifelse(n400 == 1, "", "s"))
      else if (slope > 15) " Still rising steeply at 400 m² — the site is undersampled, there's more out there."
      else " The curve is flattening — most species are being caught."
    insight_banner("graph-up", tone = "pine",
      HTML(sprintf("Richness climbs from <b>%.0f</b> species/m² to <span class='ci-hero'>%.0f</span> per 400 m² plot.%s",
        sa$richness[sa$area_m2==1], sa$richness[sa$area_m2==400], shape)))
  })
  output$hillPlot <- renderPlotly({
    occ <- rv$snap; req(occ); h <- hill_site(occ); if (is.null(h)) return(note_plot("Not enough cover data"))
    df <- data.frame(q = c("q0\nrichness","q1\ncommon","q2\ndominant"), v = as.numeric(h))
    df$q <- factor(df$q, levels = df$q)
    # q0 ≥ q1 ≥ q2 is ONE ordered quantity, not three categories — paint it a
    # single-hue lightness ramp of the primary so the colour can't imply types.
    plot_ly(df, x = ~q, y = ~v, type = "bar",
      marker = list(color = c("#1F5C3D", "#3E8B5E", "#86C2A1")),
      text = ~round(v), textposition = "outside",
      hovertemplate = "%{x}<br>%{y:.1f} effective species<extra></extra>") %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE, xaxis = list(title = ""), yaxis = list(title = "Effective # of species"))
  })
  output$hillInsight <- renderUI({
    occ <- rv$snap; req(occ); h <- hill_site(occ); req(!is.null(h))
    even <- round(h["q1"] / h["q0"], 2)
    tagList(
      insight_banner("diagram-2", tone = "navy",
        HTML(sprintf("Of <b>%.0f</b> species, only <span class='ci-hero'>%.0f</span> are effectively common (q1). Evenness ≈ <b>%.2f</b> — %s.",
          h["q0"], h["q1"], even, if (even < 0.25) "a few species dominate the cover" else "cover is fairly spread"))),
      p(class = "hill-foot", bsicons::bs_icon("info-circle"),
        " q1/q2 weight species by cover — an ocular index whose overlapping layers make it a relative measure, not a share of ground."))
  })
  output$chaoBanner <- renderUI({
    occ <- rv$snap; req(occ); ch <- chao2(occ); req(!is.null(ch))
    insight_banner("calculator", tone = "gold",
      HTML(sprintf("In the latest survey, <b>%d</b> species were seen across %d 1 m² quadrats. <b>Chao2</b> estimates <span class='ci-hero'>%.0f</span> species present%s (95%% CI %s–%s) — so roughly <b>%.0f</b> remain undetected.",
        ch$S_obs, ch$m, ch$chao2, if (ch$unstable) ", a lower bound (few doubletons)" else "",
        ifelse(is.na(ch$lo),"—",ch$lo), ifelse(is.na(ch$hi),"—",ch$hi), max(0, round(ch$chao2 - ch$S_obs)))))
  })

  # ---- NATIVE vs INVASIVE -------------------------------------------------
  output$invTrend <- renderPlotly({
    occ <- rv$occ; req(occ); nt <- native_trend(occ); if (is.null(nt) || !nrow(nt)) return(note_plot("No introduced-cover trend"))
    plot_ly(nt, x = ~year, y = ~pct_introduced, type = "scatter", mode = "lines+markers",
      line = list(color = DDL$introduced, width = 3), marker = list(color = DDL$introduced, size = 9),
      hovertemplate = "%{x}<br>%{y:.1f}% introduced cover<extra></extra>") %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE, xaxis = list(title = "", dtick = 1),
        yaxis = list(title = "% of cover introduced", rangemode = "tozero"))
  })
  output$invInsight <- renderUI({
    occ <- rv$occ; req(occ); nt <- native_trend(occ); ur <- unknown_rate(rv$snap); req(!is.null(nt))
    fin <- nt[is.finite(nt$pct_introduced), , drop = FALSE]; req(nrow(fin) >= 1)
    last <- fin[nrow(fin), ]; first <- fin[1, ]
    dir <- if (nrow(fin) < 2 || last$pct_introduced == first$pct_introduced) "about the same as"
           else if (last$pct_introduced > first$pct_introduced) "up from" else "down from"
    insight_banner("shield-exclamation", tone = "terra",
      HTML(sprintf("Introduced plants make up <span class='ci-hero'>%.1f%%</span> of cover in %d — %s %.1f%% in %d. Native status is unknown for %.0f%% of species.",
        last$pct_introduced, last$year, dir, first$pct_introduced, first$year, ur)))
  })
  output$invTable <- DT::renderDT({
    occ <- rv$snap; req(occ); wl <- invasive_watchlist(occ)
    if (is.null(wl) || !nrow(wl)) return(DT::datatable(data.frame(Message = "No introduced species recorded here."), rownames = FALSE, options = list(dom = "t")))
    df <- data.frame(Species = wl$scientificName, Family = wl$family,
                     `Mean cover %` = wl$mean_cover, `# plots` = wl$n_plots, check.names = FALSE)
    DT::datatable(df, rownames = FALSE, options = list(pageLength = 8, dom = "tp", order = list(list(2, "desc"))))
  })
  output$pressurePlot <- renderPlotly({
    occ <- rv$snap; req(occ); ip <- invasion_pressure(occ); if (is.null(ip) || !nrow(ip)) return(note_plot("No invasion-pressure data"))
    ip$lab <- short_plot(ip$plotID)
    mx <- max(c(ip$intro_1m, ip$intro_400), 1)
    # both axes are small integer counts, so ties pile up invisibly at (0,0) and
    # on the 1:1 line — nudge the DISPLAY positions deterministically while the
    # hover still reports the TRUE integers (carried in customdata).
    set.seed(1)
    ip$jx <- ip$intro_1m  + stats::runif(nrow(ip), -0.12, 0.12)
    ip$jy <- ip$intro_400 + stats::runif(nrow(ip), -0.12, 0.12)
    ip$cd <- lapply(seq_len(nrow(ip)), function(i) list(ip$lab[i], ip$intro_1m[i], ip$intro_400[i]))
    plot_ly(ip, x = ~jx, y = ~jy, type = "scatter", mode = "markers",
      customdata = ~cd, marker = list(color = DDL$introduced, size = 11, opacity = 0.7, line = list(color = "#fff", width = 1)),
      hovertemplate = "plot %{customdata[0]}<br>%{customdata[1]} introduced at 1 m²<br>%{customdata[2]} introduced in 400 m²<extra></extra>") %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE,
        xaxis = list(title = "Introduced species detectable at 1 m²", rangemode = "tozero"),
        yaxis = list(title = "Introduced species in the whole 400 m² plot", rangemode = "tozero"),
        shapes = list(list(type = "line", x0 = 0, y0 = 0, x1 = mx, y1 = mx,
          line = list(color = "rgba(120,130,140,0.5)", dash = "dot", width = 1))),
        annotations = list(list(text = "on the 1:1 line = every invader is already at the finest scale (points jittered to separate ties)",
          x = 0, y = 1.06, xref = "paper", yref = "paper", showarrow = FALSE, xanchor = "left",
          font = list(color = if (is_dark()) "#9fb0c4" else "#6b7a85", size = 11))))
  })

  # ---- ENVIRONMENT (climate & phenology vs the plant signal) -------------
  # Env data loads lazily per site (only when something on this tab renders).
  cur_env <- reactive({ s <- rv$site; if (is.null(s) || !nzchar(s)) return(NULL); load_env(s) })

  observe({                                       # populate the driver picker from this site's data
    e <- cur_env(); ch <- c("Strongest driver" = "best")
    if (!is.null(e)) ch <- c(ch, env_layer_choices(e)[-1])
    sel <- input$envLayer %||% "best"; if (!(sel %in% ch)) sel <- "best"
    updateSelectInput(session, "envLayer", choices = ch, selected = sel)
  })

  env_series <- reactive({ req(rv$occ); plant_metric_series(rv$occ, input$envMetric %||% "richness") })
  env_rank   <- reactive({ ms <- env_series(); e <- cur_env(); if (is.null(ms) || is.null(e)) NULL else plant_env_all(ms, e) })
  env_perm   <- reactive({
    ms <- env_series(); e <- cur_env(); if (is.null(ms) || is.null(e)) return(NULL)
    lay <- input$envLayer %||% "best"
    plant_env_perm(ms, e, B = 499, only = if (lay == "best") NULL else lay)
  })
  env_metric_lab <- reactive(PLANT_METRICS[[input$envMetric %||% "richness"]]$label)
  env_metric_dig <- reactive(PLANT_METRICS[[input$envMetric %||% "richness"]]$dig %||% 1)

  output$envSourceNote <- renderUI({
    if (is.null(cur_env())) return(NULL)
    div(class = "env-source env-real", bs_icon("patch-check-fill"),
        tags$span(HTML(sprintf(" Live from co-located NEON sensors at <b>%s</b> — precipitation, air temperature, and plant phenology, aggregated to one value per year.",
                               rv$site %||% "this site"))))
  })

  output$envCorrNote <- renderUI({
    e <- cur_env(); ms <- env_series()
    if (is.null(e)) return(div(class = "chart-insight ci-muted", bs_icon("cloud-slash"),
      div(class = "ci-text", "No co-located environmental data is bundled for this site yet.")))
    if (is.null(ms) || nrow(ms) < MIN_ENV_YEARS)
      return(div(class = "chart-insight ci-muted", bs_icon("hourglass-split"),
        div(class = "ci-text", HTML(sprintf("Only <b>%d</b> survey year%s here — too few to test a climate link (need %d+). The series below still show the raw context.",
          if (is.null(ms)) 0L else nrow(ms), if (!is.null(ms) && nrow(ms) == 1) "" else "s", MIN_ENV_YEARS)))))
    pm <- env_perm(); if (is.null(pm)) return(NULL); pk <- pm$top
    v <- env_verdict(pk$r, pm$p, pk$n); pos <- pk$r >= 0
    rail <- switch(v$tone, strong = "rail-strong", mod = "rail-mod", "rail-weak")
    lagtxt <- if (pk$lag == 0) "same-year signal" else if (pk$lag == 1) "1-yr lead" else sprintf("%d-yr lead", pk$lag)
    metricLab <- env_metric_lab()
    div(class = paste("ec", rail),
      style = sprintf("--ec-driver-hue:%s;", ENV_LAYERS[[pk$layer]]$color %||% "#8a97a8"),
      div(class = "ec-eyebrow", bs_icon("graph-up-arrow"), tags$span("climate & phenology tracking"),
          tags$span(class = "ec-demo", "exploratory")),
      div(class = "ec-hero",
        div(class = "ec-hero-text",
          tags$span(class = "ec-strength", tools::toTitleCase(v$word)), " — ", tolower(metricLab), " vs ",
          tags$span(class = "ec-driver", tolower(pk$label))),
        div(class = paste("ec-rvalue", if (pos) "ec-sgn-pos" else "ec-sgn-neg"),
          title = "Spearman rank-correlation, -1 to +1, at the best lag",
          bs_icon(if (pos) "arrow-up-right" else "arrow-down-right"), HTML(sprintf("r&nbsp;%+.2f", pk$r)))),
      div(class = "ec-foot",
        tags$span(class = "ec-meta", bs_icon("clock-history"), lagtxt),
        tags$span(class = "ec-meta-dot"),
        tags$span(class = "ec-meta", bs_icon("calendar3"), HTML(sprintf("<b>%d</b> survey years", pk$n))),
        tags$span(class = "ec-meta-dot"),
        tags$span(class = "ec-meta", bs_icon("shuffle"), HTML(sprintf("permutation <b>p = %.2f</b>", pm$p))),
        tags$span(class = paste("ec-meta ec-dir", if (pos) "ec-sgn-pos" else "ec-sgn-neg"),
          HTML(sprintf("more %s \U2192 <b>%s</b> %s", tolower(pk$label), if (pos) "more" else "less", tolower(metricLab))))))
  })

  output$envCaveat <- renderUI({
    pm <- env_perm(); if (is.null(pm)) return(NULL); pk <- pm$top
    n_drv <- if (is.null(env_rank())) 0L else nrow(env_rank())
    sig <- !is.na(pm$p) && pm$p < 0.05
    div(class = "pop-caveat", style = "margin: 0 0 14px;", bs_icon("exclamation-triangle"),
      HTML(sprintf(" The r above is the <b>strongest of %d driver%s \U00D7 3 lags</b>; the permutation p (%.2f) already accounts for that search. %s With only %d survey years, climate and vegetation can also drift together over time, so even a strong-looking r is a hypothesis, not proof of cause.",
        n_drv, if (n_drv == 1) "" else "s", pm$p,
        if (sig) "It clears the chance bar here." else "It does <b>not</b> clear the chance bar here.",
        pk$n)))
  })

  output$envScatter <- renderPlotly({
    e <- cur_env(); ms <- env_series(); pm <- env_perm()
    if (is.null(e) || is.null(ms)) return(note_plot("No environmental data for this site", "\U0001F326"))
    if (is.null(pm)) return(note_plot("Too few survey years to compare", "\U0001F326"))
    pk <- pm$top; meta <- ENV_LAYERS[[pk$layer]]
    pts <- plant_env_points(ms, e, pk$layer, pk$lag)
    if (is.null(pts) || nrow(pts) < 3) return(note_plot("Not enough year-matched data for this driver", "\U0001F326"))
    metricLab <- env_metric_lab(); mdig <- env_metric_dig()
    p <- plot_ly(pts, x = ~driver, y = ~metric, type = "scatter", mode = "markers+text",
      text = ~year, textposition = "top center",
      textfont = list(size = 10, color = if (is_dark()) "#9fb0c4" else "#6b7a85"),
      marker = list(size = 12, color = meta$color, opacity = 0.85, line = list(color = "#fff", width = 1)),
      hovertemplate = paste0("year %{text}<br>", meta$label, ": %{x:.", (meta$dig %||% 0), "f} ", meta$unit,
                             "<br>", metricLab, ": %{y:.", mdig, "f}<extra></extra>"))
    if (stats::sd(pts$driver) > 0) {
      fit <- stats::lm(metric ~ driver, data = pts); xs <- range(pts$driver)
      yh <- stats::predict(fit, newdata = data.frame(driver = xs))
      p <- p %>% add_trace(x = xs, y = yh, type = "scatter", mode = "lines", inherit = FALSE,
        showlegend = FALSE, hoverinfo = "skip",
        line = list(color = ec_corr_color(pk$layer, pk$r, is_dark()), width = 2, dash = "dash"))
    }
    p %>% plotly_theme(legend = FALSE) %>% plotly::layout(
      xaxis = list(title = sprintf("%s (%s)%s", meta$label, meta$unit, if (pk$lag) sprintf(" \U00B7 %d-yr lead", pk$lag) else "")),
      yaxis = list(title = metricLab))
  })

  output$envDriverRank <- renderPlotly({
    r <- env_rank(); if (is.null(r) || !nrow(r)) return(note_plot("Too few survey years to rank drivers", "\U0001F326"))
    r <- r[order(abs(r$r)), ]
    r$lab <- ifelse(r$lag == 0, "same yr", sprintf("%d-yr lead", r$lag))
    r$ccol <- mapply(ec_corr_color, r$layer, r$r, MoreArgs = list(dark = is_dark()))
    n_drv <- nrow(r)
    plot_ly(r, x = ~r, y = ~factor(label, levels = label), type = "bar", orientation = "h",
      marker = list(color = ~ccol),
      text = ~sprintf("r %+.2f \U00B7 %s \U00B7 n=%d", r, lab, n), textposition = "auto",
      hovertemplate = ~paste0("<b>", label, "</b><br>r %{x:+.2f} at ", lab, " \U00B7 n=", n, "<extra></extra>")) %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(
        xaxis = list(title = "Spearman r with the plant signal — left of 0 = inverse",
                     range = c(-1, 1), zeroline = TRUE, zerolinecolor = "rgba(31,42,48,0.30)"),
        yaxis = list(title = ""), margin = list(b = 72),
        annotations = list(list(
          text = sprintf("best of %d driver%s \U00D7 3 lags \U00B7 sorted by strength \U00B7 NOT independent evidence",
                         n_drv, if (n_drv == 1) "" else "s"),
          x = 0, y = -0.30, xref = "paper", yref = "paper", xanchor = "left", yanchor = "top",
          showarrow = FALSE, font = list(color = if (is_dark()) "#9fb0c4" else "#8a97a8", size = 10))))
  })

  output$envTrend <- renderPlotly({
    e <- cur_env(); ms <- env_series(); pm <- env_perm()
    if (is.null(e) || is.null(ms)) return(note_plot("No environmental data for this site", "\U0001F326"))
    lay <- if (!is.null(pm)) pm$top$layer else { rk <- env_rank(); if (!is.null(rk)) rk$layer[1] else NA }
    if (is.na(lay) || is.null(ENV_LAYERS[[lay]])) return(note_plot("No driver to overlay", "\U0001F326"))
    meta <- ENV_LAYERS[[lay]]; ea <- env_annual(e, lay)
    metricLab <- env_metric_lab(); mdig <- env_metric_dig()
    p <- plot_ly()
    if (!is.null(ea) && nrow(ea)) p <- p %>% add_trace(data = ea, x = ~year, y = ~value, yaxis = "y2",
      type = "scatter", mode = "lines+markers", name = meta$label,
      line = list(color = meta$color, width = 2, shape = "spline"), marker = list(color = meta$color, size = 7),
      hovertemplate = paste0(meta$label, " %{x}: %{y:.", (meta$dig %||% 0), "f} ", meta$unit, "<extra></extra>"))
    p <- p %>% add_trace(data = ms, x = ~year, y = ~value, type = "scatter", mode = "lines+markers",
      name = metricLab, line = list(color = DDL$green2, width = 3), marker = list(color = DDL$green, size = 9),
      hovertemplate = paste0(metricLab, " %{x}: %{y:.", mdig, "f}<extra></extra>"))
    p %>% plotly_theme() %>% plotly::layout(
      xaxis = list(title = "", dtick = 1),
      yaxis = list(title = metricLab, rangemode = "tozero"),
      yaxis2 = list(title = sprintf("%s (%s)", meta$label, meta$unit), overlaying = "y", side = "right",
                    showgrid = FALSE, rangemode = "tozero", color = meta$color))
  })

  # ---- DIVERSITY LAB (the flagship pin-card scatter) ---------------------
  output$labScatter <- renderPlotly({
    lb <- rv$lb; req(lb)
    pts <- lb[is.finite(lb$richness), , drop = FALSE]
    pts$piv <- ifelse(is.na(pts$pct_introduced), 0, pts$pct_introduced)
    pts$short <- short_plot(pts$plotID)
    # colour key
    keycol <- input$labColor %||% "nlcdClass"
    if (keycol == "domfam") {
      fam <- vapply(pts$dominant, function(s) { occ <- rv$occ; f <- occ$family[occ$scientificName == s][1]; if (is.na(f)) "—" else f }, character(1))
      pts$key <- fam
    } else pts$key <- as.character(pts[[keycol]])
    pts$key[is.na(pts$key) | pts$key == ""] <- "—"
    # family/NLCD colouring can yield many keys; an interpolated Dark2 muddies
    # past 8. Collapse to the top-8 by point count + an "Other" bucket, then map
    # straight onto the CVD-safe Okabe-Ito set so the legend always fits (≤9).
    keep <- names(sort(table(pts$key), decreasing = TRUE))
    keep <- keep[seq_len(min(8, length(keep)))]
    pts$key[!(pts$key %in% keep)] <- "Other"
    keys <- c(keep, if (any(pts$key == "Other")) "Other")
    kpal <- setNames(OKABE_ITO[seq_along(keep)], keep)
    if (any(pts$key == "Other")) kpal["Other"] <- "#999999"

    # per-plot pin-card HTML (customdata) — the .smt-open chip opens the plot profile
    tip <- paste0(
      "<span class='smt-pin-emoji'>\U0001F33E</span> <b>", pts$short, "</b> ",
      "<span class='smt-pin-rar'>", pts$richness, " species</span><br/>",
      "<span class='smt-pin-stats'>",
        pts$n_native, " native · ", pts$n_introduced, " introduced",
        ifelse(is.na(pts$pct_introduced), "", paste0(" · ", pts$pct_introduced, "% introduced cover")),
        "<br/>dominant: <i>", ifelse(is.na(pts$dominant), "—", pts$dominant), "</i></span>",
      "<br/><span class='smt-open' role='button' tabindex='0' data-tag='", pts$plotID,
        "'>\U0001F33F Open plot profile &rarr;</span>",
      "<br/><em class='smt-pin-hint'>Tap the dot to pin this card</em>")
    pts$tip <- tip

    p <- plot_ly()
    for (k in keys) {
      sub <- pts[pts$key == k, ]
      p <- p %>% add_trace(data = sub, x = ~richness, y = ~piv, type = "scatter", mode = "markers",
        name = k, customdata = ~tip, showlegend = TRUE,
        marker = list(color = unname(kpal[k]), size = 13, opacity = 0.82, line = list(color = "#fff", width = 0.8)),
        text = ~paste0("plot ", short, " · ", richness, " spp"),
        hovertemplate = "%{text}<br>%{y:.1f}% introduced cover<extra></extra>")
    }
    # median crosshairs + named quadrants
    qcol <- if (is_dark()) "#7e8da0" else "#9aa6b2"
    mx <- stats::median(pts$richness); my <- stats::median(pts$piv)
    xr <- range(pts$richness); yr <- range(pts$piv); padx <- diff(xr)*0.02; pady <- max(diff(yr)*0.02, 0.3)
    qlab <- function(x,y,t,xa,ya) list(text=t, x=x, y=y, xref="x", yref="y", showarrow=FALSE,
      xanchor=xa, yanchor=ya, font=list(color=qcol, size=10.5))
    ann <- list(
      list(text = "each dot is a plot · richness × how invaded its cover is",
        x = 0, y = 1.07, xref = "paper", yref = "paper", showarrow = FALSE, xanchor = "left",
        font = list(color = if (is_dark()) "#9fb0c4" else "#6b7a85", size = 11)),
      qlab(xr[1]+padx, yr[2]-pady, "SPARSE & INVADED", "left", "top"),
      qlab(xr[2]-padx, yr[2]-pady, "RICH BUT INVADED", "right", "top"),
      qlab(xr[1]+padx, yr[1]+pady, "SPARSE NATIVE", "left", "bottom"),
      qlab(xr[2]-padx, yr[1]+pady, "RICH & NATIVE \U0001F3C6", "right", "bottom"))
    # gold diamond for the selected plot
    if (!is.null(rv$plot)) {
      ir <- pts[pts$plotID == rv$plot, ]
      if (nrow(ir) == 1) p <- p %>% add_trace(x = ir$richness, y = ir$piv, type = "scatter", mode = "markers",
        name = "★ viewing", customdata = ir$tip, showlegend = TRUE,
        marker = list(symbol = "diamond", size = 18, color = "#c9a300", line = list(color = "#fff", width = 1.6)),
        hovertemplate = paste0("viewing plot ", ir$short, "<extra></extra>"))
    }
    # (no site/year caption here — the long quadrant subtitle owns the top strip;
    #  the site is already in the hero band, so a right-anchored caption collides.)
    p %>% plotly_theme() %>% plotly::layout(
      xaxis = list(title = "Species richness (400 m² plot)"),
      yaxis = list(title = "% of cover introduced", rangemode = "tozero"),
      shapes = list(
        list(type="line", xref="x", yref="paper", x0=mx, x1=mx, y0=0, y1=1, line=list(color=qcol, dash="dot", width=1)),
        list(type="line", xref="paper", yref="y", x0=0, x1=1, y0=my, y1=my, line=list(color=qcol, dash="dot", width=1))),
      annotations = ann, hovermode = "closest")
  })

  output$plotCardSlot <- renderUI({
    if (is.null(rv$plot)) return(div(class = "qc-empty",
      div(class = "qc-empty-icon", "\U0001F33F"),
      h4("Tap a plot to see its card"),
      p("Tap a dot above and choose “Open plot profile”, or pick a plot in the sidebar.")))
    lb <- rv$lb; row <- lb[lb$plotID == rv$plot, ]; if (!nrow(row)) return(NULL)
    div(class = "lab-sel",
      span(class = "ls-emoji", "\U0001F33E"),
      div(class = "ls-body",
        div(class = "ls-id", tags$b(short_plot(rv$plot)),
          sprintf(" — %d species · %d native · %d introduced", row$richness, row$n_native, row$n_introduced),
          if (!is.na(row$pct_introduced)) sprintf(" · %s%% introduced cover", row$pct_introduced)),
        div(class = "ls-dom", "dominant: ", em(ifelse(is.na(row$dominant), "—", row$dominant)))),
      actionButton("goPlotFromCard", tagList(bs_icon("arrows-fullscreen"), " Open full profile"),
                   class = "btn-outline-dark btn-sm"))
  })

  # ---- PLOT PROFILE (the funnel target, downloadable) --------------------
  plot_card_ui <- function(pid) {
    lb <- rv$lb; occ <- rv$snap; row <- lb[lb$plotID == pid, ]; if (!nrow(row)) return(NULL)
    psc <- plot_species_cover(occ); psc <- if (is.null(psc)) NULL else psc[psc$plotID == pid, ]
    sa <- species_area_plot(occ, pid)
    tile <- function(v, l) div(class = "qc-tile", div(class = "qc-tile-v", v), div(class = "qc-tile-l", l))
    pivbar <- {
      nat <- ifelse(is.na(row$native_cover), 0, row$native_cover); intro <- ifelse(is.na(row$intro_cover), 0, row$intro_cover)
      tot <- nat + intro; np <- if (tot>0) round(100*nat/tot) else 0; ip <- 100 - np
      div(class = "piv-bar", title = sprintf("%d%% native / %d%% introduced cover", np, ip),
        div(class = "piv-native", style = sprintf("width:%d%%", np), if (np>12) paste0(np,"% native")),
        div(class = "piv-intro", style = sprintf("width:%d%%", ip), if (ip>12) paste0(ip,"% intro")))
    }
    sparkid <- paste0("spark_", gsub("[^A-Za-z0-9]", "", pid))
    body <- div(id = "qcCardNode", class = "qc-card", `data-short` = short_plot(pid),
      div(class = "qc-head",
        span(class = "qc-emoji", "\U0001F33E"),
        div(div(class = "qc-id", short_plot(pid),
              if (!is.na(row$pct_introduced) && row$pct_introduced >= 10)
                span(class = "ds-warn", bs_icon("shield-exclamation"), " invaded")),
            div(class = "qc-sci", sprintf("NEON plot · %s · %s", row$plotType %||% "", row$nlcdClass %||% ""))),
        div(class = "qc-head-badges", glow_badge(paste0(row$richness, " species"), DDL$green))),
      div(class = "qc-tiles",
        tile(row$richness, "richness"),
        tile(row$n_native, "native"),
        tile(row$n_introduced, "introduced"),
        tile(ifelse(is.na(row$pct_introduced), "—", paste0(row$pct_introduced, "%")), "introduced cover"),
        tile(ifelse(is.na(row$total_cover), "—", row$total_cover), "total cover")),
      div(class = "qc-section-h", bs_icon("layout-split"), " Native vs introduced cover"), pivbar,
      div(class = "qc-section-h", bs_icon("graph-up"), " Species–area (1→400 m²)"),
      if (!is.null(sa)) plotlyOutput(sparkid, height = "150px") else p(class = "qc-cap-note", "—"),
      div(class = "qc-section-h", bs_icon("flower2"), " Top plants by cover"),
      if (!is.null(psc) && nrow(psc)) {
        top <- psc[order(-psc$mean_cover), ][seq_len(min(10, nrow(psc))), ]
        div(class = "qc-cap-scroll", tags$table(class = "inspect-tbl",
          tags$thead(tags$tr(lapply(c("Species","Family","Nativity","Mean cover %"), tags$th))),
          tags$tbody(lapply(seq_len(nrow(top)), function(i) tags$tr(
            tags$td(em(top$scientificName[i])), tags$td(top$family[i] %||% "—"),
            tags$td(span(style = sprintf("color:%s;font-weight:600", NATIVITY_COLS[top$nativity[i]]), top$nativity[i])),
            tags$td(top$mean_cover[i]))))))
      } else p(class = "qc-cap-note", "No 1 m² cover recorded for this plot."))
    div(body, div(class = "qc-toolbar",
      tags$button(class = "smt-snap-btn", type = "button", onclick = "smtSaveQcCard()", bsicons::bs_icon("download"), " Save plot card (PNG)"),
      downloadButton("plotCsv", "Download plot data (CSV)", class = "smt-clear-btn")))
  }
  # spark renderers for both compact + full cards (same output id; only one card in DOM per render path is fine
  # because compact (Lab) and full (Plot) live in different tabs but share #qcCardNode id — guard below)
  observe({
    pid <- rv$plot; req(pid)
    sparkid <- paste0("spark_", gsub("[^A-Za-z0-9]", "", pid))
    output[[sparkid]] <- renderPlotly({
      sa <- species_area_plot(rv$snap, pid); if (is.null(sa)) return(note_plot("—"))
      plot_ly(sa, x = ~area_m2, y = ~richness, type = "scatter", mode = "lines+markers",
        line = list(color = DDL$green, width = 2.5), marker = list(color = DDL$green2, size = 7),
        hovertemplate = "%{x} m²<br>%{y:.0f} species<extra></extra>") %>%
        plotly_theme(legend = FALSE) %>%
        plotly::layout(xaxis = list(title = "", type = "log", tickvals = c(1,10,100,400), ticktext = c("1","10","100","400")),
          yaxis = list(title = "species"), margin = list(l = 40, r = 10, t = 10, b = 30))
    })
  })
  observeEvent(input$goPlotFromCard, nav_select("tabs", "plot"))

  output$plotProfile <- renderUI({
    if (is.null(rv$plot)) return(div(class = "qc-empty",
      div(class = "qc-empty-icon", "\U0001F33F"),
      h4("Pick a plot to open its profile"),
      p("Use the Diversity Lab (tap a dot → “Open plot profile”) or the sidebar plot picker.")))
    div(class = "plot-profile-wrap", plot_card_ui(rv$plot))
  })

  output$plotCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_%s.csv", rv$plot %||% "plot", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      occ <- rv$occ; pid <- rv$plot; req(occ, pid)
      d <- species_level_only(occ); d <- d[d$plotID == pid, c("plotID","subplotID","scale","year","scientificName","family","nativity","percentCover")]
      utils::write.csv(d[order(d$scientificName, d$scale), ], file, row.names = FALSE, na = "")
    }, contentType = "text/csv")

  # ---- MAP ----------------------------------------------------------------
  output$map <- leaflet::renderLeaflet({
    lb <- rv$lb; req(lb)
    # drop coord-less / non-finite plots so the map can't render blank or fit to NA
    lb <- lb[is.finite(lb$lat) & is.finite(lb$lng), , drop = FALSE]
    validate(need(nrow(lb) > 0, "No plots have mappable coordinates for this site."))
    metric <- input$mapMetric %||% "pct_introduced"
    val <- if (metric == "pct_introduced") ifelse(is.na(lb$pct_introduced), 0, lb$pct_introduced) else lb$richness
    # guard a degenerate (all-equal) domain so colorNumeric doesn't error
    dom <- if (diff(range(val, na.rm = TRUE)) > 0) range(val, na.rm = TRUE) else c(val[1] - 1, val[1] + 1)
    # % introduced is a one-ended magnitude, not a diverging metric — a SEQUENTIAL
    # single-hue sand→clay ramp (no false midpoint, no native-green reuse).
    pal <- leaflet::colorNumeric(if (metric == "pct_introduced") c("#F3E9D8","#D9A066","#B85C38") else "viridis", domain = dom)
    bm <- input$view %||% "Esri.WorldImagery"
    rr <- range(lb$richness, na.rm = TRUE)
    lb$radius <- if (diff(rr) > 0) 6 + 14 * (lb$richness - rr[1]) / diff(rr) else 11
    leaflet::leaflet(lb) %>% leaflet::addProviderTiles(bm) %>%
      leaflet::addCircleMarkers(lng = ~lng, lat = ~lat,
        radius = ~radius, fillColor = pal(val), color = "#fff", weight = 1, fillOpacity = 0.85,
        label = ~lapply(sprintf("<b>%s</b><br>%d species · %s%% introduced cover", short_plot(plotID), richness,
          ifelse(is.na(pct_introduced), "—", pct_introduced)), htmltools::HTML),
        layerId = ~plotID) %>%
      leaflet::fitBounds(min(lb$lng), min(lb$lat), max(lb$lng), max(lb$lat)) %>%
      leaflet::addLegend("bottomright", pal = pal, values = val,
        title = if (metric == "pct_introduced") "% introduced" else "richness")
  })
  observeEvent(input$map_marker_click, { p <- input$map_marker_click$id; if (!is.null(p)) pick_plot(p, navigate = TRUE) })

  # ---- EXPECTED vs OBSERVED (the EcoPlot completeness + QC lens) -----------
  observeEvent(input$goExpected, nav_select("tabs", "expected"))

  expected_for_site <- reactive({ load_expected(rv$site) })
  evo <- reactive({
    occ <- rv$occ; e <- expected_for_site()
    if (is.null(occ) || is.null(e)) return(NULL)
    expected_vs_observed(occ, e, PLANT_AUTHORITY)
  })
  coarse_flag <- reactive({ occ <- rv$occ; req(occ); flag_coarse_rank(occ) })

  # hide the three reference-comparison cards when no ESD reference list is bundled
  # for this site (otherwise three empty cards read as "broken"); the coarse-rank
  # advisory + data-quality cross-checks below stay visible — they need only occ.
  # hide via a CSS class (not shinyjs inline display, which would set display:block and
  # break the bslib card's flex fill -> 0-width DTs). removeClass restores display:flex.
  observe({
    if (is.null(expected_for_site())) shinyjs::addClass(selector = ".evo-bucket", class = "evo-hidden")
    else shinyjs::removeClass(selector = ".evo-bucket", class = "evo-hidden")
  })

  evo_empty_dt <- function(msg) DT::datatable(data.frame(Note = msg), rownames = FALSE,
    options = list(dom = "t"), colnames = "")

  # reference ecological-site header
  output$evoHeader <- renderUI({
    req(rv$occ)
    e <- expected_for_site()
    if (is.null(e)) return(insight_banner("info-circle", tone = "navy",
      HTML("No NRCS ecological-site reference list is bundled for this site <i>yet</i> — the completeness comparison is live for Santa Rita (SRER) and a growing set of sites. Everything else on this page still works.")))
    src <- e$source %||% "esd"
    badge <- if (identical(src, "esd")) glow_badge("ecological site", DDL$navy) else glow_badge("MLRA union", DDL$gold)
    # only link to EDIT for a standard rangeland/forest ecoclassid that will resolve
    # (e.g. NIWO's alpine "G…" group code 404s) — otherwise show the id as plain text
    link_ok <- identical(src, "esd") && grepl("^[RF][0-9]{3}[A-Z]", e$ecoclassid %||% "") && nzchar(e$mlra %||% "")
    cite <- if (link_ok) tags$a(class = "evo-cite", target = "_blank", rel = "noopener",
        href = sprintf("https://edit.sc.egov.usda.gov/catalogs/esd/%s/%s", e$mlra, e$ecoclassid),
        bs_icon("box-arrow-up-right"), " view on EDIT (USDA Ecological Site)") else NULL
    div(class = "evo-header",
      bs_icon("geo-fill"),
      HTML(sprintf(" Reference community: <b>%s</b> &nbsp;<code>%s</code> &nbsp;·&nbsp; MLRA&nbsp;%s &nbsp;",
        htmltools::htmlEscape(e$ecosite_name %||% "—"), e$ecoclassid, e$mlra)),
      badge, cite)
  })

  # headline value boxes + match-rate honesty line
  output$evoHeadline <- renderUI({
    ev <- evo(); if (is.null(ev)) return(NULL)
    cr <- coarse_flag(); mr <- qc_match_rate(rv$occ, expected_for_site(), PLANT_AUTHORITY)
    box <- function(v, l, tone, sub = NULL) div(class = paste0("evo-box evo-box-", tone),
      div(class = "evo-box-v", v), div(class = "evo-box-l", l),
      if (!is.null(sub)) div(class = "evo-box-sub", sub))
    resolved <- if (is.finite(cr$pct_records)) 100 - cr$pct_records else NA_real_
    floor_note <- if (is.finite(cr$pct_records) && cr$pct_records >= 10)
      sprintf(" · a floor (%.0f%% of records coarser than species)", cr$pct_records) else ""
    dom_box <- if (identical(ev$dom_basis, "none") || ev$dom_total == 0)
      box("—", "reference dominants", "navy", "not production-ranked for this ecological site")
    else
      box(sprintf("%d / %d", ev$dom_obs, ev$dom_total), "reference dominants observed", "navy",
          "the core species — top 50% of reference production")
    rev_sub <- sprintf("%d introduced · %d native%s", ev$n_review_intro, ev$n_review_native,
      if (ev$n_review_unknown > 0) sprintf(" · %d unknown", ev$n_review_unknown) else "")
    div(
      div(class = "evo-boxrow",
        box(sprintf("%.0f%%", ev$overlap_pct), "of reference species detected", "green",
            sprintf("%d of %d%s", ev$n_overlap, ev$n_ref, floor_note)),
        dom_box,
        box(as.character(nrow(ev$C)), "observed, not in reference", "clay", rev_sub),
        box(if (is.finite(resolved)) sprintf("%.0f%%", resolved) else "—",
            "identified to species", "amber", "the rest are genus / family only")),
      div(class = "evo-matchnote", bs_icon("info-circle"),
        HTML(sprintf(" One survey per plot, species level only. Reference community: <b>%d</b> species (%d entries incl. genus/aggregate codes). NEON's plant codes <i>are</i> USDA PLANTS symbols, so species join USDA directly (synonyms collapsed to the accepted name).%s NEON samples ~400&nbsp;m² per plot, so <b>expected-but-absent reflects completeness, not error.</b>",
          mr$ref_n_species, mr$ref_n_all,
          if (!identical(ev$dom_basis, "none")) " Dominants = the core species making up the top 50% of reference production." else ""))))
  })

  # Flag 1 — coarse-rank advisory, surfaced FIRST (frames every other comparison)
  output$evoCoarse <- renderUI({
    cr <- coarse_flag(); if (is.null(cr) || !is.finite(cr$pct_records) || cr$pct_records < 1) return(NULL)
    insight_banner("info-circle", tone = "navy",
      HTML(sprintf("<b>%.0f%%</b> of records here are identified coarser than species — genus, family, or just “plant”%s. These can't be matched to a species-level reference list, so read the comparisons below as a floor, not a census.",
        cr$pct_records,
        if (is.finite(cr$pct_cover)) sprintf(", carrying <b>%.0f%%</b> of measured cover", cr$pct_cover) else "")))
  })

  # Bucket A — reference flora detected (green)
  output$evoTableA <- DT::renderDT({
    ev <- evo(); if (is.null(ev)) return(evo_empty_dt("No reference comparison is available for this site."))
    A <- ev$A; if (!nrow(A)) return(evo_empty_dt("None of the reference species were detected in the sampled plots."))
    df <- data.frame(Symbol = A$plantsym, Species = A$sciname, `Common name` = A$comname,
      Role = ifelse(A$is_dominant %in% TRUE, "dominant", "associated"),
      `Ref. production (lb/ac)` = ifelse(is.finite(A$rangeprod), A$rangeprod, NA),
      `Observed cover %` = ifelse(is.finite(A$obs_cover), A$obs_cover, NA),
      `# plots` = A$obs_plots, check.names = FALSE)
    DT::datatable(df, rownames = FALSE, options = list(pageLength = 10, dom = "tp", scrollX = TRUE,
      order = list(list(4, "desc")), columnDefs = list(list(className = "dt-center", targets = 3:6)))) %>%
      DT::formatStyle("Role", target = "row", fontWeight = DT::styleEqual("dominant", "700"))
  })

  # Bucket C — observed, not in reference (clay; the review lane)
  output$evoTableC <- DT::renderDT({
    ev <- evo(); if (is.null(ev)) return(evo_empty_dt("No reference comparison is available for this site."))
    C <- ev$C; if (!nrow(C)) return(evo_empty_dt("Every observed species is on the reference list — nothing to review."))
    df <- data.frame(Symbol = C$sym, Species = C$scientificName, Family = C$family,
      Nativity = C$nativity, `Mean cover %` = ifelse(is.finite(C$mean_cover), C$mean_cover, NA),
      `# plots` = C$n_plots, check.names = FALSE)
    DT::datatable(df, rownames = FALSE, options = list(pageLength = 10, dom = "tp", scrollX = TRUE,
      order = list(list(5, "desc")), columnDefs = list(list(className = "dt-center", targets = 4:5)))) %>%
      DT::formatStyle("Nativity", fontWeight = "bold",
        color = DT::styleEqual(c("Introduced", "Native", "Unknown"),
                               c(DDL$introduced, DDL$green, DDL$muted)))
  })

  # Bucket B — expected but not detected (neutral completeness; dominants highlighted)
  output$evoTableB <- DT::renderDT({
    ev <- evo(); if (is.null(ev)) return(evo_empty_dt("No reference comparison is available for this site."))
    B <- ev$B; if (!nrow(B)) return(evo_empty_dt("Every reference species was detected — a complete sample of the reference flora."))
    df <- data.frame(Symbol = B$plantsym, Species = B$sciname, `Common name` = B$comname,
      Role = ifelse(B$is_dominant %in% TRUE, "dominant", "associated"),
      `Ref. production (lb/ac)` = ifelse(is.finite(B$rangeprod), B$rangeprod, NA), check.names = FALSE)
    DT::datatable(df, rownames = FALSE, options = list(pageLength = 10, dom = "tp", scrollX = TRUE,
      order = list(list(4, "desc")), columnDefs = list(list(className = "dt-center", targets = 3:4)))) %>%
      DT::formatStyle("Role", target = "row", fontWeight = DT::styleEqual("dominant", "700"))
  })

  # Flags 2 + 4 — the true data-quality cross-checks
  output$evoFlags <- renderUI({
    occ <- rv$occ; req(occ)
    nm <- tryCatch(flag_nativity_mismatch(occ, PLANT_AUTHORITY), error = function(e) NULL)
    cs <- tryCatch(flag_cover_sum(occ), error = function(e) list(rows = data.frame(), n = 0L, ceiling = 250))
    nm_ui <- if (is.null(nm)) {
      div(class = "evo-flag evo-flag-muted", bs_icon("hourglass-split"),
        HTML(" <b>Nativity cross-check (NEON vs USDA):</b> needs the USDA PLANTS authority file — being added in a follow-up build. NEON's own native/introduced labels are used everywhere else on the page."))
    } else if (nm$n == 0) {
      div(class = "evo-flag evo-flag-clean", bs_icon("check2-circle"),
        HTML(" <b>Nativity cross-check (NEON vs USDA):</b> no disagreements — every species' native/introduced label matches USDA PLANTS."))
    } else {
      rows <- utils::head(nm$rows, 12)
      div(class = "evo-flag evo-flag-warn",
        div(class = "evo-flag-h", bs_icon("exclamation-triangle-fill"),
          sprintf(" %d species: NEON's nativity label disagrees with USDA PLANTS", nm$n)),
        tags$table(class = "evo-flag-tbl",
          tags$thead(tags$tr(tags$th("Species"), tags$th("NEON"), tags$th("USDA"), tags$th("# plots"))),
          tags$tbody(lapply(seq_len(nrow(rows)), function(i) tags$tr(
            tags$td(tags$i(rows$scientificName[i])), tags$td(rows$nativity[i]),
            tags$td(rows$usda_nativity[i]), tags$td(rows$n_plots[i]))))),
        if (nm$n > 12) div(class = "evo-flag-more", sprintf("+ %d more in the full report (CSV)", nm$n - 12)),
        div(class = "evo-flag-note", "Nativity is regional — USDA's lower-48 label and NEON's site label can legitimately differ at a range edge. Worth a look, not necessarily an error."))
    }
    cs_ui <- if (cs$n == 0) {
      div(class = "evo-flag evo-flag-clean", bs_icon("check2-circle"),
        HTML(sprintf(" <b>Cover sanity:</b> no 1 m² quadrat sums above %d%% — within what overlapping canopy layers explain.", cs$ceiling)))
    } else {
      div(class = "evo-flag evo-flag-warn",
        div(class = "evo-flag-h", bs_icon("exclamation-triangle-fill"),
          sprintf(" %d quadrat-visits sum above %d%% cover (possible entry error)", cs$n, cs$ceiling)),
        tags$table(class = "evo-flag-tbl",
          tags$thead(tags$tr(tags$th("Plot"), tags$th("Subplot"), tags$th("Year"), tags$th("Total cover %"))),
          tags$tbody(lapply(seq_len(min(nrow(cs$rows), 12)), function(i) tags$tr(
            tags$td(short_plot(cs$rows$plotID[i])), tags$td(cs$rows$subplotID[i]),
            tags$td(cs$rows$year[i]), tags$td(sprintf("%.0f", cs$rows$total_cover[i])))))))
    }
    tagList(nm_ui, cs_ui)
  })

  # downloads — per bucket + the combined report
  .evo_dl <- function(getdf, tag) downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_%s_%s.csv", rv$site %||% "site", tag, format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      ev <- evo(); df <- if (is.null(ev)) data.frame() else getdf(ev)
      utils::write.csv(df %||% data.frame(), file, row.names = FALSE, na = "")
    }, contentType = "text/csv")
  output$evoCsvA <- .evo_dl(function(ev) {
    A <- ev$A; if (is.null(A) || !nrow(A)) return(data.frame())
    data.frame(symbol = A$plantsym, scientificName = A$sciname, commonName = A$comname,
      reference_role = ifelse(A$is_dominant %in% TRUE, "dominant", "associated"),
      reference_production = A$rangeprod, observed_cover_pct = A$obs_cover, n_plots = A$obs_plots) }, "expected-observed")
  output$evoCsvB <- .evo_dl(function(ev) {
    B <- ev$B; if (is.null(B) || !nrow(B)) return(data.frame())
    data.frame(symbol = B$plantsym, scientificName = B$sciname, commonName = B$comname,
      reference_role = ifelse(B$is_dominant %in% TRUE, "dominant", "associated"),
      reference_production = B$rangeprod) }, "expected-absent")
  output$evoCsvC <- .evo_dl(function(ev) {
    C <- ev$C; if (is.null(C) || !nrow(C)) return(data.frame())
    data.frame(symbol = C$sym, scientificName = C$scientificName, family = C$family,
      nativity = C$nativity, mean_cover_pct = C$mean_cover, n_plots = C$n_plots) }, "observed-not-expected")
  output$evoReport <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_completeness-report_%s.csv", rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      ev <- evo(); tbl <- qc_report_table(ev, site = rv$site %||% NA_character_)
      if (is.null(tbl) || !nrow(tbl))
        tbl <- data.frame(note = sprintf("No NRCS ecological-site reference list is bundled for %s — completeness comparison unavailable.",
                                          rv$site %||% "this site"))
      utils::write.csv(tbl, file, row.names = FALSE, na = "")
    }, contentType = "text/csv")

  # ---- ABOUT --------------------------------------------------------------
  output$aboutPanel <- renderUI({
    div(class = "about-wrap",
      div(class = "about-card", h4("\U0001F33F What this is"),
        p("An (unofficial) explorer for NEON's ", tags$b("Plant presence & percent cover"), " product (", tags$code("DP1.10058.001"),
          "). NEON surveys plants in nested quadrats — 1 m² subplots (presence + percent cover), 10 m² and 100 m² subplots (presence), combined into a 400 m² plot list — at peak greenness each year.")),
      div(class = "about-card", h4(bs_icon("rulers"), " How richness is measured"),
        p("Species–area curves come straight from the nested design: a 1 m² quadrat, a 10 m² subplot, a 100 m² corner, the whole 400 m² plot. ",
          tags$b("Chao2"), " (incidence-based) estimates how many species remain undetected — the right estimator for presence/quadrat data."),
        p(class = "caveat", bs_icon("exclamation-triangle"), " Cover is an ocular estimate and vegetation layers overlap, so site-summed cover is relative, not a share of ground.")),
      div(class = "about-card", h4(bs_icon("shield-exclamation"), " Native vs invasive"),
        p("Status is NEON's ", tags$code("nativeStatusCode"), " (N native / I introduced / others → unknown). We publish the ", tags$b("unknown rate"),
          " so the invasion numbers are read honestly. The ", tags$b("invasion-pressure"), " index uses the nested scales to flag invaders established at the finest grain.")),
      div(class = "about-card", h4(bs_icon("clipboard-check"), " Expected vs Observed"),
        p("We resolve each site's coordinates to its NRCS ", tags$b("Ecological Site"), " and pull that site's ",
          tags$b("reference plant community"), " (the plants the soil and climate can support), then compare it to what NEON actually recorded — the ", tags$b("EcoPlot"), " recipe."),
        p("Because NEON samples ~400 m² per plot at peak greenness, a reference species not detected is read as ",
          tags$b("completeness"), " (or a real state-transition), ", tags$b("never as error"), ". Only two lanes are true data-quality signals: coarse IDs and nativity disagreements with USDA PLANTS."),
        p(tags$b("Dominant"), " = the core species making up the top 50% of the ecological site's reference production (NRCS air-dry lb/ac at normal precipitation) — an app-defined, list-length-invariant convention, not an official NRCS designation. Forest ecological sites carry no per-species production (their dominants are canopy trees, scored by site index), so dominance isn't ranked there."),
        p(class = "caveat", bs_icon("info-circle"), " Reference flora: USDA-NRCS Soil Data Access / Ecological Site Descriptions (public domain). Nativity authority: USDA, NRCS, ",
          tags$a(href = "https://plants.usda.gov", target = "_blank", "The PLANTS Database"), ". NEON taxonomy follows USDA PLANTS symbols, so the match is an exact symbol join.")),
      div(class = "about-card", h4(bs_icon("diagram-3"), " A NEONize sibling"),
        p("Built to the NEON Small Mammal Tracker quality bar — same Desert Data Labs design system, bundling, and pin-card interaction — but the analyses are plant-native (there are no individuals to track in cover data). See the NEONize playbook."),
        p(bs_icon("envelope"), " ", tags$a(href = "mailto:desertdatalabs@gmail.com", "desertdatalabs@gmail.com"),
          " · ", tags$a(href = "https://data.neonscience.org/data-products/DP1.10058.001", target = "_blank", "NEON data product"))))
  })
}
