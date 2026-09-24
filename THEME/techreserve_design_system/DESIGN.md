---
name: TechReserve Design System
colors:
  surface: '#131315'
  surface-dim: '#131315'
  surface-bright: '#39393b'
  surface-container-lowest: '#0e0e10'
  surface-container-low: '#1b1b1d'
  surface-container: '#201f21'
  surface-container-high: '#2a2a2c'
  surface-container-highest: '#353437'
  on-surface: '#e5e1e4'
  on-surface-variant: '#ddc0bd'
  inverse-surface: '#e5e1e4'
  inverse-on-surface: '#303032'
  outline: '#a58b88'
  outline-variant: '#574240'
  surface-tint: '#ffb3ad'
  primary: '#ffb3ad'
  on-primary: '#640b0e'
  primary-container: '#731717'
  on-primary-container: '#fe7f76'
  inverse-primary: '#a43b36'
  secondary: '#ffb3ae'
  on-secondary: '#68000b'
  secondary-container: '#8e1b1e'
  on-secondary-container: '#ff9e98'
  tertiary: '#f6bc70'
  on-tertiary: '#462a00'
  tertiary-container: '#543400'
  on-tertiary-container: '#d19b53'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#ffdad6'
  primary-fixed-dim: '#ffb3ad'
  on-primary-fixed: '#410003'
  on-primary-fixed-variant: '#842422'
  secondary-fixed: '#ffdad7'
  secondary-fixed-dim: '#ffb3ae'
  on-secondary-fixed: '#410004'
  on-secondary-fixed-variant: '#8b181c'
  tertiary-fixed: '#ffddb6'
  tertiary-fixed-dim: '#f6bc70'
  on-tertiary-fixed: '#2a1800'
  on-tertiary-fixed-variant: '#643f00'
  background: '#131315'
  on-background: '#e5e1e4'
  surface-variant: '#353437'
typography:
  headline-xl:
    fontFamily: Space Grotesk
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.03em
  headline-xl-mobile:
    fontFamily: Space Grotesk
    fontSize: 30px
    fontWeight: '700'
    lineHeight: 36px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Space Grotesk
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 34px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Space Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Space Grotesk
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: 0em
  body-lg:
    fontFamily: Geist
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-md:
    fontFamily: Geist
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Geist
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.06em
  mono-data:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.04em
spacing:
  gutter: 1rem
  gutter-mobile: 0.5rem
  margin: 1.5rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2.5rem
---

## Brand & Style

This design system establishes a high-precision, architectural brutalist aesthetic calibrated specifically for collegiate room reservation and academic facility logistics. Rooted in the institutional rigor of FATEC Franco da Rocha, the visual language balances scholastic authority with developer-grade operational software.

The UI avoids decorative flourishes, rounded consumer motifs, and superficial skeuomorphism. It embraces uncompromising 90-degree geometry, dense structural data grids, monolithic surfaces, and precise linework. The interface evokes the atmosphere of a modern mission-control console engineered for campus administration, laboratory coordination, and academic scheduling. Every interaction feels instant, deliberate, and mathematically aligned.

## Colors

The palette is engineered for a dark, low-fatigue technical dashboard that honors the deep institutional crimson heritage of the institution while maintaining rigorous contrast ratios.

- **Primary (`#731717`)**: Deep institutional crimson. Reserved for structural accents, active navigation states, authoritative CTAs, and system focus frames.
- **Secondary (`#A82E2E`)**: Vivid academic carmine. Applied to highlight key interactive nodes, high-priority slot selections, and critical operational alerts.
- **Tertiary (`#D19B53`)**: Parchment amber. Serves as the operational indicator for impending reservations, pending approvals, and scheduled transitions.
- **Neutral (`#121214`)**: Technical charcoal substrate. Paired with tiered surface tones (`#18191D`, `#222328`, `#2C2E35`) and high-contrast foreground typography (`#F4F4F6` primary text, `#9B9EA7` metadata).

### Reservation Status Semantics
- **CONFIRMADA**: Emerald green `#1F7A4D` (text/border: `#4ADE80`, background tint: `rgba(31, 122, 77, 0.18)`).
- **EM_USO**: Vivid institutional red `#731717` (border: `#E05353`, active pulse).
- **PENDENTE / AGENDADA**: Muted amber `#D19B53` (background: `rgba(209, 155, 83, 0.15)`).
- **CANCELADA / NO_SHOW**: Carbon slate `#3A3C44` (text: `#71747F`, strikethrough notation).

## Typography

Typography delivers a contrast between technical authority and data-dense legibility.

- **Headlines (`Space Grotesk`)**: Technical, geometric, and assertive. Provides strong structural anchors for room titles, floor identifiers, campus departments, and modal headers. Uppercase treatment is used for section pre-headers and system status designations.
- **Body & Numerical Grids (`Geist`)**: Developer-grade, neutral, and hyper-legible. Handles dense scheduling matrices, professor accreditation, time slot codes (`07:30 - 09:10`), and reservation audit logs without visual crowding. Tabular numbers must be enforced across all room capacity badges and timestamps.

## Layout & Spacing

The layout model enforces a strict, rigid grid layout optimized for schedule visualization, room availability timelines, and inventory controls.

- **Canvas Structure**: 12-column dynamic grid on desktop views (min-width `1280px`), transitioning to an 8-column layout for tablets (`768px - 1279px`), and a 4-column compact layout on mobile (`<768px`).
- **Calendar & Matrix Grids**: Room scheduling utilizes fixed 60px time-column blocks aligned synchronously against vertical day bands.
- **Rhythm**: Spacing follows a modular 4px base multiplier. Dense informational containers (e.g., room telemetry, hardware lists) prioritize `space-xs` and `space-sm` for compact internal padding, while section layouts rely on `space-lg` and `space-xl` to establish clear structural hierarchy.

## Elevation & Depth

Visual hierarchy rejects drop shadows and soft blurs in favor of architectural brutalism, structural tonal layering, and explicit technical borders.

- **Surfaces & Tiers**:
  - **Base Canvas (`#121214`)**: Ground floor of the application.
  - **Tier 1 Layer (`#18191D`)**: Schedule grids, sidebar consoles, and top navigation bars.
  - **Tier 2 Layer (`#222328`)**: Room cards, modal dialogs, and reservation inspection trays.
  - **Active State Layer (`#2A2C33`)**: Selected cells, focused form fields, and hovered matrix coordinates.
- **Borders**: Depth is governed by hairline 1px solid boundaries (`#2D3039`). Interactive or active states substitute standard boundaries with primary crimson borders (`#731717` or `#A82E2E`).
- **Shadows**: Absolutely no diffuse ambient shadows are permitted. Modals and active dropdown overlays utilize high-contrast 1px solid borders paired with an opaque offset border (`box-shadow: 4px 4px 0px 0px #000000`).

## Shapes

The design system is strictly sharp (`roundedness: 0`). 

No element, button, card, modal, badge, or input field utilizes border-radius. Every interactive touchpoint and container features sharp 90-degree right angles, evoking architectural blueprints, digital consoles, and technical schematics. Corner notches (e.g., cut corners on primary status badges) are achieved strictly through geometric CSS clip paths if required for terminal-style categorization.

## Components

### Buttons & Action Controls
- **Primary CTA**: Solid `#731717` background, `#FFFFFF` Space Grotesk medium text, 1px solid `#A82E2E` border, sharp corners. Hover transforms background to `#8E1E1E` with no motion easing.
- **Secondary / Ghost**: Transparent background, 1px solid `#2D3039` border, `#F4F4F6` text. Hover yields `#222328` fill and `#731717` border highlight.
- **Critical Action**: Deep crimson fill with high-contrast `#FFFFFF` typography for instant reservation cancellation or incident reporting.

### Room Reservation Matrix & Cards
- **Room Card**: Sharp `#18191D` container with 1px `#2D3039` border. Top header displays Room Code (e.g., `LAB-INFO-04`) in `Space Grotesk` uppercase alongside real-time hardware status indicators (Projector, AC, PCs).
- **Time Slots (Interactive Matrix)**:
  - *Available*: Transparent cell with faint dashed border `#222328`; turns into `#1F7A4D` tint on hover.
  - *Occupied*: Solid `#1E1F24` fill, left accent border 3px solid `#731717`, displaying reserved course and professor name in `body-sm`.
  - *Selected*: Solid `#731717` fill with white tabular text.

### Badges & Status Chips
- Monolithic rectangular pills with 0px radius.
- Uppercase `label-sm` tracking with a lead dot indicator.
  - `CONFIRMADA`: `#12281D` background, `#4ADE80` text, 1px `#1F7A4D` border.
  - `EM_USO`: `#2D1212` background, `#FF6B6B` text, 1px `#731717` border.
  - `NO_SHOW`: `#1E1F24` background, `#8A8D98` text, 1px `#2D3039` border.

### Input Fields & Select Menus
- Background: `#18191D`. Border: 1px solid `#2D3039`. Focus: 1px solid `#A82E2E` with 0 outline blur.
- Field labels are displayed outside input boundaries in uppercase `label-sm` with a secondary grey tone (`#9B9EA7`).

### Data Tables & Schedules
- Stripped of curved padding. Header row features `#18191D` background with 1px bottom border in `#731717`.
- Hovering over a row highlights the entire record in `#1C1D22` with a 2px vertical crimson indicator bar on the left edge.