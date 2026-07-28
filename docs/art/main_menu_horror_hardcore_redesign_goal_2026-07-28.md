# Main Menu Redesign Goal: Basement Threshold

Date: 2026-07-28
Status: selected direction for implementation planning
Concept image: [Horror-hardcore main menu redesign](research/main_menu_horror_hardcore_redesign.png)

## Goal

Redesign Gamble Battle's title gateway so the first screen feels like the
player is descending into a basement hardcore show that has become a hostile
ritual. The screen should establish horror, crowd pressure, and villain-first
stakes in one glance while keeping the three existing pieces of title-screen
copy immediately readable:

- `GAMBLE BATTLE`
- `Blood. Gold. Consequence.`
- `ENTER`

Success means the menu feels specific to this game before the player presses a
button. It must not read as ornate Gothic fantasy, industrial science fiction,
generic Halloween art, or a distressed texture pasted over conventional UI.

## Runtime Baseline

The current 1920x1080 runtime title screen uses a centered title, subtitle, one
wide red button, a nearly invisible circular sigil, and large areas of
featureless black. Its hierarchy is readable, but the background does not
communicate a place, a threat, the hardcore influence, or the social pressure
of a mosh pit. The serif-like gold-and-red treatment also keeps the screen in
the existing Gothic-fantasy lane.

## Direction Iteration

Three compositions were considered before spending the single image
generation:

1. **Occult altar:** a centered logo above a ritual object. Rejected because it
   preserved the existing centered Gothic composition and lacked hardcore
   specificity.
2. **Flyer wall:** a dense collage of posters, stickers, set lists, and menu
   scraps. Rejected because it made the first interaction noisy and risked
   turning every surface into distressed decoration.
3. **Basement threshold:** a calm pasted menu flyer beside a stairwell leading
   into a threatening crowd and backlit villain. Selected because it creates a
   clear narrative, strong depth, and one readable interaction without losing
   the underground-show influence.

## Selected Visual System

- **Scene:** player viewpoint at the bottom of a damp concrete stairwell,
  facing an open basement doorway.
- **Threat:** the crowd forms a wall of bodies around one backlit villain
  silhouette. Horror is suggestive, not graphic.
- **Composition:** the calm menu occupies the left third; the doorway and crowd
  occupy the right two-thirds. Eye path is title, doorway, then `ENTER`.
- **Palette:** matte black, dirty bone, charcoal concrete, dried oxblood, faint
  bruised green, and one emergency-red light.
- **Materials:** torn photocopied paper, screen-print ink, scratched paint,
  stained concrete, speaker cloth, handprints, cables, and restrained analog
  film damage.
- **Typography:** a readable hand-cut hardcore wordmark for the title,
  condensed sans serif for the tagline, and a heavy utility sans serif for the
  primary action.
- **Interaction:** `ENTER` is a large admission-ticket shape with a crisp focus
  border and chevron. It must remain obviously clickable with keyboard,
  controller, or mouse.

## Implementation Boundaries

The concept is a visual target, not a single flattened production texture.
Implementation should separate the environment, crowd/villain silhouette,
red-light atmosphere, title treatment, tagline, and button into independent
Godot layers so focus, hover, reduced motion, scaling, and localization remain
controllable.

- Keep all functional text rendered by Godot.
- Preserve a clean internal field behind the title and action.
- Limit motion to slow light breathing, slight film weave, and distant crowd
  movement; reduced-motion mode should retain the composition without motion.
- Keep the villain silhouette readable at compact viewport sizes.
- Do not add ornamental frames, medieval sigils, hazard stripes, road cases,
  neon machinery, excessive gore, or extra readable poster copy.
- Treat texture as atmosphere around the interaction, never as interference
  over the interaction.

## Acceptance Gates

- At 1920x1080 and 1280x720, the title, tagline, and focused `ENTER` action are
  readable within two seconds.
- The screen is identifiable as both underground hardcore and horror without
  relying on a logo explanation.
- The primary action remains obvious in grayscale and is not communicated by
  red alone.
- Keyboard/controller focus, hover, pressed, and reduced-motion states remain
  visibly distinct.
- The doorway, crowd, and villain create dread without hiding the menu.
- A fresh runtime capture matches the selected composition closely enough that
  the generated image is no longer needed to explain the direction.

## Confidence

High. The selected image has a specific location, a clear player decision, a
strong villain-first focal point, and a restrained UI surface. It carries the
horror influence in the world rather than sacrificing usability, and it moves
decisively away from both the rejected industrial lane and the current ornate
Gothic treatment.

An independent clean-context visual review passed the concept direction. The
review specifically confirmed the readable title, exact tagline, oversized
ticket action, basement-show narrative, and restrained red horror lighting.
Implementation must preserve doorway silhouette separation at 720p, add an
explicit default-focus treatment to `ENTER`, and localize ambient motion to the
ticket, lamp, and distant crowd.
