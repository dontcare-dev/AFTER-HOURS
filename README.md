# AFTERHOURS

A first-person psychological horror game for Windows, built with Godot 4.3.

## Story
Northstar Mall closed eight years ago. Night guard Elias Venn was recorded leaving at 6:00 AM, but the security cameras show him entering a sealed cinema at 3:17 AM. Tonight, you have been hired to catalogue the remaining records before demolition. Your name is already written in the shift book.

## Run
Open the repository in Godot 4.3 or newer. Run `bash tools/download_assets.sh` once before opening the project to fetch the CC0 3D mall assets, then press F6/F5. The Windows workflow downloads and converts the same assets automatically.

## Controls
WASD move · Mouse look · Shift sprint · Ctrl crouch · E interact · F flashlight · Tab objectives · Esc pause. The flashlight drains while active and recharges while switched off.

## Windows build
Push to main or run the Windows Build workflow manually. The exported Windows application is published as the AFTERHOURS-Windows Actions artifact. Version tags beginning with v also publish a GitHub Release.

## Graphics and performance
The scene now uses imported 3D retail fixtures, a detailed escalator, mall columns, planter benches and litter props, plus a moving cinematic title camera and an articulated animated pursuer. The project uses Godot's Mobile renderer, reduced 3D render scale, fewer dynamic lights, no real-time global illumination, and a CCTV viewport that only renders while open. Imported models are CC0 1.0 from 3DAssets.dev's Retail Store Fixtures and Mall pack: https://3dassets.dev/packs/retail-store-fixtures-and-mall

## Current build
This is an active development build. The imported models replace several major blockout props, while the main architectural shell and some secondary objects are still built in-engine and need further art passes.
