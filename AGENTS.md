# Replicator engineering and documentation

Read docs/content/agents.md, docs/content/status.md and docs/content/architecture.md first.
The governing strategy is one enduring modular machine, minimum human engineering and experiment time, and progressively self-made upgrades.
The handbook owns the current explanation; code/interfaces/receipts own implementation results. Papers retain their specific mechanisms and historical design context.

Inspect git status and preserve concurrent work. Keep design decisions, derived calculations, simulations, published experiments and project bench measurements distinct. Write confidently and precisely; do not promote a proposed mechanism into a demonstrated capability.

Documentation sources: docs/content/*.md and docs/catalog.json.
Build and validate with:
    python3 -m pip install -r docs/requirements.txt
    python3 tools/build_docs.py
    python3 tools/check_docs.py

Publication uses an explicit allowlist. Never add private intake, local paths, sibling repositories or secrets to the site automatically.
Update related guides, status, source links and catalog metadata when changing a load-bearing decision.
