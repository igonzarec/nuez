# Batch model to GLB converter

Run `scripts/Convert-ModelsToGlb.ps1` on Windows with either Windows PowerShell
5.1 or PowerShell 7. The script needs Blender, but does not need Godot running.

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\scripts\Convert-ModelsToGlb.ps1"
pwsh.exe -NoProfile -STA -File ".\scripts\Convert-ModelsToGlb.ps1"
```

Use `-BlenderPath "C:\path with spaces\blender.exe"` for a portable/custom
installation. Detection checks PATH and standard Blender Foundation install
folders; Browse always lets you select another executable. A non-STA launch
restarts the same PowerShell executable in STA mode for Windows dialogs.
`-ValidateOnly` constructs and disposes the UI without displaying it.

## Workflow and controls

1. Use **Add files** for individual FBX/BLEND files, or **Add folder** to scan a
   folder. **Include subfolders** affects scanning when the folder is added;
   change it and re-add the folder to rescan. Duplicate inputs are ignored.
2. Choose an output folder. **Preserve folder structure** keeps each path relative
   to its added folder. Individually added files use their containing directory
   as their root. Example: adding `Assets` exports `Assets/Trees/Oak.fbx` as
   `Output/Trees/Oak.glb`.
3. Click **Convert**. Each source gets a separate background Blender process and
   GLB. The window remains responsive; editing and closing are blocked during a
   batch. Failures are logged and the next source continues.

Overwrite defaults to **OFF**. Enable it explicitly to replace old outputs after
a successful conversion. Temporary output is created beside the destination,
validated, then moved/replaced; failed exports leave old GLBs intact. Files that
map to the same destination within one batch get a suffix such as `_fbx` or
`_fbx-2`, even when overwrite is enabled. This can occur with matching FBX/BLEND
names, multiple folder roots, or flattened output.

## Static assets and materials

Defaults: apply rotation and scale, bake parent/world transforms, skip objects
hidden from rendering, and preserve subfolders. Apply location defaults to OFF.
The options are in **Godot / export options**, with hover help on each control.

The converter freezes evaluated mesh geometry at the source's current frame,
including modifiers and armature deformation. It exports static meshes, without
animation, skins, shape keys, cameras or lights. It does not change source files.
The default world bake preserves parent shear and mirrored transforms in mesh
vertices; GLB uses the exporter's standard Y-up conversion for Godot 4.6.
This is a static-asset converter, not an animated-character pipeline. Collection
instances and non-mesh procedural objects are not realized automatically.

FBX imports start from an empty scene; BLEND files load their saved active scene
without loading their UI or automatically executing embedded scripts. Assets
depending on scripted drivers can therefore differ from their interactive view.
Viewport-only hiding is ignored; render-hidden meshes/collection branches are
excluded when **Skip meshes hidden from render** is enabled.

Normal export retains material graphs and UVs for Blender's glTF exporter and
embeds supported texture images in GLB. Missing external textures are reported
in the UI/session log. Blender-specific shaders are subject to glTF material
limitations; this tool does not bake arbitrary procedural shader graphs.
**Legacy flat-color material repair is OFF by default**: enabling it deliberately
replaces used material graphs with flat Principled colors in the exported copy.

## Diagnostics and validation

Startup and button-handler exceptions display an error dialog with a log path.
Complete commands and Blender stdout/stderr go to a unique session log in
`%LOCALAPPDATA%\ModelToGlbConverter\Logs`, with a temporary-folder fallback if
that location is unwritable. The GUI shows the actual path. Failed sources and
their details also appear in the UI log and `conversion-errors-*.txt` under the
output folder. The completion dialog reports counts and log locations.

Keep the PowerShell file encoded as **UTF-8 with BOM**. Windows PowerShell 5.1
otherwise interprets Unicode punctuation using the system ANSI code page.
The generated Blender Python file uses UTF-8 without BOM.

The original launch failure had two independent parser causes: an interpolated
`$count:` needed `${count}:`, and UTF-8 without BOM made Windows PowerShell 5.1
misread Unicode punctuation, including the em dash in the completion message.
Neither error could reach the original UI error handler because parsing failed
before script execution.

Validated locally with Windows PowerShell 5.1.26100.2161, PowerShell 7.6.5 and
Blender 5.2.2: both parsers and UI construction passed; real batch handlers
converted textured FBX/BLEND fixtures with spaces/Unicode in nested paths,
continued after corrupt inputs, resolved matching output names, skipped existing
files, replaced successful exports and preserved old output after failed exports.
Reimported GLBs retained embedded textures/materials and world vertex positions
within 0.000002 Blender units, with no cameras, lights, skins or animations.
MTA-to-STA restart also passed. These checks used disposable fixtures outside the
project, without adding a permanent test suite. Other Blender versions and the
full variety of third-party material graphs were not exercised.

Blender references: [command-line options](https://docs.blender.org/manual/en/5.1/advanced/command_line/arguments.html)
and [glTF export API](https://docs.blender.org/api/5.0/bpy.ops.export_scene.html).
