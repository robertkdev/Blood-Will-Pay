# Gameplay Composition V2 Assets

## Scope

The composition pass's original two Native ImageGen assets (recessed panel and crimson action plaque) plus the later trials recorded below: the v5 panel, the v6 arena floor and the v1 primary-action emblem. These are UI surfaces or UI emblems, not changes to unit source art, identities or gameplay, and whole-screen acceptance remains a separate rendered-runtime gate.

## Status: Rejected V2 Panel, Trial V5 Panel

The composition pass now ships **two** panel candidates and one unchanged action plaque. Their status is not the same, and this document does not claim final approval for the trial:

| Surface | Status | Shipping path | SHA-256 |
| --- | --- | --- | --- |
| Recessed panel v2 | **Rejected for gameplay chrome.** Recovered and inspected, but its relief corners read larger and louder than the surfaces they framed, so `GothicUIAssets.gameplay_panel_style()` declined it and every panel fell back to flat quiet iron. Kept on disk for provenance and one-line rollback only. | `assets/ui/gothic/generated/gameplay_panel_luna_v2.png` | `83e599782a50c53d876dd14f54b18980ff7b91e1d5717742e372883f37f71e78` |
| Recessed panel v5 | **Root-approved FULL-SCENE TRIAL, not final acceptance.** Narrower aged-brass rim over a quiet iron centre. Wired for substantial gameplay panels only; whole-screen acceptance is still the rendered-runtime gate. | `assets/ui/gothic/generated/gameplay_panel_luna_v5.png` | `c22c43809aaa9c3b48d755496d9f0f39dacedac759eddcd8d18dd485e1cde7d5` |
| Crimson action v2 | Unchanged from the earlier approved recovery. | `assets/ui/gothic/generated/gameplay_commit_luna_v2.png` | `22e0ea0d9533dd283f2773e3405530817beaa69b8b5ec1e05c7530dc7211d279` |

`GAMEPLAY_PANEL_SURFACE_TRIAL_V5` names the trial, `GAMEPLAY_PANEL_SURFACE_REJECTED_V2` names the rejected file, and `gameplay_material_status()` reports both plus the band and span rules.

| Surface | Shipping path | Source size | Nine-slice band | Content insets L/T/R/B |
| --- | --- | --- | --- | --- |
| Recessed panel (trial v5) | `assets/ui/gothic/generated/gameplay_panel_luna_v5.png` | 320x320 | 40px | 8/6/8/6 |
| Crimson action | `assets/ui/gothic/generated/gameplay_commit_luna_v2.png` | 256x144 | 24px | 12/4/12/4 |

Only substantial outer gameplay panels opt into the 40px panel surface, and only while the surface they are drawing into is at least 80px on both axes (`GAMEPLAY_PANEL_MIN_SPAN`, enforced by `gameplay_panel_style_for()` and re-checked on resize). Thin headers, summary strips, row backgrounds and secondary buttons use the matching quiet flat material, so a 40px band can never be squeezed onto a button or a strip. The action material is reserved for the primary commit button. These helpers do not replace the title/menu's existing plate family.

## V5 Material And Recovery

- Raw artwork: built-in Native ImageGen, by the Luna asset workers. ComfyUI performed deterministic scaling and alpha recovery only; it did not generate or repaint the material.
- Draft 01 (`raw_imagegen_draft.png`, 1254x1254, sha256 `4cdaeea2a8ecc6128316ddf0fe2c0b5ce1452d55857428ef91728afc03dae1bc`) was **rejected**: its grain elongated into visible directional bands under the nine-slice stretch diagnostics.
- Draft 02 (`raw_imagegen_draft_02.png`, 1254x1254, sha256 `2d4c48fbd821376f996cd5cc5b5385b444b2c52c18bfce6573ee2a4cadbb8d90`) was selected and recovered.
- Recovery: ComfyUI endpoint `http://127.0.0.1:8002`, five-node deterministic graph in `panel_recovery.api.json` (`LoadImage` -> Lanczos `ImageScale` to 320x320 -> `LoadImage` of the shape/alpha authority -> `JoinImageWithAlpha` -> `SaveImage`); prompt id `71875bc1-4983-46ee-9964-02cb507408fb`; 2.6s; peak 43 C / 2248 MiB; no diffusion model loaded; the lab prompt-node gate passed.
- Shape and alpha authority: `assets/ui/gothic/panel_plate_traits.png`, 320x320, sha256 `376d0530a6a138519181c54e1a68710da3be0575f8ef042edb40e0a47b7209b3`. The recovered candidate's alpha is identical to it with extrema 255/255, i.e. a fully opaque rectangular surface with no transparent panel-corner claim.
- Nine-slice previews at the two audited shapes (`preview_nineslice_308x550.png`, `preview_nineslice_940x270.png`) show fine low-contrast centre grain with no visible streak bands (centre mean ~21.6/21.0/19.3, centre stddev ~3.1-3.3).

## Arena Floor Onset: Luna V6 Trial

Status: **root-approved FULL-SCENE TRIAL, not final acceptance.** Only the combat
onset battlefield raster changed; the planning/combat shared-surface switching and
the `try_load_texture` fallback are untouched.

| Surface | Status | Shipping path | SHA-256 |
| --- | --- | --- | --- |
| Combat onset floor v6 | Trial: quieter open arena floor over the existing firelit plate, delivered by a masked composite. | `assets/ui/gothic/generated/arena_firelit_luna_v6.png` | `891a112f53bcdb4ce586f6889201863d44f825ca41e52810d5c9030a234fd9ec` |

Wiring: `GothicUIAssets.BATTLEFIELD_SURFACE_ONSET` is the only code change. The
combat shell keeps its existing onset/midfight/reduced-motion phase behaviour.

- Source: `outputs/art_pipeline/composition_v6_luna_floor/arena_firelit_v1_source.png`, 1672x941 RGB, SHA-256 `89936ee87aaf49e28a742a47457e60860ca02e80ff4e68b435dd2de5a536e7d2` - byte-identical to the previously shipping `arena_firelit_v1.png`, independently re-verified by the root.
- Raw artwork: built-in **Native ImageGen by the Luna asset worker** (`raw_imagegen_arena_edit.png`, SHA-256 `b561c2e63a6304a715dc42cc8c69a100d129c3e974c79999b7c10e9910e91c48`; original generation path and prompt recorded in `PROVENANCE.md`). The v2 recovery reused that edit and generated no new artwork.
- Comfy recovery 2: ComfyUI 0.32.0, graph `arena_floor_v2_recovery.api.json`, prompt `467a24c5-107d-460e-9c38-25d1ab2355d3`, 5.61s, peak 2369 MiB / 40 C. Operation: Lanczos resize of the raw edit to 1672x941, then `ImageCompositeMasked` over the original at (0,0). Mask builder `build_floor_mask_v2.py`; one continuous open-floor footprint with a 28px Gaussian feather and no internal cuts (`arena_floor_v2_mask_rgba.png`).
- Machine audit `audit_v2.json`: 0 changed pixels outside the zero-coverage mask, mean absolute channel delta 0.0 outside it, i.e. every untouched source pixel is exact. The first draft's internal seam grid is gone.
- Documented visual caveat, carried from the provenance: the outer feather contour stays faintly readable where the calmer generated stone meets the untouched, more detailed perimeter stone, most noticeably near the side edges. No further recovery is included; whole-screen acceptance remains the rendered-runtime gate.

## Primary Action Emblem: Luna V1 Trial

Status: **root-approved IN-GAME TRIAL of the emblem candidate only, not final shipping acceptance.** The asset is registered and can be served by `GothicUIAssets.primary_action_emblem()`, but it is **not yet wired into any Button**; the action bay takes it once its geometry is stable. No behaviour, `combat_view`, theme or rail change accompanies it.

| Emblem | Status | Shipping path | SHA-256 |
| --- | --- | --- | --- |
| Crossed-swords v1 | Trial: registered for the geometry pass, not attached to a Button yet. | `assets/ui/gothic/generated/crossed_swords_emblem_luna_v1.png` | `5771bd0e733a3fa21fbf9846b72581dc5138ed1c17003ca2361431e2048b2a89` |

Bounded display: the candidate is a 128x128 canvas with the mark inset inside it, so `primary_action_emblem()` is the existing `sheet_icon` route with a single cell - `sheet_icon(PRIMARY_ACTION_EMBLEM, 1, 0, PRIMARY_ACTION_EMBLEM_PIXELS)` - which loads once, Lanczos-resizes to 56 square, and caches the result in `static var _primary_action_emblem`, returning a plain `null` while the file is absent. Only that bounded texture is ever handed over, because a 128px intrinsic size becomes the Button's own minimum size; 56 logical draws a ~43px visible crest at 100% UI (56 x 98/128 = 42.9). The generated icon sheets and every other icon are unchanged.

- Recovered candidate, verified in this pass: **128x128 RGBA8**, straight (non-premultiplied) alpha, alpha extrema 0/255, transparent corners, alpha bounds x 14..111 / y 13..109 (a 98x97 mark), safe insets L14 T13 R16 B18. Machine audit: `outputs/art_pipeline/primary_action_emblem_v1/alpha_audit.json`.
- Raw artwork: built-in **Native ImageGen**, one generation, `crossed_swords_imagegen_raw.png` (1254x1254 RGBA, SHA-256 `c6aace90cee6c852a198b299834e402b74178310e8829049709aea7cf82de668`); the original generated file path and the prompt are recorded in that folder's `PROVENANCE.md`.
- Preparation: `prepare_emblem.py` crops to the alpha bounds, Lanczos-resizes with premultiplied alpha to fit within 112x112, and centres it on transparent 128x128 (`crossed_swords_prepared_128.png`, SHA-256 `38fefb64c8a6341b954e7eba59201b64a406a04870e0a82e42feccfa94bd25ba`).
- Alpha recovery: ComfyUI `LoadImage -> JoinImageWithAlpha -> SaveImage` at `http://127.0.0.1:8002`, prompt `d5b14067-bd54-47c5-b16d-fd6848bff80c`, 5.25s, no diffusion model loaded, no segmentation and no repainting; the final alpha differs from the prepared alpha by at most 1/255 with zero binary mismatches, and 12667 pixels are fully transparent.
- Legibility evidence: the 44px display check `display_check_44px.png` (SHA-256 `83ee9e16cb69385310451c90e10816975e185c582ba528eb02a969c9021401e0`) keeps the X silhouette readable, with a 37x37 mark inside that check.
- The shipping copy is byte-identical to the audited candidate (same SHA-256, 14726 bytes). Godot generates the import sidecar; it is not manually authored, and the helper loads through `TextureUtils` so it works before and after that import.

## Generation And Recovery

- Raw artwork: built-in Native ImageGen, by the Luna workers. ComfyUI did not generate the artwork.
- Recovery: ComfyUI 8002, deterministic `LoadImage`, `ImageScale`, `JoinImageWithAlpha`, `SaveImage`; no diffusion model used.
- The installed `LoadImage` mask output and `JoinImageWithAlpha` input conventions were checked by the worker. The exact supplied shape mask was retained, not estimated by segmentation.
- Primary action prompt/history ID: `c8e85e76-557a-4824-a59a-06cc5f88284a`, 5.36 seconds.
- Panel prompt/history ID: `2bc0911e-fb24-482f-b12a-f58f60d33855`, 5.39 seconds.
- Both exact graphs passed the lab prompting-node coverage gate and ran through `Invoke-BoundedComfyPrompt.ps1`.

The primary has transparent chamfer corners. All binary mask values match; 421 antialiased edge pixels differ by at most 1/255 from the shape template due to float conversion. The panel intentionally has a fully opaque rectangular surface, matching `assets/ui/gothic/panel_plate_traits.png` exactly; no transparent panel-corner claim is made.

## Evidence

Task-local source, graphs, runner records, output audit and provenance are preserved under `outputs/art_pipeline/composition_v2_comfy_recovery/`. Native raw drafts and original generation provenance for the v2 pass are under `outputs/art_pipeline/composition_v2_luna_material/` and `outputs/art_pipeline/composition_v2_luna_commit/`. The v5 trial's drafts, recovered candidate, previews, machine-readable audit and ComfyUI graph are under `outputs/art_pipeline/composition_v5_luna_material/`. These ignored artifact folders are local evidence, not a claim that raw drafts are published with the repository.

SHA-256 of the files on disk (verified in this pass against the recovery audits):

- Panel v5 (trial, wired): `c22c43809aaa9c3b48d755496d9f0f39dacedac759eddcd8d18dd485e1cde7d5`
- Panel v2 (rejected, retained): `83e599782a50c53d876dd14f54b18980ff7b91e1d5717742e372883f37f71e78`
- Action v2 (unchanged): `22e0ea0d9533dd283f2773e3405530817beaa69b8b5ec1e05c7530dc7211d279`
- Shape/alpha authority: `376d0530a6a138519181c54e1a68710da3be0575f8ef042edb40e0a47b7209b3`
- Primary action emblem v1 (trial, registered not wired): `5771bd0e733a3fa21fbf9846b72581dc5138ed1c17003ca2361431e2048b2a89`

Root inspected the recovered files before each copy and checked the shipping hashes against the recovery audits. The v5 copy is byte-identical to the audited candidate. Godot generates import sidecars; they are not manually authored.
