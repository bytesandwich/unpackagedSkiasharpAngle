# scripts/build-native.ps1
#
# A hermetic script to build the ANGLE libraries with the correct, split
# configuration required for unpackaged WinUI 3 applications.
# This script is idempotent and will skip the build if artifacts already exist.
#
# Prerequisites: Visual Studio 2022 with "Desktop development with C++" workload.

# --- 1. Configuration ---
$WorkspaceRoot = Join-Path $PSScriptRoot "..\angle_build_workspace"
$DepotToolsDir = Join-Path $WorkspaceRoot "depot_tools"
$AngleDir = Join-Path $WorkspaceRoot "angle"
$ArtifactsDir = Join-Path $PSScriptRoot "..\artifacts"


# --- Caching Logic ---
$EglArtifactPath = Join-Path $ArtifactsDir "libEGL.dll"
$GlesArtifactPath = Join-Path $ArtifactsDir "libGLESv2.dll"

if ((Test-Path $EglArtifactPath) -and (Test-Path $GlesArtifactPath)) {
    Write-Host "ANGLE artifacts already exist in '$ArtifactsDir'. Skipping build."
    exit 0
}

# --- 2. Setup Phase: Create a self-contained environment ---
Write-Host "Setting up the build workspace at $WorkspaceRoot..."
if (-not (Test-Path $WorkspaceRoot)) { New-Item -Path $WorkspaceRoot -ItemType Directory | Out-Null }
if (-not (Test-Path $ArtifactsDir)) { New-Item -Path $ArtifactsDir -ItemType Directory | Out-Null }

if (-not (Test-Path $DepotToolsDir)) {
    Write-Host "Cloning depot_tools..."
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git $DepotToolsDir
}

Write-Host "Configuring local environment..."
$env:Path = "$DepotToolsDir;" + $env:Path
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = 0

# --- 3. Source Code Phase ---
Write-Host "Fetching ANGLE source code..."
Set-Location $WorkspaceRoot

if (-not (Test-Path (Join-Path $AngleDir ".git"))) {
    @"
solutions = [
  {
    "url": "https://chromium.googlesource.com/angle/angle.git",
    "managed": False,
    "name": "angle",
  },
]
"@ | Set-Content -Path ".gclient" -Encoding Ascii
    
    gclient sync --force --delete_unversioned_trees
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gclient sync failed. This can be due to temporary network issues or server rate-limiting. Please wait a few minutes and try again. Aborting script."
        exit 1
    }
}

# --- 4. Build Phase ---
Write-Host "Starting the ANGLE build..."
Set-Location $AngleDir

# --- Build libEGL.dll ---
Write-Host "Building libEGL.dll..."
$EglOutDir = "out/Release_EGL"
# Step 1: Generate the default args.gn file.
gn gen $EglOutDir
# Step 2: Append our overrides to the default file.
@"
target_cpu = "x64"
is_debug = false
is_component_build = false
use_custom_libcxx = false
symbol_level = 0
angle_is_winappsdk = false
enable_precompiled_headers = false
angle_enable_null = false
angle_enable_wgpu = false
angle_enable_gl_desktop_backend = false
angle_enable_vulkan = false
"@ | Add-Content -Path (Join-Path $EglOutDir "args.gn")
# Step 3: Re-run gen to process the updated args.gn file.
gn gen $EglOutDir
if ($LASTEXITCODE -ne 0) { Write-Error "gn gen for libEGL failed."; exit 1 }

ninja -C $EglOutDir libEGL
if ($LASTEXITCODE -ne 0) { Write-Error "ninja build for libEGL failed."; exit 1 }

# --- Build libGLESv2.dll ---
Write-Host "Building libGLESv2.dll..."
$GlesOutDir = "out/Release_GLES"

$WinAppSdkHeadersPath = Join-Path $WorkspaceRoot "winappsdk_headers"

if (-not (Test-Path $WinAppSdkHeadersPath)) {
    python scripts/winappsdk_setup.py --output $WinAppSdkHeadersPath
}

# Step 1: Generate the default args.gn file.
gn gen $GlesOutDir
# Step 2: Append our overrides to the default file.
@"
target_cpu = "x64"
is_debug = false
is_clang = false
is_component_build = false
angle_is_winappsdk = true
use_custom_libcxx=false
winappsdk_dir = "$WinAppSdkHeadersPath"
"@ | Add-Content -Path (Join-Path $GlesOutDir "args.gn")
# Step 3: Re-run gen to process the updated args.gn file.
gn gen $GlesOutDir
if ($LASTEXITCODE -ne 0) { Write-Error "gn gen for libGLESv2 failed."; exit 1 }

ninja -C $GlesOutDir libGLESv2
if ($LASTEXITCODE -ne 0) { Write-Error "ninja build for libGLESv2 failed."; exit 1 }


# --- 5. Artifact Collection ---
Write-Host "Build complete. Collecting artifacts..."
Copy-Item -Path (Join-Path $EglOutDir "libEGL.dll") -Destination $ArtifactsDir
Copy-Item -Path (Join-Path $GlesOutDir "libGLESv2.dll") -Destination $ArtifactsDir

Write-Host "Successfully copied libraries to $ArtifactsDir"
