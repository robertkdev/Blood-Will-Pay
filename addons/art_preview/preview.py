"""Compatibility entry point; implementation belongs to visual-debug-harness."""
from pathlib import Path
import sys
from visual_debug_harness.godot_art.cli import main

if __name__ == "__main__":
    main(["--project", str(Path(__file__).resolve().parents[2]), *sys.argv[1:]])
