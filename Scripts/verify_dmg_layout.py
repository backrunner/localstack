#!/usr/bin/env python3
"""Verify the saved Finder layout on a mounted, read-only dmgbuild image."""
from pathlib import Path
import runpy
import sys

from ds_store import DSStore


def require(condition, message):
    if not condition:
        raise SystemExit(message)


mount = Path(sys.argv[1])
settings = runpy.run_path('Scripts/dmg_settings.py', init_globals={'defines': {}})
background = Path(settings['background'])
bundled_background = mount / ('.background' + background.suffix)
require(bundled_background.read_bytes() == background.read_bytes(), 'DMG background differs from the configured image.')
with DSStore.open(str(mount / '.DS_Store'), 'r') as store:
    require(store['.']['icvl'] == (b'type', b'icnv'), 'DMG must open in icon view.')
    window = store['.']['bwsp']
    icons = store['.']['icvp']
    (x, y), (width, height) = settings['window_rect']
    require(window['WindowBounds'] == f'{{{{{x}, {y}}}, {{{width}, {height}}}}}', 'Incorrect DMG window bounds.')
    for key in ('ShowStatusBar', 'ShowToolbar', 'ShowPathbar', 'ShowSidebar', 'ShowTabView'):
        require(not window[key], f'{key} must be disabled.')
    require(icons['backgroundType'] == 2, 'DMG must use a picture background.')
    require(bundled_background.name.encode() in icons['backgroundImageAlias'], 'Background alias does not reference the bundled image.')
    require(icons['iconSize'] == settings['icon_size'], 'Incorrect DMG icon size.')
    require(icons['textSize'] == settings['text_size'], 'Incorrect DMG label size.')
    require(icons['arrangeBy'] == 'none', 'DMG icons must keep their saved positions.')
    for name, position in settings['icon_locations'].items():
        require(store[name]['Iloc'] == position, f'Incorrect position for {name}.')
print('Verified saved Finder background, window settings, and icon positions.')
