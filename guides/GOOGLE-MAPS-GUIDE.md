# Google Maps Guide

The custom Google Maps integration in `widgets/google-maps-widget/`. Read before
touching map widgets, markers, or anything that renders a map inside another
component.

## Architecture

- **`GoogleMapsWidget`** (`google-maps-widget.tsx`) — the single entry point.
  Loads the API key (`GoogleMapsService.getAll()` → Firestore `GoogleMap` doc),
  creates the `google.maps.Map`, and conditionally mounts headless plugin
  components based on `mapOptions` / props.
- **Plugins** (each returns `<></>` and acts via effects):
  - `DisplayMarkerPlugin` — one static pin. Active when
    `mapOptions.displayMarker === true`.
  - `MarkersPlugin` — many pins from a `markers: MapMarker[]` prop. Active when
    `markers` is passed.
  - `DraggableMarkerPlugin` — a draggable pin (`mapOptions.draggableMarker`).
  - `GeolocationPlugin` — the "you are here" dot (`mapOptions.geoLocationControl`).
- **`marker-loader.ts`** — all marker creation: `createMarker`, `createMarkers`,
  `createGeolocationMarker`, and the private `createPinContent` that builds the
  custom SVG pin.
- **Loaders** — `map-loader` (`loadMap`), `size-loader` (`loadSize`), `api-loader`
  (`ensureApiOptions`), `street-view-loader`. All go through
  `@googlemaps/js-api-loader`'s `importLibrary`.
- **Config** — `config/google-maps-config.ts`: `ZOOM_CLOSE = 16`,
  `ZOOM_DEFAULT = 13`, `MAP_OPTIONS_DEFAULT`, UI control defaults.
- **Types** — `lib/google-maps/library.ts` (`MapOptions`, `MarkerApi`, element
  aliases), `custom-ui-options.ts` (the `disableControls` / `displayMarker` /
  `draggableMarker` / `geoLocationControl` flags layered onto
  `google.maps.MapOptions`).

## The custom pin

Markers are **not** Google's default `PinElement`. `createPinContent` hand-builds
an SVG from `@icons/map-pin` (viewBox `0 0 100 120`, tip at `(50, 108)`, head
circle centered `(50, 45)` r`24`) so a photo can be clipped into the pin head for
image markers — a look `PinElement` cannot produce. The geometry constants in
`marker-loader.ts` (`MARKER_TIP_Y_VBU`, `MARKER_HEAD_*`, `MARKER_PIN_WIDTH_PX`)
are paired with that icon — keep them in sync if the icon is redrawn.

Default pin width is `MARKER_PIN_WIDTH_PX = 44`; height is derived from the
viewBox aspect ratio (`44 × 120 / 100 = 52.8px`).

## Gotchas

### 1. AdvancedMarkerElement anchors content by its bottom-center, not the visual tip

`AdvancedMarkerElement` defaults to `anchorLeft: '-50%'`, `anchorTop: '-100%'` —
the content box's **bottom-center** lands on the coordinate. Our pin's tip is at
`108/120 = 90%` down the box (the icon pads empty space below the tip), so the
default floats the pin above the coordinate.

Fix lives in `createMarker`: pass `anchorTop: MARKER_ANCHOR_TOP` (`'-90%'`,
computed from `MARKER_TIP_Y_VBU / viewBoxHeight`). This is Google's native anchor
API — prefer it over CSS transforms or viewBox cropping. `anchorLeft` stays the
default `-50%` (the tip is already centered in x). Because `anchorTop` is a
percentage of the content's own height, it is **size-independent**: the tip stays
on the coordinate at any pin size.

### 2. A map inside a HeroUI `Button` shrinks marker SVGs to 16px

HeroUI ships `.button svg { width: 16px; height: 16px }` for icon sizing, and a
CSS rule **beats SVG `width=`/`height=` presentation attributes**. So when a map
renders **inside a HeroUI `Button`** — e.g. the pressable content card
(`ContentCard` → `PressableSurface` → `Button`) — every marker SVG collapses to
16×16 inside its correctly-sized box, giving a tiny, mis-placed pin. Maps that are
not inside a Button (map-page, modals) are unaffected, which makes this look like
a per-map bug.

Fix lives in `createPinContent`: size the marker `<svg>` with an **inline style**
(`svg.style.cssText = 'display: block; height: …; margin: 0; width: …;'`), which
outranks the `.button svg` class rule, and zero the margins HeroUI injects. Never
size the marker SVG via `width`/`height` attributes.

If you embed a map in any new pressable/button surface and the marker looks wrong,
this is the first suspect — check the computed `<svg>` box in DevTools: it must be
`44 × 52.8`, not `16 × 16`.

### 3. Markers render at fixed screen pixels — they do NOT scale with the map

`AdvancedMarkerElement` content is fixed CSS pixels regardless of map size or
zoom. A 44px pin is 44px on a 150px card and on an 800px map. To make a pin look
proportionate on a small map you make the **pin** smaller, not the map.

`MarkersPlugin` (and only it) manually scales its pins by zoom:
`content.style.scale` ramps `0.75×` (zoom 10) → `3.5×` (zoom 25), re-applied on
`zoom_changed`. `DisplayMarkerPlugin` does **not** scale — its pin stays at the
base size. A display marker can therefore look small next to the zoom-scaled
markers-plugin pins at the same zoom; that is expected, not a bug.

### 4. Container-resize drift de-centers the map

If the map container resizes after the map initializes (common when a card's
title/footer lay out late), Google keeps the top-left corner fixed and the center
drifts. `LocationDisplay` handles this by re-centering once map + marker are ready
via `onMap` / `onMarker` (`setCenter` + reassign `marker.position`). A map that
only sets `mapOptions.center` at init is subject to this drift.

### 5. `PinElement` is the escape hatch

If you don't need the photo-in-head look, Google's built-in `PinElement`
(`MarkerApi.PinElement`) is auto-anchored (tip on the coordinate) and tintable
(`background`, `borderColor`, `glyphColor`, `scale`) — none of gotchas #1–#2
apply to it. Reach for it for simple colored pins; keep the custom SVG only where
the photo-in-pin is actually needed.

## Debugging checklist — "the marker is the wrong size or position"

1. Is the map inside a HeroUI `Button` / pressable surface? → gotcha #2 (SVG
   forced to 16px).
2. Is the pin floating above/below the point? → gotcha #1 (`anchorTop`).
3. Does the pin look small next to other pins? → gotcha #3 (display marker isn't
   zoom-scaled).
4. Is the whole map off-center? → gotcha #4 (container-resize drift; re-center on
   ready).
5. In DevTools the wrapper `<div>` **and** the `<svg>` should both be `44 × 52.8`.
   A 44px div wrapping a 16px svg is gotcha #2.
