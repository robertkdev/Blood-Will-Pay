param(
	[string]$WindowTitlePattern = "Blood Will Pay|Gamble Battle|Godot",
	[string]$OutputDirectory = "outputs/vision_snapshots/os_window",
	[int]$WaitSeconds = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
	$outputRoot = $OutputDirectory
} else {
	$outputRoot = Join-Path $repoRoot $OutputDirectory
}
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

if (-not ([System.Management.Automation.PSTypeName]"VisionCapture.Native").Type) {
	Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace VisionCapture {
	public static class Native {
		public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

		[StructLayout(LayoutKind.Sequential)]
		public struct RECT {
			public int Left;
			public int Top;
			public int Right;
			public int Bottom;
		}

		[DllImport("user32.dll")]
		public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

		[DllImport("user32.dll")]
		public static extern bool IsWindowVisible(IntPtr hWnd);

		[DllImport("user32.dll", CharSet = CharSet.Unicode)]
		public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

		[DllImport("user32.dll")]
		public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

		[DllImport("user32.dll")]
		public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, int nFlags);

		[DllImport("user32.dll")]
		public static extern bool SetForegroundWindow(IntPtr hWnd);
	}
}
"@
}

Add-Type -AssemblyName System.Drawing

function New-Status {
	param(
		[bool]$Ok,
		[string]$Reason,
		[string]$Path = "",
		[string]$Title = "",
		[int]$Width = 0,
		[int]$Height = 0,
		[bool]$PrintWindowOk = $false,
		[bool]$FallbackUsed = $false,
		[object]$Stats = $null
	)

	return [ordered]@{
		ok = $Ok
		kind = "os_window"
		reason = $Reason
		title = $Title
		path = $Path
		absolute_path = $Path
		width = $Width
		height = $Height
		print_window_ok = $PrintWindowOk
		copy_from_screen_used = $FallbackUsed
		stats = $Stats
		captured_at = (Get-Date).ToString("o")
		window_title_pattern = $WindowTitlePattern
	}
}

function Write-StatusJson {
	param([object]$Status)

	$stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
	$statusPath = Join-Path $outputRoot "godot_window_status_$stamp.json"
	$json = $Status | ConvertTo-Json -Depth 8
	$json | Set-Content -Encoding UTF8 -Path $statusPath
	Write-Output $json
}

function Get-VisibleWindows {
	$script:windowMatches = @()
	$callback = [VisionCapture.Native+EnumWindowsProc]{
		param([IntPtr]$Handle, [IntPtr]$Param)

		if ([VisionCapture.Native]::IsWindowVisible($Handle)) {
			$titleBuilder = [System.Text.StringBuilder]::new(512)
			[void][VisionCapture.Native]::GetWindowText($Handle, $titleBuilder, $titleBuilder.Capacity)
			$title = $titleBuilder.ToString()
			if ($title -match $WindowTitlePattern) {
				$script:windowMatches += [pscustomobject]@{
					Handle = $Handle
					Title = $title
				}
			}
		}

		return $true
	}

	[void][VisionCapture.Native]::EnumWindows($callback, [IntPtr]::Zero)
	return $script:windowMatches
}

function Find-Window {
	$deadline = (Get-Date).AddSeconds([Math]::Max(0, $WaitSeconds))
	do {
		$matches = @(Get-VisibleWindows)
		if ($matches.Count -gt 0) {
			return $matches[0]
		}
		if ((Get-Date) -lt $deadline) {
			Start-Sleep -Milliseconds 250
		}
	} while ((Get-Date) -lt $deadline)

	return $null
}

function Get-BitmapStats {
	param([System.Drawing.Bitmap]$Bitmap)

	$sampleX = [Math]::Max(1, [int]($Bitmap.Width / 24))
	$sampleY = [Math]::Max(1, [int]($Bitmap.Height / 24))
	$unique = @{}
	$nonBlack = 0
	$total = 0

	for ($y = 0; $y -lt $Bitmap.Height; $y += $sampleY) {
		for ($x = 0; $x -lt $Bitmap.Width; $x += $sampleX) {
			$color = $Bitmap.GetPixel($x, $y)
			$key = "$($color.R),$($color.G),$($color.B)"
			$unique[$key] = $true
			if (($color.R + $color.G + $color.B) -gt 12) {
				$nonBlack += 1
			}
			$total += 1
		}
	}

	return [ordered]@{
		sample_count = $total
		unique_colors = $unique.Count
		non_black_samples = $nonBlack
	}
}

$window = Find-Window
if ($null -eq $window) {
	$status = New-Status -Ok $false -Reason "no_visible_matching_window"
	Write-StatusJson -Status $status
	exit 2
}

$rect = [VisionCapture.Native+RECT]::new()
if (-not [VisionCapture.Native]::GetWindowRect($window.Handle, [ref]$rect)) {
	$status = New-Status -Ok $false -Reason "get_window_rect_failed" -Title $window.Title
	Write-StatusJson -Status $status
	exit 3
}

$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
if ($width -le 0 -or $height -le 0) {
	$status = New-Status -Ok $false -Reason "window_has_invalid_size" -Title $window.Title -Width $width -Height $height
	Write-StatusJson -Status $status
	exit 4
}

$bitmap = [System.Drawing.Bitmap]::new($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$hdc = $graphics.GetHdc()
$printWindowOk = [VisionCapture.Native]::PrintWindow($window.Handle, $hdc, 0)
$graphics.ReleaseHdc($hdc)
$graphics.Dispose()

$stats = Get-BitmapStats -Bitmap $bitmap
$fallbackUsed = $false
if ((-not $printWindowOk) -or $stats.unique_colors -lt 3 -or $stats.non_black_samples -lt 4) {
	[void][VisionCapture.Native]::SetForegroundWindow($window.Handle)
	Start-Sleep -Milliseconds 150
	$fallbackGraphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$fallbackGraphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($width, $height))
	$fallbackGraphics.Dispose()
	$stats = Get-BitmapStats -Bitmap $bitmap
	$fallbackUsed = $true
}

$stamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
$imagePath = Join-Path $outputRoot "godot_window_$stamp.png"
$bitmap.Save($imagePath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()

$status = New-Status `
	-Ok $true `
	-Reason "captured" `
	-Path $imagePath `
	-Title $window.Title `
	-Width $width `
	-Height $height `
	-PrintWindowOk $printWindowOk `
	-FallbackUsed $fallbackUsed `
	-Stats $stats

Write-StatusJson -Status $status
