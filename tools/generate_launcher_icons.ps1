param(
  [string]$Source = (Join-Path $PSScriptRoot '..\assets\localog_blue.png')
)

Add-Type -AssemblyName System.Drawing

function Write-IconPng {
  param([string]$Path, [int]$Size)
  $sourceImage = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
  try {
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    try {
      $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
      try {
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        if ($Path -like '*\ios\Runner\Assets.xcassets\AppIcon.appiconset\*') {
          $graphics.Clear([System.Drawing.Color]::White)
        } else {
          $graphics.Clear([System.Drawing.Color]::Transparent)
        }
        $graphics.DrawImage($sourceImage, 0, 0, $Size, $Size)
      } finally {
        $graphics.Dispose()
      }
      $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
      $bitmap.Dispose()
    }
  } finally {
    $sourceImage.Dispose()
  }
}

$pngTargets = @{
  'android\app\src\main\res\mipmap-mdpi\ic_launcher.png' = 48
  'android\app\src\main\res\mipmap-hdpi\ic_launcher.png' = 72
  'android\app\src\main\res\mipmap-xhdpi\ic_launcher.png' = 96
  'android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png' = 144
  'android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png' = 192
  'web\icons\Icon-192.png' = 192
  'web\icons\Icon-512.png' = 512
  'web\icons\Icon-maskable-192.png' = 192
  'web\icons\Icon-maskable-512.png' = 512
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_16.png' = 16
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_32.png' = 32
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_64.png' = 64
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_128.png' = 128
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_256.png' = 256
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_512.png' = 512
  'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_1024.png' = 1024
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@1x.png' = 20
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@2x.png' = 40
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-20x20@3x.png' = 60
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png' = 29
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png' = 58
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@3x.png' = 87
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png' = 40
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png' = 80
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@3x.png' = 120
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png' = 120
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png' = 180
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@1x.png' = 76
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-76x76@2x.png' = 152
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-83.5x83.5@2x.png' = 167
  'ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png' = 1024
}

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
foreach ($target in $pngTargets.GetEnumerator()) {
  Write-IconPng -Path (Join-Path $root $target.Key) -Size $target.Value
}

$icoPngPath = Join-Path $root 'macos\Runner\Assets.xcassets\AppIcon.appiconset\app_icon_256.png'
$icoPng = [System.IO.File]::ReadAllBytes($icoPngPath)
$stream = [System.IO.File]::Create((Join-Path $root 'windows\runner\resources\app_icon.ico'))
try {
  $writer = New-Object System.IO.BinaryWriter($stream)
  try {
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]1)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]32)
    $writer.Write([uint32]$icoPng.Length)
    $writer.Write([uint32]22)
    $writer.Write($icoPng)
  } finally {
    $writer.Dispose()
  }
} finally {
  $stream.Dispose()
}
