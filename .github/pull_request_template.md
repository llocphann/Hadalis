<!-- Development PRs target `dev`. `stable` is the user-facing/default branch and should only receive deliberately promoted, validated work. -->

## Summary

What this changes and why.

## Validation

Describe what you actually ran and what you observed. Use the checks that match the changed subsystem rather than checking boxes by assumption.

- [ ] Relevant static/regression checks pass (for example `make test-local` or a narrower targeted test)
- [ ] Runtime behavior was exercised and logs inspected if runtime code changed
- [ ] Screenshots or a recording are attached if the change is visual
- [ ] Install/package changes were checked with a dry-run or staged install path
- [ ] No retired appearance family or legacy placement assumption was reintroduced

## Architecture / configuration impact

- [ ] Config schema/defaults/consumers stay in sync if configuration changed
- [ ] Module placement remains configurable if perimeter code changed
- [ ] Public IPC/docs/package metadata were updated if their contract changed

## AI usage

AI assistance is fine, but the submitted diff must still be reviewed and validated by the contributor.

- [ ] AI-assisted (tool/model: <!-- optional; e.g. Codex / Cursor / Copilot -->)
- [ ] I reviewed and understand the submitted diff
- [ ] I removed unrelated generated boilerplate or attribution footers

## Notes

Closes #
