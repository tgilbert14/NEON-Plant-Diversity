#!/usr/bin/env python3
# ===========================================================================
# fetch_gbif_states.py - harvest per-species US state distribution from GBIF
# for the full L48 (USDA PLANTS' own state-checklist API only serves 18 states
# and its full-distribution search times out server-side, so we use GBIF's
# occurrence facets, which cover every state).
#
# Build-only. Reads a TSV of (symbol, sci_name) the authority build emits, and
# writes (symbol, gbif_key, states_pipe_separated). A species with no confident
# GBIF name match is written as NOMATCH (the app degrades gracefully there).
# scripts/build_plant_states.R then cleans the raw state names to USPS codes and
# merges them into data/authority/plants_lookup.rds.
#
#   GBIF.org occurrence facets, CC-BY. We threshold at >=2 records per state so a
#   single stray/cultivated record can't make a state "plausible", but otherwise
#   stay permissive (GBIF-present = plausible) to match the owner's "flag obvious
#   errors only, not range-edge natives" steer.
# ===========================================================================
import json, urllib.request, urllib.parse, concurrent.futures, re, sys, time

IN  = sys.argv[1] if len(sys.argv) > 1 else "C:/temp/gbif/species.tsv"
OUT = sys.argv[2] if len(sys.argv) > 2 else "C:/temp/gbif/states_raw.tsv"
GBIF = "https://api.gbif.org/v1"
MIN_RECORDS = 2
WORKERS = 10

def get(url):
    for _ in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "DesertDataLabs-NEON/1.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except Exception:
            time.sleep(0.6)
    return None

def states_for(name):
    m = get(f"{GBIF}/species/match?name={urllib.parse.quote(name)}")
    if not m or m.get("matchType") not in ("EXACT", "FUZZY"):
        return None
    key = m.get("usageKey")
    if not key:
        return None
    o = get(f"{GBIF}/occurrence/search?taxonKey={key}&country=US&facet=stateProvince&facetLimit=70&limit=0")
    if not o:
        return (key, [])
    fac = [f for f in o.get("facets", []) if f["field"] == "STATE_PROVINCE"]
    counts = fac[0]["counts"] if fac else []
    return (key, [c["name"] for c in counts if c.get("count", 0) >= MIN_RECORDS])

rows = []
with open(IN, encoding="utf-8") as f:
    next(f)
    for line in f:
        p = line.rstrip("\n").split("\t")
        if len(p) < 2:
            continue
        sym, sci = p[0], p[1]
        mm = re.search(r"<i>([^<]+)</i>", sci)
        name = (mm.group(1) if mm else re.sub(r"<[^>]*>", "", sci)).strip()
        rows.append((sym, name))

def work(r):
    sym, name = r
    res = states_for(name)
    if res is None:
        return sym, "", "NOMATCH"
    key, st = res
    return sym, str(key), "|".join(st)

done = 0
with open(OUT, "w", encoding="utf-8") as out, \
     concurrent.futures.ThreadPoolExecutor(max_workers=WORKERS) as ex:
    for sym, key, st in ex.map(work, rows):
        out.write(f"{sym}\t{key}\t{st}\n")
        done += 1
        if done % 250 == 0:
            print(done, "of", len(rows), flush=True)
print("DONE", done)
