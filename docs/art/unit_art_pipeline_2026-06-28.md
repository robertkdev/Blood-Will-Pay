# Unit Art Pipeline - 2026-06-28

> Mara naming note (2026-07-28): Mara is the current unit name. Any lower-case `cashmere` filename or path is preserved solely as legacy artifact provenance; its image is not approved as current Mara art.

## Current roster image findings

- All 22 playable unit textures in `assets/units/` are 1024 x 1024 PNGs.
- The game displays the full texture in unit slots, so transparent padding and baked backgrounds directly affect board readability.
- Most units are transparent cutouts. `assets/units/morrak.png` is the main technical outlier because it has a baked square background.
- Narrow units including Mara, Kythera, Korath, Totem, and Veyra read smaller in 96 px board tiles than the wider roster members.
- Active filenames still include odd generated names: `assets/units/korath (1).png` and `assets/units/sari (3).png`.
- Temporary analysis sheets from the first pass were written under `%LOCALAPPDATA%\Temp\gamble_battle_unit_image_analysis\`.

## Local generation setup

- ComfyUI Desktop is installed at `C:\Users\Flipm\AppData\Local\Programs\ComfyUI`.
- The restored runtime folder is `C:\Users\Flipm\Documents\ComfyUI`.
- API server command uses port `8188` to avoid the Godot AI MCP port:
  - `C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe`
  - `C:\Users\Flipm\AppData\Local\Programs\ComfyUI\resources\ComfyUI\main.py`
  - `--base-directory C:\Users\Flipm\Documents\ComfyUI`
  - `--front-end-root C:\Users\Flipm\AppData\Local\Programs\ComfyUI\resources\ComfyUI\web_custom_versions\desktop_app`
  - `--listen 127.0.0.1 --port 8188 --lowvram --reserve-vram 1.0`
- The desktop-pinned CUDA 12.9 Torch wheel did not support the GTX 1080 Ti (`sm_61`). The working install uses `torch==2.8.0+cu126`, `torchvision==0.23.0+cu126`, and `torchaudio==2.8.0+cu126`.
- `stabilityai/sdxl-turbo` is linked into `C:\Users\Flipm\Documents\ComfyUI\models\diffusers\sdxl-turbo`.

## Repeatable commands

Start ComfyUI headless:

```powershell
$base='C:\Users\Flipm\Documents\ComfyUI'
$py="$base\.venv\Scripts\python.exe"
$main='C:\Users\Flipm\AppData\Local\Programs\ComfyUI\resources\ComfyUI\main.py'
$front='C:\Users\Flipm\AppData\Local\Programs\ComfyUI\resources\ComfyUI\web_custom_versions\desktop_app'
$extra='C:\Users\Flipm\AppData\Roaming\ComfyUI\extra_models_config.yaml'
& $py $main --base-directory $base --user-directory "$base\user" --input-directory "$base\input" --output-directory "$base\output" --extra-model-paths-config $extra --front-end-root $front --listen 127.0.0.1 --port 8188 --lowvram --reserve-vram 1.0 --disable-auto-launch --log-stdout
```

Submit a unit-art prompt:

```powershell
.\tools\art\comfy_unit_prompt.ps1 -FilenamePrefix gamble_battle_unit_art_test -Seed 2606281010
```

Post-process a green-screen output into a 1024 x 1024 transparent unit texture:

```powershell
C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe .\tools\art\postprocess_unit_sprite.py C:\Users\Flipm\Documents\ComfyUI\output\gamble_battle_unit_art_solo_muted_00001_.png outputs\art_pipeline\gamble_battle_unit_art_solo_muted_clean.png --preview outputs\art_pipeline\gamble_battle_unit_art_solo_muted_clean_preview.png --min-alpha-island-area 1600 --solid-keep-radius 28 --solid-alpha-threshold 176
```

AI-remove a generated unit background with BiRefNet:

```powershell
C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe .\tools\art\remove_unit_background_birefnet.py --input outputs\art_pipeline\openai_new_unit_concepts\vellum_contract_witch\vellum_contract_witch_raw.png --output outputs\art_pipeline\ai_background_removal\vellum\vellum_birefnet_defringe_cutout.png --mask-output outputs\art_pipeline\ai_background_removal\vellum\vellum_birefnet_defringe_mask.png --review-output outputs\art_pipeline\ai_background_removal\vellum\vellum_birefnet_defringe_review.png --device cuda --input-size 1024 --feather 0.6 --defringe-orange
```

Refined second-stage cleanup for orange-backed premium art:

```powershell
C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe .\tools\art\remove_unit_background_birefnet.py --input outputs\art_pipeline\openai_new_unit_concepts\vellum_contract_witch\vellum_contract_witch_raw.png --output outputs\art_pipeline\ai_background_removal\vellum_refine\vellum_birefnet_foregroundml_despill_cutout.png --mask-output outputs\art_pipeline\ai_background_removal\vellum_refine\vellum_birefnet_foregroundml_despill_mask.png --review-output outputs\art_pipeline\ai_background_removal\vellum_refine\vellum_birefnet_foregroundml_despill_review.png --device cuda --input-size 1024 --feather 0.6 --defringe-orange --foreground-ml --despill-orange --edge-orange-clean
```

## Verified proof

- ComfyUI API responded at `http://127.0.0.1:8188/system_stats`.
- Test prompt id: `f1f9d573-60d5-4cd3-9ac3-9c4bf327dd58`.
- ComfyUI output: `C:\Users\Flipm\Documents\ComfyUI\output\gamble_battle_unit_art_test_00001_.png`.
- Runtime log reported `Prompt executed in 39.57 seconds`.
- Accepted usable local proof:
  - Raw ComfyUI output: `C:\Users\Flipm\Documents\ComfyUI\output\gamble_battle_unit_art_solo_muted_00001_.png`.
  - Transparent 1024 px texture: `outputs/art_pipeline/gamble_battle_unit_art_solo_muted_clean.png`.
  - Tile readability preview: `outputs/art_pipeline/gamble_battle_unit_art_solo_muted_clean_preview.png`.

## Background removal bakeoff - 2026-06-29

- Pure orange/chroma keying is no longer the preferred final-alpha path. It can preserve a silhouette on simple units, but it is too fragile for premium unit art with hands, parchment strips, ink tendrils, hair, mummy ribbons, bubbles, and glow interiors.
- `ZhengPeng7/BiRefNet` is the current default AI segmentation model for generated unit art. It worked on Vellum's complex contract-paper silhouette and Kythera's mummy-ribbon silhouette, preserving the main body and most detached/near-detached magic strips better than color keying alone.
- The repeatable tracked tool is `tools/art/remove_unit_background_birefnet.py`. Use the Comfy venv Python because it has CUDA PyTorch on the GTX 1080 Ti. `timm` was added to that venv for BiRefNet; cached CUDA runs were about 15 seconds after model load/cache.
- Initial proof command options were `--device cuda --input-size 1024 --feather 0.6 --defringe-orange`. After the refined despill and edge-clean tests below, use `--foreground-ml --despill-orange --edge-orange-clean` as well for orange-backed premium art, then run the orange-fringe audit. The AI mask owns the silhouette; defringe/despill/edge-clean only clean edge/background contamination.
- BRIA RMBG-2.0 could not be tested locally because Hugging Face returned gated-repo access without an authenticated accepted-license token. BRIA RMBG-1.4 did run, but it left a large orange haze on Vellum and is not acceptable for this unit-art problem.
- Current proof outputs:
  - Vellum comparison: `outputs/art_pipeline/ai_background_removal/vellum/vellum_alpha_methods_direct_comparison_v2.png`.
  - Vellum selected AI cutout: `outputs/art_pipeline/ai_background_removal/vellum/vellum_tracked_tool_birefnet_defringe_cutout.png`.
  - Vellum review sheet: `outputs/art_pipeline/ai_background_removal/vellum/vellum_tracked_tool_birefnet_defringe_review.png`.
  - Kythera AI review sheet: `outputs/art_pipeline/ai_background_removal/kythera/kythera_openai_birefnet_defringe_review.png`.
- Production rule: keep the raw orange-background image as the highest-quality source, run BiRefNet for the body/effect matte, inspect on checker/black/white previews, then do manual or masked repair only for remaining edge cases. Do not replace `assets/units/*.png` until the AI matte passes visual QC.

## Refined despill test - 2026-06-29

- Research finding: defringe is not the best final second step by itself. BiRefNet and its matting variants produce the alpha/silhouette, but the remaining orange around hair and weapon edges is foreground-color contamination baked into RGB pixels. The stronger second step is foreground color estimation plus targeted spill cleanup.
- Tested `ZhengPeng7/BiRefNet-matting` and `ZhengPeng7/BiRefNet_HR-matting` on Vellum. Both ran successfully, but neither solved the orange hair/weapon contamination by itself. The best overall balance was the base `ZhengPeng7/BiRefNet` mask plus PyMatting foreground estimation and focused key-orange despill.
- `tools/art/remove_unit_background_birefnet.py` now supports `--foreground-ml`, `--despill-orange`, and `--edge-orange-clean`. `--foreground-ml` uses PyMatting `estimate_foreground_ml` to estimate foreground RGB from the alpha matte. `--despill-orange` targets orange-key-like spill near transparent/soft matte regions, and `--edge-orange-clean` catches remaining safety-orange-like residue in the alpha edge band instead of deleting real parchment/wax details.
- Current selected Vellum output: `outputs/art_pipeline/ai_background_removal/vellum_refine/vellum_birefnet_foregroundml_despill_cutout.png`, with review sheet `outputs/art_pipeline/ai_background_removal/vellum_refine/vellum_birefnet_foregroundml_despill_review.png`.
- Closeup comparison outputs: `outputs/art_pipeline/ai_background_removal/vellum_refine/vellum_final_despill_compare_hair_top_edge.png`, `vellum_final_despill_compare_weapon_edge.png`, and `vellum_final_despill_compare_right_scroll_edge.png`.
- Cross-check: the same refined command ran on Kythera and produced `outputs/art_pipeline/ai_background_removal/kythera_refine/kythera_birefnet_foregroundml_despill_review.png` without damaging the mummy-ribbon silhouette.

## Edge-clean audit - 2026-07-01

- The perfected cutout process is now BiRefNet alpha + foreground ML + focused orange despill + final `--edge-orange-clean`, followed by `tools/art/audit_unit_cutout_orange_fringe.py`.
- The final clean is deliberately narrow: it targets safety-orange-like residue only in the alpha edge band or soft-alpha matte after the matte and foreground RGB are already established. It should not be used as a broad chroma key, alpha eroder, or silhouette rescue.
- Perfect-exit cleanup is strict-zero: rerun `tools/art/audit_unit_cutout_orange_fringe.py --strict-zero` after cleaning and require `edge_orange_pixels == 0` and `soft_orange_pixels == 0`. The cleaner stats JSON must prove alpha was unchanged, no pixels outside the safety-orange target changed, opaque interior pixels were untouched, and no edge/soft-alpha orange residue remains.
- The fast audit output is `docs/art/unit_art_cutout_orange_fringe_audit_2026-07-01.md` plus `outputs/art_pipeline/style_validation/cutout_orange_fringe_audit_2026_07_01/unit_art_cutout_orange_fringe_review_sheet.png`.
- Current baseline result after post-clean: Vellum, Paisley, token, accepted technical references, and the edge-cleaned Teller/Korath/Hexeon current-candidate cutouts pass. The only remaining flagged row is the rejected older Creep proof, which stays useful as a negative example.

## Quality notes

- The local SDXL Turbo path is fast enough and works on the 1080 Ti. It is good for concept thumbnails, silhouettes, and quick sprite drafts.
- The first sample matched the dark gothic/autobattler direction but leaned too neon and line-art heavy compared with the current roster.
- For final-quality character edits, the best current target remains a stronger edit model such as Qwen-Image-Edit-2509 or FLUX.1 Kontext, ideally in a quantized Comfy workflow for this GPU. The restored Comfy runtime is now ready for that next model pass, but the available local cache did not contain the Qwen weights.
