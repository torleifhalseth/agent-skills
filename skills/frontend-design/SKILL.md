---
name: frontend-design
description: This skill should be used when the user asks to "design a landing page", "redesign this interface", "define a visual direction", or improve the visual hierarchy, typography, palette, or layout of a web interface. Use frontend-code for implementation or code review when the design is already defined.
---

# Frontend Design

Make the interface fit the people, purpose, and content of the product rather than starting from a generic template.

## Set the direction

1. Identify the audience, the main task, and the brand or design-system constraints. Inspect the existing UI before proposing changes. If a missing detail would change the design substantially, ask a focused question; otherwise, proceed with a stated assumption.
2. Describe the direction in one sentence, then sketch the content order and layout. Decide what people should notice first and what they should do next. Use real or representative content early so layout decisions hold up beyond placeholder copy.
3. Define a small set of choices for type, color, spacing, and layout. Give each color a role, use a clear type scale, and reuse existing tokens where possible. Choose one memorable element that makes sense for the brief, then keep the surrounding interface quiet. Use cards, gradients, or decorative labels only when they help communicate something.

## Refine against the brief

- Plan the narrow layout as well as the wide one. Preserve the reading order and primary action when columns stack, text wraps, or content grows.
- Design the states that affect the layout: loading, empty, error, and success where relevant. Use specific action labels and give people a clear next step when something goes wrong.
- Check readable contrast, visible focus, and whether the same meaning survives without color or motion. Use motion to clarify a change, and plan a reduced-motion alternative.
- Review the result with representative content at narrow and wide sizes. If a browser preview is available, inspect the rendered page. Remove details that compete with the main task or could belong to any unrelated product.

Inspiration: [Anthropic’s Frontend Design skill](https://www.skills.sh/anthropics/skills/frontend-design).
