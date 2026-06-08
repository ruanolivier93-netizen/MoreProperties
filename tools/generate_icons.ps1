Add-Type -AssemblyName System.Drawing

function New-Icon {
    param(
        [string]$Path,
        [int]$Size,
        [bool]$Padded
    )
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.Clear([System.Drawing.Color]::Transparent)

    $inset   = if ($Padded) { [int]($Size * 0.18) } else { 0 }
    $rect    = New-Object System.Drawing.Rectangle $inset, $inset, ($Size - 2 * $inset), ($Size - 2 * $inset)
    $start   = [System.Drawing.Color]::FromArgb(255, 18, 245, 138)
    $end     = [System.Drawing.Color]::FromArgb(255, 10, 184, 116)
    $brush   = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $start, $end, ([System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)

    if ($Padded) {
        $g.FillEllipse($brush, $rect)
    } else {
        $g.FillRectangle($brush, $rect)
    }

    $font  = New-Object System.Drawing.Font 'Segoe UI', ($Size * 0.46), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
    $black = [System.Drawing.Brushes]::Black
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment     = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    $textRect = New-Object System.Drawing.RectangleF ([float]$rect.X), ([float]$rect.Y), ([float]$rect.Width), ([float]$rect.Height)
    $g.DrawString('M', $font, $black, $textRect, $format)

    $brush.Dispose()
    $font.Dispose()
    $g.Dispose()

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# App icons (square with rounded background) — used by flutter_launcher_icons.
New-Item -ItemType Directory -Force -Path 'assets' | Out-Null
New-Icon -Path 'assets/app_icon.png' -Size 1024 -Padded $false
New-Icon -Path 'assets/app_icon_foreground.png' -Size 1024 -Padded $true
New-Icon -Path 'assets/splash_logo.png' -Size 512 -Padded $true

# Web favicon + manifest icons.
New-Icon -Path 'web/favicon.png' -Size 96 -Padded $true
New-Icon -Path 'web/icons/Icon-192.png' -Size 192 -Padded $true
New-Icon -Path 'web/icons/Icon-512.png' -Size 512 -Padded $true
New-Icon -Path 'web/icons/Icon-maskable-192.png' -Size 192 -Padded $false
New-Icon -Path 'web/icons/Icon-maskable-512.png' -Size 512 -Padded $false

'Generated icons.'
