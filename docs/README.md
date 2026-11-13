# Handbook maintenance

Source content lives in content/*.md; catalog.json is the shared human/agent navigation authority.
The public build includes only catalog-listed handbook pages and papers, theme assets and sources.json.
It never walks sibling repositories or copies research/intake.

Build:
    python3 -m pip install -r docs/requirements.txt
    python3 tools/build_docs.py
    python3 tools/check_docs.py
    python3 -m http.server 8765 --directory _site

Edit a guide for the current explanation; edit its owning paper for mechanism detail. Preserve existing paper anchors.
Use a review date, document role, owner lane and related IDs. The build emits HTML, Markdown, a search index, catalog.json, llms.txt and llms-full.txt.

GitHub Actions validates pull requests and deploys main to GitHub Pages. The Pages build source is GitHub Actions.
