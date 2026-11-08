# SENSE: Visual Redesign Specification

> **Direction:** SENSE Living Landscapes (paper-cut diorama, illustrated journal)
> **Status:** PROPOSAL. Home prototype v2 awaiting owner review (2026-11-08). Version 1 (the framed "valley") was not approved.
> **Scope:** this document and the Home prototype only. The live app (`mobile/lib/main.dart`) is unchanged; the prototype runs from its own entry point (section 15).
> **Unchanged by this work:** routes, navigation, consent, the six inputs, data models, baseline and fusion engines, crisis-support content, honest unavailable and sample-data wording, `SenseTappable` accessibility, the SENSE logo geometry, bundled Poppins.

---

## 1. Creative direction

Opening SENSE should feel like stepping into an illustrated natural world and finding a page of your own journal lying in it. Calm, human, grounded, warm, reflective, reassuring.

**The core idea: a paper diorama.** The landscape is built from cut-paper planes (sky, distant ranges, a rock formation, forest belts, the valley and its river, the foreground bank) stacked with real depth. Each plane casts a soft shadow onto the plane behind it and has a lit top edge, so the scene reads as dimensional even when still. A sheet of journal paper, with a torn edge, lies over the landscape and holds today's words.

Visual language: traditional landscape painting, vintage travel illustration, folk-art printmaking, risograph colour separation, engraving, contemporary editorial layout, and restrained motion.

**Signatures:**

1. **The diorama:** layered planes with cast shadows, a perspective tilt toward the pointer and parallax separation.
2. **The dimensional sun:** a shaded body with raised, bevelled rings, an off-register print plate, slowly turning irregular rays and a breathing glow.
3. **The journal sheet:** torn paper laid over the scene, faint ruled lines, an ochre margin rule for today's entry.
4. **Print misregistration:** the primary action sits off its ochre plate and settles when pressed; icon wells have off-register rings.

### 1.1 Why version 1 was not good enough, and what changed

| Version 1 weakness | Version 2 |
|---|---|
| A rounded rectangle illustration above a conventional page | The landscape is the page: edge to edge on phones, full window width on desktop; the journal sheet overlaps it |
| Repetitive, symmetrical semicircle clouds | Each cloud is an irregular cluster of puffs with its own silhouette, carved contour layers, warm printed underside, its own opacity, speed and direction |
| Mountains from repeated triangles | Noise-generated ridges with a dominant peak, atmospheric haze on the distant range, sunlit faces that fade downward, engraved shading strokes and contour engraving |
| No rock formations | A weathered butte with two spires, scree slopes, strata that follow its own profile and cracks |
| Repetitive tree silhouettes | Pines generated per tree (tier count, spread, lean, jagged branch tips), a lighter back belt and darker front belt, a broadleaf tree, cropped framing pines |
| Dot-grid sky | Printed ink mottling, paper fibres and warm light toward the sun |
| River as a simple shape with road-like marks | A meandering river that widens toward the viewer, sandy banks, sky reflected in the water, a flickering sun column and shimmer travelling downstream |
| Flowers as dots | Colour-grouped clusters (coral, ochre, cream) with stems and leaves, swaying individually |
| Little depth | Cut-paper shadows between every plane, tilt and parallax |
| Motion barely perceptible | Visible, calm motion (section 8), recorded in GIFs |
| Familiar header, image, greeting, status, button stack | Masthead floating over the sky; journal sheet over the landscape; desktop asymmetric spread with an open index below |

---

## 2. Reference study

The four references are local files at the repository root. They are **mood references only**: their source and redistribution rights are unknown, so they are **not committed, not bundled, not traced and not used as backgrounds**.

| File | Size | SHA-1 (first 12) | Subject |
|---|---|---|---|
| `inspo1.jpeg` | 675×1200 | `3d7991a52e66` | Surreal collage: blue sky, cumulus, birds, a hand-painted spiral sun behind red rock peaks, a snow mountain, pine forest, a winding river, pink wildflowers |
| `inspo2.jpeg` | 736×1308 | `a4f80b13920c` | Vintage halftone sky, cream clouds with cut-paper outlines, a folk spiral sun, a grassy hill |
| `inspo3.jpeg` | 960×1200 | `4aea58602262` | Risograph print: textured mint sky, orange sun with fine concentric lines, peach and pink contour-line clouds, a seated figure on a forested peak |
| `inspo4.jpeg` | 736×736 | `e10a3ac75387` | Aged-paper wash painting: a seated figure on rippling water, a pink halo, two ink-and-wash trees |

**Taken:** layered depth, the sun as focal point, carved contour clouds, red rock formations, a winding river, pine belts, wildflowers, printed texture, warm and cool balance.
**Not taken:** collage photography, dense full-frame swirl fields, figures and halos (section 13), sparkle fields, any composition or element traced from the images.

---

## 3. Design principles

1. **Content first.** Text never sits on busy artwork: it lives on the journal sheet or on parchment; the only text over the scene is the masthead, on the plain upper sky (ink 8.8:1, forest 4.8:1).
2. **Editorial, not dashboard.** Typography, space and a few deliberate surfaces.
3. **One filled action per view.**
4. **Honest by design.** Sample data tagged; unavailable features stated plainly; no invented numbers.
5. **Accessibility shapes the visuals.**
6. **Calm motion.** Visible but slow, independent, never looping in sync; off under reduced motion.
7. **One world.** Every future screen uses the same planes, palette and print language.

---

## 4. Colour

### 4.1 Palette and contrast

Ratios are WCAG 2.x contrast ratios, asserted in `mobile/test/redesign_home_preview_test.dart`.

| Name | Hex | Role | On parchment | On paper |
|---|---|---|---:|---:|
| Warm parchment | `#F3EBDD` | App background | | |
| Soft paper | `#FAF7EF` | Journal sheet, surfaces | | |
| Pale sage | `#DFE7D9` | Quiet panels, icon wells | | |
| Natural ink | `#293A35` | Text, focus ring | **10.1:1** | **11.2:1** |
| Muted ink | `#5A685F` | Secondary text | **4.95:1** | **5.5:1** |
| Deep forest | `#3F6556` | Actions, links, active state | **5.5:1** | **6.1:1** |
| Forest deep | `#2F5245` | Pressed state, art | 7.4:1 | 8.1:1 |
| Ochre ink | `#8A5B14` | Text-safe ochre | 4.9:1 | 5.5:1 |
| Coral ink | `#9A4A3F` | Text-safe coral | 5.2:1 | 5.7:1 |
| Sky ink | `#3E6E6A` | Date and section eyebrows | 4.9:1 | 5.4:1 |
| Control outline | `#8C7F69` | Visible outlines | 3.3:1 | 3.7:1 |
| Sun ochre, dusty coral, sky teal, river blue, eucalyptus | | Decoration and plates only | under 3:1 | under 3:1 |

Illustration-only colours (in `nature_tokens.dart`): meadow, mist range, sky wash, upper sky, horizon haze, cloud cream, sun glow, sunlit rock, mid pines; plus a few rock and sun shading tones defined inside the painters.

The approved palette is unchanged. Decorative hues never carry text or meaning alone.

### 4.2 Semantic tokens (`NatureColors`)

`background`, `surface`, `surfaceQuiet`, `primary`, `primaryForeground`, `textPrimary`, `textSecondary`, `border`, `borderStrong`, `divider`, `focus`, `success`, `warning`, `error`. Widgets use semantic tokens; raw palette names appear only in illustration code.

---

## 5. Typography

Poppins only (bundled, SIL OFL). Greeting 28 (phone) or 34 (desktop) at weight 500; status title 21/500; section title 18/600; body 15/400; muted 14/400; label 15/500; eyebrow 13/500 in sky ink; button 16/600; links 14/500 underlined. Sentence case; letter spacing only on the small wordmark; paragraph measure capped; system text scaling respected.

---

## 6. Composition

### Phone and tablet (under 1024 px)

1. **Scene** edge to edge, height 46 % of the viewport (300 to 420 px; up to 460 px on tablets).
2. **Masthead** floats over the plain upper sky: forest mark and wordmark, profile and support shield.
3. **Journal sheet** rises 54 px over the foreground with a torn top edge and a soft shadow onto the scene. It holds, in order: date, greeting, one supportive sentence, **the primary action** (visible without scrolling at 320 to 412 px), then today's entry with its ochre margin rule.
4. **Open index** of the six inputs: hairline-ruled rows, no card panel.
5. **Example observation** (sample data, quiet sage panel) and **support line**.

On tablets the sheet spans the width and its content is capped at 640 px.

### Desktop (1024 px and up)

1. **Header** in the sky colour, so it reads as part of the scene: wordmark, text tabs, a labelled "New check-in" button.
2. **Scene** across the full window, 74 % of the viewport height (480 to 700 px), with a torn paper edge where it meets the page.
3. **Journal sheet** floats over the lower left (470 px wide). The sun, the river and the rock formation stay open on the right. The primary action is above the fold.
4. Below: the six inputs as an open ruled index in three columns (two under 1240 px), then the example and support side by side. Content capped at 1200 px.

### Surfaces, each with a reason

Journal sheet (where today's words are written), sage panel (the sample aside), hairline-ruled index (a contents page). No other cards. No neumorphism, glass or decorative blobs. Radii: 8, 14, circles.

---

## 7. Illustration system

| Plane | Treatment |
|---|---|
| Sky | Vertical wash, warm light toward the sun, printed ink mottling, paper fibres |
| Sun | See section 8.3 |
| Clouds | Puff clusters with level undersides; seven carved contour layers in alternating ochre and coral, each slightly rotated; peach printed underside; ochre-ink key line; cast shadow; per-cloud opacity |
| Distant range | Mist colour, haze toward the valley, lit ridge edge, cast shadow |
| Main range | Noise ridge with a dominant peak; sunlit wash on sun-facing slopes fading downward; engraved strokes on shaded slopes; contour engraving echoing the ridge |
| Rock formation | Butte with two spires and scree; side light and top light; strata that follow its profile with natural breaks; weathering cracks; lit rim |
| Forest | Two belts of individually generated pines (different heights, spreads, leans, branch tips) |
| Valley | Meadow plane with terrain bands and grass hatching that thickens toward the viewer |
| River | Meandering, widening toward the viewer, sandy banks, sky reflected in the water |
| Foreground | Dark bank with gradient shade, framing pines cropped by the edge, a broadleaf tree |
| Plants | Grasses along the bank, colour-grouped wildflowers with stems and leaves |
| Birds | A flock of five with flapping wings |
| Paper | Fine ink and paper grain over the whole scene |

All geometry is deterministic (seeded), so renders are stable and reviewable. The scene is decorative and excluded from semantics.

**Planned scenes in the same world:** dawn horizon (splash, onboarding), path through the hills (consent), still water (check-in), night meadow (sleep), small vignettes (empty and unavailable states, profile).

---

## 8. Motion, depth and the dimensional sun

### 8.1 Ambient motion (visible, calm, independent)

| Element | Behaviour |
|---|---|
| Sun glow | Breathes over 10 s (radius and opacity); brightens when the pointer comes near |
| Sun rays | Rotate one full turn every 4 minutes |
| Clouds | Four clouds drift at 2.4 to 7.5 px/s in both directions and wrap around |
| Birds | A flock crosses the sky every 34 s (16 s crossing, then absent), wings flapping at slightly different rates |
| Plants | Each grass and flower sways on its own period (3 to 6 s) and phase |
| River | A broken sun column flickers; shimmer arcs travel downstream |

### 8.2 Depth and interaction

- **Cut-paper shadows** between every plane (visible without motion).
- **Parallax:** planes move by depth (sky 0 to flowers 1.0), up to 14 px horizontally and 8 px vertically, eased; page scroll adds up to 14 px of vertical separation.
- **Tilt:** the diorama tilts toward the pointer (perspective, at most about 2.6 degrees) with a small compensating scale so no edge shows.
- **Touch:** dragging a finger over the scene does the same, without blocking scrolling (a passive listener); no motion sensors or permissions.

### 8.3 The dimensional sun

Off-register coral plate; cast shadow; shaded body (light upper left, deeper lower right); four raised rings drawn as ridges with a shadow line below and a highlight above, slightly wobbled like carved lines; soft specular highlight; fine rim; flame-like rays with engraved centre lines behind it; breathing glow.

### 8.4 Reduced motion, hidden tabs, performance

- **Reduced motion** (`MediaQuery.disableAnimations`, which follows `prefers-reduced-motion` on the web): no ticking, no parallax, no tilt. Verified in Chrome: 0 % of pixels changed over 10 s with a pointer move.
- **Hidden tabs and covered routes** pause the scene (`TickerMode`). Verified in Chrome: 180 frame requests in 3 s on Home, 0 while Insights is shown, 181 after returning.
- **Performance:** static planes and clouds are baked once per size into images (capped at 1.5x on wide screens, 2x otherwise). Each frame draws those images plus five small live layers; ambient time updates at 30 Hz. Measured in Chrome at 1280 px: **60 fps** for ambient motion and during the tilt, with a real GPU (Apple M2, Metal) and with software rendering. Before baking it was about 30 fps ambient and 10 fps during the tilt. Baked image memory: roughly 60 MB at 1440 px, about 15 MB on phones.
- No animation or 3D package added. Text is never animated.

---

## 9. Iconography

Line icons in forest inside 42 px pale-sage wells with an off-register outline ring. No emoji as primary UI icons, no glossy or 3D icons. Check-in mood emoji are a known exception (section 13). The logo keeps its geometry; the masthead uses the single-colour forest variant.

---

## 10. Components (prototype)

| Component | Specification |
|---|---|
| Journal sheet | Paper, torn top edge, soft shadow onto the scene, faint ruled lines; floating variant with rounded lower corners on desktop |
| Printed action | Forest fill, paper text 16/600, min height 58, ochre plate 4 px off-register; hover settles 1.5 px, press 4 px and deepens |
| Today entry | 3 px ochre margin rule, eyebrow, status title, muted text, link |
| Open index row | Min height 68, printed icon well, title and honest detail, chevron that moves on hover, hairline above; one `SenseTappable` labelled "Title. Detail" |
| Text link | Forest, underlined, 48 px tap height |
| Sample tag | Paper, control outline, radius 8 |
| Bottom bar | Paper, hairline top; forest indicator and weight change for the active tab; check-in disc with off-register ochre ring; labels capped at 1.3x |
| Top bar | Sky colour on Home, parchment elsewhere; text tabs with underline indicator; "New check-in" button |
| Focus ring | 2.5 px ink |

---

## 11. Responsive behaviour

Verified in Chrome at 320, 360, 412, 768, 1024, 1280 and 1440 px, and with 2x text on a phone and 1.5x text on desktop. The scene recomposes with its size (clouds capped relative to height, sun and rock placed per layout), so the phone crop and the desktop panorama are both intentional.

---

## 12. Accessibility requirements (every screen)

- Text 4.5:1 or more (large 3:1); meaningful non-text 3:1 or more.
- Targets 48 × 48 or more (rows 68, primary action 58).
- Roles, names, states and tap actions through `SenseTappable` or Material controls; Enter and Space; visible ink focus ring.
- Focus order: page content then bottom bar (phone, tablet); header then content (desktop).
- Text scaling never disabled; bar labels capped at 1.3x.
- The scene is decorative; no information depends on it or on motion.
- Real VoiceOver, TalkBack and native Android checks remain outstanding project-wide (`docs/context.md`).

---

## 13. Decisions for the owner

1. Approve the Living Landscapes direction (diorama, dimensional sun, journal sheet, motion, desktop spread).
2. **People in illustrations:** landscapes only is recommended; meditating figures could read as a meditation or therapy product.
3. **Logo colour:** forest single-colour in the app; a parchment and forest app-icon badge to replace the blue one (geometry unchanged).
4. **Mood emoji:** replace with drawn weather and sun glyphs.
5. **Reference images:** keep local and uncommitted unless rights are confirmed.
6. **Copy style:** no em dashes in user-facing text; existing production screens that still use them (for example the Voice demo status message) will be rewritten as each screen is redesigned.

---

## 14. Screen plan (after approval)

| Screen | Direction |
|---|---|
| Splash | Dawn-horizon diorama, mono logo and wordmark |
| Onboarding | One small scene per step, journal sheet for the text |
| Consent | Path-through-the-hills header; switches on the journal sheet |
| Home | As prototyped |
| Check-in | Still-water introduction; drawn mood glyphs; forest sliders |
| Journal | A full journal sheet for writing; honest "not saved" note kept |
| Sleep | Night-meadow header; text-led duration; accessible stars |
| Workload | Sliders and a stepper on one sheet; no productivity framing |
| Voice | Planned and demo status first; no imagery implying recording |
| Activity | Manual entry only; "no health app connected" kept |
| Insights | Muted forest and sky charts, captions, sample tags, no causal wording |
| Insight detail | Editorial reading layout; "not a diagnosis" kept |
| Profile and settings | Plain grouped lists; support, consent and data-rights entries unchanged |

---

## 15. Prototype files and how to run

```bash
cd mobile
flutter run -d chrome --web-port 8766 -t lib/main_redesign_preview.dart
```

| File | Purpose |
|---|---|
| `mobile/lib/main_redesign_preview.dart` | Preview entry point |
| `mobile/lib/presentation/redesign/nature_tokens.dart` | Palette, semantic tokens, breakpoints, motion, radii, spacing, type |
| `mobile/lib/presentation/redesign/nature_illustrations.dart` | `LivingLandscape`: scene geometry, plane painters, baking, motion, parallax, tilt |
| `mobile/lib/presentation/redesign/nature_home_preview.dart` | Responsive Home, journal sheet, bottom and top bars, components |
| `mobile/test/redesign_home_preview_test.dart` | Contrast, behaviour, honesty, motion, responsive and accessibility tests |
| `mobile/lib/presentation/widgets/sense_tappable.dart` | Optional `focusColor`, `hoverColor`, `onHover` (defaults unchanged) |
| `mobile/lib/presentation/redesign/nature_check_in_preview.dart` | Check-in prototype: still-water band, mood scale, sliders, steps, honest finish page |
| `mobile/lib/presentation/redesign/mood_glyph.dart` | `MoodGlyph` painter and the SVG path parser it uses |
| `mobile/lib/presentation/redesign/mood_glyph_data.dart` | Generated from the mood SVGs; do not edit by hand |
| `mobile/test/redesign_check_in_preview_test.dart` | Mood model, artwork, selection, keyboard, semantics, flow, honesty and responsive tests |

**Assets:** all artwork is original code, the source of truth; no image files, no runtime downloads. Raster images exist only in memory at runtime (baked from that code). The mood symbols are the one exception to "code is the source": their editable originals are the SVGs in `docs/redesign/mood-symbols/`, converted to Dart by `docs/redesign/mood-symbols/tools/gen_dart.py`, and a test checks that the two match.

---

## 16. Check-in prototype (awaiting review)

Path: Home → "Begin today's check-in" (also the bottom-bar disc, the desktop "New check-in" button and the Check-in row) → redesigned check-in. The production `CheckInScreen` is unchanged and is no longer reachable from the preview.

**Kept exactly from production:** mood values, order and labels (1 Very Low … 5 Great, compared with the production source by a test); defaults (mood 3, motivation 3, stress 2); the two-step sequence and Back; 1 to 5 sliders in steps of 1; screen-reader names ("Mood: Low", "Motivation or energy level", "Perceived stress", values read as "n of 5"); the mood and stress question wording; the planned-processing notice; the honest "not saved" outcome. No persistence, no model, no new questions.

**Wording changes for review:**
- The finish action reads "Finish check-in" instead of "Save Check-in", because nothing is saved.
- The jargon subtitle ("current mood valence") is replaced by a short note that the check-in is optional.
- Em dashes are removed ("1 · Relaxed", "Check-in complete, not saved").
- The heading stays "How are you feeling right now?", not "today", because changing the time frame would change what the question measures.

**Mood scale:** five across whenever every word fits whole (360 px and wider at normal text); otherwise an ordered list, top to bottom (320 px, large text), never a broken grid. Selected: 2.5 px forest outline, check badge, paper surface with an offset ochre print, a slightly raised symbol, a heavier label. The keyboard focus ring is drawn 4 px outside the tile so it never merges with the selected outline. Animations are 110 to 180 ms with no bounce; with reduced motion they are instant.

**Verification:** `docs/redesign/check-in-preview/` contains a selected representative real-Chrome screenshot (before and after) and the QA scripts that produced it; the complete responsive screenshot galleries (flow, states, every width at 1x and 2x text) can be regenerated using the accompanying QA scripts and are not committed.

---

## 17. Production rollout, Phase 1 (awaiting review)

The approved Home, shell, check-in and mood symbols now run in the real app (`lib/main.dart`: Splash, Onboarding, Consent, then `MainShell`). Journal, Sleep, Workload, Voice, Activity, Insights, Insight detail, Onboarding, Consent and Profile are **not** redesigned yet; they keep `AppTheme.lightTheme` until their phase.

**Where the code lives**

| Production | Purpose |
|---|---|
| `mobile/lib/core/theme/nature_tokens.dart` | Living Landscapes tokens and `NatureTheme.light` (applied only around redesigned screens, so both themes coexist during migration) |
| `mobile/lib/presentation/nature/living_landscape.dart` | The animated paper-diorama landscape (moved from the prototype unchanged) |
| `mobile/lib/presentation/nature/mood_glyph.dart`, `mood_glyph_data.dart` | Mood symbol painter; data generated from `docs/redesign/mood-symbols/*.svg` by `tools/gen_dart.py` |
| `mobile/lib/presentation/nature/mood_scale.dart` | Mood tiles (selected state, offset focus ring) |
| `mobile/lib/presentation/nature/nature_widgets.dart` | Journal sheet and page, printed and quiet buttons, links, tags, sprig, still-water band, slider |
| `mobile/lib/presentation/nature/nature_navigation.dart` | Bottom bar, top bar, check-in disc |
| `mobile/lib/presentation/nature/nature_home_sections.dart` | Masthead, welcome, Today, ways to reflect, sample observation, support line |
| `mobile/lib/presentation/screens/dashboard_screen.dart` | Production Home (same class and callbacks as before) |
| `mobile/lib/presentation/screens/main_shell.dart` | Responsive shell: bottom bar under 1024 px, top bar from 1024 px |
| `mobile/lib/presentation/screens/check_in_screen.dart` | Production check-in; `CheckInScreen.moodOptions` is the mood model |

**Preview only:** `mobile/lib/main_redesign_preview.dart`, `mobile/lib/presentation/redesign/nature_home_preview.dart` and `nature_check_in_preview.dart` keep their own screen layouts as the approved reference. The other files in `redesign/` are one-line re-exports of the production modules. In Chrome at 412 px with reduced motion, production and preview are pixel-identical.

**Palette note:** superseded in Phase 2, see section 18.

**Icons:** `mobile/tool/generate_brand_assets.py` draws the app icon and maskable icon with a forest tile, parchment mark and ochre centre (geometry unchanged); `--png` renders `web/favicon.png` and `web/icons/*`. The horizontal lockup and the mark SVGs are unchanged.

**Review images:** `docs/redesign/production-phase1/` (real production build, entered through the real flow).

---

## 18. Production rollout, Phase 2: Insights, Insight detail, Profile (awaiting review)

Insights, Insight detail and Profile & settings are now in the Living Landscapes design in the real app. Journal, Sleep, Workload, Voice, Activity, Onboarding, Consent and Splash are not redesigned yet.

**Shared structure.** All three use `NatureJournalPage` (the check-in's page): an illustrated band, a torn-edge journal sheet, and on desktop a floating sheet over a full-width scene. Tab roots have no back control; pushed pages have one named "Back". A new original band, `MeadowBand` (`mobile/lib/presentation/nature/meadow_band.dart`), draws layered meadow ridges with engraved contour lines (Insights, Insight detail) or a path winding into the hills (Profile). The main shell no longer wraps these tabs in the Phase 1 interim 760 px column.

**Insights.** An editorial page of sample charts (`nature_charts.dart`): a forest line with an off-register ochre plate on ruled lines, seven river-blue bars with Friday in forest, and a rest-quality ring. Every chart carries a sample tag and a spoken description; bars keep "Wednesday, sample bar" and switch to single letters only when the three-letter names do not fit. The Day / Week / Month selector is kept, with its hint that sample charts do not change. Factor comparison stays an honest "not available yet" note. No scores, risk levels or diagnostic language.

**Insight detail.** An editorial explanation in labelled parts: Sample observation, Correlation, Causation, Personal baseline, Not built yet, then general well-being ideas marked as general information, not advice or treatment. Same constructor parameters as before.

**Profile & settings.** Honest profile placeholder; 24/7 helplines under a coral margin rule; consent review (still the shared in-memory `ConsentPreferences`, opening the same consent screen); privacy and data rights as ruled index rows; Export and Erase open a paper dialog with the unchanged "not available yet" copy; About shows the forest lockup.

**Phase 1 follow-ups**

- *Pale sage contrast.* `#D9E4D4` (approved) stays, but only for non-text: icon wells and illustration. On it, muted text is 4.47:1, teal 4.39:1 and ochre 4.46:1. Text-bearing sage surfaces and every hover tint now use `NatureColors.sageWash` (`#EEF0E6`, pale sage at 35 % over paper), where all text colours are at least 5.0:1. `surfaceQuiet` and the new `hover` token point to it; `paleSageLight` is retired.
- *Logo.* `SenseLogoVariant.forestBadge` (forest tile, parchment mark, ochre centre, identical geometry) is used on redesigned screens; `SenseLogo` takes a `variant`. `tool/generate_brand_assets.py` adds `assets/branding/sense_logo_horizontal_forest.svg`. The blue lockup and the blue in-app badge remain for Splash and Onboarding until their phase.
- *Performance with a GPU.* Headless Chrome on Apple M2 with Metal WebGL: production Home at 60 fps ambient and during pointer tilt, at 1280 and 412 px. Spare main-thread time drops about 18 % for ambient motion and about 52 % during tilt, and returns to idle when another tab or a pushed screen hides Home. Reduced motion: 0 pixels change over 3 s. These are M2 figures, not a claim about low-end phones.

**Review images:** `docs/redesign/production-phase2/`.

## 19. Production rollout, Phase 3: Journal, Sleep, Workload (awaiting review)

Journal, Sleep and Workload are now in the Living Landscapes design in the real app (reached from Home, "Ways to reflect"). Voice, Activity, Onboarding, Consent and Splash are not redesigned yet. These are visual redesigns: inputs, ranges, defaults, question wording and order, validation, navigation and the honest "not saved" behaviour are unchanged, and nothing new is stored, sent, calculated or analysed.

**Shared structure.** All three use `NatureJournalPage` with a "Back" control, and each has its own original, static band (`mobile/lib/presentation/nature/input_bands.dart`) so the pages are related but not cloned: `OrchardBand` (Journal: a morning tree, birds and a river drawn like a line of handwriting), `DuskBand` (Sleep: evening sky, crescent moon, stars, one lit window) and `TerraceBand` (Workload: a terraced hillside with a cairn of balanced stones). Shared input pieces live in `nature_inputs.dart`: `NatureQuestion` (a numbered question whose explanatory text sits on the page and whose response sits below it in a sage-wash area with a margin rule; a source note such as "Adapted from NASA-TLX" is announced as part of the heading), `NatureTimeField`, `NatureCountStepper`, `natureSliderTheme`, `showNatureNotSavedMessage` (same `PrototypeCopy.notSaved` wording) and `showNatureConfirmDialog`. `NaturePrintedAction` and `NatureQuietButton` gained a disabled state (null `onTap`, announced as disabled). `NatureSlider` stacks its end labels when a word would otherwise break.

**Journal.** A brighter leaf of ruled paper with a coral margin line; the rules follow the text's line height at every text size. The prompt is set like a pencilled margin note. The field keeps its persistent name "Journal reflection", the hint, the live word and character count and "Not saved (prototype)". The on-device crisis-phrase check is unchanged; its 24/7 support notice (same contacts) now sits under a coral rule and is a live region. "Save Reflection" (disabled until there is text) shows the honest message and then reads "Not saved (prototype only)"; "Clear" (disabled while empty, moved from the app bar to beside Save) asks for confirmation.

**Sleep.** An evening page. Order kept: (1) total sleep duration, 4 to 12 hours in half-hour steps, default 7.5, spoken as "7.5 hours"; (2) bedtime and wake time, each opening the time picker; (3) subjective rest quality, five stars, default 4. A new line states that duration is not calculated from the two times (true of the existing screen), and the page says every value is entered by hand. "Your entry (manual)" restates the answers. The example 7-day history keeps its sample tag and is read as one sentence that says "sample data".

**Workload.** A field-ledger summary, "Your ratings (self-reported)", restates the three answers; no score is calculated. Mental demand (adapted from NASA-TLX) and Effort invested keep their questions, 1 to 5 ranges and defaults; their end labels drop the em dash ("1 · Very light", "5 · Intense"). Impending deadlines in the next 48 hours: a stepper from 0 upwards with "One fewer deadline" / "One more deadline" buttons (tooltips kept) and a live value ("1 deadline"). The pre-existing unused `_tasksCompleted` field is left as it was; no task tracking is shown.

**Verification.** `test/production_phase3_test.dart` (behaviour, defaults, semantics, keyboard, honesty, motion, desktop layout, and real-Poppins checks at 320 to 1440 px and text 1x, 1.5x and 2x). Real Chrome: all 21 width and text-size combinations reach the three screens, with no sideways scroll, and Back returns to Home.

**Review images:** `docs/redesign/production-phase3/` (selected comparisons; full galleries can be regenerated with the QA scripts there).

## 20. Production rollout, Phase 4: Voice and Physical activity (awaiting review)

Voice and Physical activity are now in the Living Landscapes design in the real app (Home, "Ways to reflect"). Onboarding, Consent and Splash are not redesigned yet. Nothing new is recorded, read, stored, sent or calculated.

**Shared structure.** Both use `NatureJournalPage` with a "Back" control and their own static band (`input_bands.dart`): `EchoBand` (Voice: a still lake at first light, a songbird on a reed and the rings its song might leave on the water; deliberately no waveform or glowing orb) and `TrailBand` (Activity: a dashed footpath over rolling ground to a signpost, a stream with stepping stones, distant peaks). A new shared `NatureStatusPanel` (`nature_inputs.dart`) states availability in words (status, title, explanation) and is read as one sentence.

**Voice: planned, not built.** The page opens with an explicit status, "Planned · not built: Not available in this prototype", stating that there is no recording control, the microphone is never used, no microphone permission is requested and nothing is recorded, analysed or saved. It then explains what voice could add (experimental acoustic features, not validated indicators of stress or emotion), what a voice check-in would involve (the planned design, using the existing wording and suggested prompt), and the person's current voice preference from the shared in-memory `ConsentPreferences`, with a link to the existing consent screen. *Removed:* the demonstration "record" button with its three-second timer and decorative bars. It never recorded anything, but it looked like a working recorder, which the Phase 4 brief rules out. The Home row now reads "Planned · not built, no audio recorded" (was "demo only").

**Physical activity: manual entry only.** Fields, ranges, defaults and order are unchanged: daily step count (1,000 to 20,000 in steps of 500, default 6,800, spoken "N steps") and active exercise minutes (0 to 120 in steps of 5, default 35). "Your entry (manual)" restates both. "Where activity data comes from" lists Manual entry (available, not saved) and Health Connect (not connected, not available in this prototype), with the existing explanation that a future integration would read only daily step totals with explicit permission and no GPS or background location. *Replaced:* the always-off Health Connect switch, which looked operable but only showed an "unavailable" message, is now a status row with no control. "Save Activity Entry" shows the honest "not saved" message.

*Accessibility correction (exact values).* A Material `Slider` with `divisions` rounds its value to the nearest division, so the step default 6,800 (not on the 500-step grid from 1,000) was drawn and announced as 7,000 while the page showed 6,800; this predated Phase 4. Both Activity sliders are now continuous `Slider`s that hold the exact value, snap pointer and touch changes to the same grid, and expose one slider node whose value is exactly the text shown ("6,800 steps"). Keyboard arrows and the screen reader's increase / decrease actions move to the next or previous grid value (6,800 to 7,000 or 6,500, then by 500), clamped to 1,000 and 20,000. The default, range and step are unchanged. Real Chrome exposes `aria-valuetext` "6,800 steps" on load.

**Verification.** `test/production_phase4_test.dart` (status wording, no recorder, timer, waveform or switch, consent link, values and ranges, keyboard, motion, desktop layout, and real-Poppins checks at 320 to 1440 px and text 1x, 1.5x and 2x). Four earlier tests that described the removed demo and switch now check the explicit states instead. Real Chrome: all 21 width and text-size combinations reach both screens, with no sideways scroll, and Back returns to Home.

**Review images:** `docs/redesign/production-phase4/` (selected comparisons; full galleries can be regenerated with the QA scripts there).

## 21. Production rollout, Phase 5: Splash, Onboarding, Consent (awaiting review)

Splash, Onboarding and Consent are now in the Living Landscapes design. With Phase 5, every production screen applies `NatureTheme`. The old blue `AppTheme` is still the app-wide default in `main.dart` (each screen overrides it) and is used by the developer-only design showcase, which Home offers only in debug builds. Flow, timing, consent identifiers, defaults, state and completion behaviour are unchanged; nothing is saved.

**Flow (unchanged).** `main.dart` opens Splash; after 1.8 s Splash *replaces* itself with Onboarding. "Skip" and "Get Started" both *push* Consent (no route bypasses it; Back returns to the step the person left). "Continue to SENSE" opens Home as the only route. From Profile, "Review data and consent preferences" opens the same Consent screen in settings mode, where "Done" returns to Profile. There is no returning-user path: nothing is persisted, so every launch or browser refresh starts at Splash with all six preferences off (in memory only, `ConsentPreferences`).

**Splash.** Parchment, the forest badge printed over an off-register ochre plate, "SENSE" in forest, the existing tagline and "Non-clinical research prototype". A printed horizon (`SplashHorizon`, `arrival_art.dart`) has its own strip at the foot, so text never sits on the illustration. The only motion is a 600 ms fade-in, skipped with reduced motion. Nothing claims to load or initialise.

**Onboarding.** The three steps keep their order and meaning (badges and titles now in sentence case). Each has its own printed medallion (`OnboardingMotif`: contour rings, six stepping stones, a sheltering leaf) and a short pair of lines that keep "In this prototype" apart from "Planned". "Step n of 3" is shown and announced (live region). New: a "Back" button to the previous step (swiping still works). On desktop the medallion sits beside the text. With reduced motion, steps change without the slide.

**Consent.** A field path and an open gate (`GateBand`) above the journal sheet used by the other Living Landscapes pages. The prototype notice, the six choices and every line of their wording are unchanged. Each choice's header row is one accessible toggle named "M2 · Journal. Available to try · not saved" with its on/off state, a status tag in words and "On"/"Off" beside a printed switch (the knob moves instantly with reduced motion). The live count "n of 6 inputs turned on (kept only while the app is open)" and the support note remain. The consent model, identifiers, defaults and navigation are untouched.

**Verification.** `test/production_phase5_test.dart` (timing and replacement, the real `SenseApp` entry route, no returning-user shortcut, original step meaning, Back / Skip / Get Started, keyboard, reduced motion, consent order, defaults, toggling by tap, semantics action and keyboard, settings review, desktop layout, and real-Poppins checks at 320 to 1440 px and text 1x, 1.5x and 2x). One earlier test now scrolls to the first consent choice before tapping it. Real Chrome: the first-launch route and the Profile review path complete; every width and text size reaches Home with no sideways scroll.

**Review images:** `docs/redesign/production-phase5/` (selected comparisons; full galleries can be regenerated with the QA scripts there).
