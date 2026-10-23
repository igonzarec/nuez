#requires -version 5.1
<#!
.SYNOPSIS
    Converts selected Blender .blend models into Godot-friendly .glb files.

.DESCRIPTION
    Opens Windows dialogs so no paths need to be typed. Each model is opened in
    Blender, mesh transforms are applied, and the result is exported as a GLB.
    Applying transforms is important for Terrain3D: it needs geometry with a
    neutral scale instead of an FBX-style parent scale compensation.

.NOTES
    Run from PowerShell with:
    powershell -ExecutionPolicy Bypass -File .\Convert-BlendsToGlb.ps1
#>

[CmdletBinding()]
param(
    ## Optional: override this if Blender is installed somewhere else.
    [string]$BlenderPath = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDirectory = Split-Path -Parent $PSCommandPath
$workspaceDirectory = Split-Path -Parent $scriptDirectory
$defaultSourceDirectory = Join-Path $workspaceDirectory "Ultimate Nature Pack by Quaternius\Blends"
$defaultOutputDirectory = Join-Path $workspaceDirectory "project\resources\nature\GLB"

function Show-Message {
    param(
        [string]$Message,
        [string]$Title = "Blender to GLB Converter",
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
    )

    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Buttons, $Icon)
}

function Select-BlenderExecutable {
    param([string]$SuggestedPath)

    if (Test-Path -LiteralPath $SuggestedPath -PathType Leaf) {
        return $SuggestedPath
    }

    Show-Message -Message "Blender was not found in the expected location. Please select blender.exe." -Icon Warning | Out-Null
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select blender.exe"
    $dialog.Filter = "Blender (blender.exe)|blender.exe|Ejecutables (*.exe)|*.exe"
    $dialog.Multiselect = $false
    $dialog.FileName = "blender.exe"

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    return $dialog.FileName
}

function Select-BlendFiles {
    param([string]$InitialDirectory)

    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Select one or more Blender models to convert"
    $dialog.Filter = "Blender models (*.blend)|*.blend"
    $dialog.Multiselect = $true
    $dialog.CheckFileExists = $true

    if (Test-Path -LiteralPath $InitialDirectory -PathType Container) {
        $dialog.InitialDirectory = $InitialDirectory
    }

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return @()
    }

    return @($dialog.FileNames)
}

function Select-OutputDirectory {
    param([string]$InitialDirectory)

    if (-not (Test-Path -LiteralPath $InitialDirectory)) {
        New-Item -ItemType Directory -Path $InitialDirectory -Force | Out-Null
    }

    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Select the folder where the GLB files will be saved"
    $dialog.SelectedPath = $InitialDirectory
    $dialog.ShowNewFolderButton = $true

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    return $dialog.SelectedPath
}

$blender = Select-BlenderExecutable -SuggestedPath $BlenderPath
if (-not $blender) {
    Write-Host "Conversion cancelled: Blender was not selected." -ForegroundColor Yellow
    exit 0
}

$sourceFiles = Select-BlendFiles -InitialDirectory $defaultSourceDirectory
if ($sourceFiles.Count -eq 0) {
    Write-Host "Conversion cancelled: no models were selected." -ForegroundColor Yellow
    exit 0
}

$outputDirectory = Select-OutputDirectory -InitialDirectory $defaultOutputDirectory
if (-not $outputDirectory) {
    Write-Host "Conversion cancelled: no output folder was selected." -ForegroundColor Yellow
    exit 0
}

$existingOutputs = @($sourceFiles | ForEach-Object {
    Join-Path $outputDirectory (([System.IO.Path]::GetFileNameWithoutExtension($_)) + ".glb")
} | Where-Object { Test-Path -LiteralPath $_ })

$summary = "$($sourceFiles.Count) file(s) will be converted to GLB.`n`nOutput folder:`n$outputDirectory"
if ($existingOutputs.Count -gt 0) {
    $summary += "`n`n$($existingOutputs.Count) existing GLB file(s) will be replaced."
}

if ((Show-Message -Message $summary -Buttons YesNo -Icon Question) -ne [System.Windows.Forms.DialogResult]::Yes) {
    Write-Host "Conversion cancelled." -ForegroundColor Yellow
    exit 0
}

$workerPath = Join-Path ([System.IO.Path]::GetTempPath()) ("blender_to_glb_" + [guid]::NewGuid().ToString("N") + ".py")
$workerCode = @'
import bpy
import sys
from pathlib import Path

source_path = Path(sys.argv[-2])
output_path = Path(sys.argv[-1])

bpy.ops.wm.open_mainfile(filepath=str(source_path))

# Export only renderable mesh objects. Their transform is baked into their mesh
# data so Terrain3D receives vertices at the intended scale.
bpy.ops.object.select_all(action="DESELECT")
mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not obj.hide_render]

if not mesh_objects:
    raise RuntimeError(f"No se encontraron mallas exportables en {source_path.name}")

for obj in mesh_objects:
    obj.select_set(True)

bpy.context.view_layer.objects.active = mesh_objects[0]
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

# These Quaternius source files contain legacy duplicate shader outputs. Blender
# 5.2 exports their material names but can omit their base colors in glTF. Build
# a small, explicit Principled material from each material's existing color so
# Godot receives the foliage and trunk colors rather than white materials.
def get_base_color(material):
    if material.use_nodes:
        for node in material.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED" and "Base Color" in node.inputs:
                return tuple(node.inputs["Base Color"].default_value)
    return tuple(material.diffuse_color)

for material in bpy.data.materials:
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

output_path.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(output_path),
    export_format="GLB",
    use_selection=True,
    export_materials="EXPORT",
)

print(f"OK: {output_path}")
'@

Set-Content -LiteralPath $workerPath -Value $workerCode -Encoding UTF8

$succeeded = [System.Collections.Generic.List[string]]::new()
$failed = [System.Collections.Generic.List[string]]::new()

try {
    for ($index = 0; $index -lt $sourceFiles.Count; $index++) {
        $sourceFile = $sourceFiles[$index]
        $outputFile = Join-Path $outputDirectory (([System.IO.Path]::GetFileNameWithoutExtension($sourceFile)) + ".glb")
        $percent = [int](($index / $sourceFiles.Count) * 100)

        Write-Progress -Activity "Converting models to GLB" -Status "$(Split-Path -Leaf $sourceFile)" -PercentComplete $percent
        Write-Host "[$($index + 1)/$($sourceFiles.Count)] $(Split-Path -Leaf $sourceFile)" -ForegroundColor Cyan

        & $blender --background --python $workerPath -- $sourceFile $outputFile
        $blenderExitCode = $LASTEXITCODE
        if ($blenderExitCode -eq 0 -and (Test-Path -LiteralPath $outputFile)) {
            $succeeded.Add($outputFile)
        }
        else {
            $failed.Add("$sourceFile (Blender exit code: $blenderExitCode)")
        }
    }
}
finally {
    Write-Progress -Activity "Converting models to GLB" -Completed
    if (Test-Path -LiteralPath $workerPath) {
        Remove-Item -LiteralPath $workerPath -Force
    }
}

$result = "Conversion complete.`n`nSuccessful: $($succeeded.Count)"
if ($failed.Count -gt 0) {
    $result += "`nFailed: $($failed.Count)`n`n" + ($failed -join "`n")
    Show-Message -Message $result -Icon Warning | Out-Null
}
else {
    $result += "`n`nYour GLB files are ready in:`n$outputDirectory"
    Show-Message -Message $result | Out-Null
}

Write-Host ""
Write-Host $result
Read-Host "Press Enter to close"
