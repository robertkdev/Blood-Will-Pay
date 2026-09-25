# Agent art preview

Machine interface: `python -B addons/art_preview/preview.py <operation>`.
The fullscreen viewport contains only production game components. No tool panel.

```powershell
python -B addons/art_preview/preview.py prepare --reference '<absolute approved reference>' --output '<new directory>'
python -B addons/art_preview/preview.py launch --godot '<pinned Godot 4.5 executable>'
python -B addons/art_preview/preview.py run
python -B addons/art_preview/preview.py describe
python -B addons/art_preview/preview.py apply --expected-revision 1 --settings '{"spacing":1.1,"typography":1.05,"background":0.8,"surface_opacity":0.6,"border":1.5}'
python -B addons/art_preview/preview.py geometry --node-type TextureRect --fields rect,visible_rect,scale,texture --limit 20
python -B addons/art_preview/preview.py capture
vdh run art-preview --config visual-harness.yaml --repair-loop
python -B addons/art_preview/preview.py stop
```

For BWP, `launch` requires `--launcher '<existing restricted godot-safe-launcher.py>'`.
Keep its process alive until the owned editor closes. Require
`Tools/Test-GodotEditorHydration.ps1 -ProjectPath '<checkout>' -AsJson` to return
`ready: true` before `run`. Runtime launch and stop use Godot-AI MCP; the endpoint
can be supplied with `--url`. Selection requires both project path and editor PID.
Private APPDATA isolates saves. Each restart archives only the fixture saves.

`describe` returns live control JSON Schema, defaults and current values. The
portrait control differs by adapter; discover its name/range instead of guessing.
`apply` validates the entire batch and returns only after that exact revision has
rendered. It returns raw actual/reference images, their comparison, settings,
geometry and provenance paths. No-op edits retain the revision; invalid edits
change nothing. Concurrent writers and superseded revisions fail explicitly.
`capture` forces a new frame. `command reference --path '<absolute image>'`
replaces the reference and returns the new pair. `geometry` is paginated, filtered
and clipped to the viewport by default; use `--include-offscreen` when needed.

The art-preview scenario requires a reference/actual pair. Evidence checks the
session, editor/process identities, fullscreen mode, native 1920x1080 dimensions,
advancing frames, the pinned reference identity, loaded code/art/font hashes and current settings revision.
Changed loaded resources require a restarted preview. Historical geometry remains available through `geometry --capture-id <id>` without claiming current-source validity. Capture validity never constitutes
an aesthetic pass. Review the raw pair and record remaining composition gaps.
Settings affect preview instances; carry accepted values into production source
and verify the shipping screen separately. `preset.json` is reusable via
`prepare --preset '<file>'`.

Adapters implement `mount(host)`, `scene_path()`, `default_reference()`,
`controls(screen)` and `apply(screen, values)` against the actual production scene.
