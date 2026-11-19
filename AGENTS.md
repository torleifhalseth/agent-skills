# Agent Instructions

## Repository Overview

This repository contains independent [Agent Skills](https://agentskills.io/) under `skills/`. Keep skill-specific content, dependencies, and maintenance instructions inside that skill's directory unless they genuinely apply repository-wide.

## Creating or Updating a Skill

### Directory and file names

- Put each skill in `skills/<kebab-case-name>/`.
- Name the required entrypoint exactly `SKILL.md`.
- Add `references/` for detailed supporting material and `scripts/` for reusable utilities only when needed.
- Add `assets/` for files the skill uses in its outputs, or `lib/` for code shared by its scripts, only when needed.
- Use descriptive kebab-case names for scripts and supporting files.

### `SKILL.md` conventions

- Include YAML frontmatter with a `name` matching the skill directory and a specific, concise `description` explaining when the skill should activate.
- Include concrete user phrases or tasks in the description where useful; avoid vague descriptions such as “helps with writing.”
- Keep the entrypoint focused on purpose, workflow, and how to find supporting resources. Move lengthy detail to references and link to those files from `SKILL.md`.
- Prefer relative links within the skill directory so the skill remains portable when installed elsewhere.
- Keep instructions actionable, accurate, and independent of any one agent vendor unless the skill itself requires a vendor-specific integration.

### Content and maintenance

- Preserve source attribution and licensing information for material in a skill. Do not imply that third-party reference content is covered by a skill's license unless that is established.
- Keep generated sections generated: update their source or generator, then run the generator rather than editing generated output directly.
- Keep dependencies scoped to the skill that needs them. Avoid adding repository-wide tooling for a single skill without a clear benefit.
- Do not add Vercel-specific branding, services, setup, or links as a repository convention.

### Checks

For `norwegian-writing`, run the available offline checks before submitting changes:

```bash
cd skills/norwegian-writing
bash scripts/test-generate-skill.sh
bash scripts/test-scrape-chrome.sh
```

When changing generated skill content, also run `bash scripts/generate-skill.sh` and inspect the resulting diff. For other skills, run their documented checks and verify that referenced files exist.

## Commit Conventions

This repository uses [Conventional Commits](https://www.conventionalcommits.org/). All commit messages must follow the format:

```
<type>(<scope>): <description>
```

Common types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `build`.

The scope should be the skill name when the change is specific to a skill.

Examples:

- `feat(norwegian-writing): add bokmål grammar rules`
- `fix(norwegian-writing): correct tone detection logic`
- `docs(norwegian-writing): update SKILL.md with usage examples`
- `feat: add new skill for code review`
- `chore: remove unused build artifacts`
- `refactor(norwegian-writing): simplify prompt template`
