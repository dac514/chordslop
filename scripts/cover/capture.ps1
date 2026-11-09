Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder sb, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static IntPtr Find(string needle) {
    IntPtr found = IntPtr.Zero;
    EnumWindows((h, l) => {
      if (!IsWindowVisible(h)) return true;
      var sb = new System.Text.StringBuilder(256); GetWindowText(h, sb, 256);
      if (sb.ToString().Contains(needle)) { found = h; return false; }
      return true;
    }, IntPtr.Zero);
    return found;
  }
}
"@
$out = $args[0]
$h = [W]::Find("ChordSlop")
if ($h -eq [IntPtr]::Zero) { Write-Output "no window"; exit 1 }
[W]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 500
$r = New-Object W+RECT
[W]::GetWindowRect($h, [ref]$r) | Out-Null
$w = $r.R - $r.L; $hh = $r.B - $r.T
Write-Output "window $($r.L),$($r.T) ${w}x${hh}"
$bmp = New-Object System.Drawing.Bitmap $w, $hh
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$g.Dispose()
$bmp.Save("$out\window.png", [System.Drawing.Imaging.ImageFormat]::Png)

# cover 600x350: largest 12:7 crop centred on the window
$target = 600 / 350
$cw = $w; $ch = [int]($w / $target)
if ($ch -gt $hh) { $ch = $hh; $cw = [int]($hh * $target) }
$crop = New-Object System.Drawing.Rectangle ([int](($w - $cw) / 2)), ([int](($hh - $ch) / 2)), $cw, $ch
$cover = New-Object System.Drawing.Bitmap 600, 350
$g = [System.Drawing.Graphics]::FromImage($cover)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, 600, 350), $crop, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$cover.Save("$out\cover.png", [System.Drawing.Imaging.ImageFormat]::Png)

# thumbnail 120x45: the first pad row
$tw = [int]($w * 0.48); $th = [int]($tw * 45 / 120)
$tcrop = New-Object System.Drawing.Rectangle ([int]($w * 0.465)), ([int]($hh * 0.105)), $tw, $th
$thumb = New-Object System.Drawing.Bitmap 120, 45
$g = [System.Drawing.Graphics]::FromImage($thumb)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, 120, 45), $tcrop, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$thumb.Save("$out\thumbnail.png", [System.Drawing.Imaging.ImageFormat]::Png)
Write-Output "saved"
