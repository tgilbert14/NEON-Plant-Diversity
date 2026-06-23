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
      hoverlabel = list(
        bgcolor = if (dark) "rgba(20,51,34,0.96)" else "rgba(47,154,79,0.96)",
        bordercolor = if (dark) "#5fd16a" else DDL$gold,
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
  # pendingSite carries a site picked on the map (or in the browse list) THROUGH
  # the state cascade so the sidebar dropdowns land on THAT site instead of
  # snapping back to the first site in the newly selected state.
  rv <- reactiveValues(occ = NULL, snap = NULL, ground = NULL, lb = NULL, pal = NULL,
                       label = NULL, site = NULL, plot = NULL, ctx = NULL, is_demo = FALSE,
                       pendingSite = NULL)

  # ---- pickers ------------------------------------------------------------
  observe({
    ch <- plant_state_choices()
    sel <- if ("AZ" %in% ch) "AZ" else NULL
    updateSelectInput(session, "stateSel", choices = ch, selected = sel)
  })
  # When the state changes, repopulate the site dropdown. Honour a pendingSite
  # (set by a map pick or a browse-list pick) so the sidebar reflects the site the
  # user chose; otherwise fall back to the first site in the state.
  observeEvent(input$stateSel, {
    sites <- plant_sites_in_state(input$stateSel)
    sel <- if (!is.null(rv$pendingSite) && rv$pendingSite %in% sites) rv$pendingSite
           else if (length(sites)) sites[[1]] else NULL
    rv$pendingSite <- NULL
    updateSelectInput(session, "site", choices = sites, selected = sel)
  }, ignoreNULL = TRUE)

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
          onclick = sprintf("smtLoadStart('%s · loading…');Shiny.setInputValue('pickSite','%s',{priority:'event'});return false;",
                            gsub("'", "", r$name), r$site),
          div(class = "sc-emoji", bs_icon("flower1")),
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
    session$sendCustomMessage("plantSite", list(site = b$meta$site %||% "site"))  # name the export PNGs by site
    rv$is_demo <- is_demo
    # export provenance: prefer the bundle's own build stamp; fall back to the
    # site .rds mtime (= the build vintage on already-shipped bundles, so this
    # works with no rebuild). neon_release is NA until a release-tagged refresh.
    rv$built_at <- b$meta$built_at %||% {
      f <- file.path(SITE_DIR, paste0(b$meta$site, ".rds"))
      if (file.exists(f)) format(as.Date(file.info(f)$mtime), "%Y-%m-%d") else NA_character_
    }
    rv$neon_release <- b$meta$neon_release %||% NA_character_
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
  # Picking a site somewhere OTHER than the sidebar (the map's Explore button, or
  # the browse list): first sync the sidebar dropdowns to THAT site (set
  # pendingSite, then cascade the state selector so the site dropdown lands on it),
  # then load it. The stateSel observer updates the dropdown choices only — it does
  # not load — so there is no double load.
  load_site_full <- function(site) {
    if (is.null(site) || !nzchar(site)) { session$sendCustomMessage("loadDone", list()); return() }
    m <- site_table[site_table$site == site, ]
    if (nrow(m)) {
      rv$pendingSite <- site
      if (identical(input$stateSel, m$state[1])) {
        rv$pendingSite <- NULL
        updateSelectInput(session, "site", selected = site)
      } else {
        updateSelectInput(session, "stateSel", selected = m$state[1])
      }
    }
    load_site(site)
  }
  observeEvent(input$loadBtn, load_site(input$site))
  observeEvent(input$pickSite, load_site_full(input$pickSite))

  # "Change site" (in the hero band) -> back to the picker-map landing.
  # Clears the loaded state, hides the loaded view + plot picker, re-shows the
  # splash, and kicks the picker map to re-measure so it never paints half-width.
  observeEvent(input$changeSite, {
    rv$occ <- NULL; rv$snap <- NULL; rv$ground <- NULL; rv$lb <- NULL
    rv$pal <- NULL; rv$label <- NULL; rv$site <- NULL; rv$plot <- NULL
    shinyjs::hide("mainTabsWrap"); shinyjs::hide("plotPickerWrap"); shinyjs::show("splash")
    session$sendCustomMessage("kickMaps", list())
  })

  # (v2 flow: the Santa Rita demo path was removed — users pick a real site on
  #  the map, the Browse-all-sites list, or the by-name select panel. The
  #  demoBtn / demoBtn2 inputs and their observers are gone with it.)

  # The map dot popup: a clear two-choice card (Explore loads the site, About
  # opens an instant info modal). Mirrors the flagship Small Mammal / Ground Beetle
  # picker. Explore raises the loading overlay client-side, then fires siteExplore;
  # About fires siteInfo (no load). Both run the SAME load path the sidebar uses.
  site_popup_html <- function(row) {
    code <- row$site[1]
    nm   <- row$name[1] %||% code
    where <- paste(stats::na.omit(c(as.character(row$state[1]),
      if (!is.na(row$domain[1])) paste("NEON", row$domain[1]) else NA)), collapse = " · ")
    pir <- if (is.finite(row$pct_introduced[1])) paste0(round(row$pct_introduced[1]), "%") else "n/a"
    fam <- if (!is.na(row$dominant_family[1]) && nzchar(as.character(row$dominant_family[1])))
      sprintf("<div class='pm-pop-sp'>Top family: %s</div>", row$dominant_family[1]) else ""
    htmltools::HTML(sprintf(
      "<div class='pm-pop site-pop'>
         <div class='pm-pop-t'>\U0001F33F %s <span class='sp-code'>(%s)</span></div>
         <div class='pm-pop-s'>%s</div>
         <div class='pm-pop-n'><b>%s</b> species &middot; <b>%s</b> introduced cover</div>
         %s
         <div class='sp-actions'>
           <button type='button' class='sp-btn sp-go' onclick=\"smtLoadStart('%s · loading');Shiny.setInputValue('siteExplore','%s',{priority:'event'});\">Explore this site &rarr;</button>
           <button type='button' class='sp-btn sp-info' onclick=\"Shiny.setInputValue('siteInfo','%s',{priority:'event'});\">About this site</button>
         </div>
       </div>",
      nm, code, where, row$richness[1] %||% "?", pir, fam,
      gsub("'", "", nm), code, code))
  }

  # "About this site" -> an instant info modal (no bundle load). Its footer also
  # offers Explore, so the modal is a second door into the same load path.
  site_info_modal <- function(code) {
    row <- site_table[site_table$site == code, ]
    m   <- neon_sites[neon_sites$site == code, ]
    if (!nrow(row))
      return(modalDialog(title = "Site info", easyClose = TRUE, footer = modalButton("Close"),
                         p("No details are available for this site.")))
    dash <- function(x) if (length(x) == 0 || is.na(x) || !nzchar(as.character(x))) "—" else as.character(x)
    coords <- if (nrow(m) && !is.na(m$lat[1]) && !is.na(m$lng[1]))
      sprintf("%.3f, %.3f", m$lat[1], m$lng[1]) else "—"
    stat <- function(v, lab) div(class = "si-stat",
      div(class = "si-stat-n", if (is.null(v) || is.na(v)) "—" else format(v, big.mark = ",")),
      div(class = "si-stat-l", lab))
    pir <- if (is.finite(row$pct_introduced[1])) paste0(round(row$pct_introduced[1]), "%") else "—"
    modalDialog(
      title = HTML(sprintf("\U0001F33F %s <span class='si-code'>(%s)</span>", row$name[1] %||% code, code)),
      easyClose = TRUE, size = "m",
      footer = tagList(
        modalButton("Close"),
        tags$button(type = "button", class = "btn btn-primary",
          onclick = sprintf("smtLoadStart('%s · loading');Shiny.setInputValue('siteExplore','%s',{priority:'event'});",
                            gsub("'", "", row$name[1] %||% code), code),
          HTML("Explore this site &rarr;"))),
      div(class = "site-info",
        div(class = "si-sec",
          div(class = "si-h", "Where"),
          div(class = "si-row", dash(row$state[1]),
              if (nrow(m)) HTML(sprintf(" · NEON %s", dash(m$domain[1]))) else NULL),
          if (nrow(m) && !is.na(m$bio[1])) div(class = "si-row si-bio", m$bio[1]),
          div(class = "si-coords", "\U0001F4CD ", coords)),
        div(class = "si-sec",
          div(class = "si-h", "What's been collected"),
          div(class = "si-stats",
            stat(row$richness[1], "species"),
            stat(row$n_plots[1], "plots")),
          div(class = "si-row si-star", "Introduced cover: ", tags$b(pir)),
          if (!is.na(row$dominant_family[1]) && nzchar(as.character(row$dominant_family[1])))
            div(class = "si-row si-star", "Top family: ", tags$i(row$dominant_family[1])) else NULL)))
  }

  # national site-picker map on the splash: dot size = richness; colour toggles
  # between invasion (% introduced cover) and completeness (% of the NRCS reference
  # flora detected — the Expected-vs-Observed spatial read). Tap a dot for the
  # Explore | About choice popup; the load comes from the popup's Explore button.
  local({
    mx <- suppressWarnings(max(site_table$pct_introduced, na.rm = TRUE)); if (!is.finite(mx)) mx <- 100
    pip_pal  <- leaflet::colorNumeric("YlOrBr", domain = c(0, mx), na.color = "#c9d3bb")
    comp_pal <- leaflet::colorNumeric(c("#E7E0CC", "#7FB07A", "#1F5C3D"), domain = c(0, 100), na.color = "#c9d3bb")
    color_by <- function() input$splashColorBy %||% "invasion"
    mapPickerServer("picker", site_table = site_table, radius_metric = "richness",
      color_fn = function(st) if (identical(color_by(), "completeness"))
          comp_pal(st$pct_detected) else pip_pal(st$pct_introduced),
      label_fn = function(r) sprintf("<b>%s</b> · %s, %s<br><b>%s</b> species · <b>%s</b> introduced cover · <b>%s</b> reference flora detected",
        r$site, r$name %||% r$site, r$state %||% "", r$richness %||% "?",
        if (is.finite(r$pct_introduced)) paste0(round(r$pct_introduced), "%") else "n/a",
        if (is.finite(r$pct_detected)) paste0(round(r$pct_detected), "%") else "no ref list"),
      popup_fn = site_popup_html)
  })
  # "Explore this site" (map popup OR About-modal footer) -> sync the sidebar to
  # this site, then load it. load_site_full() runs in the MAIN server context so
  # ingest()'s shinyjs::hide("splash") isn't namespaced to the picker module.
  observeEvent(input$siteExplore, {
    removeModal()
    s <- input$siteExplore; if (is.null(s) || !nzchar(s)) { session$sendCustomMessage("loadDone", list()); return() }
    load_site_full(s)
  })
  # "About this site" -> instant info modal (no bundle load)
  observeEvent(input$siteInfo, showModal(site_info_modal(input$siteInfo)))
  output$splashLegend <- renderUI({
    if (identical(input$splashColorBy %||% "invasion", "completeness"))
      div(class = "splash-legend",
        span(class = "sl-ramp sl-comp"), " low → high % of the NRCS reference flora detected",
        span(class = "sl-na"), " grey = no reference list bundled")
    else
      div(class = "splash-legend",
        span(class = "sl-ramp sl-inv"), " low → high % introduced cover (how invaded)")
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
        tags$li(HTML("Pick a <b>site</b> on the map (or by name in the panel below it). Numbers describe the <b>most recent survey</b> of each plot. Use <b>change site</b> in the hero band to switch.")),
        tags$li(HTML("<b>Diversity</b>: the nested species-area curve (1→400 m²), the Hill profile, and a Chao2 estimate of undetected species.")),
        tags$li(HTML("<b>Native vs Invasive</b>: how much cover is introduced, which species, and where invasion has a foothold at the finest scale.")),
        tags$li(HTML("<b>Diversity Lab</b>: every plot as a dot; <b>tap one</b> to pin its card, then “Open plot profile” for the full, downloadable drill-down.")),
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

  # ---- Search the network -------------------------------------------------
  # Filters the small in-memory SEARCH_INDEX (built at boot from the committed
  # bundles) — no live fetch, instant. Two modes: find a species across sites,
  # and filter sites by introduced/native cover share. Both jump to a site's
  # Overview through the SAME load_site_full() the map / sidebar use.
  site_name_of <- function(code) {
    r <- site_table[site_table$site == code, ]
    if (nrow(r) && !is.na(r$name[1])) r$name[1] else code
  }
  # a per-row "Explore" button: raises the loading overlay client-side, then
  # fires searchGo (priority event) -> load_site_full(). Same pattern as the map.
  search_go_btn <- function(code) {
    sprintf("<button class='sp-btn sp-go search-go' onclick=\"smtLoadStart('%s &middot; loading');Shiny.setInputValue('searchGo','%s',{priority:'event'});\">Explore &rarr;</button>",
            code, code)
  }

  # populate the autocompletes server-side (3.5k taxa -> keep the client light)
  observe({
    updateSelectizeInput(session, "searchTaxon", choices = SEARCH_TAXON_CHOICES,
                         selected = "", server = TRUE)
    updateSelectizeInput(session, "threshInvader", choices = SEARCH_INVADER_CHOICES,
                         selected = "", server = TRUE)
  })

  # the rows for the picked species (one per site it occurs at)
  search_taxon_rows <- reactive({
    req(input$searchTaxon, nzchar(input$searchTaxon))
    if (is.null(SEARCH_TAXA)) return(NULL)
    d <- SEARCH_TAXA[SEARCH_TAXA$scientificName == input$searchTaxon, , drop = FALSE]
    if (!nrow(d)) return(d)
    d[order(-dplyr::coalesce(d$mean_cover, -1)), , drop = FALSE]
  })

  output$searchTaxonMeta <- renderUI({
    d <- search_taxon_rows()
    if (is.null(d) || !nrow(d)) return(NULL)
    nat <- mode_chr(d$nativity); fam <- mode_chr(d$family)
    tone <- switch(nat %||% "Unknown", Native = "native", Introduced = "introduced", "unknown")
    div(class = "search-taxon-meta",
      span(class = paste0("nat-chip nat-", tone), nat %||% "Unknown"),
      if (!is.na(fam)) span(class = "dim", " · ", em(fam)))
  })

  output$searchTaxonCount <- renderUI({
    d <- search_taxon_rows()
    n <- if (is.null(d)) 0 else nrow(d)
    tot <- if (!is.null(SEARCH_INDEX)) nrow(SEARCH_INDEX$sites) else length(BUNDLED)
    if (!nzchar(input$searchTaxon %||% ""))
      return(p(class = "dim search-count", "Pick a species to see where it occurs."))
    p(class = "search-count", sprintf("%d of %d sites", n, tot))
  })

  output$searchTaxonTbl <- renderDT({
    d <- search_taxon_rows()
    if (is.null(d) || !nrow(d))
      return(datatable(data.frame(Message = "No bundled site has this species."),
                       rownames = FALSE, options = list(dom = "t"), selection = "none"))
    yrs <- ifelse(is.na(d$year_min), "",
                  ifelse(d$year_min == d$year_max, as.character(d$year_min),
                         paste0(d$year_min, "–", d$year_max)))
    cov <- ifelse(is.na(d$mean_cover), "presence only", sprintf("%.2f%%", d$mean_cover))
    # "% cover" DISPLAYS with the % suffix but must SORT by magnitude, not as a
    # string ("10" < "9" lexicographically). Carry a hidden numeric sort key
    # (presence-only -> -1 so it ranks below all real cover) and point the visible
    # column's order at it via orderData; the key column is hidden from view.
    cov_sort <- ifelse(is.na(d$mean_cover), -1, d$mean_cover)
    out <- data.frame(Site = sprintf("%s &middot; %s", d$site, vapply(d$site, site_name_of, "")),
                      `% cover` = cov, Plots = d$n_plots, Years = yrs,
                      Go = vapply(d$site, search_go_btn, ""),
                      `_cov_sort` = cov_sort,
                      check.names = FALSE, stringsAsFactors = FALSE)
    datatable(out, rownames = FALSE, escape = FALSE, selection = "none",
              options = list(pageLength = 12, dom = "tip",
                             columnDefs = list(
                               list(orderable = FALSE, targets = 4),
                               list(orderData = 5, targets = 1),   # "% cover" sorts by hidden numeric key
                               list(visible = FALSE, targets = 5)  # hide the sort key column
                             )))
  })

  # threshold query: sites by introduced/native cover share, OR jump to a site
  # list filtered to an invader. The "where is invader X" path reuses the taxon
  # rows (sites that HAVE that introduced species, ranked by its cover there).
  search_thresh_rows <- reactive({
    inv <- input$threshInvader %||% ""
    if (nzchar(inv) && !is.null(SEARCH_TAXA)) {
      d <- SEARCH_TAXA[SEARCH_TAXA$scientificName == inv, , drop = FALSE]
      if (!nrow(d)) return(list(mode = "invader", inv = inv, df = d[0, ]))
      df <- data.frame(site = d$site,
                       value = d$mean_cover,
                       label = sprintf("%s cover", inv),
                       stringsAsFactors = FALSE)
      df <- df[order(-dplyr::coalesce(df$value, -1)), , drop = FALSE]
      return(list(mode = "invader", inv = inv, df = df))
    }
    # the % threshold path runs on the canonical site_index pct_introduced (the
    # SAME number as each site's hero), with a native counterpart derived as the
    # complement-free native share when requested.
    s <- if (!is.null(SEARCH_INDEX)) SEARCH_INDEX$sites else SITE_INDEX
    if (is.null(s) || !nrow(s)) return(list(mode = "pct", df = data.frame()))
    val <- s$pct_introduced
    lab <- "% introduced cover"
    if (identical(input$threshNativity, "Native")) {
      # native share is recomputed per site from the index taxa (cover-weighted),
      # so it matches the introduced share's denominator exactly.
      val <- vapply(s$site, function(st) {
        d <- SEARCH_TAXA[SEARCH_TAXA$site == st & is.finite(SEARCH_TAXA$mean_cover), ]
        tot <- sum(d$mean_cover, na.rm = TRUE)
        if (tot > 0) round(100 * sum(d$mean_cover[d$nativity == "Native"], na.rm = TRUE) / tot, 1) else NA_real_
      }, numeric(1))
      lab <- "% native cover"
    }
    thr <- suppressWarnings(as.numeric(input$threshPct)); if (!is.finite(thr)) thr <- 0
    keep <- if (identical(input$threshDir, "le")) is.finite(val) & val <= thr else is.finite(val) & val >= thr
    df <- data.frame(site = s$site[keep], value = val[keep], label = lab, stringsAsFactors = FALSE)
    df <- df[order(-df$value), , drop = FALSE]
    list(mode = "pct", dir = input$threshDir, thr = thr, lab = lab, df = df,
         total = nrow(s))
  })

  output$searchThreshCount <- renderUI({
    r <- search_thresh_rows(); n <- nrow(r$df)
    tot <- if (!is.null(SEARCH_INDEX)) nrow(SEARCH_INDEX$sites) else length(BUNDLED)
    if (identical(r$mode, "invader")) {
      if (!n) return(p(class = "dim search-count", sprintf("No bundled site has %s.", r$inv)))
      return(p(class = "search-count", sprintf("%s found at %d of %d sites", r$inv, n, tot)))
    }
    p(class = "search-count", sprintf("%d of %d sites", n, tot))
  })

  output$searchThreshTbl <- renderDT({
    r <- search_thresh_rows()
    if (is.null(r$df) || !nrow(r$df))
      return(datatable(data.frame(Message = "No site matches that filter."),
                       rownames = FALSE, options = list(dom = "t"), selection = "none"))
    d <- r$df
    cov <- ifelse(is.na(d$value), "presence only", sprintf("%.1f%%", d$value))
    colname <- if (identical(r$mode, "invader")) "% cover (site)" else d$label[1]
    # cover column DISPLAYS the % suffix but must SORT numerically (not as a
    # string). Hidden numeric sort key (presence-only -> -1) + orderData, same
    # recipe as searchTaxonTbl.
    cov_sort <- ifelse(is.na(d$value), -1, d$value)
    out <- data.frame(Site = sprintf("%s &middot; %s", d$site, vapply(d$site, site_name_of, "")),
                      x = cov, Go = vapply(d$site, search_go_btn, ""),
                      `_cov_sort` = cov_sort,
                      check.names = FALSE, stringsAsFactors = FALSE)
    names(out)[2] <- colname
    datatable(out, rownames = FALSE, escape = FALSE, selection = "none",
              options = list(pageLength = 12, dom = "tip",
                             columnDefs = list(
                               list(orderable = FALSE, targets = 2),
                               list(orderData = 3, targets = 1),   # cover column sorts by hidden numeric key
                               list(visible = FALSE, targets = 3)  # hide the sort key column
                             )))
  })

  # the go-to-site jump: load the bundle (instant) and land on the Overview.
  observeEvent(input$searchGo, {
    s <- input$searchGo
    if (is.null(s) || !nzchar(s)) { session$sendCustomMessage("loadDone", list()); return() }
    load_site_full(s)   # syncs the sidebar, loads from the bundle, nav -> overview
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
      div(class = "hero-title", bs_icon("broadcast"), tags$b(rv$label),
        actionLink("changeSite", tagList(bs_icon("arrow-left-circle"), " change site"),
                   class = "hero-change"),
        downloadLink("reportPdf", tagList(bs_icon("file-earmark-arrow-down"), " report card (PDF)"),
                     class = "hero-report")),
      div(class = "hero-grid",
        hero(n_sp, "species", icon = "flower3", tone = "navy", nav = "diversity"),
        hero(nrow(lb), "plots", icon = "grid-3x3", tone = "pine", nav = "map"),
        hero(if (is.na(site_intro)) 0 else site_intro, "% introduced cover", icon = "shield-exclamation", tone = "terra", nav = "invasive",
             ttl = "Share of vegetative cover that is introduced. Cover is an ocular estimate and plant layers overlap, so this is a relative index, not a percent of ground.",
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
    pts <- c(pts, sprintf("Native status is unknown for %.0f%% of species; read the native/invasive numbers with that in mind.", ur))
    div(class = "insight-list", lapply(pts, function(t) div(class = "il-item", bs_icon("dot"), HTML(t))))
  })
  output$groundBar <- renderPlotly({
    g <- ground_summary(rv$ground); if (is.null(g)) return(note_plot("No ground-cover data"))
    g <- head(g, 10); g$otherVariables <- factor(g$otherVariables, levels = rev(g$otherVariables))
    # ground-cover bars are NOT a data-encoded palette (one decorative earth tone) -
    # so brighten it on the dark theme; the light brown is muddy on the dark paper.
    gcol <- if (is_dark()) "#c79a6e" else "#8a6d4b"
    plot_ly(g, x = ~mean_cover, y = ~otherVariables, type = "bar", orientation = "h",
      marker = list(color = gcol),
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
    # per-area pin-card HTML (customdata) — one card per nested quadrat scale
    sa$tip <- paste0(
      "<span class='smt-pin-emoji'>\U0001F4D0</span> <b>", sa$area_m2, " m\U00B2</b> ",
      "<span class='smt-pin-rar'>", round(sa$richness), " species</span><br/>",
      "<span class='smt-pin-stats'>mean of ", sa$n, " plot", ifelse(sa$n == 1, "", "s"),
        " \U00B7 \U00B1", round(sa$sd, 1), " sd</span>",
      "<br/><em class='smt-pin-hint'>Tap a point to pin this card</em>")
    plot_ly(sa, x = ~area_m2, y = ~richness, type = "scatter", mode = "lines+markers",
      customdata = ~tip,
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
      else if (slope > 15) " Still rising steeply at 400 m²; the site is undersampled, there's more out there."
      else " The curve is flattening; most species are being caught."
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
    # On the dark theme the dark pole (#1F5C3D) all but vanishes on the dark
    # paper, so use a brightened green ramp that keeps the dark->light ordering.
    hill_ramp <- if (is_dark()) c("#4FA877", "#86C2A1", "#C7E8D4") else c("#1F5C3D", "#3E8B5E", "#86C2A1")
    df$qk <- c("q0", "q1", "q2")   # customdata key -> which bar was clicked
    plot_ly(df, x = ~q, y = ~v, type = "bar", source = "hillSrc",
      marker = list(color = hill_ramp), customdata = ~qk,
      text = ~round(v), textposition = "outside",
      hovertemplate = "%{x}<br>%{y:.1f} effective species<br><i>click to see the species behind this</i><extra></extra>") %>%
      plotly::event_register("plotly_click") %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE, xaxis = list(title = ""), yaxis = list(title = "Effective # of species"))
  })
  output$hillInsight <- renderUI({
    occ <- rv$snap; req(occ); h <- hill_site(occ); req(!is.null(h))
    even <- round(h["q1"] / h["q0"], 2)
    tagList(
      insight_banner("diagram-2", tone = "navy",
        HTML(sprintf("Of <b>%.0f</b> species, only <span class='ci-hero'>%.0f</span> are effectively common (q1). Evenness ≈ <b>%.2f</b>: %s.",
          h["q0"], h["q1"], even, if (even < 0.25) "a few species dominate the cover" else "cover is fairly spread"))),
      p(class = "hill-foot", bsicons::bs_icon("info-circle"),
        " q1/q2 weight species by cover, an ocular index whose overlapping layers make it a relative measure, not a share of ground."))
  })
  output$chaoBanner <- renderUI({
    occ <- rv$snap; req(occ); ch <- chao2(occ); req(!is.null(ch))
    insight_banner("calculator", tone = "gold",
      HTML(sprintf("In the latest survey, <b>%d</b> species were seen across %d 1 m² quadrats. <b>Chao2</b> estimates <span class='ci-hero'>%.0f</span> species present%s (95%% CI %s–%s), so roughly <b>%.0f</b> remain undetected.",
        ch$S_obs, ch$m, ch$chao2, if (ch$unstable) ", a lower bound (few doubletons)" else "",
        ifelse(is.na(ch$lo),"—",ch$lo), ifelse(is.na(ch$hi),"—",ch$hi), max(0, round(ch$chao2 - ch$S_obs)))))
  })

  # ---- Hill member-reveal: click a q0/q1/q2 bar -> the species behind it ----
  # q1 (and q2) are evenness-weighted EFFECTIVE numbers (~N species), NOT a
  # hand-picked set of exactly N names — so the modal shows the FULL ranked-by-
  # cover list and marks the top round(q1) as the cluster "effectively common ~N"
  # describes, with that honest caveat in the header. Reuses the QC inspector +
  # downloadHandler pattern.
  hill_ranked <- reactive({ occ <- rv$snap; req(occ); hill_ranked_species(occ) })
  hill_csv_df <- function() {
    rk <- hill_ranked(); h <- hill_site(rv$snap)
    if (is.null(rk) || !nrow(rk)) return(data.frame(note = "No cover data to rank species for this site."))
    ec <- if (!is.null(h)) max(1, round(h["q1"])) else NA_integer_
    rk$effective_common_core <- if (is.na(ec)) NA else ifelse(rk$rank <= ec, "yes", "no")
    rk[, c("rank","scientificName","family","nativity","summed_cover","cover_share_pct","cum_share_pct","effective_common_core")]
  }
  observeEvent(plotly::event_data("plotly_click", source = "hillSrc"), {
    occ <- rv$snap; req(occ)
    h  <- hill_site(occ); rk <- hill_ranked(); req(!is.null(h), !is.null(rk), nrow(rk) > 0)
    qk <- plotly::event_data("plotly_click", source = "hillSrc")$customdata %||% "q1"
    ec <- max(1, round(h["q1"]))
    lab <- switch(qk, q0 = "q0 — richness (every species present)",
                       q1 = "q1 — effectively common species",
                       q2 = "q2 — dominant species", "the diversity profile")
    df <- rk
    df$is_core <- df$rank <= ec
    show <- data.frame(
      `#` = df$rank,
      Species = df$scientificName,
      Family = df$family,
      Status = df$nativity,
      `Summed cover` = df$summed_cover,
      `Cover %` = df$cover_share_pct,
      `Cumulative %` = df$cum_share_pct,
      check.names = FALSE)
    dt <- DT::datatable(show, rownames = FALSE,
            options = list(pageLength = 12, dom = "tp", order = list()),
            class = "compact stripe") %>%
          DT::formatStyle("#", target = "row",
            backgroundColor = DT::styleRow(which(df$is_core), "rgba(95,209,106,0.14)"))
    showModal(modalDialog(
      title = tagList(bs_icon("diagram-2"), " Species behind the diversity profile"),
      size = "l", easyClose = TRUE,
      footer = tagList(
        downloadButton("hillCsv", "Download (CSV)", class = "smt-snap-btn"),
        modalButton("Close")),
      div(class = "qc-modal-intro",
        p(HTML(sprintf("You clicked <b>%s</b>. This site holds <b>%.0f</b> species in cover; q1 says about <span class='ci-hero'>%d</span> are <b>effectively common</b> (evenness-weighted).", lab, h["q0"], ec))),
        p(HTML(sprintf("q1 is an <b>effective number</b>, not a hand-picked list of exactly %d names. The species are ranked by summed 1 m\U00B2 cover below; the <span style='background:rgba(95,209,106,0.30);padding:1px 4px;border-radius:3px'>top %d highlighted</span> are the cluster that &ldquo;effectively common &asymp; %d&rdquo; describes. The long tail of low-cover species is real, just rare.", ec, ec, ec)))),
      dt))
  })
  output$hillCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_hill-ranked-species_%s.csv",
                                  rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) utils::write.csv(hill_csv_df(), file, row.names = FALSE, na = ""),
    contentType = "text/csv")

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
      HTML(sprintf("Introduced plants make up <span class='ci-hero'>%.1f%%</span> of cover in %d, %s %.1f%% in %d. Native status is unknown for %.0f%% of species.",
        last$pct_introduced, last$year, dir, first$pct_introduced, first$year, ur)))
  })
  output$invTable <- DT::renderDT({
    occ <- rv$snap; req(occ); wl <- invasive_watchlist(occ)
    if (is.null(wl) || !nrow(wl)) return(DT::datatable(data.frame(Message = "No introduced species recorded here."), rownames = FALSE, options = list(dom = "t")))
    df <- data.frame(Species = wl$scientificName, Family = wl$family,
                     `Mean cover %` = wl$mean_cover, `# plots` = wl$n_plots, check.names = FALSE)
    DT::datatable(df, rownames = FALSE, options = list(pageLength = 8, dom = "tp", order = list(list(2, "desc"))))
  })
  output$watchlistCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_invasive-watchlist_%s.csv",
                                  rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      occ <- rv$snap; wl <- if (is.null(occ)) NULL else invasive_watchlist(occ)
      out <- if (is.null(wl) || !nrow(wl)) data.frame(note = "No introduced species recorded here.")
             else data.frame(scientificName = wl$scientificName, family = wl$family,
                             mean_cover_pct = wl$mean_cover, n_plots = wl$n_plots,
                             stringsAsFactors = FALSE)
      utils::write.csv(out, file, row.names = FALSE, na = "")
    }, contentType = "text/csv")
  output$pressurePlot <- renderPlotly({
    occ <- rv$snap; req(occ); fh <- species_foothold(occ); if (is.null(fh) || !nrow(fh)) return(note_plot("No introduced species recorded here"))
    mx <- max(c(fh$plots_1m, fh$plots_400), 1)
    # both axes are small integer plot-counts, so ties pile up invisibly on the
    # 1:1 line — nudge the DISPLAY positions deterministically while the hover (and
    # the click reveal) keep the TRUE integers + the species name (customdata).
    set.seed(1)
    fh$jx <- fh$plots_1m  + stats::runif(nrow(fh), -0.12, 0.12)
    fh$jy <- fh$plots_400 + stats::runif(nrow(fh), -0.12, 0.12)
    # per-species pin-card HTML — the .smt-open chip opens this species in the
    # foothold reveal modal (same path as a direct click). data-tag = species key.
    # customdata carries the pin-card HTML (what pincards.js pins on a tap); the
    # species name rides in its data-tag, which BOTH the .smt-open chip and the
    # server's direct plotly_click handler read to open the foothold reveal.
    fh$tip <- paste0(
      "<span class='smt-pin-emoji'>\U0001F33F</span> <b><i>", fh$scientificName, "</i></b><br/>",
      "<span class='smt-pin-stats'>", fh$family, " \U00B7 introduced",
        "<br/>", fh$plots_1m, " plot", ifelse(fh$plots_1m == 1, "", "s"), " at 1 m\U00B2 \U00B7 ",
        fh$plots_400, " plot", ifelse(fh$plots_400 == 1, "", "s"), " in the 400 m\U00B2 plot",
        ifelse(is.finite(fh$mean_cover_1m), paste0("<br/>mean ", fh$mean_cover_1m, "% cover at 1 m\U00B2"), ""),
        "</span>",
      "<br/><span class='smt-open-foothold' role='button' tabindex='0' data-tag='", fh$scientificName,
        "'>\U0001F50E Where is it? &rarr;</span>",
      "<br/><em class='smt-pin-hint'>Tap the dot to pin this card</em>")
    plot_ly(fh, x = ~jx, y = ~jy, type = "scatter", mode = "markers", source = "footholdSrc",
      customdata = ~tip, text = ~scientificName,
      marker = list(color = DDL$introduced, size = 11, opacity = 0.7, line = list(color = "#fff", width = 1)),
      hovertemplate = "<i>%{text}</i><br>%{x:.0f} plots at 1 m²<br>%{y:.0f} plots in 400 m²<extra></extra>") %>%
      plotly::event_register("plotly_click") %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE,
        xaxis = list(title = "Plots the species reaches at 1 m²", rangemode = "tozero"),
        yaxis = list(title = "Plots the species reaches in the 400 m² plot", rangemode = "tozero"),
        shapes = list(list(type = "line", x0 = 0, y0 = 0, x1 = mx, y1 = mx,
          line = list(color = "rgba(120,130,140,0.5)", dash = "dot", width = 1))),
        annotations = list(list(text = "each dot = one introduced species · above the 1:1 line = spread past its 1 m² footholds (points jittered to separate ties)",
          x = 0, y = 1.06, xref = "paper", yref = "paper", showarrow = FALSE, xanchor = "left",
          font = list(color = if (is_dark()) "#9fb0c4" else "#6b7a85", size = 11))))
  })

  # ---- Foothold member-reveal: click a dot (or its "Where is it?" chip) ------
  # reveal ONE introduced species' detail — the plots it reaches at 1 m² vs across
  # the 400 m² plot, family, mean cover — + a CSV. Two entry points resolve to the
  # same species name: a direct plotly_click (species rides in the pin-card HTML's
  # data-tag, inside customdata) and the .smt-open-foothold chip (footballRequest).
  rv_foothold <- reactiveVal(NULL)
  show_foothold <- function(sp) {
    occ <- rv$snap; req(occ); fh <- species_foothold(occ); req(!is.null(fh))
    row <- fh[fh$scientificName == sp, , drop = FALSE]
    if (!nrow(row)) return(invisible())
    rv_foothold(sp)
    only1m  <- setdiff(strsplit(row$plotlist_400, ", ")[[1]], strsplit(row$plotlist_1m, ", ")[[1]])
    gap <- row$plots_400 - row$plots_1m
    reach <- if (gap > 0) sprintf("It turns up in <b>%d</b> more plot%s across the whole 400 m\U00B2 plot than its 1 m\U00B2 footholds alone (%s) — the signature of spread past a chance toehold.",
                                  gap, ifelse(gap == 1, "", "s"), if (length(only1m)) paste(only1m, collapse = ", ") else "—")
             else "Every plot it reaches, it's already detectable at the finest 1 m\U00B2 scale — no hidden spread."
    tile <- function(v, l) div(class = "qc-tile", div(class = "qc-tile-v", v), div(class = "qc-tile-l", l))
    showModal(modalDialog(
      title = tagList(bs_icon("search"), HTML(sprintf(" <i>%s</i>", sp))),
      size = "l", easyClose = TRUE,
      footer = tagList(downloadButton("footholdCsv", "Download (CSV)", class = "smt-snap-btn"), modalButton("Close")),
      div(class = "qc-head-badges", style = "margin-bottom:8px",
        glow_badge(paste0(row$family, " · introduced"), DDL$introduced)),
      div(class = "qc-tiles",
        tile(row$plots_1m, "plots at 1 m\U00B2"),
        tile(row$plots_400, "plots in 400 m\U00B2"),
        tile(if (is.finite(row$mean_cover_1m)) paste0(row$mean_cover_1m, "%") else "\U2014", "mean 1 m\U00B2 cover")),
      div(class = "qc-modal-intro", p(HTML(reach))),
      div(class = "foothold-plots",
        p(tags$b("At 1 m\U00B2 (finest scale): "), if (nzchar(row$plotlist_1m)) row$plotlist_1m else em("not detected at 1 m\U00B2")),
        p(tags$b("Across the 400 m\U00B2 plot: "), if (nzchar(row$plotlist_400)) row$plotlist_400 else em("\U2014")))))
  }
  observeEvent(plotly::event_data("plotly_click", source = "footholdSrc"), {
    cd <- plotly::event_data("plotly_click", source = "footholdSrc")$customdata
    # the customdata is the pin-card HTML; pull the species out of its data-tag.
    # regmatches (NOT a greedy sub: the class='…' quote upstream makes a greedy
    # .* capture the wrong quote-pair and return empty).
    sp <- NA_character_
    if (length(cd)) {
      m <- regmatches(as.character(cd)[1], regexpr("data-tag='[^']+'", as.character(cd)[1]))
      # strip the fixed wrapper by length, not a quote-in-regex sub (the embedded
      # single-quotes make a sub pattern fragile across engines/escaping)
      if (length(m) && nchar(m) > 11) sp <- substr(m, 11L, nchar(m) - 1L)
    }
    if (!is.na(sp) && nzchar(sp)) show_foothold(sp)
  })
  observeEvent(input$footholdRequest, if (nzchar(input$footholdRequest %||% "")) show_foothold(input$footholdRequest), ignoreInit = TRUE)
  output$footholdCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_foothold-%s_%s.csv",
                                  rv$site %||% "site",
                                  gsub("[^A-Za-z0-9]+", "-", rv_foothold() %||% "species"),
                                  format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      occ <- rv$snap; sp <- rv_foothold(); fh <- if (is.null(occ)) NULL else species_foothold(occ)
      row <- if (!is.null(fh)) fh[fh$scientificName == sp, , drop = FALSE] else NULL
      out <- if (is.null(row) || !nrow(row)) data.frame(note = "No foothold data for this species.")
             else data.frame(
               scientificName = row$scientificName, family = row$family, nativity = "Introduced",
               plots_at_1m2 = row$plots_1m, plots_in_400m2 = row$plots_400,
               foothold_gap = row$plots_400 - row$plots_1m,
               mean_cover_pct_1m2 = row$mean_cover_1m,
               plots_at_1m2_list = row$plotlist_1m, plots_in_400m2_list = row$plotlist_400,
               stringsAsFactors = FALSE)
      utils::write.csv(out, file, row.names = FALSE, na = "")
    }, contentType = "text/csv")

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

  # ---- Environment exports (matched annual series + driver-rank w/ perm p) ---
  # The matched series and the driver-rank table are the two frames behind the
  # Environment tab; export them so a reader can replay the correlation by hand.
  output$envSeriesCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_env-matched-series_%s.csv",
                                  rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      ms <- env_series(); e <- cur_env(); pm <- env_perm()
      # build the year-matched (driver lagged to its best lag) frame the scatter draws
      out <- data.frame()
      if (!is.null(ms) && !is.null(e) && !is.null(pm) && !is.null(pm$top)) {
        pk <- pm$top
        ea <- env_annual(e, pk$layer)
        if (!is.null(ea) && nrow(ea)) {
          ea2 <- ea; ea2$year <- ea2$year + pk$lag       # driver from (Y - lag) -> response year Y
          j <- merge(ms, ea2, by = "year")
          if (nrow(j)) out <- data.frame(
            year         = j$year,
            plant_metric = env_metric_lab(),
            metric_value = round(j$value.x, env_metric_dig()),
            driver       = pk$layer,
            driver_label = pk$label,
            driver_value = round(j$value.y, 2),
            lag_years    = pk$lag,
            stringsAsFactors = FALSE)
        }
      }
      if (!nrow(out))
        out <- data.frame(note = "Too few year-matched survey years to build a climate-vs-vegetation series for this site.")
      utils::write.csv(out, file, row.names = FALSE, na = "")
    }, contentType = "text/csv")

  output$envRankCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_env-driver-rank_%s.csv",
                                  rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      rk <- env_rank(); ms <- env_series(); e <- cur_env()
      out <- data.frame()
      if (!is.null(rk) && nrow(rk) && !is.null(ms) && !is.null(e)) {
        # per-driver permutation p: correct each driver for ITS OWN lag search
        pvals <- vapply(rk$layer, function(L) {
          pp <- tryCatch(plant_env_perm(ms, e, B = 499, only = L), error = function(err) NULL)
          if (is.null(pp) || is.null(pp$p)) NA_real_ else as.numeric(pp$p)
        }, numeric(1))
        out <- data.frame(
          plant_metric   = env_metric_lab(),
          driver         = rk$layer,
          driver_label   = rk$label,
          spearman_r     = rk$r,
          best_lag_years = rk$lag,
          matched_years  = rk$n,
          permutation_p  = round(pvals, 3),
          stringsAsFactors = FALSE)
        out <- out[order(-abs(out$spearman_r)), , drop = FALSE]
      }
      if (!nrow(out))
        out <- data.frame(note = "No co-located environmental data, or too few survey years, to rank drivers for this site.")
      utils::write.csv(out, file, row.names = FALSE, na = "")
    }, contentType = "text/csv")

  output$envSourceNote <- renderUI({
    if (is.null(cur_env())) return(NULL)
    div(class = "env-source env-real", bs_icon("patch-check-fill"),
        tags$span(HTML(sprintf(" Live from co-located NEON sensors at <b>%s</b>: precipitation, air temperature, and plant phenology, aggregated to one value per year.",
                               rv$site %||% "this site"))))
  })

  output$envCorrNote <- renderUI({
    e <- cur_env(); ms <- env_series()
    if (is.null(e)) return(div(class = "chart-insight ci-muted", bs_icon("cloud-slash"),
      div(class = "ci-text", "No co-located environmental data is bundled for this site yet.")))
    if (is.null(ms) || nrow(ms) < MIN_ENV_YEARS)
      return(div(class = "chart-insight ci-muted", bs_icon("hourglass-split"),
        div(class = "ci-text", HTML(sprintf("Only <b>%d</b> survey year%s here, too few to test a climate link (need %d+). The series below still show the raw context.",
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
          tags$span(class = "ec-strength", tools::toTitleCase(v$word)), " · ", tolower(metricLab), " vs ",
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
    # Draw the OLS fit line ONLY when the permutation test clears significance.
    # On 6-10 survey years a visually authoritative line can otherwise sit
    # directly under a "no clear link / p=0.76" banner (e.g. SRER green-up
    # r=-0.67, p=0.758) and overclaim. Gate on pm$p — no line when chance can
    # explain it. (Across 46 sites only 1 clears p<0.05, the null rate.)
    if (!is.na(pm$p) && pm$p < 0.05 && stats::sd(pts$driver) > 0) {
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
        xaxis = list(title = "Spearman r with the plant signal · left of 0 = inverse",
                     range = c(-1, 1), zeroline = TRUE, zerolinecolor = "rgba(31,42,48,0.30)"),
        yaxis = list(title = ""), margin = list(b = 72),
        annotations = list(list(
          text = sprintf("best of %d driver%s \U00D7 3 lags \U00B7 sorted by strength \U00B7 NOT independent evidence",
                         n_drv, if (n_drv == 1) "" else "s"),
          x = 0, y = -0.30, xref = "paper", yref = "paper", xanchor = "left", yanchor = "top",
          showarrow = FALSE, font = list(color = if (is_dark()) "#9fb0c4" else "#8a97a8", size = 10))))
  })

  # ---- The SEASONAL driver read (Driver Cascade's seasonal-aggregate question) -
  # The annual precip layer above sums the cool-season rain (Oct-Mar) and the
  # summer monsoon (Jul-Sep) into one number, even though those two seasons feed
  # different plants. This card splits the year by season and correlates RICHNESS
  # against this site's yearly winter / monsoon rain + spring warmth at LAG 0
  # (plants respond the same year), the way the Driver Cascade does. The biome
  # dictates the lead driver: in drylands it is WINTER rain (germinates the spring
  # forbs). Per-site n is a handful of years, so this is SUGGESTIVE, not a verdict;
  # the honest pooled test lives in the Driver Cascade app.
  output$seasonalDriver <- renderUI({
    e <- cur_env(); if (is.null(e)) return(NULL)
    resp <- plant_metric_series(rv$occ, "richness")          # year, value = species richness
    if (is.null(resp) || nrow(resp) < 3) return(NULL)
    site_code <- rv$site %||% (if (!is.null(rv$occ) && "siteID" %in% names(rv$occ)) mode_chr(rv$occ$siteID) else NULL)
    biome <- seasonal_biome(site_code)
    # plants respond SAME-year -> lag 0 for every seasonal driver (NOT the mammal monsoon lag-1).
    # to = "richness" makes `expected` honour the cascade's (driver, biome, RESPONSE) allow-list:
    # the ONLY sanctioned plant prior is precip_winter -> richness in water-limited biomes. Monsoon
    # and spring temp are still computed + shown for richness, but expected=FALSE ("tested, no plant
    # prior") so the lead can never headline a monsoon->richness link the cascade never sanctioned.
    links <- tryCatch(seasonal_driver_links(e, resp, biome = biome, to = "richness",
               lags = c(precip_winter = 0L, precip_monsoon = 0L, temp_spring = 0L)),
               error = function(err) NULL)
    eyebrow <- div(class = "ec-eyebrow", bs_icon("calendar-range"),
                   tags$span("seasonal climate \U00B7 the cascade read"),
                   info_pop("The seasonal read",
                     p("A single annual rain total blends two seasons that feed different plants: ", tags$b("winter rain"), " (Oct-Mar) germinates the spring annual forbs, while the ", tags$b("summer monsoon"), " (Jul-Sep) drives the warm-season grasses. The ranking above ranks the annual TOTAL, which averages them together."),
                     p("Here we aggregate rain by season and correlate it against this site's yearly species richness, the way the Driver Cascade does. ", tags$b("Per-site n is only a handful of survey years"), ", so this is suggestive, not significant. The honest test pools many sites in the Driver Cascade app.")))
    if (is.null(links) || !nrow(links)) {
      return(div(class = "ec ec-seasonal rail-weak", style = "margin-top:14px;", eyebrow,
        div(class = "ec-hero", div(class = "ec-hero-text",
          "No co-located seasonal rain record at this site, so the winter and monsoon seasons can't be split out here. That is missing climate data, not a missing signal."))))
    }
    lead <- links[links$expected, , drop = FALSE]; if (!nrow(lead)) lead <- links
    L <- lead[1, ]; pos <- L$r >= 0
    strength <- abs(L$r)
    rail <- if (strength >= 0.6) "rail-strong" else if (strength >= 0.35) "rail-mod" else "rail-weak"
    sub  <- tolower(L$label)
    lead_txt <- if (grepl("precip", L$driver))
      sprintf("A wetter %s tracks %s plant diversity the same year", sub, if (pos) "more" else "less")
      else sprintf("A warmer %s tracks %s plant diversity the same year", sub, if (pos) "more" else "less")
    # the contrast: what the plain ANNUAL precip total shows for richness here
    mr <- tryCatch({ sc <- plant_env_scan(resp, e, "precip"); if (is.null(sc)) NA_real_ else sc$r },
                   error = function(err) NA_real_)
    pstr <- if (is.finite(L$p)) sprintf("p = %.2f", L$p) else sprintf("%d yrs, too few for a p", L$n)
    div(class = paste("ec ec-seasonal", rail), style = "margin-top:14px;",
      eyebrow,
      div(class = "ec-hero",
        div(class = "ec-hero-text", lead_txt, "."),
        div(class = paste("ec-rvalue", if (pos) "ec-sgn-pos" else "ec-sgn-neg"),
          bs_icon(if (pos) "arrow-up-right" else "arrow-down-right"),
          HTML(sprintf("r&nbsp;%+.2f", L$r)))),
      div(class = "ec-foot",
        tags$span(class = "ec-meta", bs_icon("calendar3"), HTML(sprintf("<b>%d</b> survey years", L$n))),
        tags$span(class = "ec-meta-dot"), tags$span(class = "ec-meta", bs_icon("shuffle"), pstr),
        if (is.finite(L$p_adj)) tagList(tags$span(class = "ec-meta-dot"),
          tags$span(class = "ec-meta", title = "p after accounting for testing several seasons",
                    HTML(sprintf("season-corrected p = %.2f", L$p_adj))))),
      div(class = "ec-seasonal-note",
        HTML(paste0(
          "In drylands the cool-season (Oct-Mar) rain germinates the spring forbs, so winter rain tracks plant diversity better than the annual total, which averages winter and monsoon rain together even though they feed different plants.",
          if (is.finite(mr)) sprintf(" The annual rain total shows only about <b>r %+.2f</b> for richness here.", mr) else ""))),
      # the OTHER seasons: computed + shown, but greyed and labelled "tested, no plant
      # prior" — the cascade's "computed everywhere, only the tally respects expected"
      # rule. The summer monsoon and spring temperature carry no sanctioned richness
      # prior, so they never get to headline the card even when |r| is larger.
      local({
        others <- links[!(links$driver %in% L$driver), , drop = FALSE]
        if (!nrow(others)) return(NULL)
        others <- others[order(-abs(others$r)), , drop = FALSE]
        div(class = "ec-seasonal-others",
          div(class = "ec-seasonal-others-h", bs_icon("dot"),
              "Also tested here, but with no cascade plant prior for richness:"),
          tags$div(class = "ec-seasonal-others-row",
            lapply(seq_len(nrow(others)), function(i) {
              o <- others[i, ]
              tags$span(class = "ec-seasonal-chip", title = "computed for completeness; not a sanctioned plant prior, so it is excluded from the lead",
                tags$span(class = "ec-chip-label", o$label),
                HTML(sprintf(" <b>r&nbsp;%+.2f</b>", o$r)),
                tags$span(class = "ec-chip-tag", "tested, no plant prior"))
            })))
      }),
      div(class = "ec-seasonal-caveat", bs_icon("info-circle"),
        HTML(" One site, a handful of years, so suggestive not settled. The cross-site test that pools many sites is in the "),
        tags$a(href = "https://tgilbert14.github.io/NEON-Driver-Cascade/", target = "_blank", "Driver Cascade app"), "."))
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
      qlab(xr[1]+padx, yr[2]-pady, "FEW SPECIES \U00B7 INVADED", "left", "top"),
      qlab(xr[2]-padx, yr[2]-pady, "MANY SPECIES \U00B7 INVADED", "right", "top"),
      qlab(xr[1]+padx, yr[1]+pady, "FEW SPECIES \U00B7 NATIVE COVER", "left", "bottom"),
      qlab(xr[2]-padx, yr[1]+pady, "MANY SPECIES \U00B7 NATIVE COVER", "right", "bottom"))
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
      p("Tap a dot above and choose “Open plot profile”, or use the plot picker at the top.")))
    lb <- rv$lb; row <- lb[lb$plotID == rv$plot, ]; if (!nrow(row)) return(NULL)
    div(class = "lab-sel",
      span(class = "ls-emoji", "\U0001F33E"),
      div(class = "ls-body",
        div(class = "ls-id", tags$b(short_plot(rv$plot)),
          sprintf(" · %d species · %d native · %d introduced", row$richness, row$n_native, row$n_introduced),
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
      p("Use the Diversity Lab (tap a dot → “Open plot profile”) or the “Open a plot's profile” picker at the top.")))
    div(class = "plot-profile-wrap", plot_card_ui(rv$plot))
  })

  output$plotCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_%s.csv", rv$plot %||% "plot", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      occ <- rv$occ; pid <- rv$plot; req(occ, pid)
      d <- species_level_only(occ); d <- d[d$plotID == pid, c("plotID","subplotID","scale","year","scientificName","family","nativity","percentCover")]
      utils::write.csv(d[order(d$scientificName, d$scale), ], file, row.names = FALSE, na = "")
    }, contentType = "text/csv")

  # ---- whole-site exports: report PDF, all-data ZIP + codebook -------------
  output$reportPdf <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_report_%s.pdf", rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) { occ <- rv$occ; req(occ)
      e <- load_expected(rv$site)
      build_diversity_report(file, occ, rv$ground, label = rv$label %||% (rv$site %||% "Site"), expected = e) },
    contentType = "application/pdf")

  output$allDataZip <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_data_%s.zip", rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    contentType = "application/zip",
    content = function(file) {
      occ <- rv$occ; req(occ); site <- rv$site %||% "site"
      tmp <- tempfile("pdeexport"); dir.create(tmp)
      keep <- intersect(c("plotID","subplotID","scale","year","bout","taxonID","scientificName",
        "taxonRank","family","nativity","percentCover","is_species"), names(occ))
      occ_long <- species_level_only(occ)[, keep, drop = FALSE]
      names(occ_long)[names(occ_long) == "scale"] <- "scale_m2"
      pl <- plot_summary(latest_snapshot(occ))
      gr <- rv$ground
      # provenance stamp — when this bundle was built + (if tagged) the NEON release
      built_at <- rv$built_at %||% format(Sys.Date(), "%Y-%m-%d")
      neon_rel <- rv$neon_release %||% NA_character_
      prov <- data.frame(
        site = site, builtAt = built_at, neonRelease = neon_rel,
        dpid = "DP1.10058.001", exportedAt = format(Sys.Date(), "%Y-%m-%d"),
        stringsAsFactors = FALSE)
      readme <- c(
        sprintf("NEON Plant Diversity Explorer · data export for site %s", site),
        sprintf("Generated %s by an unofficial Desert Data Labs explorer.", format(Sys.Date(), "%Y-%m-%d")),
        "Source: NEON Plant presence & percent cover DP1.10058.001 (div_1m2Data + div_10m2Data100m2Data).",
        sprintf("Bundle built: %s%s", built_at,
                if (!is.na(neon_rel) && nzchar(neon_rel)) sprintf(" | NEON release %s", neon_rel) else " | NEON release not tagged"),
        "", "FILES",
        " occ_long.csv          - one row per taxon occurrence at a quadrat scale (the raw record).",
        " plots.csv             - one row per plot: richness + native/introduced + cover summary.",
        " ground_cover.csv      - abiotic ground cover (soil/litter/rock/...) at 1 m^2.",
        " expected_vs_observed.csv - NRCS reference flora vs observed (only if a reference list is bundled).",
        " provenance.csv        - build/vintage stamp (site, builtAt, neonRelease, dpid) so you can cite the exact source.",
        " data_dictionary.csv   - column definitions, types, units (derived from the actual exported frames).",
        "", "NOTES",
        " * 'snapshot' analyses in the app use each plot's LATEST (year, bout); occ_long gives every record.",
        " * percentCover is an ocular estimate at 1 m^2 (bin midpoint/ocular, NA at presence-only 10/100 m^2 scales);",
        "   layers overlap, so site-summed cover is a relative index, not a share of ground.",
        " * nativity is NEON's nativeStatusCode collapsed to native/introduced/unknown.")
      utils::write.csv(occ_long, file.path(tmp, "occ_long.csv"), row.names = FALSE, na = "")
      if (!is.null(pl)) utils::write.csv(pl, file.path(tmp, "plots.csv"), row.names = FALSE, na = "")
      if (!is.null(gr) && nrow(gr)) utils::write.csv(gr, file.path(tmp, "ground_cover.csv"), row.names = FALSE, na = "")
      utils::write.csv(prov, file.path(tmp, "provenance.csv"), row.names = FALSE, na = "")
      e <- load_expected(site)
      ev_tbl <- NULL
      if (!is.null(e)) { ev <- tryCatch(expected_vs_observed(occ, e, PLANT_AUTHORITY), error = function(err) NULL)
        if (!is.null(ev)) { ev_tbl <- qc_report_table(ev, site)
          utils::write.csv(ev_tbl, file.path(tmp, "expected_vs_observed.csv"), row.names = FALSE, na = "") } }
      # codebook DERIVED from exactly the frames shipped, so it can never drift
      frames <- list("occ_long.csv" = occ_long)
      if (!is.null(pl)) frames[["plots.csv"]] <- pl
      if (!is.null(gr) && nrow(gr)) frames[["ground_cover.csv"]] <- gr
      frames[["provenance.csv"]] <- prov
      if (!is.null(ev_tbl)) frames[["expected_vs_observed.csv"]] <- ev_tbl
      utils::write.csv(plant_codebook(frames), file.path(tmp, "data_dictionary.csv"), row.names = FALSE, na = "")
      writeLines(readme, file.path(tmp, "README.txt"))
      fs <- list.files(tmp, full.names = TRUE)
      old <- setwd(tmp); on.exit(setwd(old), add = TRUE)
      utils::zip(zipfile = file, files = basename(fs), flags = "-q")
    })

  # ---- compare two sites (side-by-side headline metrics) ------------------
  observeEvent(input$compareBtn, {
    req(rv$site)
    others <- site_table$site[site_table$site != rv$site]
    ch <- stats::setNames(others, sprintf("%s · %s", others, site_table$name[match(others, site_table$site)]))
    showModal(modalDialog(easyClose = TRUE, size = "l",
      title = tagList(bs_icon("layout-split"), sprintf(" Compare %s with…", rv$site)),
      selectInput("compareSite2", NULL, choices = c("Pick a site to compare…" = "", ch), width = "100%"),
      uiOutput("compareOut"),
      footer = modalButton("Close")))
  })
  output$compareOut <- renderUI({
    s2 <- input$compareSite2 %||% ""; if (!nzchar(s2)) return(NULL)
    b2 <- load_site_bundle(s2); if (is.null(b2)) return(p(class = "dim", "That site isn't bundled."))
    snap2 <- latest_snapshot(b2$occ)
    metrics <- function(snap) { sp <- species_level_only(snap)
      ch <- chao2(snap)
      list(rich = dplyr::n_distinct(sp$scientificName),
           intro = site_invasion(snap), plots = dplyr::n_distinct(snap$plotID),
           fam = mode_chr(sp$family),
           intro_n = dplyr::n_distinct(sp$scientificName[sp$nativity == "Introduced"]),
           chao = if (!is.null(ch)) sprintf("%.0f%s", ch$chao2, if (ch$unstable) "*" else "") else NULL) }
    a <- metrics(rv$snap); b <- metrics(snap2)
    pc <- function(v) if (!is.null(v) && is.finite(v)) paste0(v, "%") else "—"
    row <- function(l, va, vb) tags$tr(tags$td(class = "cmp-l", l), tags$td(va), tags$td(vb))
    # Raw observed richness is effort-dependent (sites differ in plots/years/bouts);
    # the caveat is clickable (ⓘ) so the default table stays clean. Chao2 — the
    # comparable, effort-corrected estimate — is surfaced as its own row.
    tags$table(class = "compare-tbl",
      tags$thead(tags$tr(tags$th(""), tags$th(rv$site), tags$th(s2))),
      tags$tbody(
        tags$tr(
          tags$td(class = "cmp-l", "Species (snapshot)",
            info_pop("Comparing richness fairly",
              p("This row is ", tags$b("raw observed richness"), " (S_obs) at each site's own sampling effort; plots, survey years and bouts differ between sites, and more effort finds more species."),
              p("For a fair side-by-side, read the ", tags$b("Chao2"), " row below: it estimates total richness from the incidence data and is the effort-corrected, comparable number. An asterisk flags a rough lower bound (few doubletons)."))),
          tags$td(a$rich), tags$td(b$rich)),
        row("Chao2 (estimated)", a$chao %||% "—", b$chao %||% "—"),
        row("Introduced species", a$intro_n, b$intro_n),
        row("Introduced cover", pc(a$intro), pc(b$intro)),
        row("Plots sampled", a$plots, b$plots),
        row("Top family", a$fam %||% "—", b$fam %||% "—")))
  })

  # ---- MAP ----------------------------------------------------------------
  output$map <- leaflet::renderLeaflet({
    lb <- rv$lb; req(lb)
    # drop coord-less / non-finite plots so the map can't render blank or fit to NA
    lb <- lb[is.finite(lb$lat) & is.finite(lb$lng), , drop = FALSE]
    validate(need(nrow(lb) > 0, "No plots have mappable coordinates for this site."))
    metric <- input$mapMetric %||% "pct_introduced"
    val <- if (metric == "pct_introduced") ifelse(is.na(lb$pct_introduced), 0, lb$pct_introduced) else lb$richness
    if (metric == "pct_introduced") {
      # % introduced is a BOUNDED one-ended magnitude (0-100), not heavy-tailed
      # and not diverging -> a linear SEQUENTIAL single-hue sand->clay ramp is
      # honest (no false midpoint, no native-green reuse). Bounded metrics stay
      # linear per the suite colour-scale standard.
      dom <- if (diff(range(val, na.rm = TRUE)) > 0) range(val, na.rm = TRUE) else c(val[1] - 1, val[1] + 1)
      pal <- leaflet::colorNumeric(c("#F3E9D8","#D9A066","#B85C38"), domain = dom)
    } else {
      # plot richness is an UNBOUNDED count: a single high-diversity plot can wash
      # the rest of the site out under a raw colorNumeric. Bin on quantile breaks
      # (~5-7 bins) so each colour step carries a comparable share of plots, with a
      # clean all-equal fallback. Matches the suite colour-scale standard.
      uv <- sort(unique(val[is.finite(val)]))
      pal <- if (length(uv) >= 5) {
        brks <- unique(stats::quantile(val, probs = seq(0, 1, length.out = 6), na.rm = TRUE, names = FALSE))
        if (length(brks) >= 3) leaflet::colorBin("viridis", domain = val, bins = brks, na.color = "#cccccc")
        else leaflet::colorNumeric("viridis", domain = range(val, na.rm = TRUE))
      } else if (length(uv) >= 2) {
        leaflet::colorNumeric("viridis", domain = range(val, na.rm = TRUE))
      } else {
        leaflet::colorNumeric("viridis", domain = c(uv[1] - 1, uv[1] + 1))
      }
    }
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
      HTML("No NRCS ecological-site reference list is bundled for this site <i>yet</i>. The completeness comparison is live for Santa Rita (SRER) and a growing set of sites. Everything else on this page still works.")))
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
          "the core species, top 50% of reference production")
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
      HTML(sprintf("<b>%.0f%%</b> of records here are identified coarser than species: genus, family, or just “plant”%s. These can't be matched to a species-level reference list, so read the comparisons below as a floor, not a census.",
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

  # the state-plausibility note: how many natives were set aside as regional
  # associates (on the state flora, not this soil unit), or why the check didn't run.
  output$evoRegionalNote <- renderUI({
    ev <- evo(); if (is.null(ev)) return(NULL)
    if (!isTRUE(ev$state_covered)) {
      st <- ev$state %||% NA
      msg <- if (is.na(st) || !nzchar(st))
        "State-level plausibility check unavailable for this site, so every unexpected species below stays in the review lane (today's behaviour)."
      else sprintf("State-level plausibility check not yet available for %s, so every unexpected species below stays in the review lane.", state_names[st] %||% st)
      return(div(class = "evo-flag evo-flag-muted", bs_icon("hourglass-split"), HTML(paste0(" ", msg))))
    }
    n <- ev$n_regional %||% 0L
    if (n == 0) return(div(class = "evo-flag evo-flag-clean", bs_icon("check2-circle"),
      HTML(sprintf(" Every unexpected species here is either introduced or a native not recorded for %s, so none were set aside. The list below is the genuine review lane.",
                   state_names[ev$state] %||% ev$state))))
    cr <- ev$C_regional
    rows <- utils::head(cr[order(-cr$n_plots), , drop = FALSE], 12)
    div(class = "evo-flag evo-flag-info",
      div(class = "evo-flag-h", bs_icon("geo-alt-fill"),
        sprintf(" %d native species set aside: on the %s state flora, just not this soil unit's reference list", n, state_names[ev$state] %||% ev$state)),
      tags$table(class = "evo-flag-tbl",
        tags$thead(tags$tr(tags$th("Species"), tags$th("Symbol"), tags$th("# plots"))),
        tags$tbody(lapply(seq_len(nrow(rows)), function(i) tags$tr(
          tags$td(tags$i(rows$scientificName[i])), tags$td(rows$sym[i]), tags$td(rows$n_plots[i]))))),
      if (n > 12) div(class = "evo-flag-more", sprintf("+ %d more in the full report (CSV)", n - 12)),
      div(class = "evo-flag-note", "These are regional associates the soil-unit reference list didn't enumerate, not data-quality issues. They're kept in the downloadable report, labelled, but left out of the review lane below."))
  })

  # Bucket C — observed, not in reference (clay; the review lane)
  output$evoTableC <- DT::renderDT({
    ev <- evo(); if (is.null(ev)) return(evo_empty_dt("No reference comparison is available for this site."))
    C <- ev$C; if (!nrow(C)) {
      msg <- if (isTRUE(ev$state_covered) && (ev$n_regional %||% 0) > 0)
        sprintf("Nothing to review: the unexpected species here are all natives on the %s state flora (set aside above as regional associates), with no introduced species and no out-of-state records.", state_names[ev$state] %||% ev$state)
      else "Every observed species is on the reference list; nothing to review."
      return(evo_empty_dt(msg))
    }
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
    B <- ev$B; if (!nrow(B)) return(evo_empty_dt("Every reference species was detected: a complete sample of the reference flora."))
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
        HTML(" <b>Nativity cross-check (NEON vs USDA):</b> needs the USDA PLANTS authority file, being added in a follow-up build. NEON's own native/introduced labels are used everywhere else on the page."))
    } else if (nm$n == 0) {
      div(class = "evo-flag evo-flag-clean", bs_icon("check2-circle"),
        HTML(" <b>Nativity cross-check (NEON vs USDA):</b> no disagreements; every species' native/introduced label matches USDA PLANTS."))
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
        div(class = "evo-flag-note", "Nativity is regional; USDA's lower-48 label and NEON's site label can legitimately differ at a range edge. Worth a look, not necessarily an error."))
    }
    cs_ui <- if (cs$n == 0) {
      div(class = "evo-flag evo-flag-clean", bs_icon("check2-circle"),
        HTML(sprintf(" <b>Cover sanity:</b> no 1 m² quadrat sums above %d%%, within what overlapping canopy layers explain.", cs$ceiling)))
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

  # downloads — per bucket + the combined report.
  # Each standalone QC bucket ships as a ZIP that bundles its CSV WITH a
  # data_dictionary.csv built from plant_codebook() over the EXACT frame
  # emitted, so the columns can never drift from their documentation.
  .evo_dl <- function(getdf, tag) downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_%s_%s.zip", rv$site %||% "site", tag, format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      ev <- evo(); df <- if (is.null(ev)) data.frame() else getdf(ev)
      df <- df %||% data.frame()
      tmp <- tempfile("evozip"); dir.create(tmp)
      csv_name <- sprintf("%s.csv", tag)
      utils::write.csv(df, file.path(tmp, csv_name), row.names = FALSE, na = "")
      cb <- plant_codebook(stats::setNames(list(df), csv_name))
      utils::write.csv(cb %||% data.frame(), file.path(tmp, "data_dictionary.csv"), row.names = FALSE, na = "")
      fs <- list.files(tmp, full.names = TRUE)
      owd <- setwd(tmp); on.exit(setwd(owd), add = TRUE)
      utils::zip(zipfile = file, files = basename(fs), flags = "-q")
    }, contentType = "application/zip")
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
    # ship the FULL observed-not-in-reference set, with the state-plausibility class
    # so review (introduced + native-not-in-state) and the demoted regional associates
    # (on the state flora, not this soil unit) are both present and labelled.
    C <- ev$C_all %||% ev$C; if (is.null(C) || !nrow(C)) return(data.frame())
    cls <- if ("c_class" %in% names(C))
      ifelse(C$c_class == "regional", "regional associate (state flora, not this soil unit)", "review")
    else "review"
    data.frame(symbol = C$sym, scientificName = C$scientificName, family = C$family,
      nativity = C$nativity, classification = cls,
      mean_cover_pct = C$mean_cover, n_plots = C$n_plots) }, "observed-not-expected")
  output$evoReport <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_completeness-report_%s.zip", rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      ev <- evo(); tbl <- qc_report_table(ev, site = rv$site %||% NA_character_)
      if (is.null(tbl) || !nrow(tbl))
        tbl <- data.frame(note = sprintf("No NRCS ecological-site reference list is bundled for %s; completeness comparison unavailable.",
                                          rv$site %||% "this site"))
      tmp <- tempfile("evorep"); dir.create(tmp)
      utils::write.csv(tbl, file.path(tmp, "completeness-report.csv"), row.names = FALSE, na = "")
      cb <- plant_codebook(list("completeness-report.csv" = tbl))
      utils::write.csv(cb %||% data.frame(), file.path(tmp, "data_dictionary.csv"), row.names = FALSE, na = "")
      fs <- list.files(tmp, full.names = TRUE)
      owd <- setwd(tmp); on.exit(setwd(owd), add = TRUE)
      utils::zip(zipfile = file, files = basename(fs), flags = "-q")
    }, contentType = "application/zip")

  # ---- ABOUT --------------------------------------------------------------
  output$aboutPanel <- renderUI({
    div(class = "about-wrap",
      div(class = "about-card", h4("\U0001F33F What this is"),
        p("An (unofficial) explorer for NEON's ", tags$b("Plant presence & percent cover"), " product (", tags$code("DP1.10058.001"),
          "). NEON surveys plants in nested quadrats: 1 m² subplots (presence + percent cover), 10 m² and 100 m² subplots (presence), combined into a 400 m² plot list, at peak greenness each year.")),
      div(class = "about-card", h4(bs_icon("rulers"), " How richness is measured"),
        p("Species–area curves come straight from the nested design: a 1 m² quadrat, a 10 m² subplot, a 100 m² corner, the whole 400 m² plot. ",
          tags$b("Chao2"), " (incidence-based) estimates how many species remain undetected, the right estimator for presence/quadrat data."),
        p(class = "caveat", bs_icon("exclamation-triangle"), " Cover is an ocular estimate and vegetation layers overlap, so site-summed cover is relative, not a share of ground.")),
      div(class = "about-card", h4(bs_icon("shield-exclamation"), " Native vs invasive"),
        p("Status is NEON's ", tags$code("nativeStatusCode"), " (N native / I introduced / others → unknown). We publish the ", tags$b("unknown rate"),
          " so the invasion numbers are read honestly. The ", tags$b("invasion-pressure"), " index uses the nested scales to flag invaders established at the finest grain.")),
      div(class = "about-card", h4(bs_icon("clipboard-check"), " Expected vs Observed"),
        p("We resolve each site's coordinates to its NRCS ", tags$b("Ecological Site"), " and pull that site's ",
          tags$b("reference plant community"), " (the plants the soil and climate can support), then compare it to what NEON actually recorded, the ", tags$b("EcoPlot"), " recipe."),
        p("Because NEON samples ~400 m² per plot at peak greenness, a reference species not detected is read as ",
          tags$b("completeness"), " (or a real state-transition), ", tags$b("never as error"), ". Only two lanes are true data-quality signals: coarse IDs and nativity disagreements with USDA PLANTS."),
        p(tags$b("Dominant"), " = the core species making up the top 50% of the ecological site's reference production (NRCS air-dry lb/ac at normal precipitation), an app-defined, list-length-invariant convention, not an official NRCS designation. Forest ecological sites carry no per-species production (their dominants are canopy trees, scored by site index), so dominance isn't ranked there."),
        p(class = "caveat", bs_icon("info-circle"), " Reference flora: USDA-NRCS Soil Data Access / Ecological Site Descriptions (public domain). Nativity authority: USDA, NRCS, ",
          tags$a(href = "https://plants.usda.gov", target = "_blank", "The PLANTS Database"), ". NEON taxonomy follows USDA PLANTS symbols, so the match is an exact symbol join.")),
      div(class = "about-card", h4(bs_icon("diagram-3"), " A NEONize sibling"),
        p("Built to the NEON Small Mammal Tracker quality bar (same Desert Data Labs design system, bundling, and pin-card interaction), but the analyses are plant-native (there are no individuals to track in cover data). See the NEONize playbook."),
        p(bs_icon("envelope"), " ", tags$a(href = "mailto:desertdatalabs@gmail.com", "desertdatalabs@gmail.com"),
          " · ", tags$a(href = "https://data.neonscience.org/data-products/DP1.10058.001", target = "_blank", "NEON data product"))),
      div(class = "about-card sib-card", h4(bs_icon("compass"), " Explore the NEON series"),
        p("This is one of a family of small explorers, each built on a different NEON data product. Same look and feel, same honest-numbers approach, different living thing."),
        div(class = "sib-grid", lapply(.SIBLINGS, function(s)
          tags$a(class = "sib-link", href = s$url, target = "_blank", rel = "noopener",
            tags$span(class = "sib-name", s$name),
            tags$span(class = "sib-prod", s$prod))))))
  })
}
