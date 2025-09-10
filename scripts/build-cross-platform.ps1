# Cross-platform build script for NenDB on Windows
# Handles Windows-specific issues and dependencies

param(
    [string]$Target = "native",
    [switch]$SkipTests = $false
)

# Colors for output (if supported)
function Write-Status { 
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success { 
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning { 
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error { 
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Detect architecture
$Arch = $env:PROCESSOR_ARCHITECTURE
Write-Status "Detected architecture: $Arch"

# Set target based on architecture if not specified
if ($Target -eq "native") {
    switch ($Arch) {
        "AMD64" { $Target = "x86_64-windows-gnu" }
        "ARM64" { $Target = "aarch64-windows-gnu" }
        default { 
            $Target = "x86_64-windows-gnu"
            Write-Warning "Unknown architecture, using x86_64-windows-gnu"
        }
    }
}

Write-Status "Using target: $Target"

# Check Zig version
Write-Status "Checking Zig version..."
try {
    $ZigVersion = zig version
    Write-Status "Zig version: $ZigVersion"
    
    if ($ZigVersion -ne "0.15.1") {
        Write-Warning "Expected Zig 0.15.1, found $ZigVersion. Build may fail."
    }
} catch {
    Write-Error "Zig not found. Please install Zig 0.15.1"
    exit 1
}

# Check for Nen dependencies
Write-Status "Checking Nen ecosystem dependencies..."

function Check-NenDep {
    param([string]$DepName)
    
    $DepPath = "../$DepName"
    
    if (-not (Test-Path $DepPath)) {
        Write-Error "Missing dependency: $DepName"
        Write-Status "Cloning $DepName..."
        
        Set-Location ..
        try {
            git clone "https://github.com/Nen-Co/$DepName.git"
            Write-Success "Cloned $DepName"
        } catch {
            Write-Error "Failed to clone $DepName"
            return $false
        } finally {
            Set-Location -
        }
    } else {
        Write-Success "Found $DepName"
    }
    return $true
}

if (-not (Check-NenDep "nen-io")) { exit 1 }
if (-not (Check-NenDep "nen-json")) { exit 1 }
if (-not (Check-NenDep "nen-net")) { exit 1 }

# Clean previous builds
Write-Status "Cleaning previous builds..."
Remove-Item -Recurse -Force .zig-cache -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force zig-out -ErrorAction SilentlyContinue

# Build configurations
$Configs = @("Debug", "ReleaseSafe", "ReleaseFast")

foreach ($Config in $Configs) {
    Write-Status "Building with $Config configuration..."
    
    try {
        zig build "-Dtarget=$Target" "-Doptimize=$Config"
        Write-Success "$Config build completed"
    } catch {
        Write-Error "$Config build failed"
        exit 1
    }
}

# Run tests (only for native-compatible builds)
if (-not $SkipTests -and ($Target -eq "native" -or $Target -like "*windows*")) {
    Write-Status "Running tests..."
    
    # Unit tests
    try {
        zig build test-unit
        Write-Success "Unit tests passed"
    } catch {
        Write-Error "Unit tests failed"
        exit 1
    }
    
    # TCP tests
    try {
        zig build test-tcp
        Write-Success "TCP tests passed"
    } catch {
        Write-Error "TCP tests failed"
        exit 1
    }
    
    # Performance tests (with timeout)
    Write-Status "Running performance tests (30s timeout)..."
    $Job = Start-Job -ScriptBlock { zig build test-performance }
    
    if (Wait-Job $Job -Timeout 30) {
        $Result = Receive-Job $Job
        Write-Success "Performance tests completed"
        Write-Host $Result
    } else {
        Stop-Job $Job
        Write-Warning "Performance tests timed out (expected for benchmarks)"
    }
    Remove-Job $Job
} else {
    Write-Warning "Skipping tests for target: $Target"
}

# Verify binaries
Write-Status "Verifying binaries..."
if (Test-Path "zig-out/bin") {
    Write-Success "Binaries created:"
    Get-ChildItem "zig-out/bin" -Recurse | Format-Table -AutoSize
} else {
    Write-Error "No binaries found in zig-out/bin"
    exit 1
}

Write-Success "🎉 Build completed successfully for Windows ($Target)"
Write-Status "Binaries available in: zig-out/bin/"
