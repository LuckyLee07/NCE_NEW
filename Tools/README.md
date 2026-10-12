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

### Academy Book 1 visuals (2026-10-11)

`ContentPipeline/word-images/academy-book1/plan.json` covers all 605 Book 1
word keys: 581 words with visuals (565 distinct PNGs, including 62 native
diagrams, 30 supplemental context scenes, 12 approved pilot images and 16
explicit shared illustrations) plus 24 native grammar/discourse hints.
The 116-word audit and previous hints are retained in `supplement.json`. Runtime selection uses `academy-image-map.json` and the
book-aware resource-store API. Each book has a separate map, so shared spellings
do not override a different book's word sense.
Every new image is a 320×320 PNG, at most 200,000 bytes, with no JPEG encoding.
Native hints and context captions leave the target word blank and use the same
visibility as meanings. Supplemental diagrams/scenes display at up to 200 pt
in the wordbook and 160 pt within lessons;
context captions are native, accessible text and wrap independently of the art.

The initial 116 generation receipts, five original correction receipts, eight
supplemental receipts and one supplemental correction receipt in `jobs/` retain
prompts, original generated atlas locations, cell order and assistant visual
review status. Replaced cells are marked `superseded_by`. The exporter
skips those cells, so receipts can be replayed in filename order into an empty
output directory. Original atlases live at their recorded local generation paths;
keep those files when moving or reproducing the pipeline. They are not bundled.

```sh
xcrun clang -fobjc-arc -framework Foundation -framework ImageIO -framework CoreGraphics \
  Tools/export_academy_word_atlas.m -o /tmp/nce-export-academy-atlas
# For each receipt, export into the same empty staging directory, then install PNGs.
/tmp/nce-export-academy-atlas <receipt.json> <staging-directory>
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
  -module-cache-path /tmp/nce-academy-swift-cache Tools/render_academy_word_diagrams.swift
python3 Tools/build_academy_word_images.py
bash Tools/test_academy_word_images.sh
```

The strict builder requires complete coverage and reviewed source receipts.
`Docs/word-resources/academy-book1-review.html` is a searchable gallery of all
images and hints; the adjacent JSON report records file hashes, sizes and source
receipts. The Swift renderer creates deterministic calendar, count and relation
diagrams directly; it does not edit generated illustrations.
`testAcademyBookOneVisuals` checks grammar hints, scene captions, calendar/timeline
loading and nonoverlapping layout in the isolated QA app.

### Academy Book 2 visuals

`ContentPipeline/word-images/academy-book2/plan.json` maps 838 independent word
keys to 660 new scene illustrations, 81 native diagrams, 69 explicitly reviewed
Book 1 reuses, six within-book aliases and 22 native grammar/discourse hints.
Its 165 initial atlas jobs use the same approved reference and PNG constraints.
`references.json` records primary references for specialized aircraft and space
equipment. Generation receipts and correction history follow the Book 1 format.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
  -module-cache-path /tmp/nce-academy-swift-cache Tools/render_academy_word_diagrams.swift 2
python3 Tools/build_academy_word_images.py --book 2
bash Tools/test_academy_word_images.sh NCE_ALL/data/words 2
```

The strict builder writes `academy-book2-image-map.json`, a per-word report and
`Docs/word-resources/academy-book2-review.html`. Use `--allow-partial` only during
generation; a partial report lists every missing word and is not completion
evidence. The resource test checks all words, image budgets and decoding, scoped
captions/hints and different-sense words such as bank, pool, key, hand and spring.
`testAcademyBookTwoVisuals` and `testAcademyBookTwoEmbedded` exercise the wordbook
and lesson views in the isolated QA app. Books 3–4 retain their existing resources.

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

## App icon export

`export_brand_assets.swift <repository-root> --icons-only` exports the approved
`ContentPipeline/branding/source/icon.png` to every slot in the AppIcon catalog
without regenerating book covers. It writes opaque sRGB PNGs and records their
dimensions and hashes in `Docs/branding/icon-asset-report.json`. Run with the
Swift toolchain and macOS SDK from the same Xcode installation.

The current icon is the user-approved lighter-background revision of concept 05,
耳机书本精灵 (2026-10-12), from `Design/2026-10-12-icon-lighter/`.
The earlier darker background and specification are preserved in
`ContentPipeline/branding/revisions/20261012-before-lighter-background/`.
The previous icon and design specification are preserved in
`ContentPipeline/branding/revisions/20261012-before-book-companion/`.

## Independent UI QA

Keep simulator ad-hoc signing enabled (`CODE_SIGNING_ALLOWED=YES
CODE_SIGN_IDENTITY=-`). An unsigned resource bundle can run but fail
SplashBoard's launch-storyboard validation, producing a black launch screen.
The app creates its main window in AppDelegate; LaunchScreen must only be set
as `UILaunchStoryboardName`, not `UIMainStoryboardFile`.

Startup/loading checks (2026-10-12): `testStartupLoadingAndRecovery`,
`testStartupSlowPreparation`, and `testAudioPreparationCancellation` cover
preparation feedback, retry, relaunch, and stale audio cancellation. The QA-only
arguments `-NCEStartupPreview` (12-second preview), `-NCEStartupFailOnce`,
`-NCEStartupReduceMotion`, and `-NCEAudioPreparationPreview` require both Debug
and `-NCEOfflineResourceQA` on a `.resourceqa` bundle. Cold startup shows a 0.8-second brand introduction while preparation runs
concurrently. Real work taking longer keeps the loading state visible; failures
show retry immediately. Retries and foreground restoration add no minimum wait. Preview captures and the generated transparent
mascot source are in `Design/2026-10-12-loading/`.

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
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
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


### Study interface QA (2026-10-11)

The current UI suite follows the three root tabs and the shared lesson sections.
It covers four volumes, current-volume search and empty results, dictation drafts
across section switches and relaunches, explicit grading, skips, wrong-only retry,
all-correct results, recall modes, saved bookmarks, corrected word names, and four
interface languages. Compact/iPad and accessibility text-size checks are separate
selectable test methods. The store capture test retains the host recorder markers
and runs only with the `.resourceqa.storemedia` identity.

The temporary `-NCEPreviewBanner` implementation was removed when the user asked
to retain the submitted 1.3 (1) advertising behavior. Offline tests no longer
simulate a banner. `-NCEResetStudyQA` clears study UI preferences and practice drafts
only in the isolated Debug QA app; relaunch-resume tests remove that flag.
Tests do not validate live ad delivery.

Run the Foundation-only practice state checks with:

```sh
bash Tools/test_practice_session.sh
```
