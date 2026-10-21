Add-Type -AssemblyName System.Drawing

$densities = @{
    "android/app/src/main/res/mipmap-mdpi" = 48
    "android/app/src/main/res/mipmap-hdpi" = 72
    "android/app/src/main/res/mipmap-xhdpi" = 96
    "android/app/src/main/res/mipmap-xxhdpi" = 144
    "android/app/src/main/res/mipmap-xxxhdpi" = 192
}

function Render-Icon([int]$size, [bool]$isRound) {
    $scale = 4
    $cs = $size * $scale
    $bmp = New-Object System.Drawing.Bitmap($cs, $cs)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $s = $cs / 512.0

    # Background
    $bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 12, 12, 16))
    if ($isRound) {
        $g.FillEllipse($bgBrush, 0, 0, $cs, $cs)
    } else {
        $r = 115 * $s
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $d = $r * 2
        $path.AddArc(0, 0, $d, $d, 180, 90)
        $path.AddArc($cs - $d, 0, $d, $d, 270, 90)
        $path.AddArc($cs - $d, $cs - $d, $d, $d, 0, 90)
        $path.AddArc(0, $cs - $d, $d, $d, 90, 90)
        $path.CloseFigure()
        $g.FillPath($bgBrush, $path)
        $path.Dispose()
    }
    $bgBrush.Dispose()

    # Transforms: translate(256,256) scale(1.2) translate(-181,-140)
    # X' = ((X - 181) * 1.2 + 256) * s
    # Y' = ((Y - 140) * 1.2 + 256) * s
    function Tx([double]$x) { return (($x - 181) * 1.2 + 256) * $s }
    function Ty([double]$y) { return (($y - 140) * 1.2 + 256) * $s }
    function Ts([double]$dim) { return $dim * 1.2 * $s }

    $cx = Tx 160
    $cy = Ty 150

    # Outer circle: r=62, stroke=12, #F2EFE9
    $rOuter = Ts 62
    $wOuter = Ts 12
    $bonePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 242, 239, 233), [float]$wOuter)
    $g.DrawEllipse($bonePen, [float]($cx - $rOuter), [float]($cy - $rOuter), [float]($rOuter * 2), [float]($rOuter * 2))
    $bonePen.Dispose()

    # Mid circle: r=36, stroke=6, #FF6B4A
    $rMid = Ts 36
    $wMid = Ts 6
    $coralPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 255, 107, 74), [float]$wMid)
    $g.DrawEllipse($coralPen, [float]($cx - $rMid), [float]($cy - $rMid), [float]($rMid * 2), [float]($rMid * 2))
    $coralPen.Dispose()

    # Inner dot: r=11, fill #FF6B4A
    $rDot = Ts 11
    $coralBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 107, 74))
    $g.FillEllipse($coralBrush, [float]($cx - $rDot), [float]($cy - $rDot), [float]($rDot * 2), [float]($rDot * 2))
    $coralBrush.Dispose()

    # Stem: x=216, y=62, w=20, h=156, rx=10, fill #F2EFE9
    $sx = Tx 216
    $sy = Ty 62
    $sw = Ts 20
    $sh = Ts 156
    $srx = Ts 10
    $stemPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $sd = $srx * 2
    $stemPath.AddArc([float]$sx, [float]$sy, [float]$sd, [float]$sd, 180, 90)
    $stemPath.AddArc([float]($sx + $sw - $sd), [float]$sy, [float]$sd, [float]$sd, 270, 90)
    $stemPath.AddArc([float]($sx + $sw - $sd), [float]($sy + $sh - $sd), [float]$sd, [float]$sd, 0, 90)
    $stemPath.AddArc([float]$sx, [float]($sy + $sh - $sd), [float]$sd, [float]$sd, 90, 90)
    $stemPath.CloseFigure()
    $boneBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 242, 239, 233))
    $g.FillPath($boneBrush, $stemPath)
    $stemPath.Dispose()
    $boneBrush.Dispose()

    # Ticks at x=250
    $ticks = @(
        @{ y = 77; w = 22; h = 6; rx = 3; r = 255; g = 107; b = 74; a = 255 },
        @{ y = 103; w = 14; h = 6; rx = 3; r = 255; g = 107; b = 74; a = 255 },
        @{ y = 129; w = 22; h = 6; rx = 3; r = 242; g = 239; b = 233; a = 140 },
        @{ y = 155; w = 14; h = 6; rx = 3; r = 242; g = 239; b = 233; a = 102 },
        @{ y = 181; w = 22; h = 6; rx = 3; r = 242; g = 239; b = 233; a = 64 }
    )

    foreach ($t in $ticks) {
        $tx = Tx 250
        $ty = Ty $t.y
        $tw = Ts $t.w
        $th = Ts $t.h
        $trx = Ts $t.rx
        $tBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($t.a, $t.r, $t.g, $t.b))
        $tPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $td = $trx * 2
        $tPath.AddArc([float]$tx, [float]$ty, [float]$td, [float]$td, 180, 90)
        $tPath.AddArc([float]($tx + $tw - $td), [float]$ty, [float]$td, [float]$td, 270, 90)
        $tPath.AddArc([float]($tx + $tw - $td), [float]($ty + $th - $td), [float]$td, [float]$td, 0, 90)
        $tPath.AddArc([float]$tx, [float]($ty + $th - $td), [float]$td, [float]$td, 90, 90)
        $tPath.CloseFigure()
        $g.FillPath($tBrush, $tPath)
        $tPath.Dispose()
        $tBrush.Dispose()
    }

    $g.Dispose()

    # Downsample to target size
    $outBmp = New-Object System.Drawing.Bitmap($size, $size)
    $outG = [System.Drawing.Graphics]::FromImage($outBmp)
    $outG.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $outG.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $outG.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $outG.DrawImage($bmp, 0, 0, $size, $size)
    $outG.Dispose()
    $bmp.Dispose()

    return $outBmp
}

# Generate 1024x1024 asset icon
$master = Render-Icon 1024 $false
$master.Save("assets/app_icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
$master.Dispose()
Write-Host "Created assets/app_icon.png"

# Generate all Android mipmaps
foreach ($entry in $densities.GetEnumerator()) {
    $dir = $entry.Key
    $sz = $entry.Value
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    
    $square = Render-Icon $sz $false
    $square.Save("$dir/ic_launcher.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $square.Dispose()

    $round = Render-Icon $sz $true
    $round.Save("$dir/ic_launcher_round.png", [System.Drawing.Imaging.ImageFormat]::Png)
    $round.Dispose()

    Write-Host "Generated $dir icons ($sz x $sz)"
}

Write-Host "ALL ICONS GENERATED SUCCESSFULLY!"
