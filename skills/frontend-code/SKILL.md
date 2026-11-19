---
name: frontend-code
description: This skill should be used when the user asks to "implement this design", "build a UI component", "review frontend code", or fix accessibility, responsive behavior, interaction states, or web performance. Use frontend-design when the main task is to decide the visual direction.
---

# Frontend Code

Build or review web interfaces that work with real content, different input methods, and different screen sizes. Start with the project's existing components, tokens, and test conventions. Keep implementation changes scoped; for review-only requests, report findings without editing.

## Implementation and review checklist

- **Semantics and input:** Use native buttons for actions and links for navigation. Give controls accessible names, label form fields, and use appropriate input types and autocomplete tokens. Provide useful alt text for informative images and empty alt text for decorative images.
- **Keyboard and feedback:** Keep focus visible and unobscured. Check keyboard operation and focus restoration for dialogs and menus. Provide an alternative to gesture-only actions. Preserve paste and zoom, associate validation errors with their fields, and expose important asynchronous updates to assistive technology.
- **Layout and content:** Prefer CSS layout over JavaScript measurements. Test narrow widths, zoom, long strings, and empty content; fix the source of overflow rather than hiding it. Cover loading, error, and success states as applicable.
- **Navigation and state:** Put shareable filters and pagination in the URL when useful, and check deep links and browser history. Offer confirmation or undo for destructive actions.
- **Motion and performance:** Respect reduced-motion preferences and transition only the properties that need to change. Reserve image space to prevent layout shifts, lazy-load noncritical images, and avoid lazy-loading the primary above-the-fold image.

## Verify and report

Run the relevant project checks. When browser testing is available, exercise the primary flow with a keyboard and at narrow and wide widths. For a review, put the highest-impact findings first and include `file:line`, the user impact, and a short suggested fix. State what could not be verified.

Inspiration: [Vercel Labs’ Web Interface Guidelines](https://www.skills.sh/vercel-labs/agent-skills/web-design-guidelines).
