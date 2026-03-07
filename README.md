## Install (Linux / macOS / WSL)

curl -fsSL https://raw.githubusercontent.com/srthk4370-IIITH/SoundExtension/main/install.sh | bash

## Uninstall (Linux/WSL)

sed -i '/# >>> failure-hook START >>>/,/# <<< failure-hook END <<</d' ~/.bashrc 
rm -f ~/failure.wav

## Install (Windows PowerShell)

irm https://raw.githubusercontent.com/srthk4370-IIITH/SoundExtension/main/install.ps1 | iex

## Uninstall (Windows PowerShell)

(Get-Content $PROFILE) -replace '(?s)# >>> failure-hook START >>>.*?# <<< failure-hook END <<<','' | Set-Content $PROFILE
Remove-Item "$env:USERPROFILE\failure.wav" -Force -ErrorAction SilentlyContinue
