suppressWarnings(suppressMessages({ library(dplyr) }))
source("R/plant_helpers.R")
b <- readRDS("data/sites/SRER.rds"); occ <- b$occ
cat("occ rows", nrow(occ), "| years", paste(b$meta$years, collapse = ","), "\n")
# plant-snapshot-v2: richness/incidence on the grain event F, cover on Q.
ss <- site_snapshot(occ); grain <- ss$grain; cover <- ss$cover
cat("\nsite events:\n"); print(ss$events)
ps <- plot_summary(grain, cover)
cat("\nplot_summary rows", nrow(ps), "\n")
print(head(ps[, c("plotID","richness","n_native","n_introduced","total_cover","pct_introduced","dominant")], 4))
cat("\nhill_site:\n"); print(round(hill_site(cover), 1))
cat("\nchao2:\n"); print(chao2(cover))
cat("\nspecies_area_site:\n"); print(species_area_site(grain))
cat("\nnative_trend:\n"); print(native_trend(occ))
cat("\ninvasive_watchlist (top 5):\n"); print(head(invasive_watchlist(cover), 5))
cat("\nunknown_rate:", unknown_rate(grain), "%\n")
ip <- cross_scale_plot_occurrence(grain)
cat("\ncross_scale_plot_occurrence: mean intro_1m", round(mean(ip$intro_1m), 2),
    "mean intro_400", round(mean(ip$intro_400), 2), "\n")
cat("\nspecies_summary top 3:\n"); print(head(species_summary(grain, cover), 3))
cat("\ncover_by_group nativity:\n"); print(cover_by_group(cover, "nativity"))
cat("\nground_summary top 5:\n"); print(head(ground_summary(b$ground), 5))
cat("OK\n")
