# Tao icon vuong 1024x1024 tu anh logo goc (2752x1536, dang ngang).
# Logo duoc thu nho vua khung (contain) va canh giua, giu nen trong suot.
param(
    [string]$Source = "C:\Users\ngocg\Downloads\Gemini_Generated_Image_enmej0enmej0enme.png",
    [string]$Output = "$PSScriptRoot\..\assets\icon\app_icon.png",
    [int]$Size = 1024,
    [double]$MarginRatio = 0.10   # de le 10% moi canh cho dep
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile($Source)
try {
    $outDir = Split-Path $Output -Parent
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        # Vung ve logo = khung tru le
        $inner = [int]($Size * (1 - 2 * $MarginRatio))
        # Scale contain: lay chieu nho hon cua 2 ty le
        $scale = [Math]::Min($inner / $src.Width, $inner / $src.Height)
        $drawW = [int]($src.Width * $scale)
        $drawH = [int]($src.Height * $scale)
        $x = [int](($Size - $drawW) / 2)
        $y = [int](($Size - $drawH) / 2)

        $g.DrawImage($src, (New-Object System.Drawing.Rectangle($x, $y, $drawW, $drawH)),
            (New-Object System.Drawing.Rectangle(0, 0, $src.Width, $src.Height)),
            [System.Drawing.GraphicsUnit]::Pixel)

        $bmp.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "ICON_OK: $Output (${drawW}x${drawH} trong khung ${Size}x${Size})"
    } finally {
        $g.Dispose(); $bmp.Dispose()
    }
} finally {
    $src.Dispose()
}
