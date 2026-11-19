# Agent Skills

A collection of [Agent Skills](https://agentskills.io/) for AI agents. Each skill is a self-contained directory with a `SKILL.md` and, when useful, supporting references or scripts.

## Available skills

### `frontend-design`

Define the visual direction for a new interface or redesign. Turn the brief into a layout, type scale, palette, and clear visual hierarchy.

See [`skills/frontend-design/SKILL.md`](skills/frontend-design/SKILL.md).

### `frontend-code`

Implement or review web interfaces for accessibility, responsive behavior, interaction states, and performance.

See [`skills/frontend-code/SKILL.md`](skills/frontend-code/SKILL.md).

### `norwegian-writing`

Norwegian writing guidance based on official spelling and grammar rules from Språkrådet.

Use it to write or edit Bokmål and Nynorsk, check grammar and punctuation, improve plain language, or choose sensitive and inclusive wording.

See [`skills/norwegian-writing/README.md`](skills/norwegian-writing/README.md) for its scope, sources, and maintenance details.

## Installation

Install the skill using the method supported by your agent. For agents that load skills from `~/.agents/skills`, for example, copy the desired skill directory:

```bash
mkdir -p ~/.agents/skills
cp -R skills/frontend-design ~/.agents/skills/
```

The skill directory can also be added to a project's agent-specific skills directory. Consult the agent's documentation for its supported location and loading behavior.

## Skill structure

```text
skills/
└── skill-name/
    ├── SKILL.md       # Required instructions and activation description
    ├── references/    # Optional supporting material loaded on demand
    ├── scripts/       # Optional utilities used by the skill
    ├── assets/        # Optional files used in skill outputs
    └── lib/           # Optional shared code for scripts
```

See [`AGENTS.md`](AGENTS.md) for repository conventions when adding or updating skills.

## License and attribution

See each skill's directory for its license and source attributions. Reference content may have separate source terms from the skill instructions.
