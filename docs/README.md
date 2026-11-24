# Handbook maintenance

Source content lives in content/*.md; catalog.json is the shared human/agent navigation authority.
The public build includes only catalog-listed handbook pages and papers, theme assets and sources.json.
It never walks sibling repositories or copies research/intake.

Build:
    python3 -m pip install -r docs/requirements.txt
    python3 tools/build_docs.py
    python3 tools/check_docs.py
    python3 tools/check_canon.py
    python3 tools/check_physics_derivations.py
    python3 -m http.server 8765 --directory _site

Edit a guide for the current explanation; edit its owning paper for mechanism detail. Preserve existing paper anchors.
Use a review date, document role, owner lane and related IDs. The build emits HTML, Markdown, a search index, catalog.json, llms.txt and llms-full.txt.

GitHub Actions validates pull requests and deploys main to GitHub Pages. The Pages build source is GitHub Actions.

The physics check independently constructs the 600-cell spectrum and verifies shell counts and the focusing-model threshold-order interval. CI compares it with the published JSON result. This is a mathematical check, not an atomic-data fit or hardware validation.

## Canon: numbers and retired designs

Guides do not type design numbers. They quote them with a token such as `{{c:desktop_geometry.gap_mm}}`, filled at build time from `docs/canon.json`. That file is a snapshot of the engineering checkout's `coordination/system_constants.json` and insight register, plus the handbook's own plain-language notes for each insight and the rules below. Refresh it with `python3 tools/sync_canon.py` (it reads the sibling engineering checkout, or the path in `$REPLICATOR_CANON`).

`tools/check_canon.py` fails when a token does not resolve, when a current guide contains a phrase listed under `rules.forbidden` (a retired design presented as current, a superseded number, a private name), when a phrase under `rules.required` is missing, or, where the engineering checkout is present, when the snapshot no longer equals the live constants. A forbidden phrase is excused on a line that states the history explicitly (for example "retired" or "earlier"). CI runs the check without the engineering checkout, so it enforces the rules against the committed snapshot.

When the constants change: run `sync_canon.py`, rebuild, and re-read every guide that quotes the changed constant. A changed number usually changes the prose around it.
