param([string]$dir, [int]$cx, [int]$cy, [int]$csize, [int]$gx, [int]$gy, [int]$gw, [int]$gh)
# $dir holds window.png; writes cover.png (600x350) and thumbnail.png (120x45) there.
# ($cx,$cy,$csize): the circle stack inside window.png; ($gx,$gy,$gw,$gh): the first pad row.
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile("$dir\window.png")

$bg = [System.Drawing.Color]::FromArgb(31, 31, 31)
$white = [System.Drawing.Color]::FromArgb(242, 242, 242)
$green = [System.Drawing.Color]::FromArgb(98, 193, 126)
$grey = [System.Drawing.Color]::FromArgb(160, 160, 160)
$dim = [System.Drawing.Color]::FromArgb(120, 120, 120)

function NewGraphics($bmp) {
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  return $g
}

# Draw the circle of fifths from the capture as a disc of the given diameter at (x, y).
function DrawDisc($g, $x, $y, $d) {
  # the disc edge is 0.49 of the stack; crop the stack square and scale so the disc fills d
  $scale = $d / (0.98 * $csize)
  $full = [int]($csize * $scale)
  $ox = $x - [int](($full - $d) / 2)
  $oy = $y - [int](($full - $d) / 2)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse($x, $y, $d, $d)
  # soft shadow
  $shadow = New-Object System.Drawing.Drawing2D.GraphicsPath
  $shadow.AddEllipse($x - 6, $y - 2, $d + 12, $d + 16)
  $sb = [System.Drawing.Drawing2D.PathGradientBrush]::new($shadow)
  $sb.CenterColor = [System.Drawing.Color]::FromArgb(140, 0, 0, 0)
  $sb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
  $g.FillPath($sb, $shadow)
  $g.SetClip($path)
  $g.DrawImage($src, ([System.Drawing.Rectangle]::new($ox, $oy, $full, $full)), ([System.Drawing.Rectangle]::new($cx, $cy, $csize, $csize)), [System.Drawing.GraphicsUnit]::Pixel)
  $g.ResetClip()
  $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(70, 255, 255, 255), 1.5)
  $g.DrawEllipse($pen, $x, $y, $d, $d)
}

# ---- cover 600x350 ----
$cover = New-Object System.Drawing.Bitmap 600, 350
$g = NewGraphics $cover
$g.Clear($bg)
# faint radial glow behind the disc
$glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$glowPath.AddEllipse(265, -30, 410, 410)
$glow = [System.Drawing.Drawing2D.PathGradientBrush]::new($glowPath)
$glow.CenterColor = [System.Drawing.Color]::FromArgb(70, 98, 193, 126)
$glow.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 31, 31, 31))
$g.FillPath($glow, $glowPath)

DrawDisc $g 345 32 250

$titleFont = [System.Drawing.Font]::new("Segoe UI", 50, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$tagFont = [System.Drawing.Font]::new("Segoe UI", 18, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$smallFont = [System.Drawing.Font]::new("Segoe UI", 13, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$fmt = [System.Drawing.StringFormat]::new([System.Drawing.StringFormat]::GenericTypographic)
$fmt.FormatFlags = $fmt.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces

$bw = [System.Drawing.SolidBrush]::new($white)
$bgreen = [System.Drawing.SolidBrush]::new($green)
$bgrey = [System.Drawing.SolidBrush]::new($grey)
$bdim = [System.Drawing.SolidBrush]::new($dim)

$x0 = 34
$g.DrawString("Chord", $titleFont, $bw, $x0, 44, $fmt)
$w1 = $g.MeasureString("Chord", $titleFont, 1000, $fmt).Width
$g.DrawString("Slop", $titleFont, $bgreen, $x0 + $w1 - 2, 44, $fmt)

$g.DrawString("Chord pads for trackers.", $tagFont, $bw, $x0, 122, $fmt)
$g.DrawString("Sixteen chords that fit the key.", $tagFont, $bgrey, $x0, 150, $fmt)
$g.DrawString("Pads, MIDI or QWERTY. Records in place.", $tagFont, $bgrey, $x0, 174, $fmt)

# a row of pads from the capture, scaled down
$padScale = 0.5
$pw = [int]($gw * $padScale); $ph = [int]($gh * $padScale)
$g.DrawImage($src, ([System.Drawing.Rectangle]::new($x0, 222, $pw, $ph)), ([System.Drawing.Rectangle]::new($gx, $gy, $gw, $gh)), [System.Drawing.GraphicsUnit]::Pixel)

$g.DrawString("Renoise 3.5", $smallFont, $bdim, $x0, 318, $fmt)
$g.Dispose()
$cover.Save("$dir\cover.png", [System.Drawing.Imaging.ImageFormat]::Png)

# ---- thumbnail 120x45 ----
$thumb = New-Object System.Drawing.Bitmap 120, 45
$g = NewGraphics $thumb
$g.Clear($bg)
DrawDisc $g 5 5 35
$tf = [System.Drawing.Font]::new("Segoe UI", 15, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString("Chord", $tf, $bw, 43, 13, $fmt)
$w1 = $g.MeasureString("Chord", $tf, 1000, $fmt).Width
$g.DrawString("Slop", $tf, $bgreen, 43 + $w1 - 1, 13, $fmt)
$g.Dispose()
$thumb.Save("$dir\thumbnail.png", [System.Drawing.Imaging.ImageFormat]::Png)
$src.Dispose()
Write-Output "composed"
