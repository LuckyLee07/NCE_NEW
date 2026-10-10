# Offline Lesson Resource Packs

Japanese/Korean incremental localization is documented in
`Docs/localization/japanese-korean.md`. Use `build_east_asian_localizations.py`
and `test_east_asian_localizations.sh`; the build-only model and resumable cache
remain outside App resources. Simplified/Traditional checks remain available in
`test_chinese_localizations.sh`.

All four books ship inside the App. There is no download flow, server, or
first-launch extraction. This change packages only lesson MP3 and LRC files;
the bundled database and word resources keep their existing locations.

## File layout

| Location | Purpose | Version control |
| --- | --- | --- |
| `NCE_ALL/data/lesson-packs/book1.zip` through `book4.zip` | Canonical offline resources | Include all four ZIPs |
| `NCE_ALL/data/lesson-packs/manifest.json` | Database, archive, and entry SHA-256 checksums | Include |
| `ResourceSources/lessons/mp3` and `lrc` | Editable local copies | Ignored; recoverable from ZIPs |
| `Tools/build_lesson_packs.py` | Build, verify, and restore tools | Include |

The existing Xcode `data` folder resource reference copies all four ZIPs into
`NCE_ALL.app/data/lesson-packs`. Do not put editable sources back under
`NCE_ALL/data`: ignoring them in Git would not prevent Xcode from copying them.

## Runtime reads

`NCELessonResourceStore` uses the database's 1-based book IDs and existing
sentence names. Each ZIP contains `mp3/<sentence>.mp3` and
`lrc/<sentence>.lrc`, with unchanged Unicode names and file bytes.

MiniZip builds the directory-position index once per opened book. Each request
then reads only its entry, validates its size and CRC, and returns `NSData` or
a UTF-8 string. The store serializes ZIP cursor access and uses an 8 MiB-cost
`NSCache`; the audio player consumes the MP3 through `initWithData:error:`.
No resource is written to the App's Documents, Caches, or temporary directory.

## Maintenance

Run these commands from the repository root with Python 3:

```sh
# Validate ZIPs, the bundled database, and any existing editable source copies.
python3 Tools/build_lesson_packs.py --verify

# Recover editable copies on a fresh clone without downloading anything.
python3 Tools/build_lesson_packs.py --restore

# After editing ResourceSources/lessons, rebuild the four ZIPs and manifest.
python3 Tools/build_lesson_packs.py

# Test packaging, all 8,890 runtime reads, audio decoding, concurrency, and errors.
bash Tools/test_lesson_packs.sh
```

The build fails for missing, unexpected, oversized, or malformed resources and
duplicate database names. Resource order, timestamps, and permissions are
fixed for reproducible builds with the same compression toolchain. MP3s use
ZIP STORE; LRCs use DEFLATE. Restoring refuses to overwrite changed local files.

The ZIPs reduce file count, not audio quality. They are binary assets, so changing
a sentence changes its book's ZIP; commit the corresponding manifest too. The
local source folder is a convenience copy, not the only copy of the content.

## Word Pictures

Word media stays offline under `NCE_ALL/data/words`. The 1,325 generated pictures are
128x128 JPEGs (3.35 MiB combined); original pictures are checksum-preserved.
Pictures include object icons, context cues, diagrams, and visibly labelled
meaning cards, not literal photographs. This includes 1,320 originally missing
images and five explicitly recorded sense corrections. AI visual review is hash-bound;
human semantic review remains open.

`build_word_images.py` reads the original missing-word baseline and explicit
`ContentPipeline/word-images/recipes.txt`, composes selected attributed Twemoji
graphics with native AppKit, and produces safe case-distinct filenames. Its
`generated-image-map.json` is consumed by the audit tool to build the ordinary
runtime `resource-index.json`. No new runtime image library is needed.

```sh
python3 Tools/build_word_images.py --twemoji-archive <Twemoji-17.0.3.zip> --include-meaning-cards
bash Tools/test_word_resources.sh
```

The source archive's fixed URL/checksum, selected PNGs and provenance are in
`ContentPipeline/word-images/`. AI prompts are recorded separately. Source artwork
and tooling stay outside the App data folder. New pictures, attribution and the
CC BY 4.0 license ship in the App. See `Docs/word-resources/README.md` for rebuilding,
reviewing and refreshing the native decode report/index.

Image tests verify complete word coverage, original SHA-256 preservation,
nonblank decoded pixels, dimensions, file-size limits, explicit lookups,
case-sensitive meanings, and bundled credits. Run the same test script with a
built App's `data/words` directory to validate its actual packaged resources.

New AI illustration batches may use a user-requested 2x2 atlas: one image
generation, then deterministic top-left/top-right/bottom-left/bottom-right cuts.
`split_word_image_atlas.py --manifest ContentPipeline/word-images/atlas-001.json`
creates four 128x128 PNG source tiles, with source/cell checksums. Add their
explicit `ai_illustration` recipes and use `build_word_images.py --only-words ...`
to rebuild just that batch. Atlas sources and tiles remain outside App resources;
only the compressed individual JPEGs ship. Every quadrant still needs semantic
and crop-boundary review.

The completed `illustration-plan.json` records 25 additional atlases
(`atlas-002` through `atlas-026`) and 100 words upgraded from meaning cards.
The atlas tests verify that every planned word has the matching final source
and an AI-illustration ledger entry. Three correction atlases (027-029) replace
imprecise drafts, including the lesson-specific gliding bird, and explicitly
record the shared bookcase/shelf cell. There are 120 AI illustrations and 415
labelled meaning cards. Start future IDs at `atlas-030` to preserve history.

## Review Evidence

`review_word_audio.py` uses a pre-existing local Whisper model and directly
resamples known PCM audio without an ffmpeg subprocess or an expected-word prompt.
The first pass covers 210 files; the second pass covers its 78 nonexact transcripts.
It does not score pronunciation or replace human listening. Evidence is separate
from the original generation ledger, which retains `pending_listening_review`.

```sh
python3 Tools/record_word_resource_review.py
```

This validates every current image/audio review SHA-256 and the required second-pass
coverage. Recording image review requires the explicit `--record-ai-visual-review`
flag and the contact directory, only after actually inspecting all final contact
pages. The gallery tool can create those pages with `CONTACT_DIRECTORY`.
Never use that flag to auto-approve generated content or human review checkboxes.

`editorial-overrides.json` changes displayed names, translations and accepted
answer aliases without migrating raw database/progress keys. `semantic-repairs.json`
allows five original wrong-sense mappings to use new case-safe pictures without
overwriting any original JPEG. Tests verify that these scopes remain explicit.

## Independent UI QA

The shared `NCE_Content_QA` scheme launches a separate App identity. Tests refuse
to run without a `.resourceqa` bundle identifier, so the production App's records
are not touched. Set `NCE_APP_BUNDLE_IDENTIFIER`; its default remains unchanged
for normal builds. Use a project-specific simulator and a fresh result bundle.

```sh
xcodebuild -project NCE_ALL.xcodeproj -scheme NCE_Content_QA \
  -configuration Debug -destination 'platform=iOS Simulator,id=<QA_SIMULATOR_ID>' \
  -derivedDataPath /tmp/NCEContentQA -resultBundlePath /tmp/NCEContentQA.xcresult \
  -parallel-testing-enabled NO \
  NCE_APP_BUNDLE_IDENTIFIER=com.palmgame.NCEALL.resourceqa.local \
  CODE_SIGNING_ALLOWED=NO test
```

The test-only launch argument `-NCEOfflineResourceQA` suppresses SDK startup and
ad requests only for Debug builds with a `.resourceqa` identity. It is ignored in
production or Release. Resource UI QA therefore does not claim ad delivery,
external dictionary availability, background audio or physical-device acceptance.
The suite covers four books/first-lesson controls, ten word-image samples and
corrected names, dictation submission/result plus both choice tests, both recall
modes, persisted wordbook marking, and offline image credits. A targeted layout
case checks long names/translations on compact iPhone and iPad windows. Screenshots
use `XCUIScreen` instead of application-cropped captures; bounds checks use the
actual App window. Physical-device UI
testing remains deferred until the user can unlock the device.

`check_packaged_word_resources.py --app <APP_PATH> --previous-app <EARLIER_APP> \
--output <REPORT_JSON>` compares the real packaged files with source, validates
the database and preserved JPEGs, and optionally verifies original WAVs against
an earlier independently built App. This is packaging evidence, not content approval.
