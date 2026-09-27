# Genera todos los iconos de Fitki a partir de una unica fuente:
# assets\icon\icon.png (1024x1024, opaco, fondo de marca).
#
# ANTES este script dibujaba un monograma "F" con primitivas de
# System.Drawing, y el icono vectorial del launcher tambien era una "F"
# dibujada a mano: la app mostraba una letra en lugar del logo. Ahora todas las
# plataformas se derivan del archivo de imagen, de modo que el recurso y el
# archivo generado nunca pueden divergir.
#
# Se genera:
#   - Android legacy     mipmap-*/ic_launcher.png (logo con esquinas redondeadas;
#                        Android 24-25 no soporta el icono adaptativo)
#   - Android adaptativo mipmap-*/ic_launcher_foreground.png (recorte central
#                        seguro del 66%, la zona que ningun recorte del launcher
#                        toca) + mipmap-anydpi-v26/ic_launcher.xml
#   - iOS                Runner/Assets.xcassets/AppIcon.appiconset
#   - macOS              Runner/Assets.xcassets/AppIcon.appiconset
#   - Windows            runner\resources\app_icon.ico
#   - Web                web\favicon.png, web\icons\Icon-*.png (incl. maskable)
#   - Tienda             store\play_store_icon_512.png
#
# Uso:  powershell -File tool\generate_launcher_icons.ps1

Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$origen = Join-Path $root 'assets\icon\icon.png'

if (-not (Test-Path -LiteralPath $origen)) {
    throw "No se encuentra el logo '$origen'."
}

# Fondo real del logo (muestreado de sus bordes). El icono adaptativo de
# Android recorta el primer plano y deja ver el fondo alrededor, asi que este
# valor tiene que ser EXACTAMENTE el del logo o se vera un anillo de otro
# color. Debe coincidir con android/app/src/main/res/values/colors.xml
# (ic_launcher_background).
#
# El splash (fitki_splash) si usa el verde de la interfaz (#0C6E4E, el mismo
# que AppColors.primary), que no tiene por que coincidir con el del logo.
$brand = '#0F6A47'

$logo = [System.Drawing.Bitmap]::FromFile($origen)

function New-RoundedPath {
    param([int]$Size, [double]$Ratio)

    $radius = [int]($Size * $Ratio)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $radius * 2
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc($Size - $d, 0, $d, $d, 270, 90)
    $path.AddArc($Size - $d, $Size - $d, $d, $d, 0, 90)
    $path.AddArc(0, $Size - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $path
}

# Dibuja el logo completo ocupando todo el lienzo, opcionalmente recortado por
# un cuadrado de esquinas redondeadas.
function Draw-LogoCompleto {
    param([System.Drawing.Graphics]$Graphics, [int]$Size, [double]$Radio = 0)

    $path = $null
    if ($Radio -gt 0) {
        $path = New-RoundedPath -Size $Size -Ratio $Radio
        $Graphics.SetClip($path)
    }
    try {
        $destino = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
        $origen = New-Object System.Drawing.Rectangle(
            0, 0, $script:logo.Width, $script:logo.Height)
        $Graphics.DrawImage(
            $script:logo, $destino, $origen, [System.Drawing.GraphicsUnit]::Pixel)
    }
    finally {
        $Graphics.ResetClip()
        if ($path) { $path.Dispose() }
    }
}

# Dibuja solo el centro del logo, ampliado hasta llenar el lienzo. Es el
# tratamiento correcto para el icono adaptativo de Android: lo que queda fuera
# del 66% central puede recortarse sin que se pierda nada del diseno.
function Draw-LogoRecortado {
    param([System.Drawing.Graphics]$Graphics, [int]$Size, [double]$Fraccion = 0.66)

    $ancho = [int][Math]::Round($script:logo.Width * $Fraccion)
    $alto = [int][Math]::Round($script:logo.Height * $Fraccion)
    $izq = [int][Math]::Round(($script:logo.Width - $ancho) / 2)
    $sup = [int][Math]::Round(($script:logo.Height - $alto) / 2)

    $destino = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
    $origen = New-Object System.Drawing.Rectangle($izq, $sup, $ancho, $alto)
    $Graphics.DrawImage(
        $script:logo, $destino, $origen, [System.Drawing.GraphicsUnit]::Pixel)
}

# Dibuja el logo reducido sobre el fondo de marca, dejando un margen. Es lo que
# necesitan los iconos "maskable" de la web: el recorte del sistema puede
# comerse hasta un 20% por cada lado.
function Draw-LogoConMargen {
    param([System.Drawing.Graphics]$Graphics, [int]$Size, [double]$Margen)

    $util = [int][Math]::Round($Size * (1 - 2 * $Margen))
    $offset = [int][Math]::Round($Size * $Margen)
    $destino = New-Object System.Drawing.Rectangle($offset, $offset, $util, $util)
    $origen = New-Object System.Drawing.Rectangle(
        0, 0, $script:logo.Width, $script:logo.Height)
    $Graphics.DrawImage(
        $script:logo, $destino, $origen, [System.Drawing.GraphicsUnit]::Pixel)
}

# Crea un icono ya rasterizado. -Opaco descarta el canal alfa (lo exigen iOS y
# la ficha de Play); -Modo elige entre el logo entero, el recorte central seguro
# o el logo con margen.
function New-Icono {
    param(
        [int]$Size,
        [double]$Radio = 0,
        [bool]$Opaco = $false,
        [ValidateSet('completo', 'recortado', 'margen')]
        [string]$Modo = 'completo',
        [double]$Margen = 0.1
    )

    $formato = if ($Opaco) {
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    }
    else {
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    }
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, $formato)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = 'AntiAlias'
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.PixelOffsetMode = 'HighQuality'
        $g.CompositingQuality = 'HighQuality'
        # Los lienzos con alfa arrancan transparentes; los opacos se pintan del
        # color de marca, porque al descartar el canal alfa quedarian de negro.
        if ($Opaco) {
            $g.Clear([System.Drawing.ColorTranslator]::FromHtml($script:brand))
        }
        else {
            $g.Clear([System.Drawing.Color]::Transparent)
        }
        switch ($Modo) {
            'recortado' { Draw-LogoRecortado -Graphics $g -Size $Size }
            'margen' { Draw-LogoConMargen -Graphics $g -Size $Size -Margen $Margen }
            default { Draw-LogoCompleto -Graphics $g -Size $Size -Radio $Radio }
        }
    }
    finally {
        $g.Dispose()
    }
    $bmp
}

function Write-Bitmap {
    param($Bitmap, [string]$Path)

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    "  $Path"
}

function Get-PngBytes {
    param($Bitmap)

    $ms = New-Object System.IO.MemoryStream
    try {
        $Bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        # La coma unitaria evita que PowerShell desarme el byte[] al devolverlo.
        , $ms.ToArray()
    }
    finally {
        $ms.Dispose()
    }
}

try {
    # ---- Android ---------------------------------------------------------
    Write-Output 'Android'
    $res = Join-Path $root 'android\app\src\main\res'
    $densities = [ordered]@{
        'mdpi'    = 48
        'hdpi'    = 72
        'xhdpi'   = 96
        'xxhdpi'  = 144
        'xxxhdpi' = 192
    }

    foreach ($entry in $densities.GetEnumerator()) {
        $dir = Join-Path $res "mipmap-$($entry.Key)"

        # Legacy: el launcher aplica su propia mascara, asi que basta con
        # redondear las esquinas del logo.
        $legacy = New-Icono -Size $entry.Value -Radio 0.22
        try { Write-Bitmap -Bitmap $legacy -Path (Join-Path $dir 'ic_launcher.png') }
        finally { $legacy.Dispose() }

        # Adaptativo: el lienzo es de 108dp y solo el 66% central sobrevive a
        # cualquier recorte, por eso el recorte se amplia hasta llenarlo.
        $foreground = New-Icono -Size $entry.Value -Modo 'recortado'
        try {
            Write-Bitmap -Bitmap $foreground `
            -Path (Join-Path $dir 'ic_launcher_foreground.png')
        }
        finally { $foreground.Dispose() }
    }

    # El icono adaptativo ahora es un bitmap, asi que el "foreground" deja de ser
    # un vector. Se regenera el XML en vez de editarlo a mano para que ejecutar
    # este script sea idempotente.
    $adaptivePath = Join-Path $res 'mipmap-anydpi-v26\ic_launcher.xml'
    $adaptive = @"
<?xml version="1.0" encoding="utf-8"?>
<!--
  Icono adaptativo de Fitki. Generado por tool\generate_launcher_icons.ps1 a
  partir de assets\icon\icon.png: el fondo es el color de marca y el primer
  plano es el recorte central seguro del logo.

  La capa monochrome se omite a proposito: Android 13+ la tine con un unico
  color usando el canal alfa, y un logo opaco produciria un bloque solido.
-->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"@
    if (-not (Test-Path -LiteralPath (Split-Path -Parent $adaptivePath))) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $adaptivePath) -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $adaptivePath, $adaptive, (New-Object System.Text.UTF8Encoding $false))
    "  $adaptivePath"

    # Los vectores de la "F" dejan de hacer falta.
    foreach ($obsoleto in @('drawable\ic_launcher_foreground.xml',
        'drawable\ic_launcher_monochrome.xml')) {
        $path = Join-Path $res $obsoleto
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
            "  (eliminado) $path"
        }
    }

    # ---- iOS -------------------------------------------------------------
    Write-Output 'iOS'
    $iosDir = Join-Path $root 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
    $ios = [ordered]@{
        'Icon-App-20x20@1x.png'     = 20
        'Icon-App-20x20@2x.png'     = 40
        'Icon-App-20x20@3x.png'     = 60
        'Icon-App-29x29@1x.png'     = 29
        'Icon-App-29x29@2x.png'     = 58
        'Icon-App-29x29@3x.png'     = 87
        'Icon-App-40x40@1x.png'     = 40
        'Icon-App-40x40@2x.png'     = 80
        'Icon-App-40x40@3x.png'     = 120
        'Icon-App-60x60@2x.png'     = 120
        'Icon-App-60x60@3x.png'     = 180
        'Icon-App-76x76@1x.png'     = 76
        'Icon-App-76x76@2x.png'     = 152
        'Icon-App-83.5x83.5@2x.png' = 167
        'Icon-App-1024x1024@1x.png' = 1024
    }
    foreach ($entry in $ios.GetEnumerator()) {
        # iOS no admite canal alfa en el icono de la app.
        $icono = New-Icono -Size $entry.Value -Opaco $true
        try { Write-Bitmap -Bitmap $icono -Path (Join-Path $iosDir $entry.Key) }
        finally { $icono.Dispose() }
    }

    # ---- macOS -----------------------------------------------------------
    Write-Output 'macOS'
    $macDir = Join-Path $root 'macos\Runner\Assets.xcassets\AppIcon.appiconset'
    $mac = [ordered]@{
        'app_icon_16.png'   = 16
        'app_icon_32.png'   = 32
        'app_icon_64.png'   = 64
        'app_icon_128.png'  = 128
        'app_icon_256.png'  = 256
        'app_icon_512.png'  = 512
        'app_icon_1024.png' = 1024
    }
    foreach ($entry in $mac.GetEnumerator()) {
        # macOS no recorta el icono, asi que el redondeo va en el propio PNG.
        $icono = New-Icono -Size $entry.Value -Radio 0.22
        try { Write-Bitmap -Bitmap $icono -Path (Join-Path $macDir $entry.Key) }
        finally { $icono.Dispose() }
    }

    # ---- Windows ---------------------------------------------------------
    # Un .ico es un directorio de entradas de 16 bytes seguidas de las imagenes
    # ( aqui PNG, admitidas desde Windows Vista ). Cada entrada lleva ancho, alto,
    # bpp, tamano en bytes y desplazamiento; el tamano depende de la imagen, asi
    # que el directorio se arma en dos pasadas.
    Write-Output 'Windows'
    $icoPath = Join-Path $root 'windows\runner\resources\app_icon.ico'
    $tamanos = @(16, 24, 32, 48, 64, 128, 256)
    $imagenes = New-Object System.Collections.Generic.List[byte[]]
    foreach ($tam in $tamanos) {
        $icono = New-Icono -Size $tam -Radio 0.22
        try { $imagenes.Add((Get-PngBytes -Bitmap $icono)) }
        finally { $icono.Dispose() }
    }

    $ms = New-Object System.IO.MemoryStream
    try {
        $w = New-Object System.IO.BinaryWriter($ms)
        $w.Write([uint16]0)                 # reservado
        $w.Write([uint16]1)                 # 1 = icono
        $w.Write([uint16]$tamanos.Count)
        $desplazamiento = 6 + 16 * $tamanos.Count
        for ($i = 0; $i -lt $tamanos.Count; $i++) {
            $tam = $tamanos[$i]
            $png = $imagenes[$i]
            # En el directorio del .ico el campo de ancho es un byte, asi que
            # 256 se escribe como 0 (asi lo define el formato).
            $lado = [byte]($(if ($tam -ge 256) { 0 } else { $tam }))
            $w.Write($lado)
            $w.Write($lado)
            $w.Write([byte]0)              # sin paleta
            $w.Write([byte]0)              # reservado
            $w.Write([uint16]1)            # planos
            $w.Write([uint16]32)           # bits por pixel
            $w.Write([int]$png.Length)     # bytes de la imagen
            $w.Write([int]$desplazamiento) # desplazamiento en el archivo
            $desplazamiento += $png.Length
        }
        foreach ($png in $imagenes) { $w.Write($png) }
        $w.Flush()
        [System.IO.File]::WriteAllBytes($icoPath, $ms.ToArray())
    }
    finally {
        $ms.Dispose()
    }
    "  $icoPath"

    # ---- Web -------------------------------------------------------------
    Write-Output 'Web'
    $webDir = Join-Path $root 'web'
    $web = [ordered]@{
        'favicon.png'                 = @{ Size = 32;  Opaco = $true;  Modo = 'completo' }
        'icons\Icon-192.png'          = @{ Size = 192; Opaco = $true;  Modo = 'completo' }
        'icons\Icon-512.png'          = @{ Size = 512; Opaco = $true;  Modo = 'completo' }
        'icons\Icon-maskable-192.png' = @{ Size = 192; Opaco = $false; Modo = 'margen' }
        'icons\Icon-maskable-512.png' = @{ Size = 512; Opaco = $false; Modo = 'margen' }
    }
    foreach ($entry in $web.GetEnumerator()) {
        $cfg = $entry.Value
        $icono = New-Icono -Size $cfg.Size -Opaco $cfg.Opaco -Modo $cfg.Modo
        try { Write-Bitmap -Bitmap $icono -Path (Join-Path $webDir $entry.Key) }
        finally { $icono.Dispose() }
    }

    # ---- Tienda ----------------------------------------------------------
    Write-Output 'Tienda'
    $store = New-Icono -Size 512 -Opaco $true
    try {
        Write-Bitmap -Bitmap $store -Path (Join-Path $root 'store\play_store_icon_512.png')
    }
    finally {
        $store.Dispose()
    }
}
finally {
    $logo.Dispose()
}

Write-Output 'Iconos generados.'
