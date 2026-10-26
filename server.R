# ===========================================================================
# NEON Plant Diversity Explorer · server.R
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
      font = list(color = ink, family = "system-ui, Segoe UI, sans-serif"),
      xaxis = list(gridcolor = grid, zerolinecolor = zero, linecolor = lin),
      yaxis = list(gridcolor = grid, zerolinecolor = zero, linecolor = lin),
      legend = list(bgcolor = "rgba(0,0,0,0)", orientation = "h", y = -0.2, font = list(color = legc)),
      margin = list(l = 55, r = 30, t = 48, b = 44),
      hoverlabel = list(
        bgcolor = if (dark) "rgba(20,51,34,0.96)" else "rgba(47,154,79,0.96)",
        bordercolor = if (dark) "#5fd16a" else DDL$gold,
        font = list(color = "#ffffff", family = "system-ui, Segoe UI, sans-serif", size = 13))) %>%
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
  # snapshot contract v2: rv$snap is the GRAIN event F (all scales, the latest
  # full-grain site (year, bout)); rv$cover is the COVER event Q (scale-1 rows,
  # the latest complete 1 m² site bout); rv$events labels both. Every richness /
  # incidence figure reads rv$snap, every cover-weighted figure reads rv$cover.
  rv <- reactiveValues(occ = NULL, snap = NULL, cover = NULL, events = NULL,
                       ground = NULL, lb = NULL, pal = NULL,
                       label = NULL, site = NULL, plot = NULL, ctx = NULL, is_demo = FALSE,
                       pendingSite = NULL, site_years = NULL, notices = NULL)

  # ---- snapshot-event helpers (the receipt every number names) -----------
  NO_GRAIN_TXT <- "no full-grain survey in the bundled record"
  NO_COVER_TXT <- "no 1 m² cover bout in the bundled record"
  event_field <- function(events, kind, field) {
    if (is.null(events) || !is.data.frame(events) || !nrow(events) || !(field %in% names(events)))
      return(NA)
    v <- events[[field]][as.character(events$kind) == kind]
    if (length(v)) v[1] else NA
  }
  ev_label <- function(kind, events = rv$events) {
    l <- event_field(events, kind, "label")
    y <- suppressWarnings(as.numeric(as.character(event_field(events, kind, "year"))))
    if (is.null(l) || is.na(l) || !nzchar(as.character(l)) || !length(y) || !is.finite(y))
      if (identical(kind, "grain")) NO_GRAIN_TXT else NO_COVER_TXT
    else as.character(l)
  }
  ev_year <- function(kind, events = rv$events) {
    y <- suppressWarnings(as.integer(as.character(event_field(events, kind, "year"))))
    if (length(y) && is.finite(y)) as.character(y) else "n/a"
  }
  has_rows <- function(d) !is.null(d) && is.data.frame(d) && nrow(d) > 0
  has_grain <- function() has_rows(rv$snap)
  has_cover <- function() has_rows(rv$cover)
  events_receipt <- function(events = rv$events)
    sprintf("Richness and species-area: %s. Cover, Hill, Chao2, watchlist: %s.",
            ev_label("grain", events), ev_label("cover", events))
  # cross-scale occurrence reads presence from F; its 1 m² mean cover column
  # from Q when the helper accepts a cover table.
  xscale_occ <- function(grain = rv$snap, cover = rv$cover) {
    if (!has_rows(grain)) return(NULL)
    f <- species_cross_scale_occurrence
    if ("cover" %in% names(formals(f))) f(grain, cover = cover) else f(grain)
  }

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
              r$state, r$richness, ifelse(is.na(r$pct_introduced), "n/a", sprintf("%.1f", r$pct_introduced))))))
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
    # Two labelled site events (plant-snapshot-v2): F = latest full-grain
    # (1/10/100 m²) site bout for richness; Q = latest complete 1 m² bout for cover.
    ss <- site_snapshot(b$occ, ground = b$ground)
    rv$snap   <- ss$grain
    rv$cover  <- ss$cover
    rv$events <- ss$events
    rv$ground <- b$ground
    rv$lb     <- if (has_rows(ss$grain)) plot_summary(rv$snap, rv$cover) else NULL
    rv$pal    <- make_species_pal(b$occ)
    rv$label  <- label
    rv$site   <- b$meta$site
    rv$site_years <- suppressWarnings(as.integer(b$meta$years %||% b$occ$year))
    # NEON change-log notices that start after this site's records end
    last_year <- suppressWarnings(max(rv$site_years, na.rm = TRUE))
    rv$notices <- if (is.finite(last_year))
      plant_site_notices(NEON_CHANGE_LOG, b$meta$site, as.Date(sprintf("%d-12-31", last_year))) else NULL
    session$sendCustomMessage("plantSite", list(site = b$meta$site %||% "site"))  # name the export PNGs by site
    rv$is_demo <- is_demo
    # Provenance comes from the verified release-wide source receipt. The legacy
    # 46-site family is content-addressed; filesystem mtimes are never data vintage.
    rv$built_at <- PLANT_SOURCE_STATUS$built_at
    rv$repository_imported_at <- PLANT_SOURCE_STATUS$repository_imported_at
    rv$neon_release <- PLANT_SOURCE_STATUS$neon_release
    rv$source_start <- PLANT_SOURCE_STATUS$source_start
    rv$source_cutoff <- PLANT_SOURCE_STATUS$source_cutoff
    rv$source_receipt_id <- PLANT_SOURCE_STATUS$source_receipt_id
    rv$source_digest <- PLANT_SOURCE_STATUS$source_digest
    rv$source_receipt_basis <- PLANT_SOURCE_STATUS$receipt_basis
    rv$source_provenance_class <- PLANT_SOURCE_STATUS$provenance_class
    rv$source_bundle_commit <- PLANT_SOURCE_STATUS$bundle_commit
    rv$query_package <- PLANT_SOURCE_STATUS$query_package
    rv$neon_utilities_version <- PLANT_SOURCE_STATUS$neon_utilities_version
    rv$plot   <- NULL
    yrs <- range(b$occ$year, na.rm = TRUE)
    rv$ctx <- paste0(b$meta$site, " · ", if (yrs[1] == yrs[2]) yrs[1] else paste0(yrs[1], "–", yrs[2]),
                     " · ", events_receipt(ss$events))

    shinyjs::show("mainTabsWrap"); shinyjs::show("plotPickerWrap"); shinyjs::hide("splash")
    pl <- if (has_rows(rv$lb)) rv$lb$plotID else character(0)
    updateSelectizeInput(session, "plotSel",
      choices = c("Pick a plot…" = "", if (length(pl))
        setNames(pl, sprintf("%s · %d species", short_plot(pl), rv$lb$richness))),
      selected = "", server = TRUE)
    nav_select("tabs", "overview")
    session$sendCustomMessage("countUp", list())
    session$sendCustomMessage("loadDone", list(site = b$meta$site %||% "site"))
    invisible(TRUE)
  }

  load_site <- function(site) {
    if (is.null(site) || site == "") { session$sendCustomMessage("loadDone", list()); return() }
    b <- load_site_bundle(site)
    if (is.null(b)) { session$sendCustomMessage("loadDone", list())
      showNotification("That site is not available in this release.", type = "error"); return() }
    row <- site_table[site_table$site == site, ]
    ingest(b, sprintf("%s · %s", site, if (nrow(row)) row$name else site))
  }
  # Picking a site somewhere OTHER than the sidebar (the map's Explore button, or
  # the browse list): first sync the sidebar dropdowns to THAT site (set
  # pendingSite, then cascade the state selector so the site dropdown lands on it),
  # then load it. The stateSel observer updates the dropdown choices only, it does
  # not load, so there is no double load.
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
    rv$occ <- NULL; rv$snap <- NULL; rv$cover <- NULL; rv$events <- NULL
    rv$ground <- NULL; rv$lb <- NULL
    rv$pal <- NULL; rv$label <- NULL; rv$site <- NULL; rv$plot <- NULL
    rv$site_years <- NULL; rv$notices <- NULL
    shinyjs::hide("mainTabsWrap"); shinyjs::hide("plotPickerWrap"); shinyjs::show("splash")
    session$sendCustomMessage("kickMaps", list())
  })

  # (v2 flow: the Santa Rita demo path was removed, users pick a real site on
  #  the map, the Browse-all-sites list, or the by-name select panel. The
  #  demoBtn / demoBtn2 inputs and their observers are gone with it.)

  # The map dot popup: a clear two-choice card (Explore loads the site, About
  # opens an instant info modal). Mirrors the flagship Small Mammal / Ground Beetle
  # picker. Explore raises the loading overlay client-side, then fires siteExplore;
  # About fires siteInfo (no load). Both run the SAME load path the sidebar uses.
  # Close the open picker popup before the splash hides, so Leaflet's popup
  # autoPan never runs against a 0-width map (PD-20).
  CLOSE_PICKER_POPUP_JS <- "try{var w=HTMLWidgets.find('#picker-map');if(w&&w.getMap)w.getMap().closePopup();}catch(e){}"
  site_popup_html <- function(row) {
    code <- row$site[1]
    nm   <- row$name[1] %||% code
    where <- paste(stats::na.omit(c(as.character(row$state[1]),
      if (!is.na(row$domain[1])) paste("NEON", row$domain[1]) else NA)), collapse = " · ")
    pir <- if (is.finite(row$pct_introduced[1])) sprintf("%.1f%%", row$pct_introduced[1]) else "n/a"
    fam <- if (!is.na(row$dominant_family[1]) && nzchar(as.character(row$dominant_family[1])))
      sprintf("<div class='pm-pop-sp'>Top family: %s</div>", htmltools::htmlEscape(row$dominant_family[1])) else ""
    htmltools::HTML(sprintf(
      "<div class='pm-pop site-pop'>
         <div class='pm-pop-t'>\U0001F33F %s <span class='sp-code'>(%s)</span></div>
         <div class='pm-pop-s'>%s</div>
         <div class='pm-pop-n'><b>%s</b> species &middot; <b>%s</b> introduced cover</div>
         %s
         <div class='sp-actions'>
           <button type='button' class='sp-btn sp-go' onclick=\"%ssmtLoadStart('%s · loading');Shiny.setInputValue('siteExplore','%s',{priority:'event'});\">Explore this site &rarr;</button>
           <button type='button' class='sp-btn sp-info' onclick=\"Shiny.setInputValue('siteInfo','%s',{priority:'event'});\">About this site</button>
         </div>
       </div>",
      htmltools::htmlEscape(nm), code, where, row$richness[1] %||% "?", pir, fam,
      CLOSE_PICKER_POPUP_JS, gsub("['\"]", "", nm), code, code))
  }

  # "About this site" -> an instant info modal (no bundle load). Its footer also
  # offers Explore, so the modal is a second door into the same load path.
  site_info_modal <- function(code) {
    row <- site_table[site_table$site == code, ]
    m   <- neon_sites[neon_sites$site == code, ]
    if (!nrow(row))
      return(modalDialog(title = "Site info", easyClose = TRUE, footer = modalButton("Close"),
                         p("No details are available for this site.")))
    dash <- function(x) if (length(x) == 0 || is.na(x) || !nzchar(as.character(x))) "n/a" else as.character(x)
    coords <- if (nrow(m) && !is.na(m$lat[1]) && !is.na(m$lng[1]))
      sprintf("%.3f, %.3f", m$lat[1], m$lng[1]) else "n/a"
    stat <- function(v, lab) div(class = "si-stat",
      div(class = "si-stat-n", if (is.null(v) || is.na(v)) "n/a" else format(v, big.mark = ",")),
      div(class = "si-stat-l", lab))
    pir <- if (is.finite(row$pct_introduced[1])) sprintf("%.1f%%", row$pct_introduced[1]) else "n/a"
    modalDialog(
      title = HTML(sprintf("\U0001F33F %s <span class='si-code'>(%s)</span>", row$name[1] %||% code, code)),
      easyClose = TRUE, size = "m",
      footer = tagList(
        modalButton("Close"),
        tags$button(type = "button", class = "btn btn-primary",
          onclick = sprintf("%ssmtLoadStart('%s · loading');Shiny.setInputValue('siteExplore','%s',{priority:'event'});",
                            CLOSE_PICKER_POPUP_JS, gsub("['\"]", "", row$name[1] %||% code), code),
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

  # National site-picker map on the splash: dot size = sampling support (plots),
  # never raw richness. Colour toggles
  # between invasion (% introduced cover) and completeness (% of the NRCS reference
  # flora detected, the Expected-vs-Observed spatial read). Tap a dot for the
  # Explore | About choice popup; the load comes from the popup's Explore button.
  local({
    mx <- suppressWarnings(max(site_table$pct_introduced, na.rm = TRUE)); if (!is.finite(mx)) mx <- 100
    pip_pal  <- leaflet::colorNumeric("YlOrBr", domain = c(0, mx), na.color = "#c9d3bb")
    comp_pal <- leaflet::colorNumeric(c("#E7E0CC", "#7FB07A", "#1F5C3D"), domain = c(0, 100), na.color = "#c9d3bb")
    color_by <- function() input$splashColorBy %||% "invasion"
    mapPickerServer("picker", site_table = site_table, radius_metric = "n_plots",
      color_fn = function(st) if (identical(color_by(), "completeness"))
          comp_pal(st$pct_detected) else pip_pal(st$pct_introduced),
      label_fn = function(r) sprintf("<b>%s</b> · %s, %s<br><b>%s</b> sampled plots · <b>%s</b> species · <b>%s</b> introduced cover · %s",
        r$site, r$name %||% r$site, r$state %||% "", r$n_plots %||% "?", r$richness %||% "?",
        if (is.finite(r$pct_introduced)) sprintf("%.1f%%", r$pct_introduced) else "n/a",
        if (is.finite(r$pct_detected)) sprintf("<b>%s%%</b> reference flora detected", round(r$pct_detected))
        else if (grepl("^cropland", as.character(r$completeness_status %||% ""))) "no native reference (cropland)"
        else "no ref list"),
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
        span(class = "sl-na"), " grey = no reference list bundled, or a cropland site where no native reference applies")
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
        tags$li(HTML("Pick a <b>site</b> on the map (or by name in the panel below it). Richness describes each site's latest full-grain survey (1, 10 and 100 m² subplots, surveyed every other year since 2019); cover describes its latest 1 m² bout; both are named in the hero band. Use <b>change site</b> in the hero band to switch.")),
        tags$li(HTML("<b>Diversity</b>: the nested species-area curve (1→400 m², from the full-grain survey), the Hill profile, and a bias-corrected Chao2 lower bound estimated from species seen in the 1 m² quadrats only. Compare Chao2 with the 1 m² count shown beside it, not with the plot-wide species count; the gap between those two is the estimated unseen component, not a confirmed missing-species count.")),
        tags$li(HTML("<b>Native vs Invasive</b>: introduced-cover composition plus a cross-scale occurrence view; neither is proof of spread or management priority.")),
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
  # bundles), no live fetch, instant. Two modes: find a species across sites,
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
    cov <- ifelse(is.na(d$mean_cover), "presence only",
      ifelse(d$mean_cover > 0 & d$mean_cover < 0.005, "<0.01%", sprintf("%.2f%%", d$mean_cover)))
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
    req(rv$occ)
    lb <- rv$lb; snap <- rv$snap; cov <- rv$cover
    grain_ok <- has_grain(); cover_ok <- has_cover()
    # species KPIs count distinct species-level names in the grain event F only
    sp <- if (grain_ok) resolve_nativity_records(species_level_only(snap)) else NULL
    n_sp <- if (grain_ok) dplyr::n_distinct(sp$scientificName) else NA
    n_intro <- if (grain_ok) dplyr::n_distinct(sp$scientificName[sp$nativity == "Introduced"]) else NA
    # cover KPIs read the cover event Q only
    site_intro <- if (cover_ok) site_invasion(cov) else NA_real_
    ucs <- if (cover_ok) unknown_cover_share(cov) else NA_real_
    gy <- ev_year("grain"); qy <- ev_year("cover")
    # plots tile: every plot in the grain event (the site_index population, PD-40)
    n_plots <- if (grain_ok) dplyr::n_distinct(snap$plotID) else NA
    n_lb <- if (has_rows(lb)) nrow(lb) else 0L
    # each KPI is a nav door, clicking jumps to the tab that explains it
    hero <- function(v, l, suf = "", icon, tone, ttl = NULL, nav = NULL, sub = NULL, sub2 = NULL) {
      nav_action <- if (!is.null(nav))
        sprintf("Shiny.setInputValue('heroNav','%s',{priority:'event'});", nav) else NULL
      div(class = paste0("hero-stat hero-", tone, if (!is.null(nav)) " hero-clickable" else ""), title = ttl,
        role = if (!is.null(nav)) "button" else NULL,
        tabindex = if (!is.null(nav)) "0" else NULL,
        `aria-label` = if (!is.null(nav)) hero_aria_label(v, suf, l, sub) else NULL,
        onclick = nav_action,
        onkeydown = if (!is.null(nav)) sprintf(
          "if(event.key==='Enter'||event.key===' '){event.preventDefault();%s}", nav_action),
        div(class = "hs-icon", bs_icon(icon)),
        div(if (is.null(v) || length(v) != 1L || is.na(v)) div(class = "hs-v", "n/a")
            else div(class = "hs-v count-up", `data-target` = v, `data-suffix` = suf, "0"),
            div(class = "hs-l", l),
            if (!is.null(sub)) div(class = "hs-sub", sub),
            if (!is.null(sub2)) div(class = "hs-sub", sub2)))
    }
    div(class = "hero-band",
      div(class = "hero-title", bs_icon("broadcast"), tags$b(rv$label),
        tags$span(class = "hero-receipt", bs_icon("database-check"), " ",
          if (identical(rv$source_provenance_class, "legacy-partial"))
            sprintf("exact legacy bundle set · registered %s · upstream release/cutoff unknown",
                    rv$repository_imported_at %||% "date unavailable")
          else short_receipt_html(
                 if (length(rv$site_years)) min(rv$site_years, na.rm = TRUE) else NA,
                 if (length(rv$site_years)) max(rv$site_years, na.rm = TRUE) else NA,
                 rv$neon_release, rv$source_cutoff, rv$source_receipt_id)),
        actionLink("changeSite", tagList(bs_icon("arrow-left-circle"), " change site"),
                   class = "hero-change"),
        downloadLink("reportPdf", tagList(bs_icon("file-earmark-arrow-down"), " report card (PDF)"),
                     class = "hero-report")),
      div(class = "hero-grid",
        hero(n_sp, "species", icon = "flower3", tone = "navy", nav = "diversity",
             ttl = "Species seen in the latest full-grain survey across all of this site's plots. More plots find more species, so this total is not effort-standardized; compare sites with mean species per 400 m² plot.",
             sub = if (grain_ok) sprintf("full-grain survey, %s", gy) else NO_GRAIN_TXT),
        hero(n_plots, "plots", icon = "grid-3x3", tone = "pine", nav = "map",
             sub = if (grain_ok) sprintf("in the %s full-grain survey", gy) else NULL,
             sub2 = if (grain_ok && n_lb != n_plots) sprintf("%d with species-level IDs", n_lb) else NULL),
        hero(site_intro, "% introduced cover", icon = "shield-exclamation", tone = "terra", nav = "invasive",
             ttl = "Share of vegetative cover that is introduced. Cover is an ocular estimate and plant layers overlap, so this is a relative index, not a percent of ground.",
             sub = if (!cover_ok) NO_COVER_TXT
                   else if (!is.na(ucs)) sprintf("1 m² bout %s · %.0f%% of cover is unknown status", qy, ucs)
                   else sprintf("1 m² bout %s", qy)),
        hero(n_intro, "introduced species", icon = "exclamation-triangle", tone = "gold", nav = "invasive",
             sub = if (grain_ok) sprintf("full-grain survey, %s", gy) else NULL)),
      div(class = "hero-events", bs_icon("calendar2-check"), " ", events_receipt()),
      neon_notices_html(rv$notices, class = "neon-notices hero-notices"))
  })

  # ---- OVERVIEW -----------------------------------------------------------
  output$coverBar <- renderPlotly({
    req(rv$occ)
    occ <- rv$cover; if (!has_rows(occ)) return(note_plot(NO_COVER_TXT))
    psc <- plot_species_cover(occ); if (is.null(psc)) return(note_plot("No cover data to summarise"))
    n_supported_plots <- attr(psc, "n_supported_plots", exact = TRUE) %||% dplyr::n_distinct(psc$plotID)
    nat1 <- psc %>% dplyr::group_by(.data$scientificName) %>%
      dplyr::summarise(nativity = if (all(c("Native", "Introduced") %in% unique(.data$nativity))) "Unknown" else mode_chr(.data$nativity), .groups = "drop")
    agg <- psc %>% dplyr::group_by(.data$scientificName) %>%
      dplyr::summarise(cover = sum(.data$mean_cover) / n_supported_plots, .groups = "drop") %>%
      dplyr::left_join(nat1, by = "scientificName") %>%
      dplyr::arrange(dplyr::desc(.data$cover)) %>% head(20)
    agg$scientificName <- factor(agg$scientificName, levels = rev(agg$scientificName))
    cols <- NATIVITY_COLS[agg$nativity]
    plot_ly(agg, x = ~cover, y = ~scientificName, type = "bar", orientation = "h",
      marker = list(color = unname(cols)),
      hovertemplate = paste0("%{y}<br>", agg$nativity, " · %{x:.1f} mean relative cover per supported plot<extra></extra>")) %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE,
        xaxis = list(title = sprintf("Mean relative cover per supported plot · 1 m² bout %s", ev_year("cover"))),
        yaxis = list(title = ""), margin = list(l = 200))
  })
  output$overviewInsight <- renderUI({
    req(rv$occ)
    grain_txt <- if (has_grain())
      sprintf("The %s full-grain survey (1, 10 and 100 m² subplots) records <span class='ci-hero'>%d</span> plant species across %d plots.",
        ev_year("grain"), dplyr::n_distinct(species_level_only(rv$snap)$scientificName),
        if (has_rows(rv$lb)) nrow(rv$lb) else 0L)
      else sprintf("Species counts are unavailable: %s.", NO_GRAIN_TXT)
    occ <- rv$cover; psc <- if (has_rows(occ)) plot_species_cover(occ) else NULL
    if (is.null(psc)) return(insight_banner("stars", tone = "pine", HTML(grain_txt)))
    n_supported_plots <- attr(psc, "n_supported_plots", exact = TRUE) %||% dplyr::n_distinct(psc$plotID)
    top <- psc %>% dplyr::group_by(.data$scientificName, .data$nativity) %>%
      dplyr::summarise(c = sum(.data$mean_cover) / n_supported_plots, .groups = "drop") %>% dplyr::arrange(dplyr::desc(.data$c))
    dom <- top$scientificName[1]; dom_nat <- top$nativity[1]
    insight_banner("stars", tone = if (dom_nat == "Introduced") "terra" else "pine",
      HTML(sprintf("<b><i>%s</i></b> has the most 1 m² cover across the site in the %s bout (%s). %s",
        dom, ev_year("cover"), tolower(dom_nat), grain_txt)))
  })
  output$siteInsights <- renderUI({
    req(rv$occ)
    occ <- rv$snap; cov <- rv$cover
    sa <- if (has_grain()) species_area_site(occ) else NULL
    ch <- if (has_cover()) chao2(cov) else NULL
    wl <- if (has_cover()) invasive_watchlist(cov) else NULL
    ur <- if (has_grain()) unknown_rate(occ) else NA_real_
    n_q_plots <- if (has_cover()) dplyr::n_distinct(cov$plotID) else 0L
    pts <- c()
    sa_val <- function(a) { v <- sa$richness[sa$area_m2 == a]; if (length(v) && is.finite(v)) sprintf("%.0f", v) else "n/a" }
    if (!is.null(sa)) pts <- c(pts, sprintf("In the full-grain survey (%s), a 1 m² quadrat holds about <b>%s</b> species; the full 400 m² plot reaches <b>%s</b>.",
      ev_label("grain"), sa_val(1), sa_val(400)))
    else pts <- c(pts, sprintf("Species-area and plot richness are unavailable: %s.", NO_GRAIN_TXT))
    if (!is.null(ch)) pts <- c(pts, sprintf("In the 1 m² bout (%s), <b>%d</b> species were recorded across the 1 m² quadrats; the bias-corrected Chao2 lower-bound estimate for 1 m² quadrat species is <b>%.0f</b>%s.",
      ev_label("cover"), ch$S_obs, ch$chao2, if (ch$unstable) " (few doubletons; interpret cautiously)" else ""))
    if (!is.null(wl) && nrow(wl)) pts <- c(pts, sprintf("The introduced plant with the highest relative 1 m² cover in the %s bout is <b><i>%s</i></b>, recorded in 1 m² quadrats in <b>%d</b> of %d plots with a 1 m² record.",
      ev_year("cover"), htmltools::htmlEscape(wl$scientificName[1]), wl$n_plots[1], n_q_plots))
    if (is.finite(ur)) pts <- c(pts, sprintf("Native status is unknown for %.0f%% of species in the %s full-grain survey; read the native/invasive numbers with that in mind.", ur, ev_year("grain")))
    div(class = "insight-list", lapply(pts, function(t) div(class = "il-item", bs_icon("dot"), HTML(t))))
  })
  # Ground cover (PD-15): restricted to the cover event, mean over the event's
  # sampled 1 m² units. Overstory is a canopy layer, drawn apart from the ground
  # classes in its own colour and named as such.
  output$groundBar <- renderPlotly({
    req(rv$occ)
    if (!has_cover()) return(note_plot(NO_COVER_TXT))
    g <- ground_summary(rv$ground, rv$cover); if (is.null(g) || !nrow(g)) return(note_plot("No ground-cover data in the 1 m² bout"))
    g <- as.data.frame(g)
    if (!"layer" %in% names(g)) g$layer <- ifelse(g$otherVariables == "overstory", "canopy", "ground")
    g <- g[order(g$layer == "canopy", -g$mean_cover), , drop = FALSE]
    g <- head(g, 11)
    g$lab <- ifelse(g$layer == "canopy", paste0(g$otherVariables, " (canopy layer)"), as.character(g$otherVariables))
    g$lab <- factor(g$lab, levels = rev(g$lab))
    n_units <- if ("n_units" %in% names(g)) suppressWarnings(max(g$n_units, na.rm = TRUE)) else NA
    g$pq <- if ("pct_quadrats_recorded" %in% names(g)) g$pct_quadrats_recorded else NA_real_
    g$hover <- sprintf("%s<br>%.1f%% mean cover%s", g$lab, g$mean_cover,
      ifelse(is.finite(g$pq), sprintf("<br>recorded in %.0f%% of 1 m² quadrats", g$pq), ""))
    # ground-cover bars are NOT a data-encoded palette (decorative earth tones);
    # the canopy layer takes a separate green so it never reads as a ground class.
    gcol <- if (is_dark()) "#c79a6e" else "#8a6d4b"
    ccol <- if (is_dark()) "#7fb98c" else "#3e7b4f"
    plot_ly(g, x = ~mean_cover, y = ~lab, type = "bar", orientation = "h",
      marker = list(color = ifelse(g$layer == "canopy", ccol, gcol)),
      text = ~hover, hovertemplate = "%{text}<extra></extra>", textposition = "none") %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE,
        xaxis = list(title = sprintf("Mean 1 m² cover (%%) · 1 m² bout %s%s", ev_year("cover"),
          if (is.finite(n_units)) sprintf(" · %d sampled 1 m² units", as.integer(n_units)) else "")),
        yaxis = list(title = ""), margin = list(l = 170))
  })

  # ---- DIVERSITY ----------------------------------------------------------
  output$saPlot <- renderPlotly({
    req(rv$occ); occ <- rv$snap
    if (!has_grain()) return(note_plot(paste0("Species–area unavailable:<br>", NO_GRAIN_TXT)))
    sa <- species_area_site(occ); if (is.null(sa)) return(note_plot("Not enough data for a species–area curve"))
    # the curve is a MEAN across n plots per area, carry its spread (±1 sd) as a
    # band and surface n so the reader sees how many plots back each point.
    sa$sd[!is.finite(sa$sd)] <- 0
    sa$n  <- ifelse(is.finite(sa$n), sa$n, 0)
    sa$nlab <- paste0("mean of ", sa$n, " plot", ifelse(sa$n == 1, "", "s"))
    # per-area pin-card HTML (customdata), one card per nested quadrat scale
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
        yaxis = list(title = sprintf("Mean species richness · full-grain survey %s", ev_year("grain"))))
  })
  output$saInsight <- renderUI({
    req(rv$occ)
    if (!has_grain()) return(insight_banner("graph-up", tone = "navy",
      HTML(sprintf("No species-area curve: %s. The 1 m² rows alone cannot stand in for a 10, 100 or 400 m² list.", NO_GRAIN_TXT))))
    occ <- rv$snap; sa <- species_area_site(occ); req(!is.null(sa))
    slope <- (sa$richness[sa$area_m2==400] - sa$richness[sa$area_m2==100])
    n400 <- sa$n[sa$area_m2==400]; if (!length(n400) || !is.finite(n400)) n400 <- 0
    shape <- if (n400 < 5)
        sprintf(" Based on just <b>%.0f</b> plot%s at 400 m², so treat the shape as low-support descriptive context.", n400, ifelse(n400 == 1, "", "s"))
      else if (!length(slope) || !is.finite(slope))
        " The 100-to-400 m² change is unavailable for this snapshot; no completeness claim is made."
      else sprintf(" Mean richness changes by <b>%+.0f</b> species between 100 and 400 m². That is a measured grain response, not evidence that the wider site is complete or undersampled.", slope)
    insight_banner("graph-up", tone = "pine",
      HTML(sprintf("In the full-grain survey (%s), mean richness climbs from <b>%.0f</b> species per 1 m² quadrat to <span class='ci-hero'>%.0f</span> per 400 m² plot.%s",
        ev_label("grain"), sa$richness[sa$area_m2==1], sa$richness[sa$area_m2==400], shape)))
  })
  output$hillPlot <- renderPlotly({
    req(rv$occ); occ <- rv$cover
    if (!has_rows(occ)) return(note_plot(NO_COVER_TXT))
    h <- hill_site(occ); if (is.null(h)) return(note_plot("Not enough cover data"))
    df <- data.frame(q = c("q0\nrichness","q1\ncommon","q2\ndominant"), v = as.numeric(h))
    df$q <- factor(df$q, levels = df$q)
    # q0 ≥ q1 ≥ q2 is ONE ordered quantity, not three categories, paint it a
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
    occ <- rv$cover; req(has_rows(occ)); h <- hill_site(occ); req(!is.null(h))
    even <- round(h["q1"] / h["q0"], 2)
    tagList(
      insight_banner("diagram-2", tone = "navy",
        HTML(sprintf("In the 1 m² bout (%s), of <b>%.0f</b> species with cover, only <span class='ci-hero'>%.0f</span> are effectively common (q1). Evenness ≈ <b>%.2f</b>: %s.",
          ev_label("cover"), h["q0"], h["q1"], even, if (even < 0.25) "a few species dominate the cover" else "cover is fairly spread"))),
      p(class = "hill-foot", bsicons::bs_icon("info-circle"),
        " q1/q2 weight species by cover, an ocular index whose overlapping layers make it a relative measure, not a share of ground."))
  })
  output$chaoBanner <- renderUI({
    req(rv$occ); occ <- rv$cover
    if (!has_rows(occ)) return(insight_banner("calculator", tone = "navy", HTML(sprintf("No Chao2 estimate: %s.", NO_COVER_TXT))))
    ch <- chao2(occ); req(!is.null(ch))
    insight_banner("calculator", tone = "gold",
      HTML(sprintf("In the 1 m² bout (%s), <b>%d</b> species were recorded across %d represented 1 m² quadrats. The bias-corrected <b>Chao2 lower-bound estimate</b> for 1 m² quadrat species is <span class='ci-hero'>%.0f</span>%s. Compare it with those %d species seen at 1 m², not with the plot-wide species count: the estimated unseen component is about <b>%.0f</b> species, an estimator output, not a confirmed missing-species count. No upper confidence bound is reported.",
        ev_label("cover"), ch$S_obs, ch$m, ch$chao2,
        if (ch$unstable) " and is unstable because doubletons are scarce" else "",
        ch$S_obs, max(0, round(ch$chao2 - ch$S_obs)))))
  })

  # ---- Hill member-reveal: click a q0/q1/q2 bar -> the species behind it ----
  # q1 (and q2) are evenness-weighted EFFECTIVE numbers (~N species), NOT a
  # hand-picked set of exactly N names, so the modal shows the FULL ranked-by-
  # cover list and marks the top round(q1) as the cluster "effectively common ~N"
  # describes, with that honest caveat in the header. Reuses the QC inspector +
  # downloadHandler pattern.
  hill_ranked <- reactive({ occ <- rv$cover; req(has_rows(occ)); hill_ranked_species(occ) })
  hill_csv_df <- function() {
    rk <- tryCatch(hill_ranked(), error = function(e) NULL)
    h <- if (has_cover()) hill_site(rv$cover) else NULL
    if (is.null(rk) || !nrow(rk)) return(data.frame(note = "No cover data to rank species for this site."))
    ec <- if (!is.null(h)) max(1, round(h["q1"])) else NA_integer_
    rk$effective_common_core <- if (is.na(ec)) NA else ifelse(rk$rank <= ec, "yes", "no")
    rk[, c("rank","scientificName","family","nativity","summed_cover","cover_share_pct","cum_share_pct","effective_common_core")]
  }
  # event_data() schedules a registration check on the next Shiny flush. Using
  # it as the observer trigger runs that check before this tab's lazy plot has
  # rendered, producing a false "source not registered" live-log warning.
  # Trigger on Plotly's raw input ID; a real click can only arrive after the
  # event-registered plot exists, so parsing inside the handler is warning-free.
  observeEvent(input[["plotly_click-hillSrc"]], {
    click <- plotly::event_data("plotly_click", source = "hillSrc")
    occ <- rv$cover; req(has_rows(occ))
    h  <- hill_site(occ); rk <- hill_ranked(); req(!is.null(h), !is.null(rk), nrow(rk) > 0)
    qk <- click$customdata %||% "q1"
    ec <- max(1, round(h["q1"]))
    lab <- switch(qk, q0 = "q0: richness (every species present)",
                       q1 = "q1: effectively common species",
                       q2 = "q2: dominant species", "the diversity profile")
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
        p(HTML(sprintf("You clicked <b>%s</b>. In the 1 m² bout (%s) this site holds <b>%.0f</b> species in cover; q1 says about <span class='ci-hero'>%d</span> are <b>effectively common</b> (evenness-weighted).", lab, ev_label("cover"), h["q0"], ec))),
        p(HTML(sprintf("q1 is an <b>effective number</b>, not a hand-picked list of exactly %d names. The species are ranked by summed 1 m\U00B2 cover below; the <span style='background:rgba(95,209,106,0.30);padding:1px 4px;border-radius:3px'>top %d highlighted</span> are the cluster that &ldquo;effectively common &asymp; %d&rdquo; describes. The long tail of low-cover species is real, just rare.", ec, ec, ec)))),
      dt))
  }, ignoreInit = TRUE)
  output$hillCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_hill-ranked-species_%s.csv",
                                  rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) utils::write.csv(hill_csv_df(), file, row.names = FALSE, na = ""),
    contentType = "text/csv")

  # ---- design-break marks + split annual traces ---------------------------
  # NEON changed the plot design in 2018/2019 (10 and 100 m² subplots surveyed
  # every other year since 2019) and suspended sampling in 2026. Annual plant
  # traces are split at 2019 so no line is ever drawn across the redesign.
  design_breaks_layout <- function(years) {
    empty <- list(shapes = list(), annotations = list())
    years <- suppressWarnings(as.numeric(years)); years <- years[is.finite(years)]
    if (!length(years) || !exists("design_break_shapes", mode = "function")) return(empty)
    out <- tryCatch(design_break_shapes(years, dark = is_dark()), error = function(e) empty)
    list(shapes = out$shapes %||% list(), annotations = out$annotations %||% list())
  }
  add_split_trace <- function(p, df, ycol, name, color, mcolor = color, width = 3, size = 9,
                              textcol = NULL, hovertemplate = NULL, split = 2019) {
    yr <- suppressWarnings(as.numeric(df$year))
    first <- TRUE
    for (seg in list(which(yr < split), which(yr >= split))) {
      if (!length(seg)) next
      s <- df[seg, , drop = FALSE]
      p <- plotly::add_trace(p, x = s$year, y = s[[ycol]], type = "scatter", mode = "lines+markers",
        name = name, legendgroup = name, showlegend = first,
        line = list(color = color, width = width), marker = list(color = mcolor, size = size),
        text = if (!is.null(textcol)) s[[textcol]] else NULL, hovertemplate = hovertemplate)
      first <- FALSE
    }
    p
  }

  # ---- NATIVE vs INVASIVE -------------------------------------------------
  output$invTrend <- renderPlotly({
    occ <- rv$occ; req(occ); nt <- native_trend(occ, ground = rv$ground); if (is.null(nt) || !nrow(nt)) return(note_plot("No introduced-cover trend"))
    nt$hover <- sprintf("%d<br>%.1f%% introduced cover<br>%d recurrent plots · %d sampled 1 m² units<br>selected bout(s): %s",
      nt$year, nt$pct_introduced, nt$n_plots, nt$n_sampling_units,
      ifelse(is.na(nt$selected_bouts), "not recorded", nt$selected_bouts))
    db <- design_breaks_layout(nt$year)
    add_split_trace(plot_ly(), nt, "pct_introduced", "% introduced cover", DDL$introduced,
      textcol = "hover", hovertemplate = "%{text}<extra></extra>") %>%
      plotly_theme(legend = FALSE) %>%
      plotly::layout(showlegend = FALSE, xaxis = list(title = "", dtick = 1),
        yaxis = list(title = "% of cover introduced", rangemode = "tozero"),
        shapes = db$shapes, annotations = db$annotations)
  })
  output$invInsight <- renderUI({
    occ <- rv$occ; req(occ); nt <- native_trend(occ, ground = rv$ground)
    ur <- if (has_grain()) unknown_rate(rv$snap) else NA_real_; req(!is.null(nt))
    fin <- nt[is.finite(nt$pct_introduced), , drop = FALSE]; req(nrow(fin) >= 1)
    last <- fin[nrow(fin), ]; first <- fin[1, ]
    dir <- if (nrow(fin) < 2 || last$pct_introduced == first$pct_introduced) "about the same as"
           else if (last$pct_introduced > first$pct_introduced) "up from" else "down from"
    insight_banner("shield-exclamation", tone = "terra",
      HTML(sprintf("Within the recurrent panel of <b>%d plots</b>, introduced plants make up <span class='ci-hero'>%.1f%%</span> of relative cover in %d, %s %.1f%% in %d. These are descriptive registered endpoints; %s",
        last$n_plots, last$pct_introduced, last$year, dir, first$pct_introduced, first$year,
        if (is.finite(ur)) sprintf("native status is unknown for %.0f%% of species in the %s full-grain survey.", ur, ev_year("grain"))
        else "the unknown-status rate needs a full-grain survey, and none is bundled.")))
  })
  output$invTable <- DT::renderDT({
    req(rv$occ); occ <- rv$cover
    if (!has_rows(occ)) return(DT::datatable(data.frame(Message = NO_COVER_TXT), rownames = FALSE, options = list(dom = "t")))
    wl <- invasive_watchlist(occ)
    if (is.null(wl) || !nrow(wl)) return(DT::datatable(data.frame(Message = sprintf("No introduced species recorded in the %s 1 m² bout.", ev_year("cover"))), rownames = FALSE, options = list(dom = "t")))
    # "<0.1" for present-but-tiny cover (PD-22); a hidden numeric column carries
    # the sort. Family hides under 576 px (Responsive "min-tablet-p") so the plot
    # count that qualifies the cover number stays visible on phones (PD-45).
    df <- data.frame(Species = wl$scientificName, Family = wl$family,
                     `Mean cover %` = watchlist_cover_label(wl$mean_cover),
                     `# plots (1 m²)` = wl$n_plots, `_cov_sort` = wl$mean_cover, check.names = FALSE)
    DT::datatable(df, rownames = FALSE, extensions = "Responsive",
      options = list(pageLength = 8, dom = "tp", order = list(list(4, "desc")), responsive = TRUE,
        columnDefs = list(
          list(className = "min-tablet-p", targets = 1),
          list(orderData = 4, targets = 2),
          list(visible = FALSE, targets = 4))))
  })
  output$watchlistCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_invasive-watchlist_%s.csv",
                                  rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      occ <- rv$cover; wl <- if (!has_rows(occ)) NULL else invasive_watchlist(occ)
      out <- if (is.null(wl) || !nrow(wl)) data.frame(note = sprintf("No introduced species recorded in the 1 m² bout (%s).", ev_label("cover")))
             else data.frame(scientificName = wl$scientificName, family = wl$family,
                             mean_cover_pct = signif(wl$mean_cover, 3), n_plots = wl$n_plots,
                             n_supported_plots = wl$n_supported_plots,
                             cover_event = ev_label("cover"),
                             stringsAsFactors = FALSE)
      utils::write.csv(out, file, row.names = FALSE, na = "")
    }, contentType = "text/csv")
  output$pressurePlot <- renderPlotly({
    req(rv$occ)
    if (!has_grain()) return(note_plot(paste0("Cross-scale occurrence unavailable:<br>", NO_GRAIN_TXT)))
    fh <- xscale_occ(); if (is.null(fh) || !nrow(fh)) return(note_plot("No introduced species recorded here"))
    mx <- max(c(fh$plots_1m, fh$plots_400), 1)
    # both axes are small integer plot-counts, so ties pile up invisibly on the
    # 1:1 line, nudge the DISPLAY positions deterministically while the hover (and
    # the click reveal) keep the TRUE integers + the species name (customdata).
    set.seed(1)
    fh$jx <- fh$plots_1m  + stats::runif(nrow(fh), -0.12, 0.12)
    fh$jy <- fh$plots_400 + stats::runif(nrow(fh), -0.12, 0.12)
    # per-species pin-card HTML, the .smt-open chip opens this species in the
    # foothold reveal modal (same path as a direct click). data-tag = species key.
    # customdata carries the pin-card HTML (what pincards.js pins on a tap); the
    # species name rides in its data-tag, which BOTH the .smt-open chip and the
    # server's direct plotly_click handler read to open the foothold reveal.
    # escaped markup (PD-30): the data-tag is attribute-escaped so names with an
    # apostrophe (Erodium cicutarium (L.) L'Hér. ex Aiton) round-trip intact.
    fh$tip <- foothold_tip_html(fh$scientificName, fh$family, fh$plots_1m, fh$plots_400, fh$mean_cover_1m)
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
        annotations = list(list(text = sprintf("each dot = one introduced species · full-grain survey %s · above 1:1 = more broad-grain than 1 m² detections (jittered only to separate ties)", ev_year("grain")),
          x = 0, y = 1.06, xref = "paper", yref = "paper", showarrow = FALSE, xanchor = "left",
          font = list(color = if (is_dark()) "#9fb0c4" else "#6b7a85", size = 11))))
  })

  # ---- Cross-scale member reveal: explicit "Where is it?" chip only ---------
  # A plot tap pins a card. The user then chooses the explicit, keyboard-accessible
  # chip to open the detail; a tap never both pins and launches a modal.
  rv_foothold <- reactiveVal(NULL)
  show_foothold <- function(sp) {
    req(has_grain()); fh <- xscale_occ(); req(!is.null(fh))
    row <- fh[fh$scientificName == sp, , drop = FALSE]
    if (!nrow(row)) return(invisible())
    rv_foothold(sp)
    broader_only <- setdiff(strsplit(row$plotlist_400, ", ")[[1]], strsplit(row$plotlist_1m, ", ")[[1]])
    gap <- row$plots_400 - row$plots_1m
    reach <- if (gap > 0) sprintf("The species was detected in <b>%d</b> more plot%s at the broader 400 m\U00B2 grain than in sampled 1 m\U00B2 quadrats (%s). Review detectability, patchiness, and sampling support before interpreting the gap; it is not evidence of temporal spread.",
                                  gap, ifelse(gap == 1, "", "s"), if (length(broader_only)) paste(broader_only, collapse = ", ") else "n/a")
             else "Every plot-level detection was also represented at the finest sampled 1 m\U00B2 grain. This describes cross-scale occurrence only, not trend or impact."
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
        tile(if (is.finite(row$mean_cover_1m)) paste0(row$mean_cover_1m, "%") else "n/a", "mean 1 m\U00B2 cover")),
      div(class = "qc-modal-intro", p(HTML(reach))),
      div(class = "foothold-plots",
        p(tags$b("At 1 m\U00B2 (finest scale): "), if (nzchar(row$plotlist_1m)) row$plotlist_1m else em("not detected at 1 m\U00B2")),
        p(tags$b("Across the 400 m\U00B2 plot: "), if (nzchar(row$plotlist_400)) row$plotlist_400 else em("n/a")))))
  }
  observeEvent(input$footholdRequest, if (nzchar(input$footholdRequest %||% "")) show_foothold(input$footholdRequest), ignoreInit = TRUE)
  output$footholdCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_foothold-%s_%s.csv",
                                  rv$site %||% "site",
                                  gsub("[^A-Za-z0-9]+", "-", rv_foothold() %||% "species"),
                                  format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      sp <- rv_foothold(); fh <- xscale_occ()
      row <- if (!is.null(fh)) fh[fh$scientificName == sp, , drop = FALSE] else NULL
      out <- if (is.null(row) || !nrow(row)) data.frame(note = "No foothold data for this species.")
             else data.frame(
               scientificName = row$scientificName, family = row$family, nativity = "Introduced",
               plots_at_1m2 = row$plots_1m, plots_in_400m2 = row$plots_400,
               broad_minus_1m_detection_gap = row$plots_400 - row$plots_1m,
               mean_cover_pct_1m2 = row$mean_cover_1m,
               plots_at_1m2_list = row$plotlist_1m, plots_in_400m2_list = row$plotlist_400,
               grain_event = ev_label("grain"),
               stringsAsFactors = FALSE)
      utils::write.csv(out, file, row.names = FALSE, na = "")
    }, contentType = "text/csv")

  # ---- ENVIRONMENT (climate & phenology vs the plant signal) -------------
  # Env data loads lazily per site (only when something on this tab renders).
  cur_env <- reactive({ s <- rv$site; if (is.null(s) || !nzchar(s)) return(NULL); load_env(s) })

  observe({                                       # populate the context-series picker
    e <- cur_env(); ch <- c("Largest screened association" = "best")
    if (!is.null(e)) ch <- c(ch, env_layer_choices(e)[-1])
    sel <- input$envLayer %||% "best"; if (!(sel %in% ch)) sel <- "best"
    updateSelectInput(session, "envLayer", choices = ch, selected = sel)
  })

  env_series <- reactive({ req(rv$occ); plant_metric_series(rv$occ, input$envMetric %||% "pct_introduced", ground = rv$ground) })
  env_rank   <- reactive({ ms <- env_series(); e <- cur_env(); if (is.null(ms) || is.null(e)) NULL else plant_env_all(ms, e) })
  env_perm   <- reactive({
    ms <- env_series(); e <- cur_env(); if (is.null(ms) || is.null(e)) return(NULL)
    lay <- input$envLayer %||% "best"
    plant_env_perm(ms, e, B = 499, only = if (lay == "best") NULL else lay)
  })
  env_metric_lab <- reactive(PLANT_METRICS[[input$envMetric %||% "pct_introduced"]]$label)
  env_metric_dig <- reactive(PLANT_METRICS[[input$envMetric %||% "pct_introduced"]]$dig %||% 1)

  # ---- Short-record context exports (matched annual series + scan) ----------
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
    filename = function() sprintf("NEON-PlantDiversity_%s_context-association-scan_%s.csv",
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
          lag_search_p   = round(pvals, 3),
          permutation_scope = "within-driver 0–2 year lag screen",
          stringsAsFactors = FALSE)
        out <- out[order(-abs(out$spearman_r)), , drop = FALSE]
      }
      if (!nrow(out))
        out <- data.frame(note = "No complete co-located context series, or too few registered survey years, to scan associations for this site.")
      utils::write.csv(out, file, row.names = FALSE, na = "")
    }, contentType = "text/csv")

  output$envSourceNote <- renderUI({
    if (is.null(cur_env())) return(NULL)
    rich_note <- if (identical(input$envMetric %||% "pct_introduced", "richness"))
      " Within the recurrent panel (mean 1 m² richness is the annual response since 10 and 100 m² subplots are surveyed every other year), each year averages the same plots." else ""
    div(class = "env-source env-real", bs_icon("patch-check-fill"),
        tags$span(HTML(sprintf(" Bundled from co-located NEON records at <b>%s</b>: only complete annual precipitation, temperature, and phenology windows are eligible for this descriptive view. Dotted lines mark NEON design changes; the plant line is broken at 2019.%s",
                               rv$site %||% "this site", rich_note))))
  })

  output$envCorrNote <- renderUI({
    e <- cur_env(); ms <- env_series()
    if (is.null(e)) return(div(class = "chart-insight ci-muted", bs_icon("cloud-slash"),
      div(class = "ci-text", "No co-located environmental data is bundled for this site yet.")))
    if (is.null(ms) || nrow(ms) < MIN_ENV_YEARS)
      return(div(class = "chart-insight ci-muted", bs_icon("hourglass-split"),
        div(class = "ci-text", HTML(sprintf("Only <b>%d</b> registered survey year%s here, too few even for the screened association view (need %d+). The raw series remain context only.",
          if (is.null(ms)) 0L else nrow(ms), if (!is.null(ms) && nrow(ms) == 1) "" else "s", MIN_ENV_YEARS)))))
    pm <- env_perm(); if (is.null(pm)) return(NULL); pk <- pm$top
    v <- env_verdict(pk$r, pm$p, pk$n); pos <- pk$r >= 0
    rail <- switch(v$tone, strong = "rail-strong", mod = "rail-mod", "rail-weak")
    lagtxt <- if (pk$lag == 0) "same-year signal" else if (pk$lag == 1) "1-yr lead" else sprintf("%d-yr lead", pk$lag)
    metricLab <- env_metric_lab()
    div(class = paste("ec", rail),
      style = sprintf("--ec-driver-hue:%s;", ENV_LAYERS[[pk$layer]]$color %||% "#8a97a8"),
      div(class = "ec-eyebrow", bs_icon("graph-up-arrow"), tags$span("short-record association scan"),
          tags$span(class = "ec-demo", "descriptive only")),
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
          HTML(sprintf("higher %s appears with <b>%s</b> %s", tolower(pk$label), if (pos) "higher" else "lower", tolower(metricLab))))))
  })

  output$envCaveat <- renderUI({
    pm <- env_perm(); if (is.null(pm)) return(NULL); pk <- pm$top
    n_drv <- if (is.null(env_rank())) 0L else nrow(env_rank())
    selected <- input$envLayer %||% "best"
    n_lags <- length(ENV_LAGS)
    scope <- if (identical(selected, "best"))
      sprintf("largest of %d context series × %d screened lags", n_drv, n_lags) else
      sprintf("largest association for the selected %s series across %d screened lags",
              tolower(pk$label), n_lags)
    correction <- if (identical(selected, "best"))
      "the full series × lag search" else "this selected series's lag search"
    sig <- !is.na(pm$p) && pm$p < 0.05
    div(class = "pop-caveat", style = "margin: 0 0 14px;", bs_icon("exclamation-triangle"),
      HTML(sprintf(" The r above is the <b>%s</b>; the circular-shift p (%.2f) accounts for %s. %s With only %d registered survey years and shared time trends, this remains descriptive and is never promoted as an edge in the NEON Cross-Product Response Atlas.",
        scope, pm$p, correction,
        if (sig) "It clears the search-corrected chance bar in this short record, but no fit or causal claim is drawn." else "It does <b>not</b> clear the search-corrected chance bar.",
        pk$n)))
  })

  output$envScatter <- renderPlotly({
    e <- cur_env(); ms <- env_series(); pm <- env_perm()
    if (is.null(e) || is.null(ms)) return(note_plot("No environmental data for this site", "\U0001F326"))
    if (is.null(pm)) return(note_plot("Too few survey years to compare", "\U0001F326"))
    pk <- pm$top; meta <- ENV_LAYERS[[pk$layer]]
    pts <- plant_env_points(ms, e, pk$layer, pk$lag)
    if (is.null(pts) || nrow(pts) < 3) return(note_plot("Not enough year-matched data for this context series", "\U0001F326"))
    metricLab <- env_metric_lab(); mdig <- env_metric_dig()
    p <- plot_ly(pts, x = ~driver, y = ~metric, type = "scatter", mode = "markers+text",
      text = ~year, textposition = "top center",
      textfont = list(size = 10, color = if (is_dark()) "#9fb0c4" else "#6b7a85"),
      marker = list(size = 12, color = meta$color, opacity = 0.85, line = list(color = "#fff", width = 1)),
      hovertemplate = paste0("year %{text}<br>", meta$label, ": %{x:.", (meta$dig %||% 0), "f} ", meta$unit,
                             "<br>", metricLab, ": %{y:.", mdig, "f}<extra></extra>"))
    # No fitted line: even the one site that clears the scan-corrected threshold
    # has too short a record for a visually authoritative ecological fit.
    p %>% plotly_theme(legend = FALSE) %>% plotly::layout(
      xaxis = list(title = sprintf("%s (%s)%s", meta$label, meta$unit, if (pk$lag) sprintf(" \U00B7 %d-yr lead", pk$lag) else "")),
      yaxis = list(title = metricLab))
  })

  output$envDriverRank <- renderPlotly({
    r <- env_rank(); if (is.null(r) || !nrow(r)) return(note_plot("Too few registered years to scan context associations", "\U0001F326"))
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
          text = sprintf("largest of %d context series%s \U00D7 3 lags \U00B7 sorted by |r| \U00B7 descriptive, not independent evidence",
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
    p <- add_split_trace(p, ms, "value", metricLab, DDL$green2, mcolor = DDL$green,
      hovertemplate = paste0(metricLab, " %{x}: %{y:.", mdig, "f}<extra></extra>"))
    db <- design_breaks_layout(c(ms$year, if (!is.null(ea) && nrow(ea)) ea$year))
    p %>% plotly_theme() %>% plotly::layout(
      shapes = db$shapes, annotations = db$annotations,
      xaxis = list(title = "", dtick = 1),
      yaxis = list(title = metricLab, rangemode = "tozero"),
      yaxis2 = list(title = sprintf("%s (%s)", meta$label, meta$unit), overlaying = "y", side = "right",
                    showgrid = FALSE, rangemode = "tozero", color = meta$color))
  })

  # ---- DIVERSITY LAB (the flagship pin-card scatter) ---------------------
  # x = 400 m² plot richness from the grain event F; y = introduced cover from the
  # cover event Q. A plot in F with no 1 m² record in Q has no y and is NOT drawn
  # (it used to sit at y = 0, which read as "native-dominated").
  lab_points <- reactive({
    lb <- rv$lb; req(has_rows(lb))
    pts <- lb[is.finite(lb$richness), , drop = FALSE]
    list(pts = pts[is.finite(pts$pct_introduced), , drop = FALSE],
         n_dropped = sum(!is.finite(pts$pct_introduced)), n_all = nrow(pts))
  })
  output$labInsight <- renderUI({
    req(rv$occ)
    if (!has_grain()) return(insight_banner("bullseye", tone = "navy",
      HTML(sprintf("No plot scatter: %s.", NO_GRAIN_TXT))))
    lp <- lab_points()
    insight_banner("bullseye", tone = "navy",
      HTML(sprintf("<b>%d</b> plots drawn: richness from the full-grain survey (%s), introduced cover from the 1 m² bout (%s).%s",
        nrow(lp$pts), ev_label("grain"), ev_label("cover"),
        if (lp$n_dropped > 0) sprintf(" <b>%d</b> plot%s without a 1 m² cover record in the %s bout %s not drawn.",
          lp$n_dropped, if (lp$n_dropped == 1) "" else "s", ev_year("cover"), if (lp$n_dropped == 1) "is" else "are") else "")))
  })
  output$labScatter <- renderPlotly({
    req(rv$occ)
    if (!has_grain()) return(note_plot(NO_GRAIN_TXT))
    lp <- lab_points(); pts <- lp$pts
    if (!nrow(pts)) return(note_plot(sprintf("No plot has both a full-grain list and a 1 m² cover record in the %s bout", ev_year("cover"))))
    pts$piv <- pts$pct_introduced
    pts$short <- short_plot(pts$plotID)
    gy <- ev_year("grain"); qy <- ev_year("cover")
    # colour key
    keycol <- input$labColor %||% "nlcdClass"
    if (keycol == "domfam") {
      fam <- vapply(pts$dominant, function(s) { occ <- rv$occ; f <- occ$family[occ$scientificName == s][1]; if (is.na(f)) "n/a" else f }, character(1))
      pts$key <- fam
    } else pts$key <- as.character(pts[[keycol]])
    pts$key[is.na(pts$key) | pts$key == ""] <- "n/a"
    # family/NLCD colouring can yield many keys; an interpolated Dark2 muddies
    # past 8. Collapse to the top-8 by point count + an "Other" bucket, then map
    # straight onto the CVD-safe Okabe-Ito set so the legend always fits (≤9).
    keep <- names(sort(table(pts$key), decreasing = TRUE))
    keep <- keep[seq_len(min(8, length(keep)))]
    pts$key[!(pts$key %in% keep)] <- "Other"
    keys <- c(keep, if (any(pts$key == "Other")) "Other")
    kpal <- setNames(OKABE_ITO[seq_along(keep)], keep)
    if (any(pts$key == "Other")) kpal["Other"] <- "#999999"

    # per-plot pin-card HTML (customdata), the .smt-open chip opens the plot profile
    tip <- paste0(
      "<span class='smt-pin-emoji'>\U0001F33E</span> <b>", pts$short, "</b> ",
      "<span class='smt-pin-rar'>", pts$richness, " species / 400 m² (", gy, ")</span><br/>",
      "<span class='smt-pin-stats'>",
        pts$n_native, " native · ", pts$n_introduced, " introduced",
        ifelse(is.na(pts$pct_introduced), "", paste0("<br/>", pts$pct_introduced, "% introduced 1 m² cover (", qy, ")")),
        "<br/>dominant (1 m² cover): <i>", ifelse(is.na(pts$dominant), "n/a", htmltools::htmlEscape(pts$dominant)), "</i></span>",
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
        text = ~paste0("plot ", short, " · ", richness, " spp / 400 m² (", gy, ")"),
        hovertemplate = paste0("%{text}<br>%{y:.1f}% introduced cover (1 m², ", qy, ")<extra></extra>"))
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
    # (no site/year caption here, the long quadrant subtitle owns the top strip;
    #  the site is already in the hero band, so a right-anchored caption collides.)
    p %>% plotly_theme() %>% plotly::layout(
      xaxis = list(title = sprintf("species per 400 m² plot, %s", gy)),
      yaxis = list(title = sprintf("%% introduced cover, %s", qy), rangemode = "tozero"),
      shapes = list(
        list(type="line", xref="x", yref="paper", x0=mx, x1=mx, y0=0, y1=1, line=list(color=qcol, dash="dot", width=1)),
        list(type="line", xref="paper", yref="y", x0=0, x1=1, y0=my, y1=my, line=list(color=qcol, dash="dot", width=1))),
      annotations = ann, hovermode = "closest")
  })

  output$labTable <- DT::renderDT({
    lb <- rv$lb; req(has_rows(lb))
    open_btn <- vapply(lb$plotID, function(pid) sprintf(
      "<button type='button' class='sp-btn sp-go plot-table-open' aria-label='Open profile for plot %s' data-plot-id=\"%s\">Open profile</button>",
      htmltools::htmlEscape(short_plot(pid), attribute = TRUE),
      htmltools::htmlEscape(as.character(pid), attribute = TRUE)), character(1))
    tbl <- data.frame(
      Plot = vapply(lb$plotID, short_plot, character(1)),
      `Richness (400 m², grain survey)` = lb$richness,
      Native = lb$n_native,
      Introduced = lb$n_introduced,
      `Introduced cover (relative %, 1 m² bout)` = lb$pct_introduced,
      `Dominant plant (1 m² cover)` = lb$dominant,
      Action = open_btn,
      check.names = FALSE, stringsAsFactors = FALSE)
    DT::datatable(tbl, rownames = FALSE, escape = seq_len(ncol(tbl) - 1L), selection = "none",
      options = list(pageLength = 10, scrollX = TRUE, dom = "tip",
        columnDefs = list(list(orderable = FALSE, targets = ncol(tbl) - 1L))))
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
          sprintf(" · %d species / 400 m² (%s) · %d native · %d introduced", row$richness, ev_year("grain"), row$n_native, row$n_introduced),
          if (!is.na(row$pct_introduced)) sprintf(" · %s%% introduced 1 m² cover (%s)", row$pct_introduced, ev_year("cover"))
          else sprintf(" · no 1 m² record in the %s bout", ev_year("cover"))),
        div(class = "ls-dom", "dominant: ", em(ifelse(is.na(row$dominant), "n/a", row$dominant)))),
      actionButton("goPlotFromCard", tagList(bs_icon("arrows-fullscreen"), " Open full profile"),
                   class = "btn-outline-dark btn-sm"))
  })

  # ---- PLOT PROFILE (the funnel target, downloadable) --------------------
  plot_card_ui <- function(pid) {
    lb <- rv$lb; req(has_rows(lb)); row <- lb[lb$plotID == pid, ]; if (!nrow(row)) return(NULL)
    # cover rows from the cover event Q; species-area from the grain event F
    in_q <- has_cover() && pid %in% rv$cover$plotID
    no_q_txt <- sprintf("no 1 m² record in the %s bout", ev_year("cover"))
    psc <- if (in_q) plot_species_cover(rv$cover[rv$cover$plotID == pid, , drop = FALSE],
      units = attr(rv$cover, "sampled_units", exact = TRUE)) else NULL
    sa <- species_area_plot(rv$snap, pid)
    tile <- function(v, l) div(class = "qc-tile", div(class = "qc-tile-v", v), div(class = "qc-tile-l", l))
    pivbar <- if (!in_q || !is.finite(row$total_cover %||% NA_real_)) p(class = "qc-cap-note", tools::toTitleCase(no_q_txt), ".") else {
      nat <- ifelse(is.na(row$native_cover), 0, row$native_cover); intro <- ifelse(is.na(row$intro_cover), 0, row$intro_cover)
      tot <- nat + intro; np <- if (tot>0) round(100*nat/tot) else 0; ip <- 100 - np
      div(class = "piv-bar", title = sprintf("%d%% native / %d%% introduced cover", np, ip),
        div(class = "piv-native", style = sprintf("width:%d%%", np), if (np>12) paste0(np,"% native")),
        div(class = "piv-intro", style = sprintf("width:%d%%", ip), if (ip>12) paste0(ip,"% intro")))
    }
    body <- div(id = "qcCardNode", class = "qc-card", `data-short` = short_plot(pid),
      div(class = "qc-head",
        span(class = "qc-emoji", "\U0001F33E"),
        div(div(class = "qc-id", short_plot(pid),
              if (!is.na(row$pct_introduced) && row$pct_introduced >= 10)
                span(class = "ds-warn", bs_icon("shield-exclamation"), " invaded")),
            div(class = "qc-sci", sprintf("NEON plot · %s · %s", row$plotType %||% "", row$nlcdClass %||% "")),
            div(class = "qc-sci qc-events", sprintf("Richness: %s · Cover: %s", ev_label("grain"),
              if (in_q) ev_label("cover") else no_q_txt))),
        div(class = "qc-head-badges", glow_badge(paste0(row$richness, " species"), DDL$green))),
      div(class = "qc-tiles",
        tile(row$richness, sprintf("species / 400 m² (%s)", ev_year("grain"))),
        tile(row$n_native, "native"),
        tile(row$n_introduced, "introduced"),
        tile(ifelse(is.na(row$pct_introduced), "n/a", paste0(row$pct_introduced, "%")),
             if (in_q) sprintf("introduced 1 m² cover (%s)", ev_year("cover")) else no_q_txt),
        tile(ifelse(is.na(row$total_cover), "n/a", row$total_cover),
             if (in_q) sprintf("total 1 m² cover (%s)", ev_year("cover")) else "total cover")),
      div(class = "qc-section-h", bs_icon("layout-split"), " Native vs introduced cover"), pivbar,
      div(class = "qc-section-h", bs_icon("graph-up"), sprintf(" Species–area (1→400 m², %s)", ev_year("grain"))),
      if (!is.null(sa)) plotlyOutput("plotSpark", height = "150px") else p(class = "qc-cap-note", "n/a"),
      div(class = "qc-section-h", bs_icon("flower2"), sprintf(" Top plants by 1 m² cover (%s)", ev_year("cover"))),
      if (!is.null(psc) && nrow(psc)) {
        top <- psc[order(-psc$mean_cover), ][seq_len(min(10, nrow(psc))), ]
        div(class = "qc-cap-scroll", tags$table(class = "inspect-tbl",
          tags$thead(tags$tr(lapply(c("Species","Family","Nativity","Mean cover %"), tags$th))),
          tags$tbody(lapply(seq_len(nrow(top)), function(i) tags$tr(
            tags$td(em(top$scientificName[i])), tags$td(top$family[i] %||% "n/a"),
            tags$td(span(style = sprintf("color:%s;font-weight:600", NATIVITY_COLS[top$nativity[i]]), top$nativity[i])),
            tags$td(watchlist_cover_label(top$mean_cover[i])))))))
      } else p(class = "qc-cap-note", if (in_q) "No 1 m² cover recorded for this plot." else paste0(tools::toTitleCase(no_q_txt), ".")))
    div(body, div(class = "qc-toolbar",
      tags$button(class = "smt-snap-btn", type = "button", onclick = "smtSaveQcCard()", bsicons::bs_icon("download"), " Save plot card (PNG)"),
      downloadButton("plotCsv", "Download plot data (CSV)", class = "smt-clear-btn")))
  }
  # One stable output id. Plot changes invalidate this renderer instead of
  # registering a new output object for every plot visited during the session.
  output$plotSpark <- renderPlotly({
      pid <- rv$plot; req(pid, has_grain())
      sa <- species_area_plot(rv$snap, pid); if (is.null(sa)) return(note_plot("n/a"))
      plot_ly(sa, x = ~area_m2, y = ~richness, type = "scatter", mode = "lines+markers",
        line = list(color = DDL$green, width = 2.5), marker = list(color = DDL$green2, size = 7),
        hovertemplate = "%{x} m²<br>%{y:.0f} species<extra></extra>") %>%
        plotly_theme(legend = FALSE) %>%
        plotly::layout(xaxis = list(title = "", type = "log", tickvals = c(1,10,100,400), ticktext = c("1","10","100","400")),
          yaxis = list(title = "species"), margin = list(l = 40, r = 10, t = 10, b = 30))
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
      build_diversity_report(file, occ, rv$ground, label = rv$label %||% (rv$site %||% "Site"), expected = e,
                             release = rv$neon_release, doi = PLANT_RELEASE_DOI) },
    contentType = "application/pdf")

  output$allDataZip <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_data_%s.zip", rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    contentType = "application/zip",
    content = function(file) {
      occ <- rv$occ; req(occ); site <- rv$site %||% "site"
      tmp <- tempfile("pdeexport"); dir.create(tmp)
      keep <- intersect(c("plotID","subplotID","scale","year","bout","taxonID","scientificName",
        "taxonRank","family","nativeStatusCode","nativity","percentCover","is_species"), names(occ))
      occ_all <- occ[, keep, drop = FALSE]
      names(occ_all)[names(occ_all) == "scale"] <- "scale_m2"
      # plant-snapshot-v2: analysis_snapshot = grain event F (all scales);
      # cover_snapshot = cover event Q (1 m² rows). Each row names its event.
      # Column name: the codebook's documented event column when present
      # (grain_event / cover_event), else the documented snapshotContract.
      ev_col <- function(pref) if (pref %in% names(.PLANT_COL_MEANING)) pref else "snapshotContract"
      snap_frame <- function(d, kind) {
        if (!has_rows(d)) {
          out <- occ[0, keep, drop = FALSE]
        } else out <- d[, intersect(keep, names(d)), drop = FALSE]
        names(out)[names(out) == "scale"] <- "scale_m2"
        out[[ev_col(if (identical(kind, "grain")) "grain_event" else "cover_event")]] <-
          rep(ev_label(kind), nrow(out))
        out
      }
      analysis_snapshot <- snap_frame(rv$snap, "grain")
      cover_snapshot <- snap_frame(rv$cover, "cover")
      pl <- rv$lb
      gr <- rv$ground
      if (!is.null(gr) && "percentCover" %in% names(gr))
        names(gr)[names(gr) == "percentCover"] <- "groundCoverPct"
      env <- tryCatch(load_env(site), error = function(e) NULL)
      bundle_file <- file.path(SITE_DIR, paste0(site, ".rds"))
      env_file <- file.path(ENV_DIR, paste0(site, ".rds"))
      # Provenance stamp for the exact verified source family. Legacy bytes retain
      # their partial receipt rather than borrowing a checkout/deploy timestamp.
      built_at <- rv$built_at
      if (is.null(built_at) || length(built_at) != 1L || is.na(built_at) ||
          !nzchar(trimws(as.character(built_at)))) built_at <- NA_character_
      neon_rel <- rv$neon_release %||% NA_character_
      repository_imported_at <- rv$repository_imported_at %||% NA_character_
      source_start <- rv$source_start %||% NA_character_
      source_cutoff <- rv$source_cutoff %||% NA_character_
      source_receipt_id <- rv$source_receipt_id %||% NA_character_
      source_digest <- rv$source_digest %||% NA_character_
      receipt_basis <- rv$source_receipt_basis %||% NA_character_
      provenance_class <- rv$source_provenance_class %||% NA_character_
      source_bundle_commit <- rv$source_bundle_commit %||% NA_character_
      query_package <- rv$query_package %||% NA_character_
      neon_utilities_version <- rv$neon_utilities_version %||% NA_character_
      raw_source_inventory <- "data/source/plant-raw-SHA256SUMS.txt"
      exported_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      prov <- data.frame(
        artifact = "plant_occurrence_bundle",
        site = site, builtAt = built_at, neonRelease = neon_rel,
        neonReleaseDoi = plant_release_doi(neon_rel),
        repositoryImportedAt = repository_imported_at,
        sourceStart = source_start, sourceCutoff = source_cutoff,
        sourceReceiptId = source_receipt_id, sourceDigest = source_digest,
        sourceReceiptBasis = receipt_basis,
        sourceProvenanceClass = provenance_class,
        sourceBundleCommit = source_bundle_commit,
        queryPackage = query_package,
        neonUtilitiesVersion = neon_utilities_version,
        dpid = "DP1.10058.001", exportedAt = exported_at,
        bundleFile = file.path("data", "sites", basename(bundle_file)),
        bundleMd5 = if (file.exists(bundle_file)) unname(tools::md5sum(bundle_file)) else NA_character_,
        snapshotContract = "plant-snapshot-v2: grain figures from the latest full-grain site event (year, bout); cover figures from the latest complete 1 m² site bout; annual tables use one deterministic bout per plot-year",
        estimatorContract = "plant-diversity-v3",
        sourceLicense = "NEON DP1.10058.001 CC BY 4.0",
        stringsAsFactors = FALSE)
      if (!is.null(env) && nrow(env)) prov <- rbind(prov, data.frame(
        artifact = "environment_context_overlay",
        site = site, builtAt = NA_character_, neonRelease = NA_character_,
        neonReleaseDoi = NA_character_,
        repositoryImportedAt = NA_character_, sourceStart = NA_character_,
        sourceCutoff = NA_character_, sourceReceiptId = NA_character_,
        sourceDigest = NA_character_,
        sourceReceiptBasis = "partial upstream query receipt; see ENVIRONMENT-CONTEXT-RECEIPT.md",
        sourceProvenanceClass = "partial-context-overlay",
        sourceBundleCommit = NA_character_,
        queryPackage = NA_character_, neonUtilitiesVersion = NA_character_,
        dpid = "multiple co-located context products; see environment_context.csv source",
        exportedAt = exported_at,
        bundleFile = file.path("data", "env", basename(env_file)),
        bundleMd5 = if (file.exists(env_file)) unname(tools::md5sum(env_file)) else NA_character_,
        snapshotContract = "monthly context; annual summaries require 12 complete monthly values",
        estimatorContract = "environment-context-v1; partial upstream query receipt; context only",
        sourceLicense = "NEON CC BY 4.0; exact upstream product/query receipt not preserved here",
        stringsAsFactors = FALSE))
      readme <- c(
        sprintf("NEON Plant Diversity Explorer · data export for site %s", site),
        sprintf("Generated %s by an unofficial Desert Data Labs explorer.", format(Sys.Date(), "%Y-%m-%d")),
        "Source: NEON Plant presence & percent cover DP1.10058.001 (div_1m2Data + div_10m2Data100m2Data).",
        "License: NEON DP1.10058.001, CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/); aggregated and derived by this app.",
        paste("Citation:", plant_release_citation(neon_rel)),
        if (identical(provenance_class, "legacy-partial"))
          sprintf("Source receipt: exact legacy 46-site family registered from a repository import on %s at commit %s | original build date, NEON release, fetch cutoff, and query receipt were not preserved.",
                  ifelse(is.na(repository_imported_at), "date unavailable", repository_imported_at),
                  ifelse(is.na(source_bundle_commit), "unavailable", source_bundle_commit))
        else sprintf("Source receipt: query %s through %s | receipt %s | bundle built %s%s",
                     ifelse(is.na(source_start), "start unavailable", source_start),
                     ifelse(is.na(source_cutoff), "cutoff unavailable", source_cutoff),
                     ifelse(is.na(source_receipt_id), "unavailable", source_receipt_id),
                     ifelse(is.na(built_at), "date unavailable", built_at),
                     if (!is.na(neon_rel) && nzchar(neon_rel))
                       sprintf(" | official NEON release %s", neon_rel) else ""),
        "", "FILES",
        " occurrences_all.csv   - every bundled taxon record, including coarse IDs; is_species marks analysis eligibility.",
        sprintf(" analysis_snapshot.csv - the grain event behind richness, species-area and cross-scale figures (all scales): %s.", ev_label("grain")),
        sprintf(" cover_snapshot.csv    - the cover event behind cover, Hill, Chao2 and watchlist figures (1 m^2 rows): %s.", ev_label("cover")),
        " plots_snapshot.csv    - one row per plot in the grain event: richness from the grain event, cover from the cover event (NA = no 1 m^2 record in that bout).",
        " ground_cover_all.csv  - bundled abiotic ground-cover records; historical unless snapshot keys are present.",
        " environment_context.csv - bundled co-located climate/phenology context, when available.",
        " expected_vs_observed.csv - NRCS reference flora vs observed (only if a reference list is bundled).",
        " reference_provenance.csv - single-point NRCS reference scope and identifiers, when available.",
        " qc_flags.csv          - every data-quality flag row (nativity review, cover sum, repeated records); verify, not wrong.",
        " provenance.csv        - source receipt, release DOI, bundle checksum, estimator contract, product and license.",
        if (file.exists(raw_source_inventory))
          " plant_raw_source_SHA256SUMS.txt - durable per-file raw-source checksum inventory bound by sourceDigest."
        else NULL,
        " data_dictionary.csv   - column definitions, types, units, NA semantics, and estimands for every shipped frame.",
        "", "NOTES",
        " * Current-state richness uses the site's latest full-grain (1/10/100 m^2) survey event; cover uses its latest complete 1 m^2 bout. Both are named above; occurrences_all.csv retains all records.",
        " * Annual estimates select one deterministic bout per plot-year and report sampling support.",
        " * percentCover is plant ocular cover at 1 m^2 (NA at presence-only 10/100 m^2 scales); groundCoverPct is abiotic ground cover;",
        "   layers overlap, so site-summed cover is a relative index, not a share of ground.",
        " * nativity is NEON's nativeStatusCode collapsed to native/introduced/unknown; contradictory statuses route to review.",
        if (identical(provenance_class, "legacy-partial"))
          " * source vintage is not inferred from filesystem timestamps. This legacy family is exact-byte verified, but its original build date, NEON release, and fetch cutoff are unknown."
        else " * source vintage comes from the matching query-snapshot receipt across all 46 bundles; filesystem and deployment timestamps are not source evidence.",
        " * the NRCS comparison is one reference point/soil unit near the site centre, not a complete site-wide flora.",
        " * environment context is a separately versioned suite overlay. Its per-row source is retained, but the original product/query receipt is partial;",
        "   it is descriptive only and excluded from Driver/Cascade promotion.")
      utils::write.csv(occ_all, file.path(tmp, "occurrences_all.csv"), row.names = FALSE, na = "")
      utils::write.csv(analysis_snapshot, file.path(tmp, "analysis_snapshot.csv"), row.names = FALSE, na = "")
      utils::write.csv(cover_snapshot, file.path(tmp, "cover_snapshot.csv"), row.names = FALSE, na = "")
      if (!is.null(pl)) utils::write.csv(pl, file.path(tmp, "plots_snapshot.csv"), row.names = FALSE, na = "")
      if (!is.null(gr) && nrow(gr)) utils::write.csv(gr, file.path(tmp, "ground_cover_all.csv"), row.names = FALSE, na = "")
      if (!is.null(env) && nrow(env)) utils::write.csv(env, file.path(tmp, "environment_context.csv"), row.names = FALSE, na = "")
      utils::write.csv(prov, file.path(tmp, "provenance.csv"), row.names = FALSE, na = "")
      qc_all <- qc_flags_table(occ, PLANT_AUTHORITY, site = site)
      utils::write.csv(qc_all, file.path(tmp, "qc_flags.csv"), row.names = FALSE, na = "")
      e <- load_expected(site)
      ev_tbl <- NULL
      ref_prov <- NULL
      if (!is.null(e)) { ev <- tryCatch(expected_vs_observed(occ, e, PLANT_AUTHORITY), error = function(err) NULL)
        if (!is.null(ev)) { ev_tbl <- qc_report_table(ev, site)
          utils::write.csv(ev_tbl, file.path(tmp, "expected_vs_observed.csv"), row.names = FALSE, na = "") }
        site_row <- neon_sites[neon_sites$site == site, , drop = FALSE]
        ref_prov <- data.frame(
          site = site,
          referenceScope = expected_reference_scope(e),
          referenceLatitude = if (nrow(site_row)) site_row$lat[1] else NA_real_,
          referenceLongitude = if (nrow(site_row)) site_row$lng[1] else NA_real_,
          source = e$source %||% "NRCS Soil Data Access / Ecological Site Descriptions",
          ecoclassid = e$ecoclassid %||% NA_character_,
          ecositeName = e$ecosite_name %||% NA_character_,
          mlra = e$mlra %||% NA_character_,
          queryDate = e$query_date %||% NA_character_,
          sourceLicense = "U.S. federal public-domain source; app-derived comparison",
          stringsAsFactors = FALSE)
        utils::write.csv(ref_prov, file.path(tmp, "reference_provenance.csv"), row.names = FALSE, na = "")
      }
      # codebook DERIVED from exactly the frames shipped, so it can never drift
      frames <- list("occurrences_all.csv" = occ_all, "analysis_snapshot.csv" = analysis_snapshot,
                     "cover_snapshot.csv" = cover_snapshot)
      if (!is.null(pl)) frames[["plots_snapshot.csv"]] <- pl
      if (!is.null(gr) && nrow(gr)) frames[["ground_cover_all.csv"]] <- gr
      if (!is.null(env) && nrow(env)) frames[["environment_context.csv"]] <- env
      frames[["provenance.csv"]] <- prov
      frames[["qc_flags.csv"]] <- qc_all
      if (!is.null(ev_tbl)) frames[["expected_vs_observed.csv"]] <- ev_tbl
      if (!is.null(ref_prov)) frames[["reference_provenance.csv"]] <- ref_prov
      utils::write.csv(plant_codebook(frames), file.path(tmp, "data_dictionary.csv"), row.names = FALSE, na = "")
      if (file.exists(raw_source_inventory) &&
          !file.copy(raw_source_inventory,
                     file.path(tmp, "plant_raw_source_SHA256SUMS.txt"),
                     overwrite = TRUE, copy.mode = FALSE, copy.date = FALSE))
        stop("Could not include the durable raw-source inventory in the export")
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
    # both sites through the same two-event contract: species rows from F,
    # cover and Chao2 from Q; each column names its own events.
    ss2 <- site_snapshot(b2$occ, ground = b2$ground)
    metrics <- function(grain, cover, events) {
      g_ok <- has_rows(grain); q_ok <- has_rows(cover)
      sp <- if (g_ok) resolve_nativity_records(species_level_only(grain)) else NULL
      ch <- if (q_ok) chao2(cover) else NULL
      ps <- if (g_ok) plot_summary(grain) else NULL
      list(rich = if (g_ok) dplyr::n_distinct(sp$scientificName) else "n/a",
           mean_plot_rich = if (!is.null(ps) && nrow(ps)) mean(ps$richness, na.rm = TRUE) else NA_real_,
           intro = if (q_ok) site_invasion(cover) else NA_real_,
           plots = if (g_ok) dplyr::n_distinct(grain$plotID) else "n/a",
           fam = if (g_ok) mode_chr(sp$family) else NULL,
           intro_n = if (g_ok) dplyr::n_distinct(sp$scientificName[sp$nativity == "Introduced"]) else "n/a",
           chao = if (!is.null(ch)) sprintf("%.0f%s", ch$chao2, if (ch$unstable) "*" else "") else NULL,
           chao_sobs = if (!is.null(ch)) ch$S_obs else NA_integer_,
           f_lab = ev_label("grain", events), q_lab = ev_label("cover", events)) }
    a <- metrics(rv$snap, rv$cover, rv$events); b <- metrics(ss2$grain, ss2$cover, ss2$events)
    chao_cell <- function(m) if (is.null(m$chao)) "n/a" else sprintf("%s (from %d seen at 1 m²)", m$chao, m$chao_sobs)
    pc <- function(v) if (!is.null(v) && is.finite(v)) paste0(v, "%") else "n/a"
    row <- function(l, va, vb) tags$tr(tags$td(class = "cmp-l", l), tags$td(va), tags$td(vb))
    # Raw site richness remains visible but explicitly non-standardized. Mean
    # 400 m² plot richness gives a common grain; Chao2 remains a site-specific
    # lower-bound estimator, not an effort-correction or coverage standardizer.
    tags$table(class = "compare-tbl",
      tags$thead(tags$tr(tags$th(""), tags$th(rv$site), tags$th(s2))),
      tags$tbody(
        tags$tr(
          tags$td(class = "cmp-l", "Species (full-grain survey)",
            info_pop("Comparing richness fairly",
              p("This row is ", tags$b("raw observed richness"), " (S_obs) at each site's own sampling effort; plots, survey years and bouts differ between sites, and more effort finds more species."),
              p("Mean richness per 400 m² plot below uses a common spatial grain and is the safer descriptive comparison. Chao2 is a lower-bound estimate of total richness within each site's incidence sample; it is estimated from species seen in the 1 m² quadrats only, so compare it with the 1 m² count shown beside it, not with the plot-wide species row; the gap between those two is the estimated unseen component. It does not standardize sites to equal coverage or effort."))),
          tags$td(a$rich), tags$td(b$rich)),
        row("Mean species / 400 m² plot", if (is.finite(a$mean_plot_rich)) sprintf("%.1f", a$mean_plot_rich) else "n/a",
                                           if (is.finite(b$mean_plot_rich)) sprintf("%.1f", b$mean_plot_rich) else "n/a"),
        row("Chao2 lower bound, 1 m² quadrat species", chao_cell(a), chao_cell(b)),
        row("Introduced species", a$intro_n, b$intro_n),
        row("Introduced cover", pc(a$intro), pc(b$intro)),
        row("Plots sampled (full-grain survey)", a$plots, b$plots),
        row("Top family", a$fam %||% "n/a", b$fam %||% "n/a"),
        row("Survey events", tagList(div("Richness: ", a$f_lab), div("Cover: ", a$q_lab)),
                             tagList(div("Richness: ", b$f_lab), div("Cover: ", b$q_lab)))))
  })

  # ---- MAP ----------------------------------------------------------------
  output$map <- leaflet::renderLeaflet({
    req(rv$occ)
    lb <- rv$lb; validate(need(has_rows(lb), paste0("No plot map: ", NO_GRAIN_TXT, ".")))
    gy <- ev_year("grain"); qy <- ev_year("cover")
    # drop coord-less / non-finite plots so the map can't render blank or fit to NA
    lb <- lb[is.finite(lb$lat) & is.finite(lb$lng), , drop = FALSE]
    validate(need(nrow(lb) > 0, "No plots have mappable coordinates for this site."))
    metric <- input$mapMetric %||% "pct_introduced"
    # a plot without a 1 m² record in the cover bout stays NA (grey), never 0
    val <- if (metric == "pct_introduced") lb$pct_introduced else lb$richness
    if (metric == "pct_introduced") {
      # % introduced is a BOUNDED one-ended magnitude (0-100), not heavy-tailed
      # and not diverging -> a linear SEQUENTIAL single-hue sand->clay ramp is
      # honest (no false midpoint, no native-green reuse). Bounded metrics stay
      # linear per the suite colour-scale standard.
      fv <- val[is.finite(val)]; if (!length(fv)) fv <- 0
      dom <- if (diff(range(fv)) > 0) range(fv) else c(fv[1] - 1, fv[1] + 1)
      pal <- leaflet::colorNumeric(c("#F3E9D8","#D9A066","#B85C38"), domain = dom, na.color = "#bdbdbd")
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
    leaflet::leaflet(lb) %>% add_suite_basemap(bm) %>%
      leaflet::addCircleMarkers(lng = ~lng, lat = ~lat,
        radius = ~radius, fillColor = pal(val), color = "#fff", weight = 1, fillOpacity = 0.85,
        label = ~lapply(sprintf("<b>%s</b><br>%d species / 400 m² (%s)<br>%s", short_plot(plotID), richness, gy,
          ifelse(is.na(pct_introduced), sprintf("no 1 m² record in the %s bout", qy),
                 sprintf("%s%% introduced 1 m² cover (%s)", pct_introduced, qy))), htmltools::HTML),
        layerId = ~plotID) %>%
      leaflet::fitBounds(min(lb$lng), min(lb$lat), max(lb$lng), max(lb$lat)) %>%
      leaflet::addLegend("bottomright", pal = pal, values = val,
        title = if (metric == "pct_introduced") sprintf("%% introduced (%s)", qy) else sprintf("species / 400 m² (%s)", gy))
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
  # advisory + data-quality cross-checks below stay visible, they need only occ.
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
      HTML("No NRCS ecological-site reference list is bundled for this site in this release. Reference comparisons are available for 34 of 46 sites; every non-reference analysis still works here.")))
    src <- e$source %||% "esd"
    badge <- if (identical(src, "esd")) glow_badge("ecological site", DDL$navy) else glow_badge("MLRA union", DDL$gold)
    # only link to EDIT for a standard rangeland/forest ecoclassid that will resolve
    # (e.g. NIWO's alpine "G…" group code 404s), otherwise show the id as plain text
    link_ok <- identical(src, "esd") && grepl("^[RF][0-9]{3}[A-Z]", e$ecoclassid %||% "") && nzchar(e$mlra %||% "")
    cite <- if (link_ok) tags$a(class = "evo-cite", target = "_blank", rel = "noopener",
        href = sprintf("https://edit.sc.egov.usda.gov/catalogs/esd/%s/%s", e$mlra, e$ecoclassid),
        bs_icon("box-arrow-up-right"), " view on EDIT (USDA Ecological Site)") else NULL
    div(class = "evo-header",
      bs_icon("geo-fill"),
      HTML(sprintf(" Reference community: <b>%s</b> &nbsp;<code>%s</code> &nbsp;·&nbsp; MLRA&nbsp;%s &nbsp;",
        htmltools::htmlEscape(e$ecosite_name %||% "n/a"), e$ecoclassid, e$mlra)),
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
    dom_box <- if (isFALSE(ev$applicability$applies))
      box("n/a", "reference dominants", "navy", ev$applicability$status %||% "no native reference applies")
    else if (identical(ev$dom_basis, "none") || ev$dom_total == 0)
      box("n/a", "reference dominants", "navy", "not production-ranked for this ecological site")
    else
      box(sprintf("%d / %d", ev$dom_obs, ev$dom_total), "reference dominants observed", "navy",
          "the core species, top 50% of reference production")
    rev_sub <- sprintf("%d introduced · %d native%s", ev$n_review_intro, ev$n_review_native,
      if (ev$n_review_unknown > 0) sprintf(" · %d unknown", ev$n_review_unknown) else "")
    applies <- !isFALSE(ev$applicability$applies)
    app_status <- ev$applicability$status %||% "cropland: no native reference applies"
    absent_note <- if (applies)
      " NEON samples ~400&nbsp;m² per plot, so <b>expected-but-absent reflects completeness, not error.</b>"
    else " This is a cultivated-crop site, so no native reference list applies and no detected-share is reported; the tables below are listed for context only."
    div(
      div(class = "evo-boxrow",
        if (applies && is.finite(ev$overlap_pct))
          box(sprintf("%.0f%%", ev$overlap_pct), "of reference species detected", "green",
              sprintf("%d of %d%s", ev$n_overlap, ev$n_ref, floor_note))
        else box("n/a", "of reference species detected", "green",
                 if (applies) "no detected-share available" else app_status),
        dom_box,
        box(as.character(nrow(ev$C)), "observed, not in reference", "clay", rev_sub),
        box(if (is.finite(resolved)) sprintf("%.0f%%", resolved) else "n/a",
            "identified to species", "amber", "the rest are genus / family only")),
      div(class = "evo-matchnote", bs_icon("info-circle"),
        HTML(sprintf(" Observed species: presence from the full-grain survey (%s), cover from the 1 m² bout (%s), species level only. Reference community: <b>%d</b> species (%d entries incl. genus/aggregate codes). NEON's plant codes <i>are</i> USDA PLANTS symbols, so species join USDA directly (synonyms collapsed to the accepted name).%s%s",
          htmltools::htmlEscape(ev_label("grain")), htmltools::htmlEscape(ev_label("cover")),
          mr$ref_n_species, mr$ref_n_all,
          if (!identical(ev$dom_basis, "none")) " Dominants = the core species making up the top 50% of reference production." else "",
          absent_note))))
  })

  # Flag 1: coarse-rank advisory, surfaced FIRST (frames every other comparison)
  output$evoCoarse <- renderUI({
    cr <- coarse_flag(); if (is.null(cr) || !is.finite(cr$pct_records) || cr$pct_records < 1) return(NULL)
    insight_banner("info-circle", tone = "navy",
      HTML(sprintf("<b>%.0f%%</b> of records here are identified coarser than species: genus, family, or just “plant”%s. These can't be matched to a species-level reference list, so read the comparisons below as a floor, not a census.",
        cr$pct_records,
        if (is.finite(cr$pct_cover)) sprintf(", carrying <b>%.0f%%</b> of measured cover", cr$pct_cover) else "")))
  })

  # Bucket A: reference flora detected (green)
  output$evoTableA <- DT::renderDT({
    ev <- evo(); if (is.null(ev)) return(evo_empty_dt("No reference comparison is available for this site."))
    A <- ev$A; if (!nrow(A)) return(evo_empty_dt("None of the reference species were detected in the sampled plots."))
    df <- data.frame(Symbol = A$plantsym, Species = A$sciname, `Common name` = A$comname,
      Role = ifelse(A$is_dominant %in% TRUE, "dominant", "associated"),
      `Ref. production (lb/ac)` = ifelse(is.finite(A$rangeprod), A$rangeprod, NA),
      `Observed cover %` = ifelse(is.finite(A$obs_cover), signif(A$obs_cover, 2), NA),
      `# plots` = A$obs_plots, check.names = FALSE)
    DT::datatable(df, rownames = FALSE, options = list(pageLength = 10, dom = "tp", scrollX = TRUE,
      order = list(list(4, "desc")), columnDefs = list(list(className = "dt-center", targets = 3:6)))) %>%
      DT::formatStyle("Role", target = "row", fontWeight = DT::styleEqual("dominant", "700"))
  })

  # Bucket C: observed, not in reference (clay; the review lane)
  output$evoTableC <- DT::renderDT({
    ev <- evo(); if (is.null(ev)) return(evo_empty_dt("No reference comparison is available for this site."))
    C <- ev$C
    if (!nrow(C)) return(evo_empty_dt("Every observed species is on the reference list; nothing to review."))
    df <- data.frame(Symbol = C$sym, Species = C$scientificName, Family = C$family,
      Nativity = C$nativity, `Mean cover %` = ifelse(is.finite(C$mean_cover), signif(C$mean_cover, 2), NA),
      `# plots` = C$n_plots, check.names = FALSE)
    DT::datatable(df, rownames = FALSE, options = list(pageLength = 10, dom = "tp", scrollX = TRUE,
      order = list(list(5, "desc")), columnDefs = list(list(className = "dt-center", targets = 4:5)))) %>%
      DT::formatStyle("Nativity", fontWeight = "bold",
        color = DT::styleEqual(c("Introduced", "Native", "Unknown"),
                               c(DDL$introduced, DDL$green, DDL$muted)))
  })

  # Bucket B: expected but not detected (neutral completeness; dominants highlighted)
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

  # Data-quality cross-checks (verify, not wrong). Each flag header is a real
  # button; a delegated handler in www/app.js sends input$qcFlagOpen = <flag id>,
  # which opens every row of that flag with a per-flag download (PD-23).
  QC_FLAG_TITLES <- c(nativity_mismatch = "Nativity: NEON label disagrees with USDA PLANTS",
                      cover_sum_gt_250 = "Cover sum above 250% in one 1 m² quadrat visit",
                      duplicate_record = "Repeated records in one subplot visit")
  qc_tbl <- reactive({
    occ <- rv$occ; req(occ)
    tryCatch(qc_flags_table(occ, PLANT_AUTHORITY, site = rv$site %||% NA_character_),
             error = function(e) { warning("qc_flags_table failed: ", conditionMessage(e)); NULL })
  })
  qc_more <- function(n) if (n > 12) div(class = "evo-flag-more",
    sprintf("+ %d more in qc_flags.csv (completeness report ZIP)", n - 12))
  output$evoFlags <- renderUI({
    occ <- rv$occ; req(occ)
    nm <- tryCatch(flag_nativity_mismatch(occ, PLANT_AUTHORITY), error = function(e) NULL)
    cs <- tryCatch(flag_cover_sum(occ), error = function(e) list(rows = data.frame(), n = 0L, ceiling = 250))
    dup <- tryCatch(flag_duplicate_records(occ), error = function(e) NULL)
    nm_ui <- if (is.null(nm)) {
      div(class = "evo-flag evo-flag-muted qc-flag-info", bs_icon("hourglass-split"),
        HTML(" <b>Nativity cross-check (NEON vs USDA):</b> needs the USDA PLANTS authority file, being added in a follow-up build. NEON's own native/introduced labels are used everywhere else on the page."))
    } else if (identical(nm$eligible, FALSE)) {
      div(class = "evo-flag evo-flag-muted qc-flag-info", bs_icon("info-circle"),
        HTML(sprintf(" <b>Nativity cross-check (NEON vs USDA):</b> not applied for %s because %s. No match claim is made.",
                     htmltools::htmlEscape(nm$state %||% "this geography"),
                     htmltools::htmlEscape(nm$reason %||% "the authority is outside its registered scope"))))
    } else if (nm$n == 0) {
      div(class = "evo-flag evo-flag-clean qc-flag-clean", bs_icon("check2-circle"),
        HTML(" <b>Nativity cross-check (NEON vs USDA):</b> no disagreements; every species' native/introduced label matches USDA PLANTS."))
    } else {
      rows <- utils::head(nm$rows, 12)
      div(class = "evo-flag evo-flag-warn qc-flag-warn",
        qc_flag_button("nativity_mismatch", bs_icon("exclamation-triangle-fill"),
          sprintf(" %d species: NEON's nativity label disagrees with USDA PLANTS", nm$n),
          tags$span(class = "qc-flag-open", " · open all rows")),
        tags$table(class = "evo-flag-tbl",
          tags$thead(tags$tr(tags$th("Species"), tags$th("NEON"), tags$th("USDA"), tags$th("# plots"))),
          tags$tbody(lapply(seq_len(nrow(rows)), function(i) tags$tr(
            tags$td(tags$i(rows$scientificName[i])), tags$td(rows$nativity[i]),
            tags$td(rows$usda_nativity[i]), tags$td(rows$n_plots[i]))))),
        qc_more(nm$n),
        div(class = "evo-flag-note", "Nativity is regional; USDA's lower-48 label and NEON's site label can legitimately differ at a range edge. Worth a look, not necessarily an error."))
    }
    cs_ui <- if (cs$n == 0) {
      div(class = "evo-flag evo-flag-clean qc-flag-clean", bs_icon("check2-circle"),
        HTML(sprintf(" <b>Cover sanity:</b> no 1 m² quadrat sums above %d%%, within what overlapping canopy layers explain.", cs$ceiling)))
    } else {
      div(class = "evo-flag evo-flag-warn qc-flag-warn",
        qc_flag_button("cover_sum_gt_250", bs_icon("exclamation-triangle-fill"),
          sprintf(" %d quadrat-visits sum above %d%% cover (possible entry error)", cs$n, cs$ceiling),
          tags$span(class = "qc-flag-open", " · open all rows")),
        tags$table(class = "evo-flag-tbl",
          tags$thead(tags$tr(tags$th("Plot"), tags$th("Subplot"), tags$th("Year"), tags$th("Total cover %"))),
          tags$tbody(lapply(seq_len(min(nrow(cs$rows), 12)), function(i) tags$tr(
            tags$td(short_plot(cs$rows$plotID[i])), tags$td(cs$rows$subplotID[i]),
            tags$td(cs$rows$year[i]), tags$td(sprintf("%.0f", cs$rows$total_cover[i])))))),
        qc_more(cs$n))
    }
    dup_ui <- if (is.null(dup)) {
      div(class = "evo-flag evo-flag-muted qc-flag-info", bs_icon("info-circle"),
        HTML(" <b>Repeated records:</b> check unavailable for this bundle."))
    } else if (dup$n == 0) {
      div(class = "evo-flag evo-flag-clean qc-flag-clean", bs_icon("check2-circle"),
        HTML(" <b>Repeated records:</b> no species is recorded twice in one subplot visit."))
    } else {
      rows <- utils::head(dup$rows, 12)
      div(class = "evo-flag evo-flag-warn qc-flag-info",
        qc_flag_button("duplicate_record", bs_icon("info-circle-fill"),
          sprintf(" %d subplot visits record the same species more than once", dup$n),
          tags$span(class = "qc-flag-open", " · open all rows")),
        tags$table(class = "evo-flag-tbl",
          tags$thead(tags$tr(tags$th("Plot"), tags$th("Subplot"), tags$th("Year"), tags$th("Species"), tags$th("Records"))),
          tags$tbody(lapply(seq_len(nrow(rows)), function(i) tags$tr(
            tags$td(short_plot(rows$plotID[i])), tags$td(rows$subplotID[i]), tags$td(rows$year[i]),
            tags$td(tags$i(rows$scientificName[i])), tags$td(rows$n_records[i]))))),
        qc_more(dup$n),
        div(class = "evo-flag-note", "Cover from repeated records is summed. Different cover values for one species in one subplot visit are worth a look, not necessarily an error."))
    }
    tagList(nm_ui, cs_ui, dup_ui)
  })

  rv_qcflag <- reactiveVal(NULL)
  qc_flag_rows <- function(id) {
    q <- qc_tbl(); if (is.null(q) || !nrow(q)) return(NULL)
    d <- as.data.frame(q[as.character(q$flag) == id, , drop = FALSE])
    if (!nrow(d)) return(d)
    keep <- vapply(d, function(x) !all(is.na(x)), logical(1))
    keep[c("site", "flag", "level")] <- TRUE
    d[, keep[names(d)], drop = FALSE]
  }
  observeEvent(input$qcFlagOpen, {
    id <- as.character(input$qcFlagOpen %||% "")
    if (!nzchar(id) || !id %in% names(QC_FLAG_TITLES)) return()
    rv_qcflag(id)
    d <- qc_flag_rows(id)
    body <- if (is.null(d) || !nrow(d)) p("No rows for this flag at this site.")
      else div(style = "width:100%", DT::datatable(d, rownames = FALSE, class = "compact stripe",
             options = list(pageLength = 12, dom = "tip", scrollX = TRUE)))
    showModal(modalDialog(
      title = tagList(bs_icon("clipboard-pulse"), " ", QC_FLAG_TITLES[[id]]),
      size = "l", easyClose = TRUE,
      footer = tagList(downloadButton("qcFlagCsv", "Download (CSV + codebook ZIP)", class = "smt-snap-btn"),
                       modalButton("Close")),
      p(class = "qc-modal-intro", sprintf("%s · %d row%s. A reason to verify these records, not a finding that they are wrong.",
        rv$site %||% "site", if (is.null(d)) 0L else nrow(d), if (!is.null(d) && nrow(d) == 1) "" else "s")),
      body))
  }, ignoreInit = TRUE)
  # ZIP of named frames plus a data_dictionary.csv derived from exactly those frames
  zip_with_codebook <- function(file, frames) {
    tmp <- tempfile("pdezip"); dir.create(tmp)
    for (nm in names(frames)) utils::write.csv(frames[[nm]], file.path(tmp, nm), row.names = FALSE, na = "")
    cb <- plant_codebook(frames)
    utils::write.csv(cb %||% data.frame(), file.path(tmp, "data_dictionary.csv"), row.names = FALSE, na = "")
    fs <- list.files(tmp, full.names = TRUE)
    owd <- setwd(tmp); on.exit(setwd(owd), add = TRUE)
    utils::zip(zipfile = file, files = basename(fs), flags = "-q")
  }
  output$qcFlagCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_qc-%s_%s.zip", rv$site %||% "site",
                                  gsub("_", "-", rv_qcflag() %||% "flag"), format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      id <- rv_qcflag() %||% ""
      q <- qc_flags_table(rv$occ, PLANT_AUTHORITY, site = rv$site %||% NA_character_)
      d <- q[as.character(q$flag) == id, , drop = FALSE]
      zip_with_codebook(file, stats::setNames(list(d), sprintf("qc_%s.csv", id)))
    }, contentType = "application/zip")

  # downloads: per bucket + the combined report.
  # Each standalone QC bucket ships as a ZIP that bundles its CSV WITH a
  # data_dictionary.csv built from plant_codebook() over the EXACT frame
  # emitted, so the columns can never drift from their documentation.
  .evo_empty_frames <- list(
    "expected-observed" = data.frame(
      symbol = character(), scientificName = character(), commonName = character(),
      reference_role = character(), reference_production = numeric(),
      observed_cover_pct = numeric(), n_plots = integer(), stringsAsFactors = FALSE),
    "expected-absent" = data.frame(
      symbol = character(), scientificName = character(), commonName = character(),
      reference_role = character(), reference_production = numeric(), stringsAsFactors = FALSE),
    "observed-not-expected" = data.frame(
      symbol = character(), scientificName = character(), family = character(),
      nativity = character(), classification = character(), mean_cover_pct = numeric(),
      n_plots = integer(), stringsAsFactors = FALSE)
  )
  .evo_dl <- function(getdf, tag) downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_%s_%s.zip", rv$site %||% "site", tag, format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      ev <- evo(); df <- if (is.null(ev)) .evo_empty_frames[[tag]] else getdf(ev)
      if (is.null(df) || !ncol(df)) df <- .evo_empty_frames[[tag]]
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
      reference_production = A$rangeprod, observed_cover_pct = signif(A$obs_cover, 3), n_plots = A$obs_plots) }, "expected-observed")
  output$evoCsvB <- .evo_dl(function(ev) {
    B <- ev$B; if (is.null(B) || !nrow(B)) return(data.frame())
    data.frame(symbol = B$plantsym, scientificName = B$sciname, commonName = B$comname,
      reference_role = ifelse(B$is_dominant %in% TRUE, "dominant", "associated"),
      reference_production = B$rangeprod) }, "expected-absent")
  output$evoCsvC <- .evo_dl(function(ev) {
    # Ship the full observed-not-reference set. Every row remains review until
    # exact per-match geographic source/query/license provenance is registered.
    C <- ev$C_all %||% ev$C; if (is.null(C) || !nrow(C)) return(data.frame())
    data.frame(symbol = C$sym, scientificName = C$scientificName, family = C$family,
      nativity = C$nativity, classification = "review",
      mean_cover_pct = signif(C$mean_cover, 3), n_plots = C$n_plots) }, "observed-not-expected")
  output$evoReport <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_%s_completeness-report_%s.zip", rv$site %||% "site", format(Sys.Date(), "%Y%m%d")),
    content = function(file) {
      ev <- evo(); tbl <- qc_report_table(ev, site = rv$site %||% NA_character_)
      if (!is.null(ev) && isFALSE(ev$applicability$applies))
        tbl <- data.frame(note = sprintf("%s is a cultivated-crop site (cropland): no native reference list applies, so no completeness percent is reported. The observed-not-in-reference table is available as its own download.",
                                         rv$site %||% "This site"))
      if (is.null(tbl) || !nrow(tbl))
        tbl <- data.frame(note = sprintf("No NRCS ecological-site reference list is bundled for %s; completeness comparison unavailable.",
                                          rv$site %||% "this site"))
      qc_all <- qc_flags_table(rv$occ, PLANT_AUTHORITY, site = rv$site %||% NA_character_)
      zip_with_codebook(file, list("completeness-report.csv" = tbl, "qc_flags.csv" = qc_all))
    }, contentType = "application/zip")

  # ---- ABOUT --------------------------------------------------------------
  output$aboutPanel <- renderUI({
    div(class = "about-wrap",
      div(class = "about-card", h4("\U0001F33F What this is"),
        p("An (unofficial) explorer for NEON's ", tags$b("Plant presence & percent cover"), " product (", tags$code("DP1.10058.001"),
          "). NEON surveys plants in nested quadrats: 1 m² subplots (presence + percent cover), 10 m² and 100 m² subplots (presence), combined into a 400 m² plot list, at peak greenness each year.")),
      div(class = "about-card", h4(bs_icon("rulers"), " How richness is measured"),
        p("Species–area curves come straight from the nested design: a 1 m² quadrat, a 10 m² subplot, a 100 m² corner, the whole 400 m² plot. ",
          tags$b("Bias-corrected Chao2"), " is an incidence-based lower-bound estimate of total richness within the sampled incidence units. It is estimated from species seen in the 1 m² quadrats only, so compare it with the 1 m² count shown beside it, not with the plot-wide species count; the gap between those two is the estimated unseen component. It does not standardize sites to equal effort or coverage."),
        p("Richness and the species-area curve describe each site's latest full-grain survey (1, 10 and 100 m² subplots, surveyed every other year since 2019). Cover, Hill numbers, Chao2 and the watchlist describe its latest 1 m² bout. The 10 m² point is the mean over 10 m² subplots including their nested 1 m² quadrat."),
        p(class = "caveat", bs_icon("exclamation-triangle"), " Cover is an ocular estimate and vegetation layers overlap, so site-summed cover is relative, not a share of ground.")),
      div(class = "about-card", h4(bs_icon("shield-exclamation"), " Native vs invasive"),
        p("Status is NEON's ", tags$code("nativeStatusCode"), " (N native / I introduced / others → unknown). We publish the ", tags$b("unknown rate"),
          " so the invasion numbers can be read with that gap in view; contradictory statuses route to Unknown/review. The ", tags$b("cross-scale occurrence"), " view compares detections at 1 m² with the full 400 m² grain. It is not a spread, impact, or management-priority estimate.")),
      div(class = "about-card", h4(bs_icon("clipboard-check"), " Expected vs Observed"),
        p("The current bundle resolves one reference coordinate near each site's centre to one NRCS soil map unit and dominant ecological class, then compares that ",
          tags$b("single-point reference plant community"), " with NEON plot records. It is context, not a site-wide expected-flora census."),
        p("Because NEON samples ~400 m² per plot at peak greenness, a reference species not detected is read as ",
          tags$b("completeness"), " (or a real state-transition), ", tags$b("never as error"), ". Review lanes retain observed-but-unlisted taxa; no undocumented fuzzy state-occurrence match silently dismisses them."),
        p(tags$b("Dominant"), " = the core species making up the top 50% of the ecological site's reference production (NRCS air-dry lb/ac at normal precipitation), an app-defined, list-length-invariant convention, not an official NRCS designation. Forest ecological sites carry no per-species production (their dominants are canopy trees, scored by site index), so dominance isn't ranked there."),
        p(class = "caveat", bs_icon("info-circle"), " Reference flora: USDA-NRCS Soil Data Access / Ecological Site Descriptions (public domain). Nativity authority: ",
          tags$a(href = "https://plants.usda.gov", target = "_blank", rel = "noopener", "USDA PLANTS"), "; lower-48 authority checks are disabled outside their valid geography.")),
      div(class = "about-card", h4(bs_icon("database"), " Data, release and citation"),
        data_through_line(PLANT_DATA_THROUGH, PLANT_SOURCE_STATUS$neon_release, PLANT_RELEASE_DOI),
        p(class = "citation", tags$b("Cite the data: "), PLANT_RELEASE_CITATION),
        p("NEON data are licensed ", tags$a(href = "https://creativecommons.org/licenses/by/4.0/", target = "_blank", rel = "noopener", "CC BY 4.0"),
          ". The bundled records end in ", if (is.na(PLANT_DATA_THROUGH)) "n/a" else PLANT_DATA_THROUGH,
          "; the query that built them ran through ", PLANT_SOURCE_STATUS$source_cutoff %||% "n/a", "."),
        p("Pu'u Maka'ala (PUUM, Hawai'i) publishes this product but is not yet bundled here: its reference flora, nativity authority and environment layers need their own build."),
        if (!is.null(rv$site)) neon_notices_html(rv$notices, heading = sprintf("NEON notices for %s after its records end", rv$site))),
      div(class = "about-card", h4(bs_icon("book"), " Data dictionary"),
        p("Every column the downloads can carry: meaning, type, units, what a blank means, and the estimand."),
        div(style = "width:100%", DT::DTOutput("codebookTbl")),
        downloadButton("codebookCsv", tagList(bs_icon("book"), " Data dictionary (CSV)"), class = "smt-clear-btn")),
      div(class = "about-card", h4(bs_icon("diagram-3"), " Role in the NEON Explorer Suite"),
        p("Plant Diversity contributes ", tags$b("composition and invasion context"), ". It does not cast a productivity vote and its per-site short-record associations do not become Atlas edges. The ",
          tags$a(href = "https://tgilbert14.github.io/NEON-Driver-Cascade/", target = "_blank", rel = "noopener", "NEON Cross-Product Response Atlas"), " is the suite's evidence-grading integrator."),
        p(bs_icon("envelope"), " ", tags$a(href = "mailto:desertdatalabs@gmail.com", "desertdatalabs@gmail.com"),
          " · ", tags$a(href = "https://data.neonscience.org/data-products/DP1.10058.001", target = "_blank", "NEON data product"))),
      div(class = "about-card", h4(bs_icon("award"), " Data attribution & license"),
        p(class = "caveat",
          "Built with data from the National Ecological Observatory Network (NEON), a U.S. National Science Foundation program operated by Battelle. NEON data are provided under a Creative Commons Attribution 4.0 International (CC BY 4.0) license (",
          tags$a(href = "https://creativecommons.org/licenses/by/4.0/", target = "_blank", "creativecommons.org/licenses/by/4.0"),
          "). This app aggregates and derives summary metrics from the raw NEON data products; the underlying measurements are unaltered. It is an independent, unofficial tool and is not endorsed by NEON, Battelle, or the NSF.")),
      div(class = "about-card sib-card", h4(bs_icon("compass"), " Explore the NEON series"),
        p("This is one of a family of small explorers, each built on a different NEON data product."),
        div(class = "sib-grid", lapply(.SIBLINGS, function(s)
          tags$a(class = "sib-link", href = s$url, target = "_blank", rel = "noopener",
            tags$span(class = "sib-name", s$name),
            tags$span(class = "sib-prod", s$prod))))))
  })
  output$codebookTbl <- DT::renderDT(
    DT::datatable(plant_codebook(), rownames = FALSE, class = "compact stripe",
                  options = list(pageLength = 15, scrollX = TRUE, dom = "ftip")))
  output$codebookCsv <- downloadHandler(
    filename = function() sprintf("NEON-PlantDiversity_data_dictionary_%s.csv", format(Sys.Date(), "%Y%m%d")),
    content = function(file) utils::write.csv(plant_codebook(), file, row.names = FALSE, na = ""),
    contentType = "text/csv")

  # ---- scope chips: the loaded site in each site tab head (PD-53) ----------
  for (.sid in c("scopeOverview", "scopeDiversity", "scopeInvasive", "scopeExpected",
                 "scopeEnvironment", "scopeLab", "scopePlot", "scopeMap")) local({
    output[[.sid]] <- renderUI(scope_chip(rv$site))
  })
}
