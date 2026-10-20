"""Resolve the maintained game-specific checks after the 0.59 filename change."""
import json
from pathlib import Path


def migrated_game_tests(repo: Path) -> set[str]:
    record = json.loads((repo / 'tools/script_renames_v059.json').read_text('utf-8'))
    return {Path(row['new']).stem for row in record['files']
            if row['new'].startswith('tests/runtime/')}
