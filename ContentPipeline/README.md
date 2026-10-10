# Content Pipeline Pilot

This folder is a pilot workflow for replacing bundled textbook content with
project-owned or user-provided learning material.

## Goal

Create small, auditable English-learning lessons that can later be imported
into the app database or served as downloadable content packs.

The first target product shape is:

- A local English listening and dictation tool.
- A small built-in sample library.
- User-owned content import as the main growth path.
- No references to protected textbook brands or bundled third-party courses.

## Production Stages

1. Brief
   - Define level, topic, audience, sentence count, word count, and exercise type.
   - Avoid prompts that ask for imitation of a specific textbook, author, course,
     narrator, publisher, or brand.

2. Draft
   - Generate original English lines, Chinese translations, vocabulary, and exercises.
   - Store the draft as JSON with metadata and review status.

3. Rights Ledger
   - Record source method, rights status, commercial-use status, and attribution needs.
   - Keep one ledger row per lesson or content asset.

4. Language QA
   - Check grammar, naturalness, CEFR level, translation accuracy, and exercise answers.
   - Mark anything unresolved before use in an app build.

5. Audio
   - Record original human audio or use a TTS provider with explicit commercial rights.
   - Record provider, voice, date, text version, and license evidence.

6. Packaging
   - Convert approved JSON into SQLite rows or app-importable course packs.
   - Include only approved assets in release builds.

## Release Rule

Only lessons with `review_status` set to `approved_for_release` should be bundled
in the app. The pilot lesson in this folder is a draft and still requires human
review before release.

