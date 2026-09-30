# Hadalis chatbot to-do

**Single entry point for active chatbot work.** Choose one of two categories below after reading `AGENTS.md` and fetching the current `dev` HEAD.

- [Cloud Bot](cloud-bot/README.md): ChatGPT is the only reasoning agent; it investigates, plans, implements authorized source changes, interprets evidence and records optimization research.
- [Local Bot](local-bot/README.md): the existing deterministic worker ONLY runs explicit SHA-pinned jobs; it never plans, prioritizes, changes code independently or declares live acceptance.

Keep research histories, technical design specifications and finished patch journals in `docs/` or `docs/archive/`, **not** as competing active work lists. The application's separate Todo/Obsidian feature and its QML files are not chatbot tasks.

