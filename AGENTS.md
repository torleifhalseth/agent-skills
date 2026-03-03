# Agent Instructions

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
