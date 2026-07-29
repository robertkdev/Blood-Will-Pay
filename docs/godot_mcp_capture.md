# Godot MCP Runtime Capture

Use `tools/Capture-GodotMcp.ps1` when Windows Graphics Capture or desktop
automation cannot see the Godot editor/game window. The helper talks to the
running `godot-ai` MCP server, selects the editor session by project path,
waits for the game helper handshake, requests `editor_screenshot`, and saves
the first visually nonblank PNG with a SHA-256 evidence record. Black startup
frames are rejected and retried instead of being accepted as visual proof.

This avoids the long-running Windows capture failure:

```text
SetIsBorderRequired failed: No such interface supported (0x80004002)
```

## Prerequisites

- Launch the project editor through Godot MCP.
- Leave the `godot-ai` server running on its configured port (default `8000`).
- Do not start a second capture writer against the same output path.
- Allow the editor-managed server a few seconds to start after launching the
  editor. The helper retries transient MCP connection failures three times.

The PowerShell wrapper discovers the Python environment belonging to the
running `godot-ai.exe`; it does not install or update dependencies.

## Capture the live game

If the game is already running:

```powershell
.\tools\Capture-GodotMcp.ps1 `
    -OutputPath C:\path\to\evidence\game.png `
    -ProjectPath C:\Users\Flipm\Documents\gamble-battle
```

To run the main scene through MCP and capture it once the game helper is ready:

```powershell
.\tools\Capture-GodotMcp.ps1 `
    -OutputPath C:\path\to\evidence\title.png `
    -ProjectPath C:\Users\Flipm\Documents\gamble-battle `
    -Run main
```

Use `-Source viewport` for the editor viewport. Use `-Run custom -Scene
res://path/to/Scene.tscn` for a specific scene. `-MaxResolution 0` preserves
the full source resolution. `-WaitSeconds` controls the game-helper readiness
window; `-VisualWaitSeconds` separately controls how long the helper polls past
blank startup frames. A capture fails closed if no visible frame arrives.

The helper never stops or restarts Godot. When a game is already live,
`-Run main` captures that live game instead of relaunching it.
