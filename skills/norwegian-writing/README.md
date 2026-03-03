# Norwegian Writing Skill

A comprehensive AI agent skill for optimizing Norwegian language writing based on official Norwegian spelling and grammar rules.

## Overview

This skill provides:

- **Grammar and spelling rules** (kommaregler, stor/liten bokstav, etc.)
- **Klarspråk guidance** (plain language principles)
- **Kansellisten** (list of bureaucratic words to avoid)
- **Practical writing tips** for various contexts
- **Sensitive language guidance**

## Structure

```
norwegian-writing/
├── SKILL.md                # Main skill file (loaded by agents)
├── README.md               # This file
├── LICENSE
├── scripts/
│   ├── scrape.sh           # Script to update references from sprakradet.no
│   └── generate-skill.sh   # Helper to review scraped content
└── references/             # Reference material (loaded on demand)
    ├── INDEX.md
    ├── rettskriving-og-grammatikk/   # Spelling & grammar rules
    │   └── tegn/                     # Punctuation marks (sub-section)
    ├── praktisk-sprakbruk/           # Practical language usage
    │   └── nynorskhjelp/             # Nynorsk writing help
    ├── klarsprak-om-skriving/        # Clear writing guidance
    ├── ordlister/                    # Word lists (Kansellisten, etc.)
    └── spraksporsmal/                # 1100+ Q&A articles
```

## Updating References

To fetch the latest guidelines from sprakradet.no:

```bash
cd skills/norwegian-writing
bash scripts/scrape.sh
```

See [BUILDING.md](BUILDING.md) for details on how the scraping pipeline works, how to extend it, and how to troubleshoot issues.

## Topics Covered

### Rettskriving og grammatikk (Spelling & Grammar)
- Kommaregler (comma rules)
- Stor/liten forbokstav (capitalization)
- Da/når, de/dem, å/og
- Tall, tid og dato (numbers, time, dates)
- Tegn (punctuation marks)
- Forkortelser (abbreviations)
- Sammensatte ord (compound words)

### Praktisk språkbruk (Practical Usage)
- Kansellisten (bureaucratic words to avoid)
- Sensitive ord (sensitive terminology)
- Kjønnsbalansert språk (gender-balanced language)
- Formell e-post (formal email)
- Norsk for engelsk (Norwegian alternatives to English)

### Klarspråk (Plain Language)
- Writing for clarity
- Structuring documents
- Writing for digital services
- Professional/technical writing

## How Token Usage Works

The skill is designed to minimize context window usage. Agents typically have 128k–200k tokens available, and this skill loads content in layers:

1. **SKILL.md (~3k tokens)** — Always loaded when the skill is active. This is a compact quick-reference with the most common rules, so it barely dents the context budget.

2. **INDEX.md (~1k tokens)** — Read on demand to discover what reference files are available. Each entry includes a token estimate so the agent can decide what's worth loading.

3. **Individual reference files** — Loaded only when needed for a specific task. For example:
   - Helping with comma rules → `kommaregler.md` (~1.4k tokens)
   - Replacing bureaucratic language → `kansellisten.md` (~11k tokens)
   - A specific word question → `grep -rl "keyword" references/spraksporsmal/` → read one Q&A file (~500 tokens)

The ~700k tokens of total reference content are **never loaded all at once**. In a typical interaction, the agent uses SKILL.md + INDEX.md + 1–3 reference files = **roughly 5k–20k tokens**, leaving plenty of room for the conversation and task.

The 1,100+ Q&A files (~520k tokens) work the same way — the agent searches by filename or `grep` and reads individual answers as needed.

## Source

All reference content is sourced from publicly available Norwegian language resources at https://sprakradet.no.

## License

MIT License - See LICENSE file for details.

## Content Attribution

The content in the `references/` directory is sourced from publicly available Norwegian language resources at https://sprakradet.no/.

This content is produced by a Norwegian government agency as part of their public mandate under Språkloven (the Norwegian Language Act). Under Norwegian law (Åndsverkloven §9), works created by government agencies in the exercise of public authority are generally not protected by copyright.

Each file includes a source URL for reference. This skill is created to help promote good Norwegian language practices.
