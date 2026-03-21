---
name: turbo-for-rails
description: >
  Use when writing Rails frontend code with Hotwire (Turbo Drive, Turbo Frames, Turbo Streams),
  Stimulus controllers, React components in Rails, ActionCable real-time features, or configuring
  esbuild/TypeScript/CSS bundling for Rails. Also use when writing Cypress tests for Rails apps.
  Trigger when you see turbo_frame_tag, turbo_stream, data-controller, data-action, data-target,
  stimulus-rails, @hotwired/turbo-rails, createRoot with turbo:load, or Rails + React integration.
---

# Turbo for Rails (Hotwire + React)

Hotwire (Turbo + Stimulus) handles 80% of interactivity without writing JavaScript. React is for the 20% needing rich client-side state. Both coexist in one Rails app.

## Quick Reference

| Task | Hotwire approach | React approach |
|---|---|---|
| Scoped page update | Turbo Frame (`turbo_frame_tag`) | N/A |
| Multi-region update | Turbo Stream (`.turbo_stream.erb`) | `useState`/`useReducer` + re-render |
| Toggle/show/hide | Stimulus controller + CSS class | `useState` + conditional render |
| Real-time push | `turbo_stream_from` + ActionCable | ActionCable subscription + `dispatch` |
| Form submission | Standard Rails form (Turbo intercepts) | `fetch` with CSRF token |
| Complex client state | Not ideal -- use React | `useReducer` or Redux Toolkit |

## Turbo Essentials

**Drive** -- Always on. Replaces `<body>` on navigation. Use `turbo:load` instead of `DOMContentLoaded`. Disable per-element with `data-turbo="false"`.

**Frames** -- Scoped navigation. One frame updated per response. IDs must match between display and form partials.
```erb
<%= turbo_frame_tag(dom_id(concert)) do %>
  <%= link_to "Edit", edit_concert_path(concert) %>
<% end %>
```
Key options: `src:` (lazy-load), `loading: "lazy"` (defer until visible), `target: "_top"` (break out).

**Streams** -- Multi-region updates. Actions: `append`, `prepend`, `replace`, `update`, `remove`, `before`, `after`. Use `target` (single ID) or `targets` (CSS selector).
```erb
<%# app/views/favorites/create.turbo_stream.erb %>
<%= turbo_stream.append("list", @favorite) %>
<%= turbo_stream.remove(dom_id(@old)) %>
<%= turbo_stream.update("count", plain: count) %>
```
Controller: `format.turbo_stream` renders `<action>.turbo_stream.erb` without layout.

**Frames vs Streams**: Frame = one element, must be `<turbo-frame>`. Stream = any number of elements, any DOM ID, richer actions.

**Critical gotchas**: Use `requestSubmit()` not `submit()`. Lazy-load response must omit `src` (infinite loop). `button_to` needs `form: {data: {"turbo-frame": "id"}}`. When ActionCable broadcasts AND controller returns stream, use `format.turbo_stream { head(:ok) }` to prevent double updates.

See references/turbo.md for inline edit pattern, all ERB helpers, and complete gotcha list.

## Stimulus Essentials

File: `app/javascript/controllers/<name>_controller.ts`. HTML: `data-controller="<name>"`.

```ts
import { Controller } from "@hotwired/stimulus"
export default class MyController extends Controller {
  static targets = ["output"]
  static values = { count: Number }
  outputTarget: HTMLElement    // Must declare for TypeScript
  countValue: number           // lowercase type, uppercase in static

  toggle(): void { this.countValue += 1 }
  countValueChanged(): void { this.outputTarget.innerText = `${this.countValue}` }
}
```

**Action format**: `data-action="event->controller#method"` (e.g., `click->css#toggle`).
**Targets**: `data-<controller>-target="name"` -- generates `nameTarget`, `nameTargets`, `hasNameTarget`.
**Values**: `data-<controller>-<value>-value="x"` -- generates getter/setter + `<value>Changed` callback.
**Classes**: `data-<controller>-<token>-class="hidden"` -- decouples CSS from JS.

**Key rules**: DOM is the state store. `<value>Changed` fires on connect (no separate `connect()` needed). Multiple controllers on one element: `data-controller="css text"`. Chained actions execute in order. After creating `.ts` files, run `bin/rails stimulus:manifest:update`.

**Generic reusable controllers** (configure entirely in HTML): CSS toggle, text toggle, CSS flip, sort (MutationObserver). See references/stimulus.md for full implementations.

See references/stimulus.md for lifecycle callbacks, params, cross-controller communication, debounce, and all common mistakes.

## React in Rails Essentials

Components live in `app/javascript/components/`. Mount on `turbo:load`:
```tsx
document.addEventListener("turbo:load", () => {
  const el = document.getElementById("react-element")
  if (el) createRoot(el).render(<App {...parseDataAttrs(el.dataset)} />)
})
```
Import entry point in `app/javascript/application.js`. Pass server data via `data-*` attributes on the mount `<div>`.

**State**: `useState` for simple, `useReducer` for complex (discriminated union actions), Redux Toolkit for app-wide. Reducers must be synchronous -- async in `useEffect` or thunks.

**CSRF**: All non-GET `fetch` calls need `X-CSRF-Token` from `document.querySelector("[name='csrf-token']")`.

**useEffect rules**: Cannot be async (wrap inner fn). `[]` = mount only. Return cleanup fn for intervals/subscriptions. Never omit dependency array if effect updates state.

**Immutable updates**: `setSeatStatuses(prev.map(...))` -- never mutate in place.

See references/react.md for useReducer/Redux patterns, styled-components, Context API, and complete gotcha list.

## ActionCable / Real-Time

**Turbo Streams over ActionCable** (zero JS):
```erb
<%= turbo_stream_from(current_user, :favorites) %>
```
```ruby
# Model callback (prefer _later_ variants)
after_create_commit -> { broadcast_append_later_to(user, :favorites, target: "list") }
after_destroy_commit -> { broadcast_remove_to(user, :favorites) }
```
For multi-region broadcasts, use `Turbo::StreamsChannel.broadcast_stream_to` with `content: ApplicationController.render(...)`. Partials must use locals (no `current_user` -- runs outside request cycle).

**Custom channels** (Stimulus or React): Guard against double-subscribe (`if (this.subscription) return`). React subscriptions at module level, not inside `useEffect`. Non-serializable objects (subscriptions) stay outside Redux.

**Signed streams for React**: Embed `Turbo::StreamsChannel.signed_stream_name(...)` in a data attribute; subscribe with `channel: "Turbo::StreamsChannel"` + `"signed-stream-name"`.

See references/real-time.md for bidirectional channels, Redux thunk integration, and broadcast patterns.

## Setup Quick Reference

```bash
# New app (book defaults)
bundle exec rails new . -a propshaft -j esbuild --database postgresql --skip-test --css tailwind

# Key packages
yarn add react react-dom @types/react @types/react-dom
yarn add @rails/actioncable @types/rails__actioncable
yarn add --dev typescript tsc-watch cypress

# TypeScript dev loop (Procfile.dev)
js: yarn dev    # tsc-watch -> esbuild on success
css: yarn build:css --watch
```

**tsconfig.json**: Set `"jsx": "react"`, `"noEmit": true` (esbuild transpiles), `"allowSyntheticDefaultImports": true` (Redux).

**Tailwind content paths** -- must include `.turbo_stream.erb` and `.tsx`:
```js
content: ["./app/views/**/*.(html|turbostream).erb", "./app/javascript/**/*.(js|ts|tsx)"]
```

**esbuild + Tailwind CSS conflict**: If importing a CSS package (e.g., animate.css), rename Tailwind output to `tailwind.css` and update `stylesheet_link_tag`.

See references/setup-and-bundling.md for esbuild flags, import maps migration, TypeScript types, and full package.json.

## Testing (Cypress)

```bash
yarn add --dev cypress eslint-plugin-cypress
# Gemfile: gem "cypress-rails", gem "dotenv-rails"
rails cypress:open   # interactive    rails cypress:run  # headless
```

```js
beforeEach(() => {
  cy.request("/cypress_rails_reset_state")
  cy.request("POST", "/test/log_in_user")
  cy.visit("/concerts/last")
})
cy.get("[data-cy=submit]").click()
cy.get("[data-cy=list]").find("article").should("have.lengthOf", 1)
```

Use `data-cy` attributes for stable selectors. Use test-only controllers for login/setup via `cy.request`. Only one test should walk through the real login form.

See references/testing.md for full Cypress command reference, seed patterns, and debugging techniques.

## References

- `references/turbo.md` -- Turbo Drive/Frames/Streams, ERB helpers, inline edit pattern, all gotchas
- `references/stimulus.md` -- Controller structure, actions/targets/values/classes, generic controllers, TypeScript
- `references/react.md` -- Mounting, hooks, Redux Toolkit, styled-components, CSRF, ActionCable integration
- `references/real-time.md` -- ActionCable setup, Turbo Stream broadcasts, custom channels, signed streams
- `references/setup-and-bundling.md` -- rails new, esbuild, TypeScript, Tailwind, Propshaft, import maps
- `references/testing.md` -- Cypress setup, commands, seed data, test controllers, debugging
