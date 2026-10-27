#requires -version 5.1
<#
.SYNOPSIS
    Batch-converts Blender (.blend) and FBX (.fbx) models to Godot-friendly GLB.

.DESCRIPTION
    A reusable WinForms front-end for Blender. It supports individual files or
    whole folders, optional recursive scanning, destination selection, safe
    per-file conversion, progress reporting, and failure logging.

    The default settings are optimized for static Godot 4 assets such as trees,
    rocks, props, and environment meshes.

.NOTES
    Run with:
      powershell -ExecutionPolicy Bypass -File .\Convert-ModelsToGlb.ps1
      pwsh -STA -File .\Convert-ModelsToGlb.ps1

    Save this file as UTF-8 WITH BOM for Windows PowerShell 5.1.
    -ValidateOnly checks UI construction without opening a window.

    The original source files are never modified.
#>

[CmdletBinding()]
param(
    [string]$BlenderPath = "",
    # Build and validate the UI without showing it (for local startup checks).
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$script:SessionLog = $null
$script:IsConverting = $false

function Write-SessionLog {
    param([string]$Text)
    if ($script:SessionLog) {
        try { [IO.File]::AppendAllText($script:SessionLog, $Text + [Environment]::NewLine, [Text.Encoding]::UTF8) }
        catch { [Console]::Error.WriteLine("Unable to write log: " + $_.Exception.Message) }
    }
}

function Show-ConverterError {
    param([System.Management.Automation.ErrorRecord]$Record)
    $detail = ($Record | Out-String) + [Environment]::NewLine + $Record.ScriptStackTrace
    Write-SessionLog $detail
    [Console]::Error.WriteLine($detail)
    if ($ValidateOnly) { return }
    $message = $Record.Exception.Message
    if ($script:SessionLog) { $message += "`r`n`r`nLog: " + $script:SessionLog }
    try {
        [void][System.Windows.Forms.MessageBox]::Show($message, "Model -> GLB Converter: error", 'OK', 'Error')
    }
    catch {
        # WinForms itself may have failed to load. WScript supplies a native dialog.
        try { $shell = New-Object -ComObject WScript.Shell; [void]$shell.Popup($message, 0, 'Model -> GLB Converter: error', 16) }
        catch { [Console]::Error.WriteLine($message) }
    }
}

trap { Show-ConverterError $_; exit 1 }

# Logs live outside the source/output folders and survive startup failures.
$logRoot = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'ModelToGlbConverter\Logs'
$logName = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N') + '.log'
try {
    [void][IO.Directory]::CreateDirectory($logRoot)
    $script:SessionLog = Join-Path $logRoot $logName
    [IO.File]::WriteAllText($script:SessionLog, '', [Text.Encoding]::UTF8)
}
catch {
    $logRoot = Join-Path ([IO.Path]::GetTempPath()) 'ModelToGlbConverter-Logs'
    [void][IO.Directory]::CreateDirectory($logRoot)
    $script:SessionLog = Join-Path $logRoot $logName
    [IO.File]::WriteAllText($script:SessionLog, '', [Text.Encoding]::UTF8)
}
Write-SessionLog "Starting $PSCommandPath | PowerShell $($PSVersionTable.PSVersion) | $([Threading.Thread]::CurrentThread.ApartmentState)"

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    # Windows CommandLineToArgvW quoting, including backslashes before quotes/end.
    return '"' + ([regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1')) + '"'
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'This GUI requires Windows and WinForms.'
}
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = (Get-Process -Id $PID).Path
    $start.UseShellExecute = $false
    $launchArgs = @('-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    if ($BlenderPath) { $launchArgs += @('-BlenderPath', $BlenderPath) }
    if ($ValidateOnly) { $launchArgs += '-ValidateOnly' }
    $start.Arguments = ($launchArgs | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $child = [Diagnostics.Process]::Start($start)
    $child.WaitForExit()
    $childCode = $child.ExitCode
    $child.Dispose()
    exit $childCode
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::SetUnhandledExceptionMode('ThrowException')
[System.Windows.Forms.Application]::EnableVisualStyles()

# ----------------------------- Helpers -------------------------------------

function Find-BlenderExecutable {
    param([string]$Preferred)

    if ($Preferred) {
        # Keep an explicit override visible, even if invalid, so it can be corrected.
        return $Preferred.Trim().Trim('"')
    }

    $command = Get-Command blender.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }
    $roots = @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:LOCALAPPDATA) |
        Where-Object { $_ } | ForEach-Object { Join-Path $_ 'Blender Foundation' } | Select-Object -Unique

    $candidates = @()
    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root -PathType Container) {
            $candidates += Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName "blender.exe" } |
                Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
        }
    }

    if ($candidates.Count -gt 0) {
        # Prefer the most recently modified install. This avoids hard-coding a Blender version.
        return ($candidates | Sort-Object { (Get-Item -LiteralPath $_).LastWriteTime } -Descending | Select-Object -First 1)
    }

    return ""
}

function Add-LogLine {
    param(
        [System.Windows.Forms.TextBox]$TextBox,
        [string]$Text
    )

    $timestamp = (Get-Date).ToString("HH:mm:ss")
    Write-SessionLog "[$timestamp] $Text"
    $TextBox.AppendText("[$timestamp] $Text`r`n")
    $TextBox.SelectionStart = $TextBox.TextLength
    $TextBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Get-RelativePathCompat {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath)
    if (-not $base.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString())) {
        $base += [System.IO.Path]::DirectorySeparatorChar
    }

    $target = [System.IO.Path]::GetFullPath($TargetPath).TrimEnd('\') + '\'
    $baseUri = New-Object System.Uri($base)
    $targetUri = New-Object System.Uri($target)
    $relativeUri = $baseUri.MakeRelativeUri($targetUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

function Invoke-BlenderWorker {
    param([string]$Executable, [string[]]$Arguments)
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $info.Arguments = ($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [Text.Encoding]::UTF8
    $info.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        Write-SessionLog ("COMMAND: " + $Executable + ' ' + $info.Arguments)
        [void]$process.Start()
        # Drain both pipes concurrently; stderr is data, not a terminating PS 5.1 error.
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        while (-not $process.WaitForExit(100)) { [System.Windows.Forms.Application]::DoEvents() }
        $result = [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.Result + "`r`n" + $stderr.Result }
        Write-SessionLog $result.Output
        return $result
    }
    finally { $process.Dispose() }
}

function New-WorkerScript {
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("model_to_glb_" + [guid]::NewGuid().ToString("N") + ".py")

    $code = @'
import bpy
import sys
from pathlib import Path
from mathutils import Matrix

args = sys.argv[sys.argv.index("--") + 1:]
if len(args) < 8:
    raise RuntimeError("Internal error: converter received too few arguments")

source_path = Path(args[0])
output_path = Path(args[1])
apply_rotation = args[2] == "1"
apply_scale = args[3] == "1"
apply_location = args[4] == "1"
bake_world = args[5] == "1"
visible_only = args[6] == "1"
flat_color_repair = args[7] == "1"

suffix = source_path.suffix.lower()

if suffix == ".blend":
    bpy.ops.wm.open_mainfile(filepath=str(source_path), load_ui=False, use_scripts=False)
elif suffix == ".fbx":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    imported = False
    errors = []

    # Blender has used import_scene.fbx for many releases. Keep a fallback for
    # versions exposing the newer native FBX operator under wm.
    try:
        bpy.ops.import_scene.fbx(filepath=str(source_path))
        imported = True
    except Exception as exc:
        errors.append(f"import_scene.fbx: {exc}")

    if not imported:
        # A failed import can leave partially imported objects behind.
        bpy.ops.wm.read_factory_settings(use_empty=True)
        try:
            bpy.ops.wm.fbx_import(filepath=str(source_path))
            imported = True
        except Exception as exc:
            errors.append(f"wm.fbx_import: {exc}")

    if not imported:
        raise RuntimeError("FBX import failed. " + " | ".join(errors))
else:
    raise RuntimeError(f"Unsupported source type: {suffix}")

# Reveal viewport-only exclusions in this disposable scene; render visibility
# remains the filter. Never save these changes back to the source file.
if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")

def reveal_layer(layer):
    layer.exclude = False
    layer.hide_viewport = False
    layer.collection.hide_viewport = False
    for child in layer.children:
        reveal_layer(child)

reveal_layer(bpy.context.view_layer.layer_collection)

renderable = set()
def collect_renderable(collection, hidden=False):
    hidden = hidden or collection.hide_render
    if not hidden:
        renderable.update(collection.objects)
    for child in collection.children:
        collect_renderable(child, hidden)

collect_renderable(bpy.context.scene.collection)

# Use mesh objects only. This makes static environment assets predictable in
# Godot and avoids exporting cameras/lights bundled with asset packs.
mesh_objects = [
    obj for obj in bpy.context.scene.objects
    if obj.type == "MESH" and (not visible_only or (not obj.hide_render and obj in renderable))
]

if not mesh_objects:
    raise RuntimeError(f"No exportable mesh objects found in {source_path.name}")

# Freeze evaluated geometry at the current frame: modifiers, constraints and
# armature deformation become a static mesh. Material slots/UVs are preserved.
for obj in mesh_objects:
    obj.hide_viewport = False
    obj.hide_select = False
    obj.hide_set(False)
bpy.context.view_layer.update()
depsgraph = bpy.context.evaluated_depsgraph_get()
snapshots = []
for obj in mesh_objects:
    evaluated = obj.evaluated_get(depsgraph)
    mesh = bpy.data.meshes.new_from_object(evaluated, preserve_all_data_layers=True, depsgraph=depsgraph)
    snapshots.append((obj, mesh, evaluated.matrix_world.copy()))

for obj, mesh, world in snapshots:
    obj.modifiers.clear()
    obj.constraints.clear()
    obj.animation_data_clear()
    obj.data = mesh

# For static assets, parent empties imported from FBX can carry scale/rotation.
# Preserve each mesh's world matrix, detach it, then apply transforms locally.
# This is especially useful for Godot/Terrain3D assets.
if bake_world:
    for obj, mesh, world in snapshots:
        obj.parent = None
        obj.matrix_world = world
        if apply_rotation and apply_scale:
            # Bake the full matrix, including shear from rotated/scaled parents.
            # Decomposing it into object TRS would silently lose that shear.
            remaining = Matrix.Identity(4) if apply_location else Matrix.Translation(world.translation)
            baked = remaining.inverted() @ world
            mesh.transform(baked)
            if baked.determinant() < 0:
                mesh.flip_normals()
            mesh.update()
            obj.matrix_world = remaining

bpy.ops.object.select_all(action="DESELECT")
for obj in mesh_objects:
    obj.select_set(True)

bpy.context.view_layer.objects.active = mesh_objects[0]

if (apply_location or apply_rotation or apply_scale) and not (bake_world and apply_rotation and apply_scale):
    bpy.ops.object.transform_apply(
        location=apply_location,
        rotation=apply_rotation,
        scale=apply_scale,
    )

# Optional compatibility mode for old flat-color packs. This intentionally
# discards complex shader graphs/textures, so it is OFF by default.
if flat_color_repair:
    def get_base_color(material):
        if material.use_nodes and material.node_tree:
            for node in material.node_tree.nodes:
                if node.type == "BSDF_PRINCIPLED" and "Base Color" in node.inputs:
                    return tuple(node.inputs["Base Color"].default_value)
        return tuple(material.diffuse_color)

    used_materials = set()
    for obj in mesh_objects:
        for slot in obj.material_slots:
            if slot.material:
                used_materials.add(slot.material)

    for material in used_materials:
        base_color = get_base_color(material)
        material.use_nodes = True
        nodes = material.node_tree.nodes
        links = material.node_tree.links
        nodes.clear()

        output = nodes.new(type="ShaderNodeOutputMaterial")
        shader = nodes.new(type="ShaderNodeBsdfPrincipled")
        shader.inputs["Base Color"].default_value = base_color
        shader.inputs["Roughness"].default_value = 1.0
        links.new(shader.outputs["BSDF"], output.inputs["Surface"])

for image in bpy.data.images:
    if image.source == "FILE" and not image.packed_file:
        resolved = Path(bpy.path.abspath(image.filepath, library=image.library))
        if not resolved.is_file():
            print(f"WARNING: missing texture: {resolved}", flush=True)

output_path.parent.mkdir(parents=True, exist_ok=True)

# Re-select meshes in case an operator changed selection state.
bpy.ops.object.select_all(action="DESELECT")
for obj in mesh_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = mesh_objects[0]

result = bpy.ops.export_scene.gltf(
    filepath=str(output_path),
    export_format="GLB",
    use_selection=True,
    export_materials="EXPORT",
    export_animations=False,
    export_skins=False,
    export_morph=False,
    export_cameras=False,
    export_lights=False,
    export_yup=True,
)
if "FINISHED" not in result or not output_path.is_file():
    raise RuntimeError(f"GLB export did not finish: {result}")

print(f"CONVERTER_OK:{output_path}")
'@

    [IO.File]::WriteAllText($path, $code, (New-Object Text.UTF8Encoding($false)))
    return $path
}

# ----------------------------- UI ------------------------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "Model → GLB Converter"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(820, 700)
$form.MinimumSize = New-Object System.Drawing.Size(820, 700)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(248, 249, 250)

$title = New-Object System.Windows.Forms.Label
$title.Text = "Model → GLB Converter"
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 18)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(18, 14)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "Convert static .blend / .fbx assets to Godot-friendly .glb files (current frame)"
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(21, 49)
$form.Controls.Add($subtitle)

# Blender executable
$lblBlender = New-Object System.Windows.Forms.Label
$lblBlender.Text = "Blender"
$lblBlender.AutoSize = $true
$lblBlender.Location = New-Object System.Drawing.Point(20, 85)
$form.Controls.Add($lblBlender)

$txtBlender = New-Object System.Windows.Forms.TextBox
$txtBlender.Location = New-Object System.Drawing.Point(20, 105)
$txtBlender.Size = New-Object System.Drawing.Size(665, 24)
$txtBlender.Anchor = "Top,Left,Right"
$txtBlender.Text = Find-BlenderExecutable -Preferred $BlenderPath
$form.Controls.Add($txtBlender)

$btnBlender = New-Object System.Windows.Forms.Button
$btnBlender.Text = "Browse…"
$btnBlender.Location = New-Object System.Drawing.Point(695, 103)
$btnBlender.Size = New-Object System.Drawing.Size(90, 28)
$btnBlender.Anchor = "Top,Right"
$form.Controls.Add($btnBlender)

# Sources
$lblSources = New-Object System.Windows.Forms.Label
$lblSources.Text = "Source models"
$lblSources.AutoSize = $true
$lblSources.Location = New-Object System.Drawing.Point(20, 145)
$form.Controls.Add($lblSources)

$listSources = New-Object System.Windows.Forms.ListBox
$listSources.Location = New-Object System.Drawing.Point(20, 166)
$listSources.Size = New-Object System.Drawing.Size(765, 110)
$listSources.Anchor = "Top,Left,Right"
$listSources.HorizontalScrollbar = $true
$form.Controls.Add($listSources)

$btnFiles = New-Object System.Windows.Forms.Button
$btnFiles.Text = "Add files…"
$btnFiles.Location = New-Object System.Drawing.Point(20, 284)
$btnFiles.Size = New-Object System.Drawing.Size(100, 29)
$form.Controls.Add($btnFiles)

$btnFolder = New-Object System.Windows.Forms.Button
$btnFolder.Text = "Add folder…"
$btnFolder.Location = New-Object System.Drawing.Point(128, 284)
$btnFolder.Size = New-Object System.Drawing.Size(105, 29)
$form.Controls.Add($btnFolder)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear"
$btnClear.Location = New-Object System.Drawing.Point(241, 284)
$btnClear.Size = New-Object System.Drawing.Size(75, 29)
$form.Controls.Add($btnClear)

$chkRecursive = New-Object System.Windows.Forms.CheckBox
$chkRecursive.Text = "Include subfolders when adding a folder"
$chkRecursive.Checked = $true
$chkRecursive.AutoSize = $true
$chkRecursive.Location = New-Object System.Drawing.Point(334, 290)
$form.Controls.Add($chkRecursive)

# Output
$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text = "Output folder"
$lblOutput.AutoSize = $true
$lblOutput.Location = New-Object System.Drawing.Point(20, 329)
$form.Controls.Add($lblOutput)

$txtOutput = New-Object System.Windows.Forms.TextBox
$txtOutput.Location = New-Object System.Drawing.Point(20, 349)
$txtOutput.Size = New-Object System.Drawing.Size(665, 24)
$txtOutput.Anchor = "Top,Left,Right"
$form.Controls.Add($txtOutput)

$btnOutput = New-Object System.Windows.Forms.Button
$btnOutput.Text = "Browse…"
$btnOutput.Location = New-Object System.Drawing.Point(695, 347)
$btnOutput.Size = New-Object System.Drawing.Size(90, 28)
$btnOutput.Anchor = "Top,Right"
$form.Controls.Add($btnOutput)

# Options group
$options = New-Object System.Windows.Forms.GroupBox
$options.Text = "Godot / export options"
$options.Location = New-Object System.Drawing.Point(20, 390)
$options.Size = New-Object System.Drawing.Size(765, 112)
$options.Anchor = "Top,Left,Right"
$form.Controls.Add($options)

$chkApplyRotation = New-Object System.Windows.Forms.CheckBox
$chkApplyRotation.Text = "Apply rotation"
$chkApplyRotation.Checked = $true
$chkApplyRotation.AutoSize = $true
$chkApplyRotation.Location = New-Object System.Drawing.Point(15, 26)
$options.Controls.Add($chkApplyRotation)

$chkApplyScale = New-Object System.Windows.Forms.CheckBox
$chkApplyScale.Text = "Apply scale"
$chkApplyScale.Checked = $true
$chkApplyScale.AutoSize = $true
$chkApplyScale.Location = New-Object System.Drawing.Point(140, 26)
$options.Controls.Add($chkApplyScale)

$chkApplyLocation = New-Object System.Windows.Forms.CheckBox
$chkApplyLocation.Text = "Apply location"
$chkApplyLocation.Checked = $false
$chkApplyLocation.AutoSize = $true
$chkApplyLocation.Location = New-Object System.Drawing.Point(250, 26)
$options.Controls.Add($chkApplyLocation)

$chkBakeWorld = New-Object System.Windows.Forms.CheckBox
$chkBakeWorld.Text = "Bake parent/world transforms (recommended for static assets)"
$chkBakeWorld.Checked = $true
$chkBakeWorld.AutoSize = $true
$chkBakeWorld.Location = New-Object System.Drawing.Point(365, 26)
$options.Controls.Add($chkBakeWorld)

$chkVisibleOnly = New-Object System.Windows.Forms.CheckBox
$chkVisibleOnly.Text = "Skip meshes hidden from render"
$chkVisibleOnly.Checked = $true
$chkVisibleOnly.AutoSize = $true
$chkVisibleOnly.Location = New-Object System.Drawing.Point(15, 56)
$options.Controls.Add($chkVisibleOnly)

$chkOverwrite = New-Object System.Windows.Forms.CheckBox
$chkOverwrite.Text = "Overwrite existing GLB"
$chkOverwrite.Checked = $false
$chkOverwrite.AutoSize = $true
$chkOverwrite.Location = New-Object System.Drawing.Point(225, 56)
$options.Controls.Add($chkOverwrite)

$chkPreserveFolders = New-Object System.Windows.Forms.CheckBox
$chkPreserveFolders.Text = "Preserve folder structure"
$chkPreserveFolders.Checked = $true
$chkPreserveFolders.AutoSize = $true
$chkPreserveFolders.Location = New-Object System.Drawing.Point(395, 56)
$options.Controls.Add($chkPreserveFolders)

$chkFlatColor = New-Object System.Windows.Forms.CheckBox
$chkFlatColor.Text = "Legacy flat-color material repair (removes complex shaders/textures)"
$chkFlatColor.Checked = $false
$chkFlatColor.AutoSize = $true
$chkFlatColor.Location = New-Object System.Drawing.Point(15, 83)
$options.Controls.Add($chkFlatColor)

# Progress / status
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(20, 518)
$progress.Size = New-Object System.Drawing.Size(650, 22)
$progress.Anchor = "Top,Left,Right"
$progress.Minimum = 0
$progress.Maximum = 100
$form.Controls.Add($progress)

$btnConvert = New-Object System.Windows.Forms.Button
$btnConvert.Text = "Convert"
$btnConvert.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$btnConvert.Location = New-Object System.Drawing.Point(680, 514)
$btnConvert.Size = New-Object System.Drawing.Size(105, 31)
$btnConvert.Anchor = "Top,Right"
$form.Controls.Add($btnConvert)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Ready"
$status.AutoSize = $true
$status.ForeColor = [System.Drawing.Color]::DimGray
$status.Location = New-Object System.Drawing.Point(20, 547)
$form.Controls.Add($status)

$log = New-Object System.Windows.Forms.TextBox
$log.Location = New-Object System.Drawing.Point(20, 570)
$log.Size = New-Object System.Drawing.Size(765, 78)
$log.Anchor = "Top,Bottom,Left,Right"
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = "Vertical"
$log.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($log)

# Track both source path and the folder root from which it was added.
$script:SourceItems = New-Object System.Collections.ArrayList

$tips = New-Object System.Windows.Forms.ToolTip
$tips.SetToolTip($chkRecursive, 'Applies when Add folder scans the selected folder. Re-add a folder after changing this option.')
$tips.SetToolTip($chkBakeWorld, 'Flatten mesh parents while retaining world placement. Rotation + scale also bake parent shear. Source files are never saved.')
$tips.SetToolTip($chkApplyLocation, 'Bake translation into vertices. OFF keeps the current object position and avoids moving the mesh origin unnecessarily.')
$tips.SetToolTip($chkApplyRotation, 'Bake rotation into static mesh vertices in the temporary Blender process.')
$tips.SetToolTip($chkApplyScale, 'Bake scale into static mesh vertices; useful for predictable Godot asset scale.')
$tips.SetToolTip($chkVisibleOnly, 'Skip meshes or collection branches hidden from rendering. Viewport-only hiding is ignored.')
$tips.SetToolTip($chkOverwrite, 'OFF skips existing GLBs. ON replaces them only after a successful export. Duplicate batch names get a suffix.')
$tips.SetToolTip($chkPreserveFolders, 'Keep paths relative to each folder added. Individually added files use their containing folder as the root.')
$tips.SetToolTip($chkFlatColor, 'Destructive compatibility mode in the exported copy only: replaces shader graphs with a single flat color. Leave OFF for textured assets.')

function Refresh-SourceList {
    $listSources.Items.Clear()
    foreach ($item in $script:SourceItems) {
        [void]$listSources.Items.Add($item.Path)
    }
    $status.Text = "$($script:SourceItems.Count) model(s) selected"
}

function Add-SourceItem {
    param(
        [string]$Path,
        [string]$Root
    )

    $full = [System.IO.Path]::GetFullPath($Path)
    $exists = $script:SourceItems | Where-Object { $_.Path -ieq $full }
    if ($exists) { return }

    [void]$script:SourceItems.Add([pscustomobject]@{
        Path = $full
        Root = [System.IO.Path]::GetFullPath($Root)
    })
}

$btnBlender.Add_Click({
    try {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select blender.exe"
    $dialog.Filter = "Blender (blender.exe)|blender.exe|Executable (*.exe)|*.exe"
    $dialog.FileName = "blender.exe"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtBlender.Text = $dialog.FileName
    }
    }
    catch { Show-ConverterError $_ }
    finally {
        if (Get-Variable -Name dialog -Scope Local -ErrorAction SilentlyContinue) { $dialog.Dispose() }
    }
})

$btnFiles.Add_Click({
    try {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Add Blender or FBX models"
    $dialog.Filter = "Supported models (*.blend;*.fbx)|*.blend;*.fbx|Blender (*.blend)|*.blend|FBX (*.fbx)|*.fbx"
    $dialog.Multiselect = $true
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($file in $dialog.FileNames) {
            Add-SourceItem -Path $file -Root (Split-Path -Parent $file)
        }
        Refresh-SourceList
    }
    }
    catch { Show-ConverterError $_ }
    finally {
        if (Get-Variable -Name dialog -Scope Local -ErrorAction SilentlyContinue) { $dialog.Dispose() }
    }
})

$btnFolder.Add_Click({
    try {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select a folder containing .blend or .fbx models"
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $root = $dialog.SelectedPath
        $search = if ($chkRecursive.Checked) { [System.IO.SearchOption]::AllDirectories } else { [System.IO.SearchOption]::TopDirectoryOnly }
        $files = @()
        $files += [System.IO.Directory]::GetFiles($root, "*.blend", $search)
        $files += [System.IO.Directory]::GetFiles($root, "*.fbx", $search)
        foreach ($file in ($files | Sort-Object)) {
            Add-SourceItem -Path $file -Root $root
        }
        Refresh-SourceList
        Add-LogLine -TextBox $log -Text "Added $($files.Count) model(s) from: $root"
    }
    }
    catch { Show-ConverterError $_ }
    finally {
        if (Get-Variable -Name dialog -Scope Local -ErrorAction SilentlyContinue) { $dialog.Dispose() }
    }
})

$btnClear.Add_Click({
    try {
    $script:SourceItems.Clear()
    Refresh-SourceList
    $progress.Value = 0
    }
    catch { Show-ConverterError $_ }
    finally {
        if (Get-Variable -Name dialog -Scope Local -ErrorAction SilentlyContinue) { $dialog.Dispose() }
    }
})

$btnOutput.Add_Click({
    try {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the GLB output folder"
    $dialog.ShowNewFolderButton = $true
    if ($txtOutput.Text -and (Test-Path -LiteralPath $txtOutput.Text -PathType Container)) {
        $dialog.SelectedPath = $txtOutput.Text
    }
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtOutput.Text = $dialog.SelectedPath
    }
    }
    catch { Show-ConverterError $_ }
    finally {
        if (Get-Variable -Name dialog -Scope Local -ErrorAction SilentlyContinue) { $dialog.Dispose() }
    }
})

$btnConvert.Add_Click({
    try {
        $blender = $txtBlender.Text.Trim().Trim('"')
        if (-not (Test-Path -LiteralPath $blender -PathType Leaf) -or [IO.Path]::GetFileName($blender) -ine 'blender.exe') {
            [System.Windows.Forms.MessageBox]::Show(
                "Select a valid blender.exe first.",
                "Model → GLB Converter",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        if ($script:SourceItems.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show(
                "Add at least one .blend or .fbx model.",
                "Model → GLB Converter",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        $outputRoot = $txtOutput.Text.Trim().Trim('"')
        if (-not $outputRoot) {
            [System.Windows.Forms.MessageBox]::Show(
                "Choose an output folder.",
                "Model → GLB Converter",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }

        $outputRoot = [IO.Path]::GetFullPath($outputRoot)
        [void][IO.Directory]::CreateDirectory($outputRoot)

        $script:IsConverting = $true
        foreach ($control in $form.Controls) {
            if ($control -is [System.Windows.Forms.Button] -or $control -is [System.Windows.Forms.CheckBox] -or
                $control -is [System.Windows.Forms.GroupBox] -or ($control -is [System.Windows.Forms.TextBox] -and -not $control.ReadOnly)) {
                $control.Enabled = $false
            }
        }
        $progress.Value = 0
        $log.Clear()

        $worker = New-WorkerScript
        $success = 0
        $failed = New-Object System.Collections.Generic.List[string]
        $skipped = 0
        $targets = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)

        try {
            $count = $script:SourceItems.Count
            for ($i = 0; $i -lt $count; $i++) {
                $item = $script:SourceItems[$i]
                $source = $item.Path
                $name = [System.IO.Path]::GetFileNameWithoutExtension($source)
                $stagedTarget = $null

                try {
                    $targetDir = $outputRoot
                    if ($chkPreserveFolders.Checked) {
                        $sourceDir = Split-Path -Parent $source
                        $relativeDir = Get-RelativePathCompat -BasePath $item.Root -TargetPath $sourceDir
                        if ($relativeDir -and $relativeDir -ne ".") {
                            $targetDir = Join-Path $outputRoot $relativeDir
                        }
                    }

                    $target = Join-Path $targetDir ($name + ".glb")
                    # Prevent two inputs from overwriting each other in this batch.
                    $suffix = [IO.Path]::GetExtension($source).TrimStart('.')
                    $index = 1
                    while (-not $targets.Add($target)) {
                        $tag = if ($index -eq 1) { $suffix } else { "$suffix-$index" }
                        $target = Join-Path $targetDir ($name + '_' + $tag + '.glb')
                        $index++
                    }

                    $status.Text = "Converting $($i + 1) of ${count}: $(Split-Path -Leaf $source)"
                    $progress.Value = [Math]::Min(99, [int](($i / [double]$count) * 100))
                    Add-LogLine -TextBox $log -Text "[$($i + 1)/$count] $(Split-Path -Leaf $source)"

                    if ((Test-Path -LiteralPath $target) -and -not $chkOverwrite.Checked) {
                        $skipped++
                        Add-LogLine -TextBox $log -Text "Skipped (already exists): $target"
                        continue
                    }

                    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
                        [void][IO.Directory]::CreateDirectory($targetDir)
                    }
                    $stagedTarget = Join-Path $targetDir ('.converter-' + [guid]::NewGuid().ToString('N') + '.glb')

                    $arguments = @(
                        "--background",
                        "--factory-startup",
                        "--disable-autoexec",
                        "--python-exit-code", "1",
                        "--python", $worker,
                        "--",
                        $source,
                        $stagedTarget,
                        $(if ($chkApplyRotation.Checked) { "1" } else { "0" }),
                        $(if ($chkApplyScale.Checked) { "1" } else { "0" }),
                        $(if ($chkApplyLocation.Checked) { "1" } else { "0" }),
                        $(if ($chkBakeWorld.Checked) { "1" } else { "0" }),
                        $(if ($chkVisibleOnly.Checked) { "1" } else { "0" }),
                        $(if ($chkFlatColor.Checked) { "1" } else { "0" })
                    )

                    $result = Invoke-BlenderWorker -Executable $blender -Arguments $arguments
                    if ($result.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $stagedTarget -PathType Leaf) -or
                        -not $result.Output.Contains("CONVERTER_OK:$stagedTarget")) {
                        $tail = ($result.Output -split '\r?\n' | Select-Object -Last 16) -join "`r`n"
                        throw "Blender failed (exit $($result.ExitCode)).`r`n$tail"
                    }
                    $header = [IO.File]::OpenRead($stagedTarget)
                    try {
                        $magic = New-Object byte[] 4
                        if ($header.Read($magic, 0, 4) -ne 4 -or [Text.Encoding]::ASCII.GetString($magic) -ne 'glTF') {
                            throw 'Blender output is not a valid GLB file.'
                        }
                    }
                    finally { $header.Dispose() }
                    if ([IO.File]::Exists($target)) {
                        if (-not $chkOverwrite.Checked) { throw "Output appeared during conversion; overwrite is off: $target" }
                        # A plain $null becomes an empty string in this .NET call in
                        # PowerShell; NullString passes an actual null backup path.
                        [IO.File]::Replace($stagedTarget, $target, [NullString]::Value)
                    }
                    else { [IO.File]::Move($stagedTarget, $target) }
                    $success++
                    Add-LogLine -TextBox $log -Text "OK -> $target"
                    foreach ($line in ($result.Output -split '\r?\n' | Where-Object { $_ -match 'WARNING:' })) {
                        Add-LogLine -TextBox $log -Text $line
                    }
                }
                catch {
                    $failed.Add("$source`r`n  $($_.Exception.Message)")
                    Add-LogLine -TextBox $log -Text "FAILED: $source | $($_.Exception.Message)"
                }
                finally {
                    if ($stagedTarget -and (Test-Path -LiteralPath $stagedTarget)) {
                        Remove-Item -LiteralPath $stagedTarget -Force -ErrorAction SilentlyContinue
                    }
                    $progress.Value = [Math]::Min(100, [int]((($i + 1) / [double]$count) * 100))
                    [System.Windows.Forms.Application]::DoEvents()
                }
            }
        }
        finally {
            if ($worker -and (Test-Path -LiteralPath $worker)) {
                Remove-Item -LiteralPath $worker -Force -ErrorAction SilentlyContinue
            }
        }

        $progress.Value = 100
        $status.Text = "Done — $success converted, $skipped skipped, $($failed.Count) failed"

        if ($failed.Count -gt 0) {
            $logPath = Join-Path $outputRoot ("conversion-errors-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt")
            Set-Content -LiteralPath $logPath -Value ($failed -join "`r`n`r`n") -Encoding UTF8
            Add-LogLine -TextBox $log -Text "Failure log saved to: $logPath"
            foreach ($failure in $failed) { Add-LogLine -TextBox $log -Text $failure }
        }

        $message = "Conversion complete.`n`nConverted: $success`nSkipped: $skipped`nFailed: $($failed.Count)`n`nOutput:`n$outputRoot"
        if ($failed.Count -gt 0) { $message += "`n`nFailed files and details: $logPath" }
        $message += "`n`nSession log: $script:SessionLog"
        $icon = if ($failed.Count -gt 0) { [System.Windows.Forms.MessageBoxIcon]::Warning } else { [System.Windows.Forms.MessageBoxIcon]::Information }
        [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Model → GLB Converter",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            $icon
        ) | Out-Null
    }
    catch {
        Add-LogLine -TextBox $log -Text ("ERROR: " + $_.Exception.Message)
        $status.Text = "Error"
        Show-ConverterError $_
    }
    finally {
        $script:IsConverting = $false
        foreach ($control in $form.Controls) { $control.Enabled = $true }
    }
})

# Nice initial state: if launched from a scripts folder, propose sibling GLB folder
# only when it exists; otherwise leave output explicit instead of guessing.
if (-not $txtOutput.Text) {
    $scriptDir = Split-Path -Parent $PSCommandPath
    $candidate = Join-Path (Split-Path -Parent $scriptDir) "GLB"
    if (Test-Path -LiteralPath $candidate -PathType Container) {
        $txtOutput.Text = $candidate
    }
}

Add-LogLine -TextBox $log -Text "Ready. Add .blend/.fbx files or a folder."
Add-LogLine -TextBox $log -Text "Session log: $script:SessionLog"
$form.Add_FormClosing({
    param($sender, $eventArgs)
    if ($script:IsConverting) {
        $eventArgs.Cancel = $true
        $status.Text = 'Conversion running. Please wait for this batch to finish before closing.'
    }
})
if ($ValidateOnly) {
    Write-Output "UI initialized successfully | PowerShell $($PSVersionTable.PSVersion) | Blender: $($txtBlender.Text) | Log: $script:SessionLog"
    $form.Dispose()
    return
}
[void]$form.ShowDialog()
$form.Dispose()
