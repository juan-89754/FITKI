# Genera los PNGs legacy del icono de Fitki (mipmap-*/ic_launcher.png) y el
# icono de 512x512 para la ficha de Google Play.
#
# El icono adaptativo (mipmap-anydpi-v26) ya es vectorial, pero Android 24-25
# no lo soporta y usaria los PNG. Estos se dibujan con System.Drawing para no
# depender de herramientas de diseno ni agregar dependencias al proyecto.
#
# Uso:  powershell -File tool\generate_launcher_icons.ps1

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$res = Join-Path $root 'android\app\src\main\res'

$brand = [System.Drawing.ColorTranslator]::FromHtml('#0C6E4E')

# tamanos de mipmap por densidad (mdpi=1x)
$densities = [ordered]@{
    'mdpi'    = 48
    'hdpi'    = 72
    'xhdpi'   = 96
    'xxhdpi'  = 144
    'xxxhdpi' = 192
}

function New-FitkiBitmap {
    param(
        [int]$Size,
        [bool]$Rounded
    )

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode     = 'AntiAlias'
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.PixelOffsetMode   = 'HighQuality'
        $g.Clear([System.Drawing.Color]::Transparent)

        # Fondo: cuadrado con esquinas redondeadas en el launcher, cuadrado
        # lleno en el icono de la ficha de Play.
        if ($Rounded) {
            $radius = [int]($Size * 0.22)
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $d = $radius * 2
            $path.AddArc(0, 0, $d, $d, 180, 90)
            $path.AddArc($Size - $d, 0, $d, $d, 270, 90)
            $path.AddArc($Size - $d, $Size - $d, $d, $d, 0, 90)
            $path.AddArc(0, $Size - $d, $d, $d, 90, 90)
            $path.CloseFigure()
            $brush = New-Object System.Drawing.SolidBrush($brand)
            $g.FillPath($brush, $path)
            $brush.Dispose()
            $path.Dispose()
        }
        else {
            $brush = New-Object System.Drawing.SolidBrush($brand)
            $g.FillRectangle($brush, 0, 0, $Size, $Size)
            $brush.Dispose()
        }

        # Monograma "F" en blanco, con las mismas proporciones del vector:
        # 30 de ancho por 50 de alto sobre un lienzo de 108.
        $u = $Size / 108.0
        $x = 39 * $u
        $y = 29 * $u
        $w = 30 * $u
        $h = 50 * $u
        $barH = 9 * $u
        $midH = 9 * $u
        $stemW = 9 * $u
        $gap = 11 * $u
        $midW = 18 * $u

        $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        # barra superior
        $g.FillRectangle($white, $x, $y, $w, $barH)
        # travesano
        $g.FillRectangle($white, $x, $y + $barH + $gap, $midW, $midH)
        # astil
        $g.FillRectangle($white, $x, $y, $stemW, $h)
        $white.Dispose()

        return $bmp
    }
    finally {
        $g.Dispose()
    }
}

foreach ($entry in $densities.GetEnumerator()) {
    $density = $entry.Key
    $size = $entry.Value
    $dir = Join-Path $res "mipmap-$density"
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
    $out = Join-Path $dir 'ic_launcher.png'
    $bmp = New-FitkiBitmap -Size $size -Rounded $true
    try {
        $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "  $out ($size x $size)"
    }
    finally {
        $bmp.Dispose()
    }
}

# Icono de la ficha de Play: 512x512, sin redondear, sin transparencia.
$storeDir = Join-Path $root 'store'
if (-not (Test-Path -LiteralPath $storeDir)) {
    New-Item -ItemType Directory -Path $storeDir | Out-Null
}
$storePath = Join-Path $storeDir 'play_store_icon_512.png'
$store = New-FitkiBitmap -Size 512 -Rounded $false
try {
    $store.Save($storePath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "  $storePath (512 x 512)"
}
finally {
    $store.Dispose()
}

Write-Output 'Iconos generados.'
