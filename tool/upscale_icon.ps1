# Phong to icon len 1024x1024 (bicubic chat luong cao).
# Cach chay: powershell -File tool/upscale_icon.ps1 <input.png> <output.png>
param(
    [Parameter(Mandatory=$true)][string]$InputFile,
    [Parameter(Mandatory=$true)][string]$OutputFile,
    [int]$Size = 1024
)

Add-Type -AssemblyName System.Drawing

$src = [System.Drawing.Image]::FromFile((Resolve-Path $InputFile))
try {
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)),
            (New-Object System.Drawing.Rectangle(0, 0, $src.Width, $src.Height)),
            [System.Drawing.GraphicsUnit]::Pixel)
        $bmp.Save($OutputFile, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "UPSCALE_OK: $OutputFile ($($src.Width)x$($src.Height) -> ${Size}x${Size})"
    } finally {
        $g.Dispose(); $bmp.Dispose()
    }
} finally {
    $src.Dispose()
}
