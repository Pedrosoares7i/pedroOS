function Write-PedroOk {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-PedroWarn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-PedroError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-PedroInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-PedroNa {
    param([string]$Message)
    Write-Host "[N/A] $Message" -ForegroundColor DarkGray
}

function Write-PedroSkip {
    param([string]$Message)
    Write-Host "[SKIP] $Message" -ForegroundColor DarkGray
}

function Write-PedroSection {
    param([string]$Title)
    Write-Host ''
    Write-Host $Title -ForegroundColor Yellow
}
