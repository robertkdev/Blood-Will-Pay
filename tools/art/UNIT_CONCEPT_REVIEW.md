# Blood Will Pay Unit Concepts: Agent Protocol

This tool is the shared review surface through which the user communicates the
current unit-art direction to agents.

## Read Path

1. Inspect the live workspace and server process.
2. Read `C:\Users\Flipm\Documents\Blood-Will-Pay-shared\tools\art\unit-art-review-state.json`.
3. Read `communication.phase2_working_concepts`, not a guessed image folder.
4. Match the requested unit by `unit` and use its exact `image_path`, `decision`, and `note`.
5. Open that exact image when visual judgment is required.
6. Use the existing Chrome tool page only when interactive or visual confirmation is useful.

The stable page is:

`http://127.0.0.1:8769/tools/art/unit-art-review.html?shared-main=1c71fbbb`

The JSON API is:

`http://127.0.0.1:8769/api/unit-art-review-state`

## Semantics

- `working concept`: the selected version the user is going with for now.
- `like` / `Use for now`: approved as the current working concept.
- `maybe` / `Needs revision`: direction may survive, but revision is required.
- `cut` / `Reject`: do not use as the current direction.
- `undecided`: no review decision yet.
- A selection is not a claim that the image is already production-ready.

## Agent Rules

- Never answer “what is wrong with Unit X?” until the selected manifest row and exact image have been inspected.
- Never infer the selected version from filenames, pins, newest timestamps, historical manifests, screenshots, or conversation memory.
- Never replace a selected image with a nearby candidate merely because it looks more polished.
- If the browser and JSON disagree, stop art judgment and diagnose persistence first.
- Make ordinary review changes through the live page, not by hand-editing JSON.
- After a change, verify the page reports a saved revision and independently reread the JSON row.
- Report the selected path when there is any chance of version ambiguity.

## Downstream Verification

Audit the exact working concept separately for:

- front, side, and back reconstruction clarity;
- stable anatomy, face, costume, materials, and color identifiers;
- equipment attachment and hand occupancy;
- silhouette readability at intended sprite scale;
- occluded or invented regions that require design decisions;
- animation constraints, moving layers, and deformation risks;
- compatibility with 3D modeling, sprite-sheet generation, portraits, icons, and VFX.

Record findings as notes against the selected concept or in a linked audit
artifact. Do not silently change the working concept while performing this
verification.
