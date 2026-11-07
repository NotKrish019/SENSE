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

**Assets:** all artwork is original code, the source of truth; no image files, no runtime downloads. Raster images exist only in memory at runtime (baked from that code).
