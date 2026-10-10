# Word Resource Checklist

The counts use distinct database words, not lesson rows. Images are optional learning aids; a missing image is not automatically a content defect.

| Check | Current |
| --- | ---: |
| unique_words | 3104 |
| word_rows | 3332 |
| audio_files | 3099 |
| audio_missing | 0 |
| audio_case_alias | 6 |
| audio_ambiguous | 0 |
| audio_invalid | 0 |
| audio_mapped | 0 |
| image_files | 3104 |
| image_missing | 0 |
| image_case_alias | 4 |
| image_ambiguous | 0 |
| image_invalid | 0 |
| image_mapped | 1325 |

## Audio Completion

Missing audio before: 210. Missing audio now: 0.

AI-generated additions: 210. Technical validation is not a substitute for pronunciation listening review.

## Editorial Holds

These existing word-list issues must be reviewed before publishing the synthesized pronunciations. The database has not been rewritten.

| Stored word | Spoken text | Reason |
| --- | --- | --- |
| Justiteombudsman | Justiteombudsman | Unconfirmed foreign title in the legacy word list. This is only a synthetic reading of the stored label, not an authoritative pronunciation. Hold for editorial and pronunciation review. |
| Mew Jersey | New Jersey | The database says New Jersey in Chinese but its English label is misspelled. Audio uses the intended name; the database is unchanged and needs editorial correction. |
| St.Petersbrug | Saint Petersburg | The database meaning identifies Saint Petersburg. Audio uses the intended name; the misspelled database label is unchanged. |

## Explicit Filename Aliases

| Word | Type | Actual file |
| --- | --- | --- |
| Miss | audio | wav/miss.wav |
| Miss | image | jpg/miss.jpg |
| March | image | jpg/march.jpg |
| May | image | jpg/may.jpg |
| may | audio | wav/May.wav |
| Endeavour | audio | wav/endeavour.wav |
| march | audio | wav/March.wav |
| Press | audio | wav/press.wav |
| Press | image | jpg/press.jpg |
| South | audio | wav/south.wav |

Image aliases preserve the legacy lookup behavior, but images of case-sensitive meanings (for example May versus may) still need semantic review.

## Audio Follow Up

| Word | Meaning | Book and lesson | Action |
| --- | --- | --- | --- |

## Image Follow Up

| Word | Meaning | Book and lesson | Action |
| --- | --- | --- | --- |

## Unreferenced Files

Do not delete these automatically; retain them until their origin and use are confirmed.
- `wav/word.wav`

## Release Checks

- [ ] Decode all available audio and image files using native Apple frameworks.
- [ ] Listen to every generated pronunciation, especially abbreviations, proper names, and inflected words.
- [ ] Review image aliases against the database meanings.
- [ ] Review every new image, context diagram, and labelled meaning card against its word sense.
- [ ] Confirm rights to the pre-existing audio, images, and textbook content separately.
- [ ] Run the native resource decoder and verify the resource index before packaging.
