# AFTERHOURS

A first-person psychological horror game for Windows, built with Godot 4.3.

## Story
Northstar Mall closed eight years ago. Night guard Elias Venn was recorded leaving at 6:00 AM, but the security cameras show him entering a sealed cinema at 3:17 AM. Tonight, you have been hired to catalogue the remaining records before demolition. Your name is already written in the shift book.

## Run
Open the repository in Godot 4.3 or newer. Run `bash tools/download_assets.sh` once before opening the project to fetch the CC0 retail shopfloor model, then press F6/F5. The Windows workflow downloads the same asset automatically.

## Controls
WASD move · Mouse look · Shift sprint · Ctrl crouch · E interact · F flashlight · Tab objectives · Esc pause. The flashlight drains while active and recharges while switched off.

## Windows build
Push to main or run the Windows Build workflow manually. The exported Windows application is published as the AFTERHOURS-Windows Actions artifact. Version tags beginning with v also publish a GitHub Release.

## Graphics and performance
The game uses a real imported 3D retail shopfloor scene, a moving cinematic title camera, an articulated animated pursuer, reduced dynamic lighting, and the Godot Mobile renderer with a lower 3D render scale. The retail shopfloor model is CC0 1.0 from 3DAssets.dev: https://3dassets.dev/packs/retail-store-fixtures-and-mall

## Current build
This is an active development build. The imported shop model improves one storefront; other parts of the mall are still built from in-engine geometry and will need further art passes.
