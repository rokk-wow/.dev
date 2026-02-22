# Dev Notes (Core Basics)

This file is intentionally short so AI can load it quickly each session.

## Project Context
- WoW Beta addon development (12.0.x era behavior).
- Use `LibSAdCore` patterns first before inventing custom framework behavior.
- For deep details, check source docs when needed (for example `Libs/LibSAdCore/README.md`).

## Critical API Reality (Beta)
- The old combat log workflow is effectively gone for addon logic.
- Specific combat values are now secret/private.
- Secret examples include aura/spell names, IDs, durations, and targeting/combat detail values.
- Do not perform logical operations on secret values.

## What Is Allowed
- You can manipulate and style data/UI that Blizzard already exposes.
- Prefer new Blizzard APIs that work with protected/secret values without revealing raw values.
- Use built-in aura filters and API helpers instead of custom parsing.
- Build behavior around public API responses and framework events, not raw hidden combat metadata.

## FStack Triage (When User Shares Screenshots)
- Find the mouse cursor first (the exact UI element in question).
- Check the `SOURCE` line to identify which Blizzard/AddOn frame created it.
- Confirm the exact frame container before editing (do not assume viewers/frames are interchangeable).

## SAdCore Coding Rules (Keep These)
- For every `addon.*` function:
  - First line: `callHook(self, "BeforeFunctionName", ...)`
  - Before every return: `callHook(self, "AfterFunctionName", returnValue)`
- Always return explicit values (`true`/`false`/actual value). Never return `nil`.
- Local/private functions are not bound by the `addon.*` hook rule.

## Localization + Messaging
- All user-facing info/error text must use localization via `self:L()`.
- Keep release/user messaging concise and readable.

## Code Style Essentials
- Favor self-documenting code and descriptive names.
- Keep comments minimal (only major section headers or required file headers).
- Prefer affirmative logic when practical.

## Preparing for a Release
To prepare for a release:
- Bump addon version in the `.toc` file:
  - Increase minor version for normal changes.
  - Increase major version for major/breaking changes.
- Read SAdCore docs and create the one-time release-notes section shown to players after update.
- Add a very brief overview of release changes (chat window space is limited).
