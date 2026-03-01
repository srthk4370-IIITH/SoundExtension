$MarkerStart = "# >>> failure-hook START >>>"
$MarkerEnd   = "# <<< failure-hook END <<<"

$HookName = "failure-hook"
$SoundFile = "failure.wav"
$TargetSoundPath = Join-Path $env:USERPROFILE $SoundFile

Write-Host "Installing $HookName..."

# Ensure profile exists
if (!(Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "Created PowerShell profile at $PROFILE"
}

# Copy sound file
$InstallerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SourceSoundPath = Join-Path $InstallerDir $SoundFile

if (Test-Path $SourceSoundPath) {
    Copy-Item $SourceSoundPath $TargetSoundPath -Force
    Write-Host "Copied $SoundFile to $TargetSoundPath"
} else {
    Write-Host "ERROR: $SoundFile not found in installer directory."
    exit 1
}

# Remove existing installation block (idempotent)
$ProfileContent = Get-Content $PROFILE -Raw

if ($ProfileContent -match [regex]::Escape($MarkerStart)) {
    Write-Host "Existing installation detected. Updating..."
    $Pattern = [regex]::Escape($MarkerStart) + ".*?" + [regex]::Escape($MarkerEnd)
    $ProfileContent = [regex]::Replace($ProfileContent, $Pattern, "", "Singleline")
    Set-Content $PROFILE $ProfileContent
}

# Append hook block
Add-Content $PROFILE @"

$MarkerStart

function Play-FailureSound {
    try {
        \$player = New-Object System.Media.SoundPlayer "$TargetSoundPath"
        \$player.Play()
    } catch {}
}

function global:prompt {

    \$lastExit = \$LASTEXITCODE

    # Get last command line
    \$lastCommand = (Get-History -Count 1).CommandLine
    if (-not \$lastCommand) {
        return "PS " + (Get-Location) + "> "
    }

    \$firstWord = \$lastCommand.Split(" ")[0]

    switch -Regex (\$firstWord) {
        "^(gcc|g\+\+|clang|clang\+\+|make|cmake|javac|rustc|cargo|go)$" {
            if (\$lastExit -ne 0) {
                Play-FailureSound
            }
        }
        "^\.\\.*" {
            if (Test-Path \$firstWord -PathType Leaf -and \$lastExit -ne 0) {
                Play-FailureSound
            }
        }
    }

    return "PS " + (Get-Location) + "> "
}

$MarkerEnd

"@

Write-Host "Installation complete."
Write-Host "Restart PowerShell."