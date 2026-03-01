$MarkerStart = "# >>> failure-hook START >>>"
$MarkerEnd   = "# <<< failure-hook END <<<"

$HookName = "failure-hook"
$SoundFile = "failure.wav"
$TargetSoundPath = Join-Path $env:USERPROFILE $SoundFile

# 🔴 IMPORTANT — Replace this
$RepoRawBase = "https://raw.githubusercontent.com/YOUR_USERNAME/failure-hook/main"

Write-Host "Installing $HookName..."

# Ensure profile exists
if (!(Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
    Write-Host "Created PowerShell profile at $PROFILE"
}

# Download sound file directly from GitHub
$SoundUrl = "$RepoRawBase/$SoundFile"

Write-Host "Downloading $SoundFile..."

try {
    Invoke-WebRequest -Uri $SoundUrl -OutFile $TargetSoundPath -UseBasicParsing
    Write-Host "Downloaded to $TargetSoundPath"
} catch {
    Write-Host "ERROR: Failed to download sound file."
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