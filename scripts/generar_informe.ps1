param([Parameter(Mandatory = $true)][string]$RegataName)
# --- Motor de Auditoría de Hándicap v6.6 (Basado en handicaps2.jpeg) ---
function Get-OfficialHcp($avgAge, $distanciaOficial, $womenCount) {
    $age = [math]::Floor($avgAge)
    $tabla = @{ 45=0; 46=1; 47=2; 48=3; 49=4; 50=6; 51=8; 52=10; 53=12; 54=14; 55=16; 56=19; 57=22; 58=25; 59=28; 60=31; 61=35; 62=39; 63=43; 64=47; 65=51 }
    $base = if ($age -ge 65) { 51 + ($age - 65) * 4 } elseif ($tabla.ContainsKey($age)) { $tabla[$age] } else { 0 }
    
    $bonusGenero = $womenCount * 5.0
    
    # Coeficiente por tramos oficiales (Tabla 125m)
    $coef = 1.0
    if ($distanciaOficial -ge 4376) { $coef = 1.40 }
    elseif ($distanciaOficial -ge 4251) { $coef = 1.35 }
    elseif ($distanciaOficial -ge 4126) { $coef = 1.30 }
    elseif ($distanciaOficial -ge 4001) { $coef = 1.25 }
    elseif ($distanciaOficial -ge 3876) { $coef = 1.20 }
    elseif ($distanciaOficial -ge 3751) { $coef = 1.15 }
    elseif ($distanciaOficial -ge 3626) { $coef = 1.10 }
    elseif ($distanciaOficial -ge 3501) { $coef = 1.05 }
    elseif ($distanciaOficial -ge 3401) { $coef = 1.00 }
    elseif ($distanciaOficial -ge 3301) { $coef = 0.95 }
    elseif ($distanciaOficial -ge 3201) { $coef = 0.90 }
    elseif ($distanciaOficial -ge 3101) { $coef = 0.85 }
    elseif ($distanciaOficial -ge 3000) { $coef = 0.80 }
    elseif ($distanciaOficial -ge 2875) { $coef = 0.75 }
    elseif ($distanciaOficial -ge 2750) { $coef = 0.70 }
    elseif ($distanciaOficial -ge 2625) { $coef = 0.65 }
    elseif ($distanciaOficial -ge 2500) { $coef = 0.60 }
    
    return [math]::Round(($base + $bonusGenero) * $coef, 1)
}

function Get-ClubRoot([string]$name) {
    if (-not $name) { return "---" }
    $n = $name.ToUpper().Trim()
    if ($n -match "ITSASOKO AMA" -or $n -match "SANTURTZI") { return "SANTURTZI" }
    if ($n -match "BADOK") { return "BADOK" }
    if ($n -match "GETXO") { return "GETXO" }
    if ($n -match "PLENTZIA") { return "PLENTZIA" }
    if ($n -match "IBERIA") { return "IBERIA" }
    if ($n -match "PONTEJOS") { return "PONTEJOS" }
    if ($n -match "ILLUNBE") { return "ILLUNBE" }
    if ($n -match "BILBAO") { return "BILBAO" }
    if ($n -match "AIZBURUA") { return "AIZBURUA" }
    if ($n -match "MUNDAKA") { return "MUNDAKA" }
    return $n.Split(" ")[0]
}

# ---------- Funciones Auxiliares ----------
function TS([string]$t) {
    if (-not $t) { return 0.0 }
    if ($t -match '^(\d+):(\d+)[,.](\d+)$') { return [double]$Matches[1] * 60 + [double]$Matches[2] + [double]("0." + $Matches[3]) }
    return 0.0
}
function DiffStr([double]$a, [double]$b) {
    $d = [math]::Round($a - $b, 1)
    if ($d -ge 0) { return "+${d}s" }
    return "${d}s"
}
function PctStr([double]$a, [double]$b) {
    if ($b -le 0) { return "---" }
    $p = [math]::Round((($a - $b) / $b) * 100, 2)
    return "+${p}%"
}
function ToMMSS([double]$s) {
    if ($s -le 0) { return "00:00,0" }
    $m = [math]::Floor($s / 60)
    $sec = $s - ($m * 60)
    $ss = $sec.ToString("00.0", [System.Globalization.CultureInfo]::InvariantCulture).Replace(".", ",")
    return ("{0:00}:$ss" -f $m)
}
function ConvertTo-HtmlEntity($s) {
    if (-not $s) { return "" }
    return $s.ToString().Replace(([string][char]225), "&aacute;").Replace(([string][char]233), "&eacute;").Replace(([string][char]237), "&iacute;").Replace(([string][char]243), "&oacute;").Replace(([string][char]250), "&uacute;").Replace(([string][char]241), "&ntilde;").Replace(([string][char]193), "&Aacute;").Replace(([string][char]201), "&Eacute;").Replace(([string][char]205), "&Iacute;").Replace(([string][char]211), "&Oacute;").Replace(([string][char]218), "&Uacute;").Replace(([string][char]209), "&Ntilde;").Replace(([string][char]186), "&ordm;").Replace(([string][char]170), "&ordf;").Replace(([string][char]191), "&iquest;").Replace(([string][char]161), "&iexcl;")
}
# HM: parsea formato HH:MM (hora de salida) a minutos decimales para comparar con evolucion_meteo
function HM([string]$t) {
    if ($t -match '^(\d+):(\d+)$') { return [double]$Matches[1] * 60 + [double]$Matches[2] }
    return 0.0
}
function Get-MeteoByTime([string]$timeStr) {
    if (-not $cond.evolucion_meteo) { return $null }
    $t = HM $timeStr
    $best = $null ; $bestDiff = 999999
    foreach ($m in $cond.evolucion_meteo) {
        $mt = HM $m.hora
        $diff = [math]::Abs($t - $mt)
        if ($diff -lt $bestDiff) { $bestDiff = $diff; $best = $m }
    }
    return $best
}

# Icono SVG para alertas (Estandar v5.0)
$svgIcon = "<svg class='alert-icon' width='20' height='20' viewBox='0 0 24 24' fill='none' stroke='#C0001A' stroke-width='2.5' stroke-linecap='round' stroke-linejoin='round'><path d='M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z'></path><line x1='12' y1='9' x2='12' y2='13'></line><line x1='12' y1='17' x2='12.01' y2='17'></line></svg>"

function Get-RowerInfo([string]$name, [string]$posicion) {
    if (-not $name) { return $null }
    $cleanName = $name.Replace(".", "").Trim()
    
    # Busqueda en DB con logica de desambiguacion para Maite
    $rower = $null
    if ($cleanName -ieq "Maite") {
        # --- Lógica de Desambiguación Unificada v4.3 ---
        if ($posicion -ieq "Babor") {
            $rower = $remerosDB | Where-Object { $_.nombre -ieq "Maite Zarra" }
        }
        else {
            $rower = $remerosDB | Where-Object { $_.nombre -ieq "Maite" -and $_.posicion -ieq "Estribor" }
        }
    }
    else {
        $rower = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $cleanName -or $_.apodo -ieq $cleanName } | Select-Object -First 1
    }

    $displayName = $name
    $imgBase64 = ""
    $apodo = ""
    $altura = 0
    $peso = 0.0
    $anios = 0

    if ($rower) {
        if ($rower.PSObject.Properties['apodo'] -and $rower.apodo) {
            $apodo = $rower.apodo
            $displayName = $rower.apodo
        }
        
        # Captura robusta de métricas (permitir cualquier tipo numérico)
        try {
            if ($rower.PSObject.Properties['altura_cm'] -and $rower.altura_cm -match '^\d') { $altura = [double]$rower.altura_cm }
            if ($rower.PSObject.Properties['peso_kg'] -and $rower.peso_kg -match '^\d') { $peso = [double]$rower.peso_kg }
            
            # Busqueda robusta de experiencia (evitar problemas con la 'ñ' en PowerShell)
            $propAnios = $rower.PSObject.Properties | Where-Object { $_.Name -match 'experiencia' -and ($_.Name -match 'a.os' -or $_.Name -match 'anios') } | Select-Object -First 1
            if ($propAnios -and ($propAnios.Value -as [double] -ge 0)) { $anios = [double]$propAnios.Value }
        } catch { }

        # Intentar cargar foto
        $photoFile = ""
        if ($apodo) { $photoFile = Join-Path $remerosPath "$apodo.jpg" }
        if (($photoFile -eq "") -or (-not (Test-Path $photoFile))) { $photoFile = Join-Path $remerosPath "$($rower.nombre).jpg" }
        if (-not (Test-Path $photoFile)) { $photoFile = Join-Path $remerosPath "$cleanName.jpg" }

        if (Test-Path $photoFile) {
            $bytes = [System.IO.File]::ReadAllBytes($photoFile)
            $imgBase64 = [System.Convert]::ToBase64String($bytes)
        }
    }

    # --- Perfil Estándar para Datos Nulos (v4.2) ---
    if ($peso -le 0)   { $peso = 78.0 }   # Peso estándar Aizburua
    if ($altura -le 0) { $altura = 175 }  # Altura estándar Aizburua

    return [PSCustomObject]@{
        DisplayName  = $displayName.ToUpper()
        ImgBase64    = $imgBase64
        OriginalName = $name
        Altura       = $altura
        Peso         = $peso
        Anios        = $anios
    }
}

# Set-StrictMode -Version Latest # Deshabilitado para permitir acceso flexible a propiedades JSON opcionales
$ErrorActionPreference = "Stop"
$rootPath = Resolve-Path (Join-Path $PSScriptRoot "..") 
$jsonPath = Join-Path $rootPath "data\historico-regatas.json"
$plantillaPath = Join-Path $rootPath "data\plantilla_remeros.json"
$remerosPath = Join-Path $rootPath "remeros"
$outPath = Join-Path $rootPath "informes"
$safe = $RegataName -replace '[^\w]', '_'
$htmlFile = Join-Path $outPath "Informe_Aizburua_$safe.html"

if (-not(Test-Path $outPath)) { New-Item -ItemType Directory -Path $outPath | Out-Null }
$data = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
$regata = $data.regatas | Where-Object { $_.nombre_corto -eq $RegataName -or $_.nombre -like "*$RegataName*" } | Select-Object -First 1
if (-not $regata) { Write-Error "Regata no encontrada en el historico"; exit 1 }

$remerosDB = @()
if (Test-Path $plantillaPath) {
    $remerosDB = Get-Content $plantillaPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

$cond = $regata.condiciones_campo
$aizd = $regata.aizburua

$ali = $null
if ($aizd.PSObject.Properties['alineacion']) { $ali = $aizd.alineacion }
$g1 = $null
if ($regata.grupos.PSObject.Properties['grupo_1']) { $g1 = $regata.grupos.grupo_1 }
$g2 = $null
if ($regata.grupos.PSObject.Properties['grupo_2']) { $g2 = $regata.grupos.grupo_2 }

# Resultados y Top 3 (usando Grupo 1 por defecto o el que contenga a Aizburua)
$mainGroup = $g1
if ($aizd.PSObject.Properties['grupo']) { $mainGroup = $regata.grupos.$($aizd.grupo) }
$res = @()
if ($mainGroup) { 
    # Filtrar invitados (Sestao, Castreña) si el usuario lo prefiere para el análisis de liga
    $res = @($mainGroup.resultados | Where-Object { $_.club -notmatch "SESTAO|CASTREÑA" } | Sort-Object { [double]($_.puesto) })
}
$aiz = $res | Where-Object { $_.club -eq "AIZBURUA" } | Select-Object -First 1
$top1 = $res | Where-Object { [int]$_.puesto -eq 1 } | Select-Object -First 1
$top2 = $res | Where-Object { [int]$_.puesto -eq 2 } | Select-Object -First 1
$top3 = $res | Where-Object { [int]$_.puesto -eq 3 } | Select-Object -First 1

# ---------- Activos Visuales (Logos) ----------
$logo1Base64 = "" ; $logo2Base64 = ""
$logo1Path = Join-Path $rootPath "Logo1.jpg"
$logo2Path = Join-Path $rootPath "Logo2.jpg"

if (Test-Path $logo1Path) {
    $bytes = [System.IO.File]::ReadAllBytes($logo1Path)
    $logo1Base64 = [System.Convert]::ToBase64String($bytes)
}
if (Test-Path $logo2Path) {
    $bytes = [System.IO.File]::ReadAllBytes($logo2Path)
    $logo2Base64 = [System.Convert]::ToBase64String($bytes)
}


# ---------- Calculos de tiempos ----------
$sa = 0; $sg = 0; $s2t = 0; $s3t = 0; $sciaAiz = 0; $sciaG1 = 0; $sciaG2 = 0; $sciaG3 = 0
$tanda1 = $null

if ($aiz) { $sa = TS ($aiz | Select-Object -ExpandProperty tiempo_raw -ErrorAction SilentlyContinue) }
if ($top1) { $sg = TS ($top1 | Select-Object -ExpandProperty tiempo_raw -ErrorAction SilentlyContinue) }
if ($top2) { $s2t = TS ($top2 | Select-Object -ExpandProperty tiempo_raw -ErrorAction SilentlyContinue) }
if ($top3) { $s3t = TS ($top3 | Select-Object -ExpandProperty tiempo_raw -ErrorAction SilentlyContinue) }

$avgG1 = 0 ; $mediaG1Fmt = "00:00,0"
if ($res) {
    try {
        $avgG1 = [math]::Round(($res | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
        $mediaG1Fmt = ToMMSS $avgG1
    }
    catch { }
}

if ($mainGroup -and $aiz) {
    $tanda1 = $mainGroup.resultados | Where-Object { $_.tanda -eq $aiz.tanda }
}

$avgT1 = 0 ; $mediaT1Fmt = "00:00,0"
if ($tanda1) {
    try {
        $avgT1 = [math]::Round(($tanda1 | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
        $mediaT1Fmt = ToMMSS $avgT1
    }
    catch { }
}

# Ciabogas (Segundos y Diferenciales)
if ($aiz) { $sciaAiz = TS ($aiz | Select-Object -ExpandProperty ciaboga_1 -ErrorAction SilentlyContinue) }
if ($top1) { $sciaG1 = TS ($top1 | Select-Object -ExpandProperty ciaboga_1 -ErrorAction SilentlyContinue) }
if ($top2) { $sciaG2 = TS ($top2 | Select-Object -ExpandProperty ciaboga_1 -ErrorAction SilentlyContinue) }
if ($top3) { $sciaG3 = TS ($top3 | Select-Object -ExpandProperty ciaboga_1 -ErrorAction SilentlyContinue) }

$dCiaG1 = DiffStr $sciaG1 $sciaAiz
$dCiaG2 = DiffStr $sciaG2 $sciaAiz
$dCiaG3 = DiffStr $sciaG3 $sciaAiz

$avgCiaG1 = 0 ; $mediaCiaG1Fmt = "00:00,0"
if ($mainGroup) {
    try {
        $avgCiaG1 = [math]::Round(($mainGroup.resultados | ForEach-Object { 
                    if ($_.PSObject.Properties['ciaboga_1']) { TS $_.ciaboga_1 } else { 0 } 
                } | Measure-Object -Average | Select-Object -ExpandProperty Average), 1)
        $mediaCiaG1Fmt = ToMMSS $avgCiaG1
    }
    catch { }
}
$dCiaMediaG1 = DiffStr $avgCiaG1 $sciaAiz

$avgCiaT1 = 0 ; $mediaCiaT1Fmt = "00:00,0"
if ($tanda1) {
    try {
        $avgCiaT1 = [math]::Round(($tanda1 | ForEach-Object { 
                    if ($_.PSObject.Properties['ciaboga_1']) { TS $_.ciaboga_1 } else { 0 } 
                } | Measure-Object -Average | Select-Object -ExpandProperty Average), 1)
        $mediaCiaT1Fmt = ToMMSS $avgCiaT1
    }
    catch { }
}
$dCiaMediaT1 = DiffStr $avgCiaT1 $sciaAiz

# ---------- ANALISIS DINAMICO DE CALLES ----------
$lanesData = @{}
$callesProps = $cond.geometria.PSObject.Properties | Where-Object { $_.Name -like "calle*" }
foreach ($prop in $callesProps) {
    try {
        $cIdStr = $prop.Name -replace "calle", ""
        if (-not $cIdStr) { continue }
        $cId = [int]$cIdStr
        $cResults = $mainGroup.resultados | Where-Object { [int]$_.calle -eq $cId }
        if ($cResults) {
            $avg = [math]::Round(($cResults | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
            $dif = [math]::Round($avg - $avgG1, 1)
            $difStr = "${dif}s"
            if ($dif -gt 0) { $difStr = "+${dif}s" }
            $lanesData[$cId] = @{ 
                avg    = $avg; 
                fmt    = ToMMSS $avg; 
                dif    = $dif; 
                difStr = $difStr;
                label  = $prop.Value.color;
                pos    = $prop.Value.posicion
            }
        }
    }
    catch { 
        Write-Host "Aviso: Error procesando calle $($prop.Name): $($_.Exception.Message)"
    }
}

# Determinar mejor y peor calle
$mejorCalleId = 1 ; $peorCalleId = 1
$minDif = 999.0 ; $maxDif = -999.0
foreach ($cid in $lanesData.Keys) {
    if ($lanesData[$cid].dif -lt $minDif) { $minDif = $lanesData[$cid].dif; $mejorCalleId = $cid }
    if ($lanesData[$cid].dif -gt $maxDif) { $maxDif = $lanesData[$cid].dif; $peorCalleId = $cid }
}

$aizCalle = 1
if ($aiz) { $aizCalle = [int]$aiz.calle }
$saAiz = if ($aiz) { TS $aiz.tiempo_raw } else { 0 }

$mejorDifVal = 0
if ($lanesData.ContainsKey($mejorCalleId)) { $mejorDifVal = $lanesData[$mejorCalleId].dif }
$aizDifPropia = 0
if ($lanesData.ContainsKey($aizCalle)) { $aizDifPropia = $lanesData[$aizCalle].dif }

$sProy = $saAiz - $aizDifPropia + $mejorDifVal
$tProyFmt = ToMMSS $sProy
$puestoProy = ($mainGroup.resultados | Where-Object { (TS $_.tiempo_raw) -le $sProy } | Measure-Object).Count + 1

$veredictoCalles = "Topografia del campo analizada en modalidad N-Calles."
if ([math]::Abs($maxDif - $minDif) -gt 5) {
    $veredictoCalles = "La Calle $peorCalleId fue considerablemente desfavorable (+$( [math]::Round($maxDif - $minDif, 1) )s de diferencia vs $mejorCalleId)."
}

# Analisis por tanda
$tandas = $mainGroup.resultados | Select-Object -ExpandProperty tanda | Sort-Object -Unique
$tandaRows = [System.Collections.Generic.List[string]]::new()
$prevAvgT = 0.0
foreach ($t in $tandas) {
    $tRes = $mainGroup.resultados | Where-Object { $_.tanda -eq $t } | Sort-Object hora_salida
    $horaIni = ($tRes | Select-Object -First 1).hora_salida
    $horaFin = ($tRes | Select-Object -Last 1).hora_salida
    $rangoHora = if ($horaIni -eq $horaFin) { "${horaIni}h" } else { "${horaIni}h a ${horaFin}h" }
    
    $avgT = [math]::Round(($tRes | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
    $fmtT = ToMMSS $avgT
    $rc1 = $tRes | Where-Object { $_.calle -eq 1 }
    $rc2 = $tRes | Where-Object { $_.calle -eq 2 }
    $ac1 = if ($rc1) { [math]::Round((TS ($rc1 | Select-Object -First 1).tiempo_raw), 1) }else { -1 }
    $ac2 = if ($rc2) { [math]::Round((TS ($rc2 | Select-Object -First 1).tiempo_raw), 1) }else { -1 }

    $tandaMeteo = Get-MeteoByTime $horaIni
    $mPill = ""
    if ($tandaMeteo) { 
        $corrFmt = $tandaMeteo.corriente.Replace("Vaciante", "Marea Bajando")
        $mPill = "<br><span style='font-size:9px; color:#c0001a'>Viento: $($tandaMeteo.viento_kmh) km/h | Ola: $($tandaMeteo.ola_m)m | $corrFmt</span>" 
    }
    $calleComent = ""
    if ($ac1 -gt 0 -and $ac2 -gt 0) {
        $difCC = [math]::Round($ac1 - $ac2, 1)
        if ($difCC -gt 3) { $calleComent = " - Calle 1 (Blanca) fue +${difCC}s m&aacute;s lenta que Calle 2 (Roja)" }
        elseif ($difCC -lt -3) { $difCCa = [math]::Abs($difCC); $calleComent = " - Calle 2 (Roja) fue +${difCCa}s m&aacute;s lenta que Calle 1 (Blanca)" }
        else { $calleComent = " - Ambas calles similares en esta tanda" }
    }
    elseif ($ac1 -gt 0) {
        $calleComent = " - Modalidad Calle &Uacute;nica (Contrarreloj)"
    }

    $tendComent = ""
    if ($prevAvgT -gt 0) {
        $delt = [math]::Round($avgT - $prevAvgT, 1)
        if ($delt -lt -2) { $aDelt = [math]::Abs($delt); $tendComent = "<span class='tendencia-buena'>Mejora de ranking (-${aDelt}s vs tanda anterior)</span>" }
        elseif ($delt -gt 2) { $tendComent = "<span class='tendencia-mala'>P&eacute;rdida de ritmo (+${delt}s vs tanda anterior)</span>" }
        else { $tendComent = "Tiempos estables entre tandas" }
    }
    else { $tendComent = "Referencia inicial (Grupo 1)" }

    $avgVel = [math]::Round($regata.distancia_m / $avgT, 2)
    $fmtTandaVal = "$fmtT <span style='font-size:10px; color:#666'>($avgVel m/s)</span>"
    $aizMark = if ($t -eq $aiz.tanda) { ' class="aiz"' }else { "" }
    $tandaRows.Add("<tr${aizMark}><td><strong>Tanda $t</strong></td><td>${rangoHora}$mPill</td><td>$fmtTandaVal</td><td>${tendComent}${calleComent}</td></tr>")
    $prevAvgT = $avgT
}
$ultimaTanda = ($tandas | Measure-Object -Maximum).Maximum
$trUlt = $mainGroup.resultados | Where-Object { $_.tanda -eq $ultimaTanda }
$avgUlt = [math]::Round(($trUlt | ForEach-Object { TS $_.tiempo_raw } | Measure-Object -Average).Average, 1)
$difGlobal = [math]::Round($avgT1 - $avgUlt, 1)
$tendenciaGlobal = if ($difGlobal -gt 2) { "Las tandas finales promediaron ${difGlobal}s menos que la Tanda 1. Comportamiento l&oacute;gico por el ranking de los botes." }
elseif ($difGlobal -lt -2) { $dga = [math]::Abs($difGlobal); "<strong>AVISO:</strong> Las tandas finales promediaron ${dga}s m&aacute;s lentas. El campo se endureci&oacute; para los cabezas de serie." }
else { "Tiempos muy consistentes en todo el grupo (${difGlobal}s)." }

# Detectar columnas de ciaboga dinámicamente en los resultados
$ciabogasHeader = @()
$resArr = @($res)
if ($resArr.Count -gt 0) {
    foreach ($prop in $resArr[0].PSObject.Properties.Name) {
        if ($prop -like "ciaboga_*") { $ciabogasHeader += $prop }
    }
}
$ciabogasHeader = $ciabogasHeader | Sort-Object

# Tablas de clasificacion
$trG1 = [System.Text.StringBuilder]::new()
if ($g1 -and $g1.resultados) {
    foreach ($r in ($g1.resultados | Sort-Object puesto)) {
        $cls = if ($r.club -eq "AIZBURUA") { ' class="aiz"' } else { "" }
        $ciaCells = ""
        foreach ($ciaKey in $ciabogasHeader) {
            $ciaVal = if ($r.$ciaKey) { $r.$ciaKey } else { "---" }
            $ciaCells += "<td>$ciaVal</td>"
        }
        [void]$trG1.AppendLine("<tr${cls}><td>$($r.puesto)&ordm;</td><td>$($r.club)</td><td>$($r.hora_salida)h</td><td>T$($r.tanda) C$($r.calle)</td>${ciaCells}<td>$($r.tiempo_raw)</td><td>$($r.handicap)</td><td><strong>$($r.tiempo_final)</strong></td></tr>")
    }
}

$trG2 = [System.Text.StringBuilder]::new()
if ($g2 -and $g2.resultados) {
    foreach ($r in ($g2.resultados | Sort-Object puesto)) {
        $cls = if ($r.club -eq "AIZBURUA") { ' class="aiz"' } else { "" }
        $ciaCells = ""
        foreach ($ciaKey in $ciabogasHeader) {
            $ciaVal = if ($r.$ciaKey) { $r.$ciaKey } else { "---" }
            $ciaCells += "<td>$ciaVal</td>"
        }
        [void]$trG2.AppendLine("<tr${cls}><td>$($r.puesto)&ordm;</td><td>$($r.club)</td><td>$($r.hora_salida)h</td><td>T$($r.tanda) C$($r.calle)</td>${ciaCells}<td>$($r.tiempo_raw)</td><td>$($r.handicap)</td><td><strong>$($r.tiempo_final)</strong></td></tr>")
    }
}
# Construccion tabla alineacion con edades (ahora con FOTOS y APODOS)
$trAli = [System.Text.StringBuilder]::new()

function New-RowerCell($name, $pos, $isBabor) {
    $info = Get-RowerInfo $name $pos
    $imgHtml = ""
    if ($info.ImgBase64) {
        $imgHtml = "<img src='data:image/jpeg;base64,$($info.ImgBase64)' class='r-avatar' alt='$name'>"
    }
    else {
        $imgHtml = "<div class='r-avatar' style='display:flex;align-items:center;justify-content:center;font-weight:900;color:#999'>?</div>"
    }
    
    $sideBdg = if ($isBabor) { "<span class='bdg'>B</span>" } else { "<span class='bdg'>E</span>" }
    $meta = "$sideBdg"
    
    # --- Alertas Tácticas v4.3 ---
    $nameStyle = ""
    $pesoStyle = ""
    if ($pos -match "1 - POPA" -and $info.Peso -gt 85) { $nameStyle = "color:#C0001A; font-weight:900; text-decoration:underline" }
    if ($pos -match "Bancada [34]" -and $info.Edad -gt 65) { $nameStyle = "color:#C0001A; font-weight:900" }
    if ($pos -match "Proa|Bancada 6" -and $info.Peso -gt 75) { $pesoStyle = "color:#C0001A; font-weight:bold" }

    # Usar datos ya obtenidos por Get-RowerInfo
    if ($info.Peso -gt 0) { $meta += " | <strong style='$pesoStyle'>$($info.Peso)</strong> kg" }
    if ($info.Altura -gt 0) { $meta += " | $($info.Altura) cm" }
    if ($info.Anios -ge 0) { $meta += " | $($info.Anios) &ntilde;os exp" }

    return "<div class='r-cell'>$imgHtml <div class='r-info'><span class='r-name' style='$nameStyle'>$(ConvertTo-HtmlEntity $info.DisplayName)</span><span class='r-meta'>$meta</span></div></div>"
}

# --- PROA ---
$proaCell = New-RowerCell $ali.proa.nombre "Proa" $false
[void]$trAli.AppendLine("<tr class='proa-row'><td class='bn'>PROA</td><td colspan='2' style='text-align:center'>$proaCell</td></tr>")

# --- BANCADAS (Auditoría v6.0) ---
foreach ($n in 6..1) {
    $b = $ali.bancadas."$n"
    $lbl = if ($n -eq 1) { "1 - POPA" } else { "$n" }
    
    $rB = Get-RowerInfo $b.B.nombre "Babor"
    $rE = Get-RowerInfo $b.E.nombre "Estribor"
    
    $bCell = New-RowerCell $b.B.nombre "Babor" $true
    $eCell = New-RowerCell $b.E.nombre "Estribor" $false
    
    $difBancada = [math]::Abs($rB.Peso - $rE.Peso)
    $alertaEq = ""
    $limiteEq = if ($lbl -match "6") { 10 } else { 15 }
    if ($difBancada -gt $limiteEq) {
        $alertaEq = "<tr><td colspan='3'><div class='tactical-alert'>$svgIcon <strong>ALERTA DE EQUILIBRIO:</strong> Asimetr&iacute;a cr&iacute;tica en Bancada $lbl ($([math]::Round($difBancada,1)) kg). El bote tiende a escorar hacia $(if($rB.Peso -gt $rE.Peso){"Babor"}else{"Estribor"}).</div></td></tr>"
    }

    [void]$trAli.AppendLine("<tr><td class='bn'>Bancada $lbl</td><td class='bab'>$bCell</td><td class='est'>$eCell</td></tr>")
    if ($alertaEq) { [void]$trAli.AppendLine($alertaEq) }
}

# --- PATRON ---
$patronCell = New-RowerCell $ali.patron.nombre "Patron" $false
[void]$trAli.AppendLine("<tr class='patron-row'><td class='bn'>PATRON</td><td colspan='2' style='text-align:center'>$patronCell</td></tr>")

# Calculos de estad&iacute;sticas de edad, peso y talla
$edadesConfirmadas = [System.Collections.Generic.List[int]]::new()
$pesosTotal = [System.Collections.Generic.List[double]]::new()
$pesosBabor = [System.Collections.Generic.List[double]]::new()
$pesosEstribor = [System.Collections.Generic.List[double]]::new()
$tallasMotor = [System.Collections.Generic.List[int]]::new()
$tallasResto = [System.Collections.Generic.List[int]]::new()

function Collect-RowerData($name, $pos, $side) {
    $r = Get-RowerInfo $name $pos
    if ($r.Peso -gt 0) { 
        [void]$pesosTotal.Add([double]$r.Peso) 
        if ($side -eq "Babor") { [void]$pesosBabor.Add([double]$r.Peso) }
        elseif ($side -eq "Estribor") { [void]$pesosEstribor.Add([double]$r.Peso) }
    }
    # Edades y Experience
    $clean = $name.Replace(".", "").Trim()
    $dbRower = $null
    if ($clean -ieq "Maite") {
        if ($pos -ieq "Babor") { $dbRower = $remerosDB | Where-Object { $_.nombre -ieq "Maite Zarra" } }
        else { $dbRower = $remerosDB | Where-Object { $_.nombre -ieq "Maite" -and $_.posicion -ieq "Estribor" } }
    } else {
        $dbRower = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $clean -or $_.apodo -ieq $clean } | Select-Object -First 1
    }
    
    if ($dbRower -and $dbRower.edad) { [void]$edadesConfirmadas.Add([int]$dbRower.edad) }
}

# Procesar tripulación
Collect-RowerData $ali.proa.nombre "Proa" "Proa"
Collect-RowerData $ali.patron.nombre "Patron" "Patron"
foreach ($n in 1..6) {
    Collect-RowerData $ali.bancadas."$n".B.nombre "Babor" "Babor"
    Collect-RowerData $ali.bancadas."$n".E.nombre "Estribor" "Estribor"
    
    # Recoger tallas para analisis de motor
    $rB = Get-RowerInfo $ali.bancadas."$n".B.nombre "Babor"
    $rE = Get-RowerInfo $ali.bancadas."$n".E.nombre "Estribor"
    if ($n -match "3|4|5") {
        if ($rB.Altura -gt 0) { [void]$tallasMotor.Add($rB.Altura) }
        if ($rE.Altura -gt 0) { [void]$tallasMotor.Add($rE.Altura) }
    } else {
        if ($rB.Altura -gt 0) { [void]$tallasResto.Add($rB.Altura) }
        if ($rE.Altura -gt 0) { [void]$tallasResto.Add($rE.Altura) }
    }
}

$pesoTripulacion = ($pesosTotal | Measure-Object -Sum).Sum
$pesoBabor = ($pesosBabor | Measure-Object -Sum).Sum
$pesoEstribor = ($pesosEstribor | Measure-Object -Sum).Sum
$difPeso = [math]::Round($pesoBabor - $pesoEstribor, 1)

$totalConfirm = $edadesConfirmadas.Count
$totalMiembros = 14
$edadMedia = if ($edadesConfirmadas.Count -gt 0) { [math]::Round(($edadesConfirmadas | Measure-Object -Average).Average, 1) }else { $null }
$edadMediaStr = if ($edadMedia) { "${edadMedia} a&ntilde;os" }else { "Pendiente" }
$edadMin = if ($edadesConfirmadas.Count -gt 0) { ($edadesConfirmadas | Measure-Object -Minimum).Minimum }else { $null }
$edadMax = if ($edadesConfirmadas.Count -gt 0) { ($edadesConfirmadas | Measure-Object -Maximum).Maximum }else { $null }
$edadRangoStr = if ($null -ne $edadMin -and $null -ne $edadMax) { "${edadMin} - ${edadMax} a&ntilde;os" }else { "Pendiente" }


# Analisis especifico por bloque Popa (bancadas 1-2) vs Proa (bancadas 5-6)
$edadesBloquePopa = [System.Collections.Generic.List[int]]::new()
$edadesBloqueCentral = [System.Collections.Generic.List[int]]::new()
$edadesBloqueProa = [System.Collections.Generic.List[int]]::new()
foreach ($n in 1..2) {
    $b = $ali.bancadas."$n"
    $rB = Get-RowerInfo $b.B.nombre "Babor" ; $rE = Get-RowerInfo $b.E.nombre "Estribor"
    if ($rB.Anios -gt 0) { [void]$edadesBloquePopa.Add($rB.Anios) } # Usamos experiencia para estos bloques? No, el skill pide EDAD real.
}
# Re-hacer bloques con edad real
$edadesBloquePopa.Clear(); $edadesBloqueCentral.Clear(); $edadesBloqueProa.Clear()
foreach ($n in 1..2) {
    $b = $ali.bancadas."$n"
    $dbB = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.B.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.B.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    $dbE = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.E.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.E.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    if ($dbB.edad) { [void]$edadesBloquePopa.Add($dbB.edad) }
    if ($dbE.edad) { [void]$edadesBloquePopa.Add($dbE.edad) }
}
foreach ($n in 3..4) {
    $b = $ali.bancadas."$n"
    $dbB = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.B.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.B.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    $dbE = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.E.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.E.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    if ($dbB.edad) { [void]$edadesBloqueCentral.Add($dbB.edad) }
    if ($dbE.edad) { [void]$edadesBloqueCentral.Add($dbE.edad) }
}
foreach ($n in 5..6) {
    $b = $ali.bancadas."$n"
    $dbB = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.B.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.B.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    $dbE = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $b.E.nombre.Replace(".", "").Trim() -or $_.apodo -ieq $b.E.nombre.Replace(".", "").Trim() } | Select-Object -First 1
    if ($dbB.edad) { [void]$edadesBloqueProa.Add($dbB.edad) }
    if ($dbE.edad) { [void]$edadesBloqueProa.Add($dbE.edad) }
}

$avgBloquePopa = if ($edadesBloquePopa.Count -gt 0) { [math]::Round(($edadesBloquePopa | Measure-Object -Average).Average, 1) }else { $null }
$avgBloqueCentral = if ($edadesBloqueCentral.Count -gt 0) { [math]::Round(($edadesBloqueCentral | Measure-Object -Average).Average, 1) }else { $null }
$avgBloqueProa = if ($edadesBloqueProa.Count -gt 0) { [math]::Round(($edadesBloqueProa | Measure-Object -Average).Average, 1) }else { $null }
$avgPopaStr = if ($avgBloquePopa) { "${avgBloquePopa} a&ntilde;os" }else { "Pendiente" }
$avgCentralStr = if ($avgBloqueCentral) { "${avgBloqueCentral} a&ntilde;os" }else { "Pendiente" }
$avgProaStr = if ($avgBloqueProa) { "${avgBloqueProa} a&ntilde;os" }else { "Pendiente" }

# Variables planas para el HTML
$aizGroupName = if ($aizd.grupo) { $aizd.grupo } else { "grupo_1" }
$aizPuesto = $aizd.puesto_en_grupo
$aizTotal = $aizd.total_en_grupo
$aizCalle = if ($aiz.calle) { [int]$aiz.calle } else { 0 }
$aizTanda = $aiz.tanda
$aizHora = $aiz.hora_salida
$aizHcp = $aiz.handicap
$aizRaw = $aiz.tiempo_raw
$aizFin = $aiz.tiempo_final
$aizCiab = $aiz.ciaboga_1
$t1Nom = $top1.club ; $t1Raw = $top1.tiempo_raw ; $t1Hora = $top1.hora_salida ; $t1T = $top1.tanda ; $t1C = $top1.calle ; $t1Ciab = $top1.ciaboga_1
$t2Nom = $top2.club ; $t2Raw = $top2.tiempo_raw ; $t2Hora = $top2.hora_salida ; $t2T = $top2.tanda ; $t2C = $top2.calle ; $t2Ciab = $top2.ciaboga_1
$t3Nom = $top3.club ; $t3Raw = $top3.tiempo_raw ; $t3Hora = $top3.hora_salida ; $t3T = $top3.tanda ; $t3C = $top3.calle ; $t3Ciab = $top3.ciaboga_1
$RegNombre = $regata.nombre
$RegFecha = $regata.fecha

$numLargos = 2
if ($regata.PSObject.Properties['num_largos']) {
    $numLargos = [int]$regata.num_largos
}

$numCiabogas = 1
if ($regata.PSObject.Properties['num_ciabogas']) {
    $numCiabogas = [int]$regata.num_ciabogas
} elseif ($numLargos -gt 1) {
    $numCiabogas = $numLargos - 1
} else {
    $numCiabogas = 0
}

$distDetail = ""
if ($regata.PSObject.Properties['detalles_distancia']) {
    $distDetail = " ($($regata.detalles_distancia))"
}

# Calcular Puesto Raw (Potencia Bruta sin Handicap comparando tiempos Raw reales)
$sAizRaw = TS $aiz.tiempo_raw
$aizPuestoRaw = ($mainGroup.resultados | Where-Object { (TS $_.tiempo_raw) -lt $sAizRaw } | Measure-Object).Count + 1

# Calcular Puesto Normalizado (Tiempo Final descontando Handicap de Calle comparado con Tiempos Finales)
$sAizFin = TS $aiz.tiempo_final
$sAizNorm = $sAizFin - $difC1
$aizPuestoNorm = ($mainGroup.resultados | Where-Object { (TS $_.tiempo_final) -lt $sAizNorm } | Measure-Object).Count + 1

$RegLugar = $regata.lugar
Write-Host "DEBUG: Iniciando calculos de tiempos..."
$g1Hora = $(if ($g1) { $g1.hora_inicio } else { "---" })
$g1FinHora = "---"
if ($g1 -and $g1.resultados) {
    $resTmp = @($g1.resultados | Sort-Object { HM $_.hora_salida })
    if ($resTmp.Count -gt 0) { $g1FinHora = $resTmp[-1].hora_salida }
}
$g2Hora = $(if ($g2) { $g2.hora_inicio } else { "---" })
$g2FinHora = "---"
if ($g2 -and $g2.resultados) {
    $resTmp2 = @($g2.resultados | Sort-Object { HM $_.hora_salida })
    if ($resTmp2.Count -gt 0) { $g2FinHora = $resTmp2[-1].hora_salida }
}
$g1Gan = $(if ($g1) { $g1.ganador } else { "" })
$g1GanRaw = $(if ($g1) { $g1.tiempo_ganador_raw } else { "" })
$g1GanFin = $(if ($g1) { $g1.tiempo_ganador_final } else { "" })
$g2Gan = $(if ($g2) { $g2.ganador } else { "" })
$g2GanRaw = $(if ($g2) { $g2.tiempo_ganador_raw } else { "" })
$g2GanFin = $(if ($g2) { $g2.tiempo_ganador_final } else { "" })

$mainGroupHora = $(if ($mainGroup) { $mainGroup.hora_inicio } else { "---" })
$mainGroupFinHora = "---"
if ($mainGroup -and $mainGroup.resultados) {
    $resTmpM = @($mainGroup.resultados | Sort-Object { HM $_.hora_salida })
    if ($resTmpM.Count -gt 0) { $mainGroupFinHora = $resTmpM[-1].hora_salida }
}

# ---------- METEOROLOGIA REAL (Boga Aizburua) ----------
$meteoReal = Get-MeteoByTime $aizHora
$CondVkmh = $(if ($meteoReal.viento_kmh) { $meteoReal.viento_kmh } else { $cond.viento.velocidad_kmh })
$CondVms = [math]::Round($CondVkmh / 3.6, 1)
$CondVdir = $(if ($meteoReal.viento_dir) { $meteoReal.viento_dir } else { $cond.viento.direccion })
$CondVdesc = "Fuerza $($cond.viento.fuerza_beaufort) Beaufort"
$CondOla = $(if ($meteoReal.ola_m) { $meteoReal.ola_m } else { $cond.olas.altura_m })
$CondMar = $(if ($meteoReal.ola_desc) { $meteoReal.ola_desc } else { "$($cond.olas.tipo) ($($cond.olas.direccion))" })

$CondAire = $cond.temperatura_aire_c
$CondAgua = $cond.temperatura_agua_c
$CondSal = $cond.salinidad_psu

# Auditoría de Hándicap Aizburua
$countFem = 0
foreach ($name in @($ali.proa.nombre, $ali.patron.nombre)) {
    $dbR = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $name.Replace(".", "").Trim() -or $_.apodo -ieq $name.Replace(".", "").Trim() } | Select-Object -First 1
    if ($dbR.genero -ieq "Femenino" -and $dbR.edad -ge 45) { $countFem++ }
}
foreach ($n in 1..6) {
    foreach ($side in @("B", "E")) {
        $name = $ali.bancadas."$n".$side.nombre
        $dbR = $remerosDB | Where-Object { $_.nombre.Replace(".", "").Trim() -ieq $name.Replace(".", "").Trim() -or $_.apodo -ieq $name.Replace(".", "").Trim() } | Select-Object -First 1
        if ($dbR.genero -ieq "Femenino" -and $dbR.edad -ge 45) { $countFem++ }
    }
}

$hcpTeorico = Get-OfficialHcp $edadMedia $regata.distancia_m $countFem
$hcpOficial = TS $aizHcp
$discrepanciaHcp = [math]::Abs($hcpTeorico - $hcpOficial)
$alertaHcpHtml = ""
# if ($discrepanciaHcp -gt 0.2) {
#     $alertaHcpHtml = "<div class='tactical-alert' style='margin-top:10px; border-left-color:#1e3a5f; background:#f0f4ff'><strong>AUDITOR&Iacute;A DE H&Aacute;NDICAP:</strong> El h&aacute;ndicap asignado ($hcpOficial s) difiere del c&aacute;lculo te&oacute;rico ($hcpTeorico s) seg&uacute;n la tabla oficial de tramos para $($regata.distancia_m)m. Recomienda revisi&oacute;n con el comit&eacute;.</div>"
# }

# Densidad calculada dinamicamente
$CondDens = [math]::Round(1000 + ($CondSal * 0.7) + (0.006 * (1500 - ($CondAgua * 100))), 1)
$CondCoef = $cond.marea.coeficiente
$MareaPM = $cond.marea.pleamar_1
$MareaBM = $cond.marea.bajamar_diurna
$MareaEst = $(if ($meteoReal.corriente) { $meteoReal.corriente } else { $cond.marea.estado_en_regata })

# Inicialización de tiempos para comparativas
$sa = 0.0
$sg = 0.0
$s2t = 0.0
$s3t = 0.0
if ($aiz)  { $sa = TS $aiz.tiempo_raw }
if ($top1) { $sg = TS $top1.tiempo_raw }
if ($top2) { $s2t = TS $top2.tiempo_raw }
if ($top3) { $s3t = TS $top3.tiempo_raw }
$avgG1 = TS $mediaG1Fmt
$avgT1 = TS $mediaT1Fmt

$dG1 = DiffStr $sg $sa
$pG1 = PctStr $sg $sa
$dG2 = DiffStr $s2t $sa
$pG2 = PctStr $s2t $sa
$dG3 = DiffStr $s3t $sa
$pG3 = PctStr $s3t $sa
$dGm1 = DiffStr $avgG1 $sa
$pGm1 = PctStr $avgG1 $sa
$dTm1 = DiffStr $avgT1 $sa
$pTm1 = PctStr $avgT1 $sa

    # ---------- ANALISIS RIVALES DIRECTOS PLAYOFF ----------
    $rivalesNombres = @("SANTURTZI", "ITSASOKO AMA", "PLENTZIA", "BILBAO", "IBERIA", "ILLUNBE", "PONTEJOS")
    

    # Calcular Puntos Acumulados (Solo del grupo donde compitió Aizburua en cada regata)
    $puntosAcum = @{}
    foreach ($reg in $data.regatas) {
        $aizGrpName = $reg.aizburua.grupo
        if (-not $aizGrpName) { continue }
        
        $grp = $reg.grupos.$aizGrpName
        if (-not $grp) { continue }

        foreach ($resItem in $grp.resultados) {
            if ($resItem.puntos) {
                $root = Get-ClubRoot $resItem.club
                if ($puntosAcum.ContainsKey($root)) { $puntosAcum[$root] += [int]$resItem.puntos }
                else { $puntosAcum[$root] = [int]$resItem.puntos }
            }
        }
    }

    $resEnLucha = $mainGroup.resultados | Where-Object { 
        $c = $_.club
        $isRival = $false
        foreach ($r in $rivalesNombres) { if ($c -match $r) { $isRival = $true; break } }
        $isRival -or $c -eq "AIZBURUA" 
    } | Sort-Object { 
        $root = Get-ClubRoot $_.club
        if ($puntosAcum.ContainsKey($root)) { $puntosAcum[$root] } else { 0 }
    } -Descending
    $puestoEnLucha = 1
    $trLucha = [System.Text.StringBuilder]::new()
    foreach ($r in $resEnLucha) {
        $cls = if ($r.club -eq "AIZBURUA") { ' class="aiz"' } else { "" }
        
        # Calculos de tiempo y puntos
        $sRaw = TS $r.tiempo_raw
        $sFin = TS $r.tiempo_final
        $difLucha = DiffStr $sFin $sAizFin
        $colorDif = if ($sFin -lt $sAizFin) { "#C0001A" } else { "#145a32" }
        
        # Puntos Normalizados
        $ptsHoy = [int]$r.puntos
        $rootR = Get-ClubRoot $r.club
        $ptsTot = if ($puntosAcum.ContainsKey($rootR)) { $puntosAcum[$rootR] } else { $ptsHoy }
        $ptsStr = "$ptsHoy ($ptsTot)"
    
        # --- ANALISIS POR TRAMOS DISPONIBLES (C1, C2, FINAL) ---
        $sC1 = TS $r.ciaboga_1
        $sC2 = TS $r.ciaboga_2
        $sReal = TS $r.tiempo_raw
        
        $sC1Aiz = TS $aiz.ciaboga_1
        $sC2Aiz = TS $aiz.ciaboga_2
        $sRealAiz = TS $aiz.tiempo_raw
        
        $difC1 = DiffStr $sC1 $sC1Aiz
        $colorC1 = if ($sC1 -lt $sC1Aiz) { "#C0001A" } else { "#145a32" }
        $difC2 = DiffStr $sC2 $sC2Aiz
        $colorC2 = if ($sC2 -lt $sC2Aiz) { "#C0001A" } else { "#145a32" }
        $difReal = DiffStr $sReal $sRealAiz
        $colorReal = if ($sReal -lt $sRealAiz) { "#C0001A" } else { "#145a32" }
        
        # Alerta de zona PlayOFF
        $isPeligro = $r.puesto -ge ($mainGroup.total_participantes - 1)
        $peligroIcon = if ($isPeligro) { " <span title='Puesto de PlayOFF' style='color:#C0001A; cursor:help'>&#9888;</span>" } else { "" }
        
        $cia1Cell = if ($numCiabogas -ge 1) { "<td>$(ToMMSS $sC1) <span style='font-size:9px; color:$colorC1'>($difC1)</span></td>" } else { "" }
        $cia2Cell = if ($numCiabogas -ge 2) { "<td>$(ToMMSS $sC2) <span style='font-size:9px; color:$colorC2'>($difC2)</span></td>" } else { "" }

        [void]$trLucha.AppendLine("<tr${cls}><td><strong>$puestoEnLucha&ordm;</strong></td><td>$($r.club)$peligroIcon</td>$cia1Cell$cia2Cell<td style='background:rgba(0,0,0,0.02)'>$(ToMMSS $sReal) <span style='font-size:9px; color:$colorReal'>($difReal)</span></td><td style='font-size:10px; color:#666'>$($r.handicap)</td><td><strong>$($r.tiempo_final)</strong></td><td style='color:$colorDif'><strong>$difLucha</strong></td><td style='text-align:center; background:rgba(0,0,0,0.03)'><strong>$ptsStr</strong></td></tr>")
        $puestoEnLucha++
    }

# --- NARRATIVA DETALLADA DE SITUACION ---
$resEnLuchaArr = @($resEnLucha)
$idxAizLucha = 0; for ($i = 0; $i -lt $resEnLuchaArr.Count; $i++) { if ($resEnLuchaArr[$i].club -eq "AIZBURUA") { $idxAizLucha = $i; break } }
$isAizPeligro = $aizPuesto -ge ($mainGroup.total_participantes - 1)


# Datos para la narrativa
$totalEnLucha = $resEnLuchaArr.Count
$rivEncima = if ($idxAizLucha -gt 0) { $resEnLuchaArr[$idxAizLucha - 1] } else { $null }
$rivDebajo = if ($idxAizLucha -lt ($totalEnLucha - 1)) { $resEnLuchaArr[$idxAizLucha + 1] } else { $null }

# --- DASHBOARD ESTRATEGICO (SITUACION EXCLUSIVA PLAYOFF) ---
$rivalesRaices = @("IBERIA", "PLENTZIA", "PONTEJOS", "ILLUNBE", "BILBAO", "AIZBURUA", "SANTURTZI")

# Filtrar puntos solo para los botes en lucha
$puntosLucha = @{}
foreach ($rName in $rivalesRaices) {
    if ($puntosAcum.ContainsKey($rName)) { $puntosLucha[$rName] = $puntosAcum[$rName] }
    else { $puntosLucha[$rName] = 0 }
}

$rankingLucha = $puntosLucha.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { $_.Name }
$idxAizLuchaGlobal = [array]::IndexOf($rankingLucha, "AIZBURUA")
$posAizLucha = $idxAizLuchaGlobal + 1
$ptsAizTotal = $puntosLucha["AIZBURUA"]

# El corte de salvación es el puesto 5 de este grupo (los 3 últimos están en peligro)
$clubCorte = $rankingLucha[4] # El 5º clasificado
$ptsCorte = $puntosLucha[$clubCorte]
$margenRealPts = $ptsAizTotal - $ptsCorte

# Rivales inmediatos en la LUCHA POR EL PLAYOFF
$rivEncimaLucha = if ($idxAizLuchaGlobal -gt 0) { $rankingLucha[$idxAizLuchaGlobal - 1] } else { $null }
$rivDebajoLucha = if ($idxAizLuchaGlobal -lt ($rankingLucha.Count - 1)) { $rankingLucha[$idxAizLuchaGlobal + 1] } else { $null }

$difPtsEncima = if ($rivEncimaLucha) { $puntosLucha[$rivEncimaLucha] - $ptsAizTotal } else { 0 }
$difPtsDebajo = if ($rivDebajoLucha) { $ptsAizTotal - $puntosLucha[$rivDebajoLucha] } else { 0 }

# Colores y Textos de Estado (Basado en posición de lucha)
$isAizPeligroLucha = $posAizLucha -gt 5
$colorStatus = if ($isAizPeligroLucha) { "#C0001A" } else { "#145a32" }
$bgStatus = if ($isAizPeligroLucha) { "#fff2f2" } else { "#f2fdf5" }
$txtStatus = if ($isAizPeligroLucha) { "ZONA DE PLAYOFF" } else { "ZONA SEGURA" }
$icoStatus = if ($isAizPeligroLucha) { "&#9888;" } else { "&#10004;" }

$situacionLucha = @"
    <div style="background:$bgStatus; border:1px solid $colorStatus; border-radius:8px; padding:20px; position:relative; overflow:hidden">
        <h3 style="color:$colorStatus; margin-bottom:5px; font-size:18px">$icoStatus $txtStatus</h3>
        <p style="font-size:12px; color:#666; margin-bottom:15px">Situaci&oacute;n actual en la Tabla de Permanencia</p>
        
        <div style="border-left:4px solid #1a5276; padding-left:15px; margin-bottom:20px">
            <div style="font-size:10px; text-transform:uppercase; color:#1a5276; font-weight:bold; letter-spacing:1px">Diferencia de Puntos</div>
            <div style="font-size:24px; font-weight:900; margin:5px 0">$($margenRealPts) Pts <span style="font-size:12px; font-weight:normal; color:#666">sobre la Salvaci&oacute;n ($clubCorte)</span></div>
        </div>

        <div style="border-left:4px solid #566573; padding-left:15px; margin-bottom:20px">
            <div style="font-size:10px; text-transform:uppercase; color:#566573; font-weight:bold; letter-spacing:1px">Defensa (Colch&oacute;n Liga)</div>
            <div style="font-size:20px; font-weight:bold; margin:5px 0">+$($difPtsDebajo) Pts <span style="font-size:12px; font-weight:normal; color:#666">sobre $rivDebajoLucha</span></div>
        </div>

        <div style="border-left:4px solid #d35400; padding-left:15px">
            <div style="font-size:10px; text-transform:uppercase; color:#d35400; font-weight:bold; letter-spacing:1px">Ataque (Para Escalar)</div>
            <div style="font-size:20px; font-weight:bold; margin:5px 0">-$($difPtsEncima) Pts <span style="font-size:12px; font-weight:normal; color:#666">para alcanzar a $rivEncimaLucha</span></div>
        </div>
    </div>
"@

# Textos dinámicos para la nota
$metaEncima = if ($isAizPeligroLucha) { "para salir de la zona de PlayOFF" } else { "para consolidar la permanencia" }
$metaDebajo = if ($isAizPeligroLucha) { "para evitar el farolillo rojo" } else { "para no caer en zona de PlayOFF" }

$objetivosStr = ""
if ($rivEncimaLucha -and $rivDebajoLucha) {
    $objetivosStr = "tus objetivos son <strong>$rivEncimaLucha</strong> ($metaEncima) e <strong>$rivDebajoLucha</strong> ($metaDebajo)."
} elseif ($rivEncimaLucha) {
    $objetivosStr = "tu objetivo principal es alcanzar a <strong>$rivEncimaLucha</strong> ($metaEncima)."
} elseif ($rivDebajoLucha) {
    $objetivosStr = "tu prioridad es mantener la distancia con <strong>$rivDebajoLucha</strong> ($metaDebajo)."
}

$notaEstrategica = @"
    <div style="margin-top:20px; font-size:12px; line-height:1.6; color:#444">
        <strong>Nota Estrat&eacute;gica:</strong> En la lucha directa por la permanencia, $objetivosStr
    </div>
"@
# Bloque de Dashboard limpio (v4.5)

# ---------- Construccion del HTML ----------
$h = [System.Collections.Generic.List[string]]::new()

$h.Add('<!DOCTYPE html><html lang="es"><head><meta charset="UTF-8">')
$h.Add('<title>Informe Aizburua - ' + $RegNombre + '</title>')
$h.Add('<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600;700;900&display=swap" rel="stylesheet">')
$h.Add('<style>
@media print {
  body { background: #fff !important; -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
  .card, .wrap, .st, .cc, .stitle, tr, .pb, .info-box, .leg, .boat-container { page-break-inside: avoid !important; break-inside: avoid !important; }
  h2, .stitle, .ch { page-break-after: avoid !important; break-after: avoid !important; }
}
:root{--r:#C0001A;--rd:#8B0013;--rl:#f8e6e9;--dk:#1a1a2e;--gy:#5a6170;--lg:#f4f4f8;--bd:#e0e0e8;--wh:#fff;--blu:#1e3a5f;--grn:#1a4a2e}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:Inter,sans-serif;background:var(--lg);color:var(--dk);font-size:13px;line-height:1.6}
.stitle { 
    font-weight: 900; font-size: 24px; color: #ffffff !important; 
    background: linear-gradient(135deg, #b01c2e 0%, #1a1a2e 100%); 
    padding: 18px 28px; border-radius: 12px; margin: 60px 0 30px 0; 
    border-left: 10px solid #000; border-bottom: 2px solid rgba(255,255,255,0.15);
    box-shadow: 0 10px 25px rgba(0,0,0,0.2); 
    text-transform: uppercase; letter-spacing: 2px;
    text-shadow: 0 2px 4px rgba(0,0,0,0.5);
    display: flex; align-items: center;
}
.card { background: #fff; border-radius: 12px; padding: 28px; box-shadow: 0 12px 30px rgba(0,0,0,0.08); margin-bottom: 35px; border: 1px solid #eee; position: relative; overflow: hidden; }
.ch { display: flex; align-items: center; margin-bottom: 22px; border-bottom: 3px solid #f0f0f0; padding-bottom: 18px; gap: 5px; }
.ch h2 { font-size: 19px; margin: 0; color: #111; font-weight: 800; text-transform: uppercase; letter-spacing: 0.5px; }
.ico { 
    width: 38px; height: 38px; border-radius: 8px; display: flex; align-items: center; justify-content: center; 
    margin-right: 12px; font-weight: 900; font-size: 18px; color: #fff; flex-shrink: 0; box-shadow: 0 4px 8px rgba(0,0,0,0.15);
}
.ico-h { background: #b01c2e; } /* Horario */
.ico-r { background: #0a3d62; } /* Ritmo */
.ico-a { background: #145a32; } /* Alineacion */
.ico-e { background: #6c5ce7; } /* Estadisticas */
.ico-star { background: #f39c12; } /* Recomendaciones */
.ico-1 { background: var(--rd); } /* Grupo 1 */
.ico-2 { background: #444; } /* Grupo 2 */
.ico-c { background: #2980b9; } /* Comparativa */
.ico-p { background: #34495e; } /* Posicionamiento */
.ico-v { background: #1e3a5f; } /* Variables */
.ico-alert { background: #d35400; } /* Alerta */
.hdr{background:linear-gradient(135deg,var(--dk) 0%,#16213e 60%,var(--rd) 100%);color:#fff;padding:40px 60px;display:flex;align-items:center;justify-content:space-between;border-bottom:6px solid var(--r)}
.brand-group{display:flex;align-items:center;gap:20px}
.logo-header{height:75px;width:auto;filter:drop-shadow(0 2px 8px rgba(0,0,0,0.4))}
.ht h1{font-size:22px;font-weight:900;letter-spacing:1px;text-transform:uppercase;color:#fff;line-height:1}
.ht .sub{font-size:10px;color:rgba(255,255,255,.6);letter-spacing:3px;margin-top:5px;font-weight:700}
.hm{text-align:right;border-left:1px solid rgba(255,255,255,.15);padding-left:24px}
.hm .rn{font-size:14px;font-weight:700;color:#fff;line-height:1.4}
.hm .fd{font-size:11px;color:rgba(255,255,255,.65);margin-top:5px}
.hm .hora-badge{display:inline-block;background:rgba(192,0,26,.5);border:1px solid rgba(255,80,80,.6);border-radius:6px;padding:5px 12px;font-size:12px;font-weight:700;color:#fff;margin-top:8px;letter-spacing:1px}
.wrap{max-width:1600px;margin:0 auto;padding:28px 24px}
.g2{display:grid;grid-template-columns:1fr 1fr;gap:18px}
.g4{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}
.gs{display:grid;grid-template-columns:repeat(auto-fit,minmax(115px,1fr));gap:10px}
.st{background:var(--lg);border-radius:8px;padding:10px 12px;border-left:3px solid var(--r)}
.st .lbl{font-size:9px;text-transform:uppercase;letter-spacing:1px;color:var(--gy)}
.st .val{font-size:18px;font-weight:700;color:var(--dk);margin-top:2px}
.st .sbl{font-size:10px;color:var(--gy);margin-top:1px;line-height:1.3}
.pb{border-radius:10px;padding:14px 10px;border:2px solid transparent}
.pb.real{background:var(--r);color:#fff;border-color:var(--rd)}
.pb.norm{background:var(--dk);color:#fff}
.pb.proy{background:var(--blu);color:#fff}
.pb.raw{background:var(--grn);color:#fff}
.pb .pn{font-size:30px;font-weight:900;line-height:1;text-align:center}
.pb .pt{font-size:11px;font-weight:700;text-align:center;margin-top:4px;opacity:.9;line-height:1.3}
.pb .pd{font-size:9px;text-align:center;margin-top:6px;opacity:.7;line-height:1.3;font-style:italic}
.legend-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;margin-top:14px}
.leg{border-radius:6px;padding:9px 11px;font-size:10px;line-height:1.5}
.leg .lt{font-weight:700;font-size:10px;margin-bottom:4px;text-transform:uppercase;letter-spacing:.5px}
.leg.real{background:var(--rl);border-left:3px solid var(--r);color:var(--rd)}
.leg.norm{background:#e8eaf6;border-left:3px solid var(--dk);color:var(--dk)}
.leg.proy{background:#e3eeff;border-left:3px solid var(--blu);color:var(--blu)}
.leg.raw{background:#e8f5e9;border-left:3px solid var(--grn);color:var(--grn)}
table{width:100%;border-collapse:collapse;font-size:11.5px}
thead th{background:var(--r);color:#fff;padding:8px 9px;text-align:left;font-size:9px;letter-spacing:1px;text-transform:uppercase;font-weight:700}
tbody tr:nth-child(even){background:#fafafa}
tbody tr:hover{background:#fff0f2}
tbody td{padding:7px 9px;border-bottom:1px solid #eee;color:var(--dk)}
tr.aiz td{background:var(--rl)!important;font-weight:700;color:var(--rd)!important}
.bp{background:linear-gradient(135deg,#fff0f2,#ffe0e5);border:2px solid var(--r);border-radius:10px;padding:16px 20px}
.bpl{font-size:9px;text-transform:uppercase;letter-spacing:2px;color:var(--r);font-weight:700;margin-bottom:6px}
.diag-box { background: #f8fbff; border: 1px solid #d0e1f9; border-left: 5px solid #1e3a5f; border-radius: 8px; padding: 22px; margin-top: 15px; }
.diag-header { color: #1e3a5f; font-weight: 900; font-size: 13px; text-transform: uppercase; letter-spacing: 1.5px; border-bottom: 2px solid #d0e1f9; padding-bottom: 10px; margin-bottom: 18px; }
.diag-segment { margin-bottom: 15px; line-height: 1.6; }
.diag-label { font-weight: 800; color: #C0001A; text-transform: uppercase; font-size: 10px; display: block; margin-bottom: 4px; letter-spacing: 0.5px; }
.diag-content { font-size: 15px; color: #334155; }
.diag-content strong { color: #1e3a5f; }
.cc{background:linear-gradient(135deg,#0f1b35,#1a2a50);border-radius:12px;padding:20px;color:#fff;border-left:5px solid var(--r)}
.cc h2{font-size:10px;text-transform:uppercase;letter-spacing:2px;color:rgba(255,255,255,.6);margin-bottom:8px}
.cnum{font-size:40px;font-weight:900;color:var(--r);line-height:1}
.cverd{display:inline-block;margin-top:8px;padding:4px 12px;border-radius:20px;background:var(--r);color:#fff;font-size:10px;font-weight:700;text-transform:uppercase}
.tt{width:100%;border-collapse:separate;border-spacing:3px}
.tt td{padding:7px 10px;border-radius:5px;text-align:center;font-size:12px;font-weight:600;border:none}
.bn{background:#1a1a2e!important;color:#fff!important;font-weight:700!important}
.tactical-alert { background: #fef2f2; border-left: 6px solid var(--r); padding: 16px 20px; border-radius: 8px; margin-top: 15px; color: #991b1b; font-size: 13px; font-weight: 500; line-height: 1.6; display: flex; align-items: flex-start; gap: 14px; box-shadow: 0 2px 10px rgba(192, 0, 26, 0.08); text-align: left; }
.alert-icon { flex-shrink: 0; margin-top: 2px; }
.bab{background:#d4edfa!important;color:#0a3d62!important}
.est{background:#d5f5e3!important;color:#145a32!important}
.proa-row td{background:var(--rl)!important;color:var(--rd)!important;font-weight:700!important;text-align:center}
.patron-row td{background:var(--r)!important;color:#fff!important;font-weight:700!important;text-align:center}
.bl{display:inline-block;padding:2px 8px;border-radius:20px;font-size:10px;font-weight:700;letter-spacing:1px;margin-right:8px;background:rgba(0,0,0,.2)}
.bdg{display:inline-block;padding:1px 5px;border-radius:3px;font-size:9px;font-weight:700;background:rgba(0,0,0,.15)}
.rl{list-style:none}
.rl li{padding:9px 13px;border-radius:6px;margin-bottom:6px;background:var(--lg);border-left:3px solid var(--r);font-size:12px;line-height:1.6}
.stitle{font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:2px;color:var(--gy);margin:24px 0 8px;display:flex;align-items:center;gap:10px}
.stitle::after{content:"";flex:1;height:1px;background:var(--bd)}
.bg1{background:var(--r);color:#fff;display:inline-block;padding:3px 10px;border-radius:20px;font-size:10px;font-weight:700;margin-bottom:10px}
.bg2{background:var(--blu);color:#fff;display:inline-block;padding:3px 10px;border-radius:20px;font-size:10px;font-weight:700;margin-bottom:10px}
.info-box{background:#fffbe6;border:1px solid #f5c842;border-radius:8px;padding:15px 20px;font-size:14px;color:#7a5a00;margin-bottom:12px;line-height:1.6}
.tanda-info { background: #fff9e6; border: 1px solid #f5c842; border-radius: 12px; padding: 24px 32px; font-size: 15px; color: #7a5a00; margin-bottom: 15px; line-height: 1.8; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }
.tanda-info strong { font-size: 20px; color: #8b0013; display: block; margin-bottom: 5px; }
.tanda-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 20px; margin-top: 15px; }
.tanda-item { background: rgba(255,255,255,0.4); padding: 12px 18px; border-radius: 8px; border: 1px solid rgba(245, 200, 66, 0.3); }
.tanda-label { opacity: 0.7; font-size: 11px; text-transform: uppercase; font-weight: 800; display: block; margin-bottom: 4px; letter-spacing: 0.5px; }
.tanda-val { font-weight: 700; color: #444; }
.tendencia-buena{color:#0a7a3a;font-weight:600}
.tendencia-mala{color:var(--r);font-weight:600}
.timeline-container{display:flex;justify-content:space-between;align-items:flex-end;min-height:240px;background:linear-gradient(180deg,#f8fafc,#f0f4f8);padding:30px 50px 20px;border-radius:12px;margin:25px 0;border:1px solid #d0dae1;position:relative}
.tl-label-y{position:absolute;left:-38px;top:50%;transform:rotate(-90deg);font-size:10px;color:var(--gy);font-weight:700;text-transform:uppercase;letter-spacing:1px}
.tl-tick{display:flex;flex-direction:column;align-items:center;flex:1}
.tl-bar-group{display:flex;align-items:flex-end;gap:10px;min-height:140px}
.tl-bar-wind{width:28px;background:linear-gradient(180deg,#e8384f,var(--r));border-radius:4px 4px 0 0;transition:all 0.3s}
.tl-bar-wave{width:16px;background:linear-gradient(180deg,#4a90d9,var(--blu));border-radius:3px 3px 0 0}
.tl-time{font-size:13px;font-weight:800;margin-top:12px;color:var(--dk)}
.tl-desc{font-size:10px;color:var(--gy);margin-top:3px;text-align:center;line-height:1.2}
.leg-tl{display:flex;gap:20px;justify-content:center;margin-top:14px}
.leg-item{display:flex;align-items:center;gap:6px;font-size:10px;font-weight:700;text-transform:uppercase}
.dot{width:10px;height:10px;border-radius:2px}
.ftr{background:var(--dk);color:rgba(255,255,255,.5);padding:40px;text-align:center;font-size:10px;border-top:5px solid var(--r);display:flex;flex-direction:column;align-items:center;gap:15px}
.logo-footer{height:45px;width:auto;opacity:0.8;filter:grayscale(1) brightness(3)}
.lane-split { display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 20px; margin: 25px 0; }
.lane-box { border-radius: 12px; padding: 22px; position: relative; overflow: hidden; border: 1px solid rgba(0,0,0,0.05); box-shadow: 0 4px 15px rgba(0,0,0,0.03); }
.lane-box::before { content: ""; position: absolute; top: 0; left: 0; width: 6px; height: 100%; }
.lane-1 { background: linear-gradient(135deg, #f8fbff 0%, #ebf4ff 100%); border-top: 1px solid #d0e1f9; }
.lane-1::before { background: #1e3a5f; }
.lane-2 { background: linear-gradient(135deg, #fffafa 0%, #fff1f1 100%); border-top: 1px solid #f9d0d0; }
.lane-2::before { background: #c0001a; }
.lane-tag { position: absolute; top: 10px; right: 15px; font-size: 34px; font-weight: 900; opacity: 0.25; pointer-events: none; }
.lane-title { font-size: 13px; font-weight: 800; text-transform: uppercase; letter-spacing: 1.5px; margin-bottom: 15px; border-bottom: 1px solid rgba(0,0,0,0.05); padding-bottom: 8px; }
.lane-item { font-size: 12px; line-height: 1.6; margin-bottom: 12px; }
.lane-item strong { display: block; font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 2px; }
.dir-hdr { font-size: 10px; font-weight: 800; background: rgba(0,0,0,0.06); padding: 4px 8px; border-radius: 4px; margin: 12px 0 8px; text-transform: uppercase; letter-spacing: 1px; color: #555; display: inline-block; }
.conc-box { background: #faf9f0; border: 1px solid #e8dfbe; border-radius: 10px; padding: 18px; margin-top: 20px; border-left: 5px solid #d35400; }
.conc-title { font-size: 12px; font-weight: 800; text-transform: uppercase; color: #d35400; letter-spacing: 1.5px; margin-bottom: 8px; display: flex; align-items: center; gap: 8px;}
.r-cell { display: flex; align-items: center; gap: 12px; text-align: left !important; padding: 8px !important; width: fit-content; margin: 0 auto; }
.r-avatar { width: 50px; height: 50px; border-radius: 10px; object-fit: cover; border: 2px solid rgba(255,255,255,0.8); box-shadow: 0 4px 10px rgba(0,0,0,0.15); background: #eee; flex-shrink: 0; }
.r-info { display: flex; flex-direction: column; gap: 2px; }
.r-name { font-weight: 800; font-size: 14px; text-transform: uppercase; letter-spacing: 0.5px; }
.r-meta { font-size: 10px; opacity: 0.7; font-weight: 600; }
@media print{body{background:#fff;font-size:11px}.card{box-shadow:none;break-inside:avoid}.hdr,.aiz td,.pb,.bp,.cc,.proa-row td,.patron-row td,.bn,.bab,.est,thead th,.bg1,.bg2,.leg,.lane-box,.conc-box{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
</style></head><body>')

# -------- HEADER con LOGO --------
$h.Add('<div class="hdr">')
$h.Add('  <div class="brand-group">')
if ($logo1Base64) {
    $h.Add('    <img src="data:image/jpeg;base64,' + $logo1Base64 + '" class="logo-header" alt="Aizburua">')
}
else {
    $h.Add('    <div style="width:75px;height:75px;background:var(--r);border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:900;font-size:24px">A</div>')
}
$h.Add('    <div class="ht"><h1>Aizburua</h1><div class="sub">Informe T&eacute;cnico de Rendimiento &mdash; Liga AKK 11.1</div></div>')
$h.Add('  </div>')
$h.Add('  <div class="hm">')
$h.Add('    <div class="rn">' + $RegNombre + '</div>')
$h.Add('    <div class="fd">' + $RegFecha + ' &nbsp;&mdash;&nbsp; ' + $RegLugar + '</div>')
$h.Add('    <div class="hora-badge">' + $aizGroupName.ToUpper().Replace("_", " ") + ' &mdash; Tanda ' + $aizTanda + ' &mdash; Salida ' + $aizHora + 'h &mdash; Calle ' + $aizCalle + '</div>')
$h.Add('  </div>')
$h.Add('</div>')
$h.Add('<div class="wrap">')

# --- DETECCION DE MODALIDAD Y DINAMIZACION DE CALLES ---
$modalidad = "calles"
if ($regata.PSObject.Properties['modalidad']) {
    $modalidad = $regata.modalidad
}

# -------- HORARIO DE LA REGATA --------
$h.Add('<div class="stitle">Horario y Estructura de la Regata</div>')
$numGrupos = ($regata.grupos.PSObject.Properties.Name | Measure-Object).Count
$gClass = if ($numGrupos -gt 1) { "g2" } else { "" }
$h.Add('<div class="card"><div class="ch"><div class="ico ico-h">H</div><h2>Cu&aacute;ndo sali&oacute; cada tanda/grupo</h2></div><div class="' + $gClass + '">')

# Iterar por los grupos definidos en el JSON de forma dinámica
foreach ($gName in $regata.grupos.PSObject.Properties.Name) {
    $g = $regata.grupos.$gName
    if (-not $g -or -not $g.resultados) { continue }
    
    # Calcular el rango horario real de la tanda/grupo basado en las salidas
    $groupRes = @($g.resultados | Sort-Object { HM $_.hora_salida })
    $hStart = "---" ; $hEnd = "---"
    if ($groupRes.Count -gt 0) {
        $hStart = $groupRes[0].hora_salida
        $hEnd = $groupRes[-1].hora_salida
    }
    $range = "$hStart a $hEnd"
    
    $lbl = $gName.ToUpper().Replace("_", " ")
    if ($g.descripcion) { $lbl = $g.descripcion.ToUpper() }
    
    $isAizGroup = ($aizd.grupo -eq $gName)
    $aizNote = if ($isAizGroup) { " &mdash; Aqu&iacute; compite Aizburua" } else { "" }
    
    $h.Add('<div class="tanda-info">')
    $h.Add('<strong>' + $lbl + ' &mdash; ' + $range + 'h' + $aizNote + '</strong>')
    $h.Add('<div class="tanda-grid">')
    
    $modalidadTxt = if ($modalidad -eq "contrareloj") { "$($g.total_participantes) clubes, salidas individuales de 1 en 1 (Calle &uacute;nica)" } else { "$($g.total_participantes) clubes, salidas 2 a 2 (Calle 1 y 2)" }
    $h.Add('<div class="tanda-item"><span class="tanda-label">Participaci&oacute;n y Formato</span><span class="tanda-val">' + $modalidadTxt + '</span></div>')
    
    $h.Add('<div class="tanda-item"><span class="tanda-label">Ganador del Grupo</span><span class="tanda-val">' + $g.ganador + ' (' + $g.tiempo_ganador_raw + ' / ' + $g.tiempo_ganador_final + ')</span></div>')
    
    if ($isAizGroup) {
        $h.Add('<div class="tanda-item" style="background:rgba(139,0,19,0.08); border-color:rgba(139,0,19,0.2)"><span class="tanda-label" style="color:#8b0013">Aizburua (Datos Salida)</span><span class="tanda-val" style="color:#8b0013">Calle ' + $aizCalle + ' | Salida Individual a las ' + $aizHora + 'h</span>')
        # if ($alertaHcpHtml) { $h.Add($alertaHcpHtml) }
        $h.Add('</div>')
    }
    $h.Add('</div></div>')
}
$h.Add('</div></div>')

# -------- CONDICIONES --------
$h.Add('<div class="stitle">Condiciones del Campo el Dia de la Regata</div>')
$h.Add('<div class="card" style="border-left:4px solid #1e3a5f"><div class="ch"><div class="ico ico-v">V</div><h2 style="color:#1e3a5f;text-transform:uppercase;letter-spacing:1px;font-weight:900">Variables Atmosfericas y Campo Nautico</h2></div>')

# Geometría Principal y Marea (destacado arriba)
$h.Add('<div class="cc" style="margin-bottom:20px;border-left:4px solid var(--r);display:grid;grid-template-columns: 1.6fr 1.2fr;gap:25px;align-items:stretch;background:linear-gradient(90deg, #1e3a5f, #152945);padding:25px">')
$h.Add('<div style="display:flex;flex-direction:column;justify-content:center"><h2 style="color:#a8c0e0;font-size:12px;letter-spacing:2px;margin-bottom:18px;text-transform:uppercase;border-bottom:1px solid rgba(255,255,255,0.1);padding-bottom:8px">Geometria tactica del Campo (Muelle &harr; Mar)</h2>')
$h.Add('<div style="font-size:15px;line-height:1.8;color:#e2e8f0;display:flex;flex-direction:column;gap:10px">')

$numLargos = 2
if ($regata.PSObject.Properties['num_largos']) {
    $numLargos = [int]$regata.num_largos
} elseif ($RegNombre -like "*Santurtzi*") {
    $numLargos = 4
}

$metrosPorLargo = [math]::Round($regata.distancia_m / $numLargos)

$h.Add('<span><strong style="color:#fff">Distancia:</strong> ' + $regata.distancia_m + 'm (' + $numLargos + ' largo/s, ' + $numCiabogas + ' ciabogas' + $distDetail + ')</span>')
$h.Add('<span><strong style="color:#fff">Eje de Boga:</strong> ' + $cond.geometria.eje + '</span>')
if ($modalidad -eq "contrareloj") {
    $h.Add('<span><strong style="color:#fff">Calle Unica:</strong> Recorrido por el balizado central (Contrarreloj)</span>')
} else {
    $h.Add('<span><strong style="color:#fff">Calle 1 (Blanca):</strong> ' + $cond.geometria.calle1.posicion + ' (M&aacute;s corriente)</span>')
    $h.Add('<span><strong style="color:#fff">Calle 2 (Roja):</strong> ' + $cond.geometria.calle2.posicion + ' (M&aacute;s protegida)</span>')
}
$vDir = $cond.viento.direccion
$vKmh = $cond.viento.velocidad_kmh
$oDir = $cond.olas.direccion
$oAlt = $cond.olas.altura_m

if ($numLargos -eq 4) {
    $h.Add('<span><strong style="color:#fff">Largos Impares (1 y 3 - IDA):</strong> Viento ' + $vDir + ' (' + $vKmh + ' km/h). Ola ' + $oDir + ' (' + $oAlt + 'm). Corriente a favor.</span>')
    $h.Add('<span><strong style="color:#fff">Largos Pares (2 y 4 - VUELTA):</strong> Viento ' + $vDir + ' (' + $vKmh + ' km/h). Ola ' + $oDir + ' (' + $oAlt + 'm). <span style="color:#ff8e8e;font-weight:700">Corriente EN CONTRA.</span></span></div></div>')
} elseif ($numLargos -eq 1) {
    $h.Add('<span><strong style="color:#fff">Largo &Uacute;nico (En l&iacute;nea):</strong> Viento ' + $vDir + ' (' + $vKmh + ' km/h). Ola ' + $oDir + ' (' + $oAlt + 'm). Sin ciabogas.</span></div></div>')
} else {
    $h.Add('<span><strong style="color:#fff">Largo 1 (IDA):</strong> Viento ' + $vDir + ' (' + $vKmh + ' km/h). Ola ' + $oDir + ' (' + $oAlt + 'm). Corriente a favor.</span>')
    $h.Add('<span><strong style="color:#fff">Largo 2 (VUELTA):</strong> Viento ' + $vDir + ' (' + $vKmh + ' km/h). Ola ' + $oDir + ' (' + $oAlt + 'm). <span style="color:#ff8e8e;font-weight:700">Corriente EN CONTRA.</span></span></div></div>')
}

$coefCtx = "MAREA MUERTA &mdash; Corriente m&iacute;nima. Campo m&aacute;s neutro."
if ($CondCoef -ge 90) { $coefCtx = 'MAREA VIVA &mdash; Corrientes m&aacute;ximas. Muy adversas a la vuelta.' }
elseif ($CondCoef -ge 60) { $coefCtx = 'MAREA MODERADA-ALTA &mdash; Corriente considerable. Penaliza la vuelta.' }
elseif ($CondCoef -ge 30) { $coefCtx = 'MAREA MEDIA &mdash; Corriente moderada. Impacto controlable.' }

$h.Add('<div style="text-align:right;background:rgba(0,0,0,.35);padding:22px;border-radius:12px;border:1px solid rgba(255,255,255,.1);box-shadow:inset 0 2px 15px rgba(0,0,0,.3);display:flex;flex-direction:column;justify-content:center">')
$h.Add('<h2 style="font-size:13px;color:#a8c0e0;letter-spacing:2px;margin-bottom:6px;text-transform:uppercase">Coeficiente Marea <span style="font-weight:400;opacity:.7">(escala 0&ndash;120)</span></h2>')
$h.Add('<div style="font-size:11px;color:#cbd5e1;margin-bottom:10px">0 = Mar muerta &nbsp;|&nbsp; 60 = Media &nbsp;|&nbsp; 120 = M&aacute;xima viva</div>')
$h.Add('<div class="cnum" style="font-size:54px;line-height:1;margin-bottom:12px;color:#fff;text-shadow:0 3px 6px rgba(0,0,0,0.5);font-weight:900">' + $cond.marea.coeficiente + '</div>')
    
$mEstado = $cond.marea.estado_en_regata
if ($mEstado -like "*vaciante*") { $mEstado = "Marea Bajando (Corriente hacia el Mar)" }
    
$h.Add('<div class="cverd" style="font-size:12px;margin-bottom:15px;background:var(--r);color:#fff;display:inline-block;padding:5px 12px;border-radius:6px;font-weight:900;letter-spacing:1px;align-self:flex-end">' + $mEstado.ToUpper() + '</div>')
$h.Add('<div style="font-size:13px;text-align:left;color:#e2e8f0;line-height:1.6;border-left:3px solid rgba(255,255,255,.3);padding-left:15px;margin-top:5px;background:rgba(255,255,255,0.05);padding:10px;border-radius:0 6px 6px 0">')
$h.Add('<strong style="color:#fff;text-decoration:underline;margin-bottom:4px;display:block">' + $coefCtx + '</strong>')
$h.Add('Bajamar: <strong style="color:#fff">' + $cond.marea.bajamar_diurna + 'h</strong> &mdash; Al bajar la marea, el agua de la r&iacute;a sale hacia el mar, creando una corriente que ayuda a la IDA pero dificulta enormemente la VUELTA al muelle.</div></div>')
$h.Add('</div>')
    
# --- DETECCION DE MODALIDAD Y DINAMIZACION DE CALLES ---
$modalidad = "calles"
if ($regata.PSObject.Properties['modalidad']) {
    $modalidad = $regata.modalidad
}
    
if ($modalidad -eq "contrareloj") {
    $h.Add('<div class="stitle">Evolucion Tactica del Campo (Contrareloj)</div>')
    $h.Add('<p style="font-size:12px; color:#555; margin-bottom:15px; margin-top:-5px;">Analisis de la variabilidad del campo de regatas a lo largo del tiempo. En modalidad C.R., el factor determinante es el cambio de las condiciones entre el primer y ultimo bote.</p>')
    $h.Add('<div class="lane-box lane-1" style="border-left:6px solid #1e3a5f">')
    $h.Add('<div class="lane-title" style="color:#1e3a5f">Trazada Unica - Analisis Temporal</div>')
    
    if ($numLargos -eq 4) {
        $h.Add('<div class="dir-hdr" style="color:#1e3a5f; background:#e6f0ff">&rarr; LARGOS IMPARES (1 y 3 - IDA)</div>')
        $ayuda = "frena"
        if ($cond.marea.estado_en_regata -like "*vaciante*") { $ayuda = "ayuda" }
        $h.Add('<div class="lane-item"><strong>Inercia de Salida</strong>Campo influenciado por ' + $cond.marea.estado_en_regata + '. La corriente ' + $ayuda + ' el avance hacia la baliza exterior.</div>')
        $h.Add('<div class="dir-hdr" style="color:#c0001a; background:#fbeeee">&larr; LARGOS PARES (2 y 4 - VUELTA)</div>')
        $h.Add('<div class="lane-item"><strong>Resistencia del Retorno</strong>Impacto directo del viento ' + $cond.viento.direccion + ' y la ola de ' + $cond.olas.direccion + ' sobre la fatiga acumulada.</div>')
    } elseif ($numLargos -eq 1) {
        $h.Add('<div class="dir-hdr" style="color:#1e3a5f; background:#e6f0ff">&rarr; LARGO &Uacute;NICO (EN L&Iacute;NEA)</div>')
        $h.Add('<div class="lane-item"><strong>Traves&iacute;a Directa</strong>Regata de un solo largo sin ciabogas. Análisis centrado en la gestión de la palada constante y la adaptación al viento/ola de costado o aleta.</div>')
    } else {
        $h.Add('<div class="dir-hdr" style="color:#1e3a5f; background:#e6f0ff">&rarr; LARGO 1 (IDA)</div>')
        $ayuda = "frena"
        if ($cond.marea.estado_en_regata -like "*vaciante*") { $ayuda = "ayuda" }
        $h.Add('<div class="lane-item"><strong>Inercia de Salida</strong>Campo influenciado por ' + $cond.marea.estado_en_regata + '. La corriente ' + $ayuda + ' el avance inicial hacia la baliza exterior.</div>')
        $h.Add('<div class="dir-hdr" style="color:#c0001a; background:#fbeeee">&larr; LARGO 2 (VUELTA)</div>')
        $h.Add('<div class="lane-item"><strong>Resistencia del Retorno</strong>Impacto directo del viento ' + $cond.viento.direccion + ' y la ola de ' + $cond.olas.direccion + ' sobre la fatiga acumulada.</div>')
    }
    $h.Add('</div>')
}
else {
    $h.Add('<div class="stitle">Micro-Topografia Nautica por Calles (Ida vs Vuelta)</div>')
    $h.Add('<p style="font-size:12px; color:#555; margin-bottom:15px; margin-top:5px; padding-left:2px;">Desglose del impacto de la hidrodin&aacute;mica dependiente del sentido de la boga. Las condiciones asim&eacute;tricas penalizan o benefician a cada calle seg&uacute;n se salga hacia alta mar o retroceda a la r&iacute;a.</p>')
    $h.Add('<div class="lane-split">')
        
    # Iterar sobre las calles definidas en la geometria
    $callesDinas = $cond.geometria.PSObject.Properties | Where-Object { $_.Name -like "calle*" }
    foreach ($prop in $callesDinas) {
        $cId = $prop.Name.Replace("calle", "")
        $cData = $prop.Value
        $cStyle = "lane-1" ; $cColor = "#1e3a5f"
        if ([int]$cId % 2 -eq 0) { $cStyle = "lane-2" ; $cColor = "#c0001a" }
            
        # Inferencia de impacto segun posicion
        $pos = $cData.posicion.ToLower()
        $txtIda = ""
        $txtVue = ""
        $vDir = $cond.viento.direccion
            
        if ($pos -match "rio|canal|exterior") {
            $txtIda = "<strong style='display:block;margin-bottom:4px;color:#1e3a5f'>CORRIENTE A FAVOR (M&Aacute;XIMA)</strong>Al coincidir con el eje central de desag&uuml;e del r&iacute;o en marea bajando, ofrece el mayor empuje `"gratuito`" al barco de todo el campo de regatas.<br><br><strong style='display:block;margin-bottom:4px;color:#1e3a5f'>VIENTO ($vDir) Y OLA</strong><br>El abatimiento de brisa lateral es f&aacute;cilmente mitigado por la alta velocidad de avance impulsada por la marea. Ola muy limpia."
            $txtVue = "<strong style='display:block;margin-bottom:4px;color:#c0001a'>CORRIENTE EN CONTRA (EL `"MURO`")</strong>El canal principal eyecta contra la proa el flujo de agua m&aacute;s denso y r&aacute;pido imaginable. Exige una enorme entrega muscular y frena dr&aacute;sticamente el deslizamiento (ca&iacute;da de MpP).<br><br><strong style='display:block;margin-bottom:4px;color:#c0001a'>EMPOPADA FALLIDA</strong><br>Aunque el viento de $vDir acaricie la aleta y una ola sana cruce la popa, la extrema succi&oacute;n de la marea te roba la velocidad necesaria para montarse sostenidamente encima de las crestas; asfixia inevitable."
        }
        else {
            $txtIda = "<strong style='display:block;margin-bottom:4px;color:#1e3a5f'>CORRIENTE A FAVOR (REDUCIDA)</strong>Al estar pegada a la orilla rocosa y la playa, la fricci&oacute;n perimetral ralentiza el paso del agua de r&iacute;a frente a la zona de alta profundidad. Menos ayuda, boga m&aacute;s lenta s&oacute;lo hacia afuera.<br><br><strong style='display:block;margin-bottom:4px;color:#1e3a5f'>VIENTO ($vDir) Y OLA</strong><br>Mar de fondo parcialmente encrespado por rotura costera temprana. Turbulencia de aire procedente de contorno portuario."
            $txtVue = "<strong style='display:block;margin-bottom:4px;color:#c0001a'>CORRIENTE EN CONTRA (MITIGADA)</strong>El temido `"muro`" del centro del canal es francamente m&aacute;s d&eacute;bil y vadeable bajo la ribera rocosa. Permite mantener el golpe rotacional en cotas sostenibles.<br><br><strong style='display:block;margin-bottom:4px;color:#c0001a'>EMPOPADA APROVECHABLE (SURF EFECTIVO)</strong><br>De cara a la Vuelta, sin ese rozamiento f&oacute;sil extremo desde proa, la tripulaci&oacute;n s&iacute; empalma el planeo con el golpe de empuje cruzado de $vDir sobre la espalda junto a la estela de la onda."
        }

        $h.Add('<div class="lane-box ' + $cStyle + '"><div class="lane-tag">C' + $cId + '</div>')
        $h.Add('<div class="lane-title" style="color:' + $cColor + '">Calle ' + $cId + ' (' + $cData.color + ') - ' + $cData.posicion + '</div>')
            
        $h.Add('<div class="dir-hdr" style="color:#1e3a5f; background:#e6f0ff">&rarr; LARGO 1 (IDA: HACIA EL ABRA)</div>')
        $h.Add('<div class="lane-item">' + $txtIda + '</div>')
            
        $h.Add('<div class="dir-hdr" style="color:#c0001a; background:#fbeeee">&larr; LARGO 2 (VUELTA: AL MUELLE)</div>')
        $h.Add('<div class="lane-item">' + $txtVue + '</div>')
        $h.Add('</div>')
    }
    $h.Add('</div>')
}
    
# Conclusion Táctica Dinámica
$h.Add('<div class="conc-box">')
$h.Add('<div class="conc-title">&#9875; CONCLUSI&Oacute;N T&Aacute;CTICA DEL CAMPO (' + $regata.lugar.ToUpper() + ')</div>')
$h.Add('<div style="font-size:13px; line-height:1.6; color:#333">')

if ($modalidad -eq "contrareloj") {
    $h.Add('<p style="margin-bottom:10px">En resumen, bajo un r&eacute;gimen de <strong>' + $cond.marea.estado_en_regata + '</strong> y modalidad de <strong>Contrarreloj</strong>, el factor t&aacute;ctico clave no fue la calle (&uacute;nica para todos), sino la ventana temporal de salida:</p>')
    $h.Add('<ul style="margin-left:20px; margin-bottom:12px; color:#444">')
    $h.Add('<li style="margin-bottom:6px"><strong>Gesti&oacute;n de la Marea:</strong> Aizburua sali&oacute; con una ' + $cond.marea.estado_en_regata + ' muy marcada. La corriente facilit&oacute; la ida pero penaliz&oacute; severamente la vuelta al muelle, exigiendo una gesti&oacute;n de vatios muy precisa.</li>')
    $h.Add('<li style="margin-bottom:6px"><strong>Variabilidad del Viento:</strong> A medida que avanz&oacute; la regata, el viento de ' + $cond.viento.direccion + ' se mantuvo constante, lo que permiti&oacute; una comparativa justa entre las tandas iniciales y finales en cuanto a aerodin&aacute;mica.</li>')
    $h.Add('</ul>')
    $verd = if ($aizd.analisis.veredicto) { ConvertTo-HtmlEntity $aizd.analisis.veredicto } else { "La regata se decidi&oacute; en la capacidad de boga sostenida y la gesti&oacute;n de las corrientes locales. Aizburua demostr&oacute; solidez en los tramos de ida, pero el factor ambiental fue determinante en el crono final." }
    $h.Add('<p style="font-weight:700; color:#1a1a2e; padding-top:6px; border-top:1px dashed #dca;">Veredicto Final Total: ' + $verd + '</p>')
} else {
    $h.Add('<p style="margin-bottom:10px">En resumen, bajo un r&eacute;gimen de <strong>' + $cond.marea.estado_en_regata + '</strong>, el rendimiento hidrodin&aacute;mico real de las calles dibuja dos realidades antag&oacute;nicas y asim&eacute;tricas seg&uacute;n qu&eacute; rumbo toques:</p>')
    $h.Add('<ul style="margin-left:20px; margin-bottom:12px; color:#444">')
    
    $peorCIdVal = 1
    if ($peorCalleId) { $peorCIdVal = $peorCalleId }
    $mejorCIdVal = 2
    if ($mejorCalleId) { $mejorCIdVal = $mejorCalleId }
    
    $h.Add('<li style="margin-bottom:6px">Para la <strong>IDA</strong> (Sentido Alta Mar): La <strong>Calle ' + $peorCIdVal + '</strong> es netamente m&aacute;s r&aacute; r&aacute;pida porque discurre por el torrente central de evacuaci&oacute;n hidrogr&aacute;fica.</li>')
    $h.Add('<li style="margin-bottom:6px">Para la <strong>VUELTA</strong> (Sentido Base de Muelle): La <strong>Calle ' + $mejorCIdVal + '</strong> es inmensamente superior por pura amortiguaci&oacute;n isob&aacute;rica orillada.</li>')
    $h.Add('</ul>')
    $h.Add('<p style="font-weight:700; color:#1a1a2e; padding-top:6px; border-top:1px dashed #dca;">Veredicto Final Total: La balanza de ingenier&iacute;a n&aacute;utica corona a la Calle ' + $mejorCIdVal + ' en el c&oacute;mputo global. Y esto se cristaliza porque el castigo de p&eacute;rdida volum&eacute;trica excede con aplastante margen est&aacute;ndar la d&eacute;bil inercia regalada al ir.</p>')
}
$h.Add('</div></div>')


# Linea de Tiempo Atmosférica (Evolución de Viento y Mar)
if ($cond.evolucion_meteo) {
    $meteoArr = @($cond.evolucion_meteo)
    if ($meteoArr.Count -gt 0) {
        $meteoStart = $meteoArr[0].hora
        $meteoEnd = $meteoArr[-1].hora
        $h.Add('<div style="margin:30px 0"><div class="bpl" style="color:var(--blu);margin-bottom:10px">Evoluci&oacute;n Atmosf&eacute;rica (' + $meteoStart + 'h &rarr; ' + $meteoEnd + 'h)</div>')
        $h.Add('<div class="timeline-container"><div class="tl-label-y">Intensidad</div>')
    }

    # Flechas FROM: apuntan DESDE donde viene el viento (convenci&oacute;n meteorol&oacute;gica)
    $dirArrows = @{ 'N' = '&darr;'; 'NE' = '&swarr;'; 'E' = '&larr;'; 'SE' = '&nwarr;'; 'S' = '&uarr;'; 'SW' = '&nearr;'; 'W' = '&rarr;'; 'NW' = '&searr;'; 'NNE' = '&swarr;'; 'NNW' = '&searr;'; 'ENE' = '&larr;'; 'ESE' = '&nwarr;'; 'SSE' = '&nwarr;'; 'SSW' = '&nearr;'; 'WNW' = '&rarr;'; 'WSW' = '&rarr;' }
    foreach ($m in $cond.evolucion_meteo) {
        $wH = [math]::Max($m.viento_kmh * 5, 12)
        $oH = [math]::Max($m.ola_m * 65, 12)
        
        $wDir = ""
        if ($m.viento_dir -and $dirArrows[$m.viento_dir]) { $wDir = $dirArrows[$m.viento_dir] }
        
        $wDirLabel = ""
        if ($m.viento_dir) { $wDirLabel = $m.viento_dir }
        $h.Add("<div class='tl-tick'><div class='tl-bar-group'>")
        $h.Add("<div style='display:flex;flex-direction:column;align-items:center'><span style='font-size:16px;color:var(--r);margin-bottom:1px'>$wDir</span><span style='font-size:11px;font-weight:800;color:var(--r)'>$($m.viento_kmh)</span><span style='font-size:8px;color:#666;margin-bottom:3px'>$wDirLabel</span><div class='tl-bar-wind' style='height:${wH}px'></div></div>")
        $h.Add("<div style='display:flex;flex-direction:column;align-items:center'><span style='font-size:11px;font-weight:800;color:var(--blu);margin-bottom:3px'>$($m.ola_m)m</span><div class='tl-bar-wave' style='height:${oH}px'></div></div>")
        $h.Add("</div><div class='tl-time'>$($m.hora)h</div><div class='tl-desc'>$($m.desc)</div></div>")
    }
    $h.Add('</div><div class="leg-tl">')
    $h.Add('<div class="leg-item"><div class="dot" style="background:var(--r)"></div> Viento (km/h)</div>')
    $h.Add('<div class="leg-item"><div class="dot" style="background:var(--blu)"></div> Ola (m)</div>')
    $h.Add('</div></div>')

    # Grid de 5 variables atmosfericas (debajo del timeline)
    $h.Add('<div class="gs" style="border-top:1px solid var(--bd);padding-top:20px;margin-top:5px">')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Term&oacute;metr&iacute;a Aire / Agua</div><div class="val" style="font-size:18px">' + $CondAire + '&deg;C / ' + $CondAgua + '&deg;C</div><div class="sbl">Superfice y dique Arriluze</div></div>')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Densidad del Agua</div><div class="val" style="font-size:18px">' + $CondDens + ' kg/m&sup3;</div><div class="sbl">Salinidad ' + $CondSal + ' PSU &mdash; agua +densa que dulce</div></div>')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Viento</div><div class="val" style="font-size:18px">' + $CondVkmh + ' km/h (' + $CondVms + ' m/s)</div><div class="sbl">' + $CondVdir + ' &mdash; ' + $CondVdesc + '</div></div>')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Estado del Mar</div><div class="val" style="font-size:13px;color:#1e3a5f;line-height:1.2">' + $CondOla + 'm &mdash; ' + $CondMar + '</div><div class="sbl">Ola NW dificulta la vuelta al muelle</div></div>')
    $h.Add('<div class="st"><div class="lbl" style="color:#64748b;font-weight:700;font-size:10px;text-transform:uppercase;letter-spacing:1px">Horario Mareas</div><div class="val" style="font-size:14px;color:#1e3a5f">PM ' + $MareaPM + 'h / BM ' + $MareaBM + 'h</div><div class="sbl">' + $MareaEst + '</div></div>')
    $h.Add('</div>')
}

# -------- DASHBOARD con leyenda --------
$h.Add('<div class="stitle">Posicionamiento de Aizburua &mdash; 4 formas de leer el resultado</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-p">P</div><h2>Que significan estos numeros</h2></div>')
$h.Add('<div class="g4">')
$h.Add('<div class="pb real"><div class="pn">' + $aizPuesto + '&ordm;/' + $aizTotal + '</div><div class="pt">Puesto Oficial</div><div class="pd">El del marcador. Con el handicap que asigna la liga a cada club.</div></div>')

if ($modalidad -eq "contrareloj") {
    $h.Add('<div class="pb norm"><div class="pn">' + $aizPuestoNorm + '&ordm;/' + $aizTotal + '</div><div class="pt">Sin Desventaja Temporal</div><div class="pd">Midiendo el "tiempo oficial" como si la marea se hubiera mantenido est&aacute;tica para todos los botes.</div></div>')
    $h.Add('<div class="pb proy"><div class="pn">' + $puestoProy + '&ordm;/' + $aizTotal + '</div><div class="pt">Potencia en Ventana &Oacute;ptima</div><div class="pd">Simulaci&oacute;n: el puesto si hubieran remado en el momento de mejores condiciones del d&iacute;a.</div></div>')
} else {
    $h.Add('<div class="pb norm"><div class="pn">' + $aizPuestoNorm + '&ordm;/' + $aizTotal + '</div><div class="pt">Sin Desventaja de Calle</div><div class="pd">Midiendo el "tiempo oficial" como si hubieran remado en aguas neutras (sin penalizaci&oacute;n por Calle ' + $aizCalle + ').</div></div>')
    $h.Add('<div class="pb proy"><div class="pn">' + $puestoProy + '&ordm;/' + $aizTotal + '</div><div class="pt">Potencia en Calle Mas Rapida</div><div class="pd">Midiendo el "tiempo raw puro", si hubieran corrido sin handicap en la calle ganadora.</div></div>')
}

$h.Add('<div class="pb raw"><div class="pn">' + $aizPuestoRaw + '&ordm;/' + $aizTotal + '</div><div class="pt">Sin Handicap de Liga</div><div class="pd">El puesto que habr&iacute;an ocupado ignorando los handicaps reglamentarios, a potencia bruta en su calle real.</div></div>')
$h.Add('</div>')
$h.Add('<div class="legend-grid">')
$h.Add('<div class="leg real"><div class="lt">Puesto Oficial</div>Resultado en el acta de la regata. El handicap iguala clubes de distinto nivel para que la puntuacion de liga sea equilibrada.</div>')

if ($modalidad -eq "contrareloj") {
    $h.Add('<div class="leg norm"><div class="lt">Sin Desventaja Temporal</div>En C.R., el factor determinante es la hora de salida. La marea y el viento cambian durante la sesi&oacute;n. Este n&uacute;mero estima el puesto si las condiciones fueran id&eacute;nticas para todos.</div>')
    $h.Add('<div class="leg proy"><div class="lt">En la Ventana Mas Rapida</div>Simulaci&oacute;n: si Aizburua hubiera salido en el momento de la regata con mejores condiciones hidrodin&aacute;micas, el tiempo estimado ser&iacute;a <strong>' + $tProyFmt + '</strong>.</div>')
} else {
    $h.Add('<div class="leg norm"><div class="lt">Sin Desventaja de Calle</div>Las calles no son iguales: la corriente y el viento favorecen unas sobre otras. Este numero estima donde habria quedado Aizburua si el sorteo hubiera sido neutro.</div>')
    $h.Add('<div class="leg proy"><div class="lt">En la Calle Mas Rapida</div>Simulacion: si Aizburua hubiera salido desde la calle con mejores condiciones (Calle ' + $mejorCalleId + ' en esta regata), el tiempo estimado seria <strong>' + $tProyFmt + '</strong>.</div>')
}

$h.Add('<div class="leg raw"><div class="lt">Sin Handicap de Liga</div>La liga asigna ventajas de tiempo a clubes de menor nivel historico. Sin ese ajuste, este es el puesto por tiempo remado puro.</div>')
$h.Add('</div></div>')

# -------- GRUPO 1 --------
$ciaHeadersHtml = ""
foreach ($ciaKey in $ciabogasHeader) {
    $num = $ciaKey.Split("_")[1]
    $ciaHeadersHtml += "<th>${num}a Ciaboga</th>"
}

$aizGroupName = if ($aizd.grupo) { $aizd.grupo } else { "grupo_1" }
$noteAiz = if($aizGroupName -eq "grupo_1"){"&mdash; Aizburua compite aqu&iacute;"}else{""}
$h.Add('<div class="stitle">Clasificaci&oacute;n Completa &mdash; Grupo 1 (' + $g1Hora + 'h) ' + $noteAiz + '</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-1">1</div><h2>' + $g1.total_participantes + ' participantes &mdash; Ganador: ' + $g1Gan + ' &mdash; Salida primera tanda: ' + $g1Hora + 'h</h2></div>')

$h.Add('<span class="bg1">GRUPO 1 &mdash; ' + $g1Hora + 'h</span>')
$h.Add('<table><thead><tr><th>Pos</th><th>Club</th><th>Hora Salida</th><th>Tanda / Calle</th>' + $ciaHeadersHtml + '<th>Tiempo Real Remado</th><th>Handicap de Liga</th><th>Tiempo Oficial</th></tr></thead><tbody>')
$h.Add($trG1.ToString())
$h.Add('</tbody></table>')
$h.Add('<div style="margin-top:10px;font-size:11px;color:var(--gy)">Media del grupo (tiempo real): <strong>' + $mediaG1Fmt + '</strong> &nbsp;|&nbsp; Media Tanda ' + $aizTanda + ' de Aizburua (tiempo real): <strong>' + $mediaT1Fmt + '</strong></div>')
$h.Add('<div class="info-box" style="margin-top:10px;font-size:10px"><strong>Como leer esta tabla:</strong> "Tiempo Real Remado" = segundos reales en el agua, la medida justa para comparar rendimiento fisico. "Tiempo Oficial" = tiempo real MENOS el handicap de la liga = el que cuenta para la puntuacion.</div>')
$h.Add('</div>')

# -------- GRUPO 2 --------
if ($trG2.Length -gt 0) {
    $noteAiz2 = if($aizGroupName -eq "grupo_2"){"&mdash; Aizburua compite aqu&iacute;"}else{""}
    $h.Add('<div class="stitle">Clasificaci&oacute;n Completa &mdash; Grupo 2 (' + $g2Hora + 'h) ' + $noteAiz2 + '</div>')
    $h.Add('<div class="card"><div class="ch"><div class="ico ico-2">2</div><h2>' + $g2.total_participantes + ' participantes &mdash; Ganador: ' + $g2Gan + ' &mdash; Salida primera tanda: ' + $g2Hora + 'h</h2></div>')

    $h.Add('<span class="bg2">GRUPO 2 &mdash; ' + $g2Hora + 'h</span>')
    $h.Add('<table><thead><tr><th>Pos</th><th>Club</th><th>Hora Salida</th><th>Tanda / Calle</th>' + $ciaHeadersHtml + '<th>Tiempo Real Remado</th><th>Handicap de Liga</th><th>Tiempo Oficial</th></tr></thead><tbody>')
    $h.Add($trG2.ToString())
    $h.Add('</tbody></table></div>')
}

$h.Add('</div>') # Cierra la primera columna del G2 de alineación

# -------- COMPARATIVA DE RENDIMIENTO --------
$h.Add('<div class="stitle">Cu&aacute;nto le sac&oacute; cada rival a Aizburua (usando tiempo real remado)</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-c">C</div><h2>Aizburua vs el Ganador, el Podio y la Media del Grupo 1</h2></div>')

$h.Add('<div class="info-box">Se compara el <strong>tiempo real remado</strong> (sin handicap) para medir el rendimiento fisico de cada trainera. La columna <strong>"vs Aizburua"</strong> muestra la diferencia de tiempo: los valores <strong>negativos (-)</strong> indican que el club fue m&aacute;s r&aacute;pido que Aizburua, y los <strong>positivos (+)</strong> que fue m&aacute;s lento.</div>')
$h.Add('<table><thead><tr><th>Club</th><th>Hora Salida</th><th>1a Ciaboga (dif.)</th><th>Tiempo Real</th><th>vs Aizburua</th><th>En porcentaje</th><th>Nota</th></tr></thead><tbody>')
$h.Add('<tr class="aiz"><td><strong>AIZBURUA</strong> &mdash; T' + $aizTanda + ' C' + $aizCalle + '</td><td>' + $aizHora + 'h</td><td>' + $aizCiab + '</td><td><strong>' + $aizRaw + '</strong></td><td>referencia</td><td>---</td><td>Oficial: ' + $aizFin + '</td></tr>')
$h.Add('<tr><td>1&ordm; <strong>' + (ConvertTo-HtmlEntity $t1Nom) + '</strong> (ganador)</td><td>' + $t1Hora + 'h</td><td>' + $t1Ciab + ' <span style="font-size:10px; color:#C0001A">(' + $dCiaG1 + ')</span></td><td>' + $t1Raw + '</td><td style="color:#C0001A"><strong>' + $dG1 + '</strong></td><td style="color:#C0001A">' + $pG1 + '</td><td>T' + $t1T + ' C' + $t1C + '</td></tr>')
$h.Add('<tr><td>2&ordm; <strong>' + (ConvertTo-HtmlEntity $t2Nom) + '</strong></td><td>' + $t2Hora + 'h</td><td>' + $t2Ciab + ' <span style="font-size:10px; color:#C0001A">(' + $dCiaG2 + ')</span></td><td>' + $t2Raw + '</td><td style="color:#C0001A"><strong>' + $dG2 + '</strong></td><td style="color:#C0001A">' + $pG2 + '</td><td>T' + $t2T + ' C' + $t2C + '</td></tr>')
$h.Add('<tr><td>3&ordm; <strong>' + (ConvertTo-HtmlEntity $t3Nom) + '</strong></td><td>' + $t3Hora + 'h</td><td>' + $t3Ciab + ' <span style="font-size:10px; color:#C0001A">(' + $dCiaG3 + ')</span></td><td>' + $t3Raw + '</td><td style="color:#C0001A"><strong>' + $dG3 + '</strong></td><td style="color:#C0001A">' + $pG3 + '</td><td>T' + $t3T + ' C' + $t3C + '</td></tr>')
$h.Add('<tr style="background:#f0f8ff"><td><em>Media del Grupo 1</em></td><td>---</td><td>' + $mediaCiaG1Fmt + ' <span style="font-size:10px; color:#1a3a6a">(' + $dCiaMediaG1 + ')</span></td><td><em>' + $mediaG1Fmt + '</em></td><td style="color:#1a3a6a"><strong>' + $dGm1 + '</strong></td><td style="color:#1a3a6a">' + $pGm1 + '</td><td>12 participantes</td></tr>')
$h.Add('<tr style="background:#f0f8ff"><td><em>Media Tanda ' + $aizTanda + ' (misma hora)</em></td><td>' + $aizHora + 'h</td><td>' + $mediaCiaT1Fmt + ' <span style="font-size:10px; color:#1a3a6a">(' + $dCiaMediaT1 + ')</span></td><td><em>' + $mediaT1Fmt + '</em></td><td style="color:#1a3a6a"><strong>' + $dTm1 + '</strong></td><td style="color:#1a3a6a">' + $pTm1 + '</td><td>Misma franja horaria</td></tr>')
$h.Add('</tbody></table></div>')

# -------- SECCION RIVALES DIRECTOS PLAYOFF --------
$h.Add('<div class="stitle">Lucha por la Permanencia &mdash; Objetivo PlayOFF</div>')
$h.Add('<div class="card" style="border-top: 5px solid #d35400"><div class="ch"><div class="ico ico-alert" style="background:#d35400">P</div><h2>Rendimiento vs Rivales Directos</h2></div>')
$h.Add('<div class="g2" style="grid-template-columns: 1.8fr 1fr; gap:30px; align-items: start">')
$h.Add('<div><p style="margin-bottom:15px; font-size:12px; color:#555">An&aacute;lisis exhaustivo frente a rivales directos. La secuencia muestra los tiempos en cada punto de control disponible (Ciabogas y Tiempo Real), el h&aacute;ndicap aplicado y el resultado oficial final. Los puntos indican: Regata (Total Liga).</p>')
$cia1Hdr = if ($numCiabogas -ge 1) { "<th>1&ordf; Ciab. (dif)</th>" } else { "" }
$cia2Hdr = if ($numCiabogas -ge 2) { "<th>2&ordf; Ciab. (dif)</th>" } else { "" }
$h.Add('<table style="font-size:12px"><thead><tr style="background:#d35400"><th>#</th><th>Club</th>' + $cia1Hdr + $cia2Hdr + '<th>T. Real (dif)</th><th>Hcp</th><th>T. Final</th><th>vs AIZ</th><th>Pts (Liga)</th></tr></thead><tbody>')
$h.Add($trLucha.ToString())
$h.Add('</tbody></table></div>')
$h.Add('<div style="min-width: 300px"><div class="bpl" style="color:#d35400; margin-bottom:12px">ESTADO DE SITUACI&Oacute;N</div>' + $situacionLucha + $notaEstrategica + '</div>')
$h.Add('</div></div>')

# -------- ANALISIS DE CONDICIONES POR HORA Y CALLE --------
$h.Add('<div class="stitle">An&aacute;lisis de Tiempos por Tanda y Calle (Nivel vs Condiciones)</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-alert">!</div><h2>Evoluci&oacute;n de los promedios durante el ' + $aizGroupName.ToUpper().Replace("_", " ") + ' (' + $mainGroupHora + ' a ' + $mainGroupFinHora + ' aprox.)</h2></div>')

$h.Add('<div class="info-box" style="color:#0a3d62;background:#e3eeff;border-color:#bbd2f5"><strong>Contexto importante sobre las tandas:</strong> El orden de salida esta dictado por las clasificaciones (los peores primero, los mejores al final). Por tanto, es natural que las marcas mejoren tanda a tanda. <strong>Solo si las tandas finales son MAS LENTAS podemos afirmar que las condiciones del campo empeoraron.</strong><br><br>' + $tendenciaGlobal + '</div>')
$h.Add('<table><thead><tr><th>Franja Horaria</th><th>Hora de Salida</th><th>Tiempo Medio Real (Vel.)</th><th>Analisis (considerando que los cabezas de serie salen despues)</th></tr></thead><tbody>')
$h.Add($tandaRows -join "`n")
$h.Add('</tbody></table>')
$h.Add('<div style="margin-top:16px"><div class="bpl" style="margin-bottom:8px">IMPACTO DE LAS CALLES EN EL GRUPO 1</div>')
$h.Add('<table><thead><tr><th>Calle</th><th>Tiempo Medio Real de todos los clubs</th><th>Ventaja o Desventaja vs media</th><th>Veredicto</th></tr></thead><tbody>')

foreach ($cid in ($lanesData.Keys | Sort-Object)) {
    $lane = $lanesData[$cid]
    $rowCls = ""
    if ($aizCalle -eq $cid) { $rowCls = ' class="aiz"' }
    
    $veredicto = "Neutral"
    if ($lane.dif -gt 2) { $veredicto = "M&aacute;s lenta" }
    elseif ($lane.dif -lt -2) { $veredicto = "M&aacute;s r&aacute;pida" }
    
    $h.Add('<tr' + $rowCls + '><td><strong>Calle ' + $cid + '</strong></td><td>' + $lane.fmt + '</td><td style="color:#C0001A">' + $lane.difStr + ' sobre la media del grupo</td><td>' + $veredicto + '</td></tr>')
}
$h.Add('</tbody></table>')
$resumenImpacto = ""
if ($lanesData.Count -gt 1) {
    $resumenImpacto = "<strong>Resumen del impacto en Aizburua:</strong> $veredictoCalles. Aizburua sali&oacute; desde Calle $aizCalle. Simulando la salida desde Calle ${mejorCalleId}: tiempo estimado <strong>$tProyFmt</strong> &rarr; <strong>$puestoProy&ordm; puesto</strong> en lugar de $aizPuesto&ordm;."
} else {
    $resumenImpacto = "<strong>An&aacute;lisis de calle &uacute;nica:</strong> El resultado de Aizburua ($aizPuesto&ordm;) es el rendimiento neto en campo abierto, sin distorsiones por asignaci&oacute;n de calle o topograf&iacute;a diferencial."
}
$h.Add('<div style="margin-top:10px;padding:12px;background:var(--rl);border-radius:6px;font-size:12px;color:var(--rd)">' + $resumenImpacto + '</div>')
$h.Add('</div></div>')


# -------- CALCULO DE RESPONSABILIDADES (ARRIBA PARA EVITAR INFINITY) --------
$diffCia = [math]::Round($sciaAiz - $sciaG1, 1)
$diffFin = [math]::Round($sa - $sg, 1)
$diffVuel = [math]::Round($diffFin - $diffCia, 1)
if ($diffFin -eq 0) { $diffFin = 0.1 } # Evitar division por cero

$fCampo = 0
if ($lanesData.ContainsKey($aizCalle)) {
    $aizLane = $lanesData[$aizCalle]
    $fCampo = [math]::Round($aizLane.dif, 1)
}
if ($fCampo -lt 0) { $fCampo = 0 } 
$fEquipo = [math]::Round($diffFin - $fCampo, 1)
if ($fEquipo -lt 0) { $fEquipo = 0 }

# -------- SECCION CALLES + AUDITORIA --------
$h.Add('<div class="g2" style="margin-top:18px">')

# Columna 1: La Calle
$h.Add('<div class="cc"><h2>La Calle Que le Toco a Aizburua</h2><div class="cnum">Calle ' + $aizCalle + '</div>')
$h.Add('<div style="margin-top:10px;font-size:12px;color:rgba(255,255,255,.85);line-height:1.9">')
foreach ($cid in ($lanesData.Keys | Sort-Object)) {
    $lane = $lanesData[$cid]
    $h.Add('Tiempo medio Calle ' + $cid + ': <strong>' + $lane.fmt + '</strong><br>')
}
$h.Add('La Calle ' + $aizCalle + ' fue <strong style="color:#ff9999">' + $aizLane.difStr + '</strong> mas lenta que la media.<br>')
$h.Add('Tiempo estimado en Calle ' + $mejorCalleId + ': <strong style="color:#ff9999">' + $tProyFmt + '</strong><br>')
$h.Add('Puesto estimado: <strong style="color:#ff9999">' + $puestoProy + '&ordm; de ' + $aizTotal + '</strong></div>')
$verTexto = "Calle Penalizada (" + $aizLane.difStr + ")"
if ($aizLane.dif -lt -1) { $verTexto = "Calle Favorable (" + $aizLane.difStr + ")" }
elseif ($aizLane.dif -le 1) { $verTexto = "Calle Neutra (" + $aizLane.difStr + ")" }
$h.Add('<div class="cverd">' + $verTexto + '</div>')
$mTextExplicativo = $cond.marea.estado_en_regata
if ($mTextExplicativo -like "*vaciante*") { $mTextExplicativo = "Marea Bajando (Corriente M&aacute;xima)" }
$h.Add('<div style="margin-top:12px;font-size:10px;color:rgba(255,255,255,.6);line-height:1.5">')
$h.Add('<strong>Causa t&eacute;cnica:</strong> ' + $mTextExplicativo + '. El impacto de la calle depende de su posicion (Rio vs Playa) y del estado de la marea en el momento de la tanda.<br>')
$h.Add('Handicap de liga de Aizburua: ' + $aizHcp + '</div>')
$h.Add('</div>')

# Columna 2: Auditoria MIX (TARJETAS + NARRATIVA)
$h.Add('<div class="cc" style="background:#1a1a2e; border:1px solid rgba(255,255,255,0.1); padding:25px; box-shadow: 0 4px 15px rgba(0,0,0,0.3)">')
$h.Add('<h2 style="color:var(--r); font-size:14px; text-transform:uppercase; letter-spacing:1px; margin-bottom:20px">Auditor&iacute;a de Responsabilidades</h2>')

# 1. Cabecera Métrica (Estilo Cockpit)
$h.Add('<div style="display:grid; grid-template-columns:1fr 1fr 1fr; gap:15px; margin-bottom:25px">')
$h.Add('  <div style="background:rgba(255,255,255,0.03); padding:12px; border-radius:8px; border-top:2px solid #fff">')
$h.Add('    <span style="font-size:9px; text-transform:uppercase; color:#888; display:block">Brecha vs Ganador</span>')
$h.Add('    <span style="font-size:20px; font-weight:900; color:#fff">+' + $diffFin + 's</span>')
$h.Add('  </div>')
$h.Add('  <div style="background:rgba(255,255,255,0.03); padding:12px; border-radius:8px; border-top:2px solid #ff9999">')
$h.Add('    <span style="font-size:9px; text-transform:uppercase; color:#888; display:block">Factor Campo</span>')
$h.Add('    <span style="font-size:20px; font-weight:900; color:#ff9999">+' + $fCampo + 's</span>')
$h.Add('  </div>')
$h.Add('  <div style="background:rgba(255,255,255,0.03); padding:12px; border-radius:8px; border-top:2px solid var(--r)">')
$h.Add('    <span style="font-size:9px; text-transform:uppercase; color:#888; display:block">Factor Equipo</span>')
$h.Add('    <span style="font-size:20px; font-weight:900; color:var(--r)">+' + $fEquipo + 's</span>')
$h.Add('  </div>')
$h.Add('</div>')

# 2. Cuerpo Narrativo (Auditor&iacute;a de los 4 Largos)
$h.Add('<div style="color:rgba(255,255,255,0.9); line-height:1.6; font-size:12px">')
$h.Add('  <h3 style="color:var(--r); margin-bottom:10px; text-transform:uppercase; font-size:12px">Evoluci&oacute;n T&aacute;ctica por Largo &mdash; ' + $RegNombre + '</h3>')
$h.Add('  <p style="margin-bottom:10px"><strong>An&aacute;lisis de Esfuerzo:</strong> La regata de ' + $RegNombre + ' exigi&oacute; una gesti&oacute;n de ' + $numLargos + ' largo/s. Aizburua mantuvo una frecuencia de <strong>' + $aizd.analisis.frecuencia_boga_real + ' p/min</strong>.</p>')
$h.Add('  <div style="background:rgba(255,255,255,0.05); padding:12px; border-radius:6px; border-left:3px solid var(--r); font-size:11px">')
$h.Add('    <strong>VEREDICTO T&Eacute;CNICO:</strong> ' + $verd + '</div>')
$h.Add('</div>')
$h.Add('</div>') 
$h.Add('</div>') # Cierre de la rejilla g2

# -------- ANALISIS DE RENDIMIENTO (ESTILO NATIVO v4.2) --------
$diffCia = [math]::Round($sciaAiz - $sciaG1, 1)
$diffFin = [math]::Round($sa - $sg, 1)
$diffVuel = [math]::Round($diffFin - $diffCia, 1)

$labelIda = if ($diffCia -le 5) { "Excelente" } elseif ($diffCia -le 12) { "Competitivo" } else { "Lento" }
$labelVuel = if ($diffVuel -le 5) { "S&oacute;lida" } elseif ($diffVuel -le 15) { "Fatiga" } else { "RUPTURA" }

$veredictoFinal = ""
if ($diffVuel -gt ($diffCia * 2) -and $diffVuel -gt 15) {
    $veredictoFinal = "Hundimiento estructural detectado en los tramos de retorno (contra corriente). El equipo no pudo sostener el vatiaje ante 'El Muro', cediendo $diffVuel segundos extra respecto a la ida."
} elseif ($diffCia -gt 15 -and $diffCia -gt $diffVuel) {
    $veredictoFinal = "La regata se perdi&oacute; en la salida. El d&eacute;ficit inicial de $diffCia segundos fue irrecuperable pese a estabilizar la ca&iacute;da en el resto del campo."
} else {
    $veredictoFinal = "Falta de ritmo sostenido. Se requiere mayor vatiaje medio para evitar la ca&iacute;da progresiva de la velocidad a medida que avanza la regata."
}

function Format-TacticalNarrative([string]$text) {
    if (-not $text) { return "" }
    $text = ConvertTo-HtmlEntity $text
    # Resaltar hitos tácticos - USAR COMILLAS SIMPLES PARA EL REEMPLAZO ($1)
    $text = $text -replace '(Largo \d|ciaboga|Ciaboga)', '<strong>$1</strong>'
    $text = $text -replace '(\d+:\d\d/km|sub-\d+:\d\d/km)', '<span style="color:var(--r); font-weight:700">$1</span>'
    $text = $text -replace '(hundimiento estructural|asfixia rotacional|remara en vac&iacute;o|muro|Breaking Point)', '<span style="text-decoration:underline; font-weight:700">$1</span>'
    return $text
}

$cronicaTecnica = "No se dispone de cr&oacute;nica detallada."
if ($aizd.analisis.datos_garmin.analisis_grafica_ritmo) { 
    $cronicaTecnica = Format-TacticalNarrative $aizd.analisis.datos_garmin.analisis_grafica_ritmo 
}

# -------- SECCION FINAL (CRONICA Y AUDITORIA) --------
$h.Add('<div class="stitle">Cr&oacute;nica T&eacute;cnica de Regata</div>')
$h.Add('<div class="card" style="border-left:4px solid var(--r)">')
$h.Add('  <div class="ch"><div class="ico ico-v">!</div><h2>Diagn&oacute;stico T&aacute;ctico &mdash; Breaking Point</h2></div>')
$h.Add('  <div class="info-box" style="background:var(--dk); color:#fff; border:none; padding:15px; font-size:13px"><strong>Veredicto T&eacute;cnico Final:</strong> ' + $veredictoFinal + '</div>')
$h.Add('  <div style="margin-top:20px; padding-top:15px; border-top:1px solid #eee">')
$h.Add('    <h3 style="font-size:11px; text-transform:uppercase; letter-spacing:1px; color:var(--blu); margin-bottom:10px">Detalle de Sensores GPS</h3>')
$h.Add('    <div style="font-size:12.5px; line-height:1.7; color:#333; text-align:justify">' + $cronicaTecnica + '</div>')
$h.Add('  </div>')
$h.Add('</div>')

# Columna 2: Espacio para el siguiente card (Boga y Rendimiento)
# El siguiente card en el script original se cerrará solo al entrar en su flujo.

# -------- BOGA Y RENDIMIENTO (DATOS GPS) --------
$fL1 = "(Sin datos)"
if ($aizd.analisis.frecuencia_boga_L1_real) { $fL1 = $aizd.analisis.frecuencia_boga_L1_real }
$fL2 = "(Sin datos)"
if ($aizd.analisis.frecuencia_boga_L2_real) { $fL2 = $aizd.analisis.frecuencia_boga_L2_real }

$dg = $aizd.analisis.datos_garmin # Lectura de la clave original para estabilidad del script

# Calculo de velocidades dinámicas (m/s) y Metros por Palada (MpP)
$distLargo = $regata.distancia_m / 2
$velL1 = 0 ; $velL2 = 0
if ($sciaAiz -gt 0) { $velL1 = [math]::Round($distLargo / $sciaAiz, 2) }
if ($saAiz -gt $sciaAiz) { $velL2 = [math]::Round($distLargo / ($saAiz - $sciaAiz), 2) }

$dropVel = 0
if ($velL1 -gt 0) { $dropVel = [math]::Round((($velL2 - $velL1) / $velL1) * 100, 0) }

$mppL1 = "---" ; $mppL2 = "---"
if ($fL1 -match '(\d+)-(\d+)') { 
    $avgL1 = ([int]$Matches[1] + [int]$Matches[2]) / 2 
    if ($avgL1 -gt 0) { $mppL1 = [math]::Round(($velL1 * 60) / $avgL1, 2) }
}
if ($fL2 -match '(\d+)-(\d+)') { 
    $avgL2 = ([int]$Matches[1] + [int]$Matches[2]) / 2 
    if ($avgL2 -gt 0) { $mppL2 = [math]::Round(($velL2 * 60) / $avgL2, 2) }
}

$h.Add('<div class="stitle">C&oacute;mo Remaron &mdash; An&aacute;lisis Cruzado de Ritmo y Telemetr&iacute;a</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-r">R</div><h2>Estimaci&oacute;n del Ritmo por Tramo &mdash; Tiempo total real: ' + $aizRaw + ' minutos</h2></div>')

if ($dg) {
    $h.Add('<div class="g2" style="margin-bottom:15px;">')
    $fmtRitmo = $dg.ritmo_medio.Replace("/km", " min/km")
    $h.Add('<div class="info-box" style="background:#f0f4ff;border-color:#1a3a6a;color:#1a3a6a"><strong>M&eacute;tricas de Sensores GPS:</strong><br>Distancia Real: ' + $dg.distancia_real_m + 'm | Desv&iacute;o: ' + $dg.desvio_distancia_m + 'm (ahorro)<br>Ritmo Medio: ' + $fmtRitmo + ' | Vel. M&aacute;xima: ' + $dg.velocidad_maxima_kmh + ' km/h</div>')
    $h.Add('<div class="info-box" style="background:#fffbe6;border-color:#f5c842;color:#7a5a00"><strong>Eficiencia de Trazada:</strong><br>' + $dg.conclusion_desvio + '</div>')

    $h.Add('</div>')
}

$h.Add('<!-- ANALISIS DINAMICO DE LARGOS (v5.0) -->')
$h.Add('<div style="overflow-x:auto;">')
$h.Add('<table style="width:100%"><thead><tr><th>DATO HIDRODIN&Aacute;MICO</th>')

# Cabeceras dinámicas
$distLargo = [math]::Round($regata.distancia_m / $numLargos, 0)
for ($i=1; $i -le $numLargos; $i++) {
    $sentido = if ($i % 2 -ne 0) { "IDA" } else { "VUELTA" }
    $h.Add("<th>L$i ($distLargo" + "m) $sentido</th>")
}
$h.Add('<th style="color:#C0001A">VEREDICTO / FALLO</th></tr></thead><tbody>')

# Fila: Corriente y Viento
$h.Add('<tr><td>Corriente y Viento</td>')
for ($i=1; $i -le $numLargos; $i++) {
    $txtMeteo = if ($i % 2 -ne 0) { "Resistencia/Apoyo (Ida)" } else { "Resistencia/Apoyo (Vuelta)" }
    if ($cond.marea.estado_en_regata -match "vaciante") {
        $txtMeteo = if ($i % 2 -ne 0) { "Contra vaciante" } else { "Vaciante a favor" }
    } elseif ($cond.marea.estado_en_regata -match "pleamar|entrante") {
        $txtMeteo = if ($i % 2 -ne 0) { "A favor de corriente" } else { "Contra corriente" }
    }
    $h.Add("<td>$txtMeteo</td>")
}
$h.Add('<td style="color:#C0001A">Gesti&oacute;n del "Muro" meteorol&oacute;gico</td></tr>')

# Fila: Frecuencia de Boga
$h.Add('<tr><td>Frecuencia de boga</td>')
$frecBase = if ($aizd.analisis.frecuencia_boga_real) { $aizd.analisis.frecuencia_boga_real } else { "34-36" }
for ($i=1; $i -le $numLargos; $i++) {
    $h.Add("<td>$frecBase p/min</td>")
}
$h.Add('<td style="color:#C0001A">Frecuencia sostenida</td></tr>')

# Fila: Metros por Palada (Dinamico)
$h.Add('<tr><td>Metros por palada</td>')
$fVal = 35.0
if ($frecBase -match '(\d+)-(\d+)') {
    $fVal = ([double]$Matches[1] + [double]$Matches[2]) / 2
} elseif ($frecBase -match '(\d+)') {
    $fVal = [double]$Matches[1]
}

for ($i=1; $i -le $numLargos; $i++) {
    $tLargo = if ($i -eq 1) { $aizd.analisis.tiempo_L1_estimado_s } elseif ($i -eq 2) { $aizd.analisis.tiempo_L2_estimado_s } elseif ($i -eq 3) { $aizd.analisis.tiempo_L3_estimado_s } else { $aizd.analisis.tiempo_L4_estimado_s }
    if ($tLargo -gt 0 -and $distLargo -gt 0 -and $fVal -gt 0) {
        $velMS = $distLargo / $tLargo
        $mps = [math]::Round(($velMS * 60) / $fVal, 2)
        $h.Add("<td><strong>$mps m</strong></td>")
    } else {
        $h.Add("<td><strong>---</strong></td>")
    }
}
$h.Add('<td style="color:#C0001A">Eficiencia de palanca</td></tr>')

# Nota de marea
$h.Add('<tr><td colspan="' + ($numLargos + 2) + '" style="background:#fffbe6; font-size:10px; color:#7a5a00; font-style:italic">Nota: Datos calculados mediante integraci&oacute;n de telemetr&iacute;a Garmin y tiempos de paso oficiales.</td></tr>')

# Fila: Desplazamiento útil (Dinamico basado en velocidades)
$h.Add('<tr><td>Desplazamiento &uacute;til</td>')
$vel1 = if ($aizd.analisis.velocidad_L1_ms) { $aizd.analisis.velocidad_L1_ms } else { 0 }
$vel2 = if ($aizd.analisis.velocidad_L2_ms) { $aizd.analisis.velocidad_L2_ms } else { 0 }
for ($i=1; $i -le $numLargos; $i++) {
    $txtUtil = ""
    if ($i % 2 -ne 0) {
        if ($vel1 -gt 0 -and $vel2 -gt 0 -and $vel1 -lt $vel2) { $txtUtil = "Tracci&oacute;n pesada (Mayor Resistencia)" }
        else { $txtUtil = "Ataque fluido y veloz" }
    } else {
        if ($vel1 -gt 0 -and $vel2 -gt 0 -and $vel2 -lt $vel1) { $txtUtil = "Tracci&oacute;n pesada (Mayor Resistencia)" }
        else { $txtUtil = "Aprovechamiento de flujo y planeo" }
    }
    $h.Add("<td>$txtUtil</td>")
}
$h.Add('<td style="color:#C0001A">P&eacute;rdida de inercia en el retorno</td></tr>')

# Fila: Velocidad media (Ritmo) Dinamico
$h.Add('<tr><td>Velocidad media (Ritmo)</td>')
for ($i=1; $i -le $numLargos; $i++) {
    $tLargo = if ($i -eq 1) { $aizd.analisis.tiempo_L1_estimado_s } elseif ($i -eq 2) { $aizd.analisis.tiempo_L2_estimado_s } elseif ($i -eq 3) { $aizd.analisis.tiempo_L3_estimado_s } else { $aizd.analisis.tiempo_L4_estimado_s }
    if ($tLargo -and $distLargo -gt 0) {
        $ritmoKm = (1000 * $tLargo) / $distLargo
        $m = [math]::Floor($ritmoKm / 60)
        $s = [math]::Round($ritmoKm % 60, 0)
        $h.Add("<td>$($m):$($s.ToString('00')) min/km</td>")
    } else {
        $h.Add("<td>N/A</td>")
    }
}
$h.Add('<td style="color:#C0001A">Brecha t&eacute;cnica detectada</td></tr>')

# Fila: Brecha VS el Líder Absoluto
$h.Add('<tr><td>Brecha VS el L&iacute;der Absoluto</td>')
$todosResultados = @()
foreach ($gName in $regata.grupos.PSObject.Properties.Name) {
    if ($regata.grupos.$gName.resultados) { $todosResultados += $regata.grupos.$gName.resultados }
}
$liderAbs = $todosResultados | Sort-Object { TS $_.tiempo_raw } | Select-Object -First 1
$sLiderAbs = TS $liderAbs.tiempo_raw
$sCiaLiderAbs = TS $liderAbs.ciaboga_1
$diffCiaAbs = [math]::Round($sciaAiz - $sCiaLiderAbs, 1)
$diffFinAbs = [math]::Round($sa - $sLiderAbs, 1)
$diffVuelAbs = [math]::Round($diffFinAbs - $diffCiaAbs, 1)

for ($i=1; $i -le $numLargos; $i++) {
    $txtBrecha = ""
    if ($numLargos -eq 2) {
        $txtBrecha = if ($i -eq 1) { "+$diffCiaAbs s (en ciaboga)" } else { "+$diffVuelAbs s (total +$diffFinAbs s)" }
    } elseif ($numLargos -eq 4) {
        if ($i -eq 1) { $txtBrecha = "+$diffCiaAbs s (C1)" }
        elseif ($i -eq 4) { $txtBrecha = "+$diffVuelAbs s (Total: +$diffFinAbs s)" }
        else { $txtBrecha = "---" }
    }
    $h.Add("<td>$txtBrecha</td>")
}
$h.Add('<td style="color:#C0001A">D&eacute;ficit de vatiaje absoluto</td></tr>')

$h.Add('</tbody></table>')
$h.Add('</div>')

# Diagnostico Segmentado Dinámico
$h.Add('<div class="diag-box">')
$h.Add('<div class="diag-header">An&aacute;lisis de Esfuerzo &mdash; Gesti&oacute;n T&aacute;ctica por Largos</div>')

if ($aizd.analisis.datos_garmin.analisis_grafica_ritmo) {
    $h.Add('<div class="diag-segment" style="margin-bottom:0">')
    $h.Add('<span class="diag-label">INFORME DE TELEMETR&Iacute;A COMPLETO</span>')
    $h.Add('<div class="diag-content">' + (Format-TacticalNarrative $aizd.analisis.datos_garmin.analisis_grafica_ritmo) + '</div>')
    $h.Add('</div>')
} else {
    for ($i=1; $i -le $numLargos; $i++) {
        $label = if ($i % 2 -ne 0) { "EXPLOSI&Oacute;N E IDA" } else { "RETORNO Y SPRINT" }
        $h.Add('<div class="diag-segment">')
        $h.Add("<span class='diag-label'>LARGO $($i): $($label)</span>")
        $h.Add('<div class="diag-content">Tramo de boga estable manteniendo la frecuencia objetivo y gestionando las condiciones del campo.</div>')
        $h.Add('</div>')
    }
}

$h.Add('</div>') # Cierre de diag-box
$h.Add('</div>') # Cierre de card


# -------- ALINEACION --------
$h.Add('<div class="stitle">Tripulaci&oacute;n de Aizburua</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-r">A</div><h2>Disposici&oacute;n en la Trainera &mdash; Bancada 1 = Popa (junto al patr&oacute;n), Bancada 6 = Proa</h2></div><div class="g2" style="align-items:start">')

$h.Add('<table class="tt"><thead><tr>')
$h.Add('<th style="background:#1a1a2e;color:#fff;border-radius:5px;padding:7px">Bancada</th>')
$h.Add('<th style="background:#0a3d62;color:#fff;border-radius:5px;padding:7px">Babor (lado izq.) &mdash; edad</th>')
$h.Add('<th style="background:#145a32;color:#fff;border-radius:5px;padding:7px">Estribor (lado der.) &mdash; edad</th>')
$h.Add('</tr></thead><tbody>')
$h.Add($trAli.ToString())
$h.Add('</tbody></table>')

# -- LEYENDA A LA DERECHA DE LA TABLA --
$h.Add('<div style="background:var(--lg);border-radius:10px;padding:14px;align-self:start"><div style="font-size:10px;text-transform:uppercase;color:var(--gy);margin-bottom:10px">Datos de Salida y Edad</div><div style="display:grid;gap:7px">')
$h.Add('<div style="background:#d4edfa;padding:7px 12px;border-radius:5px;font-size:11px;color:#0a3d62"><strong>Babor (B)</strong>: Lado izquierdo mirando de popa hacia proa</div>')
$h.Add('<div style="background:#d5f5e3;padding:7px 12px;border-radius:5px;font-size:11px;color:#145a32"><strong>Estribor (E)</strong>: Lado derecho mirando de popa hacia proa</div>')
$h.Add('<div style="background:var(--rl);padding:7px 12px;border-radius:5px;font-size:11px;color:var(--rd)"><strong>Bancada 1 &mdash; POPA</strong>: Los dos remeros m&aacute;s cercanos al patr&oacute;n</div>')
$h.Add('<div style="background:#f0f4ff;padding:7px 12px;border-radius:5px;font-size:11px;color:#1a3a6a"><strong>Tanda ' + $aizTanda + ' &mdash; Calle ' + $aizCalle + '</strong> | Salida: ' + $aizHora + 'h | H&aacute;ndicap de liga: ' + $aizHcp + '</div>')
    if ($totalConfirm -gt 0) {
        $h.Add('<div style="background:#fff8e1;padding:7px 12px;border-radius:5px;font-size:11px;color:#7a5a00"><strong>Edad Media Tripulaci&oacute;n</strong>: <strong>' + $edadMediaStr + '</strong> (' + $totalConfirm + '/' + $totalMiembros + ' confirmadas)</div>')
    }
    $h.Add('</div></div>')
    $h.Add('</div>') # Cierra el g2 para que la tabla y leyenda estén juntas

    # --- TABLA DE EQUILIBRIO DE MASAS (NUEVA SECCIÓN) ---
$difColor = if ([math]::Abs($difPeso) -gt 15) { "#C0001A" } else { "#145a32" }
$h.Add('<div style="margin-top:20px; background:#f8f9fa; border-radius:10px; padding:20px; border:1px solid #ddd">')
$h.Add('<div style="font-size:11px; font-weight:800; text-transform:uppercase; letter-spacing:1px; margin-bottom:15px; color:#555">Equilibrio de Masas y Trimado Lateral (Excl. Proa/Patr&oacute;n para B/E)</div>')
$h.Add('<div style="display:grid; grid-template-columns: repeat(4, 1fr); gap:15px">')
$h.Add('<div class="st" style="border-left-color:#1a1a2e"><div class="lbl">Peso Total Tripulaci&oacute;n</div><div class="val">' + $pesoTripulacion + ' kg</div><div class="sbl">Incluye Proa y Patr&oacute;n</div></div>')
$h.Add('<div class="st" style="border-left-color:#0a3d62"><div class="lbl">Total Babor (B1-B6)</div><div class="val">' + $pesoBabor + ' kg</div><div class="sbl">Motor de babor</div></div>')
$h.Add('<div class="st" style="border-left-color:#145a32"><div class="lbl">Total Estribor (E1-E6)</div><div class="val">' + $pesoEstribor + ' kg</div><div class="sbl">Motor de estribor</div></div>')
$h.Add('<div class="st" style="border-left-color:' + $difColor + '"><div class="lbl">Desequilibrio Lateral</div><div class="val">' + $difPeso + ' kg</div><div class="sbl">Diferencia Babor - Estribor</div></div>')
$h.Add('</div>')

$absDif = [math]::Abs($difPeso)
if ($absDif -gt 15) {
    $h.Add("<div class='tactical-alert' style='margin-top:15px'>")
    $h.Add("$svgIcon <span><strong>ALERTA DE TRIMADO CR&Iacute;TICO:</strong> Existe un desequilibrio lateral de <strong>$absDif kg</strong>. El bote escora excesivamente hacia el lado m&aacute;s pesado, aumentando la superficie mojada (fricci&oacute;n). El patr&oacute;n debe meter tim&oacute;n constantemente para evitar que el bote gire, lo que act&uacute;a como un freno continuo.</span></div>")
} elseif ($absDif -gt 5) {
    $h.Add('<div class="info-box" style="margin-top:15px; background:#fffbe6; border-color:#f5c842; color:#7a5a00">')
    $h.Add('<strong>DESV&Iacute;O LEVE:</strong> Diferencia lateral de <strong>' + $absDif + ' kg</strong>. El bote tender&aacute; a escorar ligeramente. Situaci&oacute;n manejable pero requerir&aacute; peque&ntilde;as correcciones de rumbo por parte del patr&oacute;n.</div>')
} else {
    $h.Add('<div class="info-box" style="margin-top:15px; background:#f2fdf5; border-color:#ccffdd; color:#145a32">')
    $h.Add('<strong>TRIMADO &Oacute;PTIMO:</strong> El equilibrio lateral es excelente (diferencia de ' + $absDif + ' kg). El bote navegar&aacute; totalmente plano, minimizando la fricci&oacute;n y maximizando la eficiencia de cada palada.</div>')
}
$h.Add('</div>')
$h.Add('</div>') # Cierra el card

# -------- ANALISIS DE EDAD --------
$h.Add('<div class="stitle">Perfil de Edad de la Tripulaci&oacute;n</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-e">E</div><h2>M&eacute;tricas de Edad &mdash; Referencia para comparativas futuras entre regatas</h2></div>')

if ($totalConfirm -lt $totalMiembros) {
    $h.Add('<div class="info-box">Edades confirmadas: <strong>' + $totalConfirm + ' de ' + $totalMiembros + '</strong>. Las estad&iacute;sticas parciales se basan en las edades disponibles. Puedes completarlas en el JSON con el dato del patr&oacute;n + PDF de alineaci&oacute;n.</div>')
}
$h.Add('<div class="gs" style="margin-bottom:16px">')
$h.Add('<div class="st"><div class="lbl">Edad Media Tripulaci&oacute;n</div><div class="val">' + $edadMediaStr + '</div><div class="sbl">' + $totalConfirm + '/' + $totalMiembros + ' datos confirmados</div></div>')
$h.Add('<div class="st"><div class="lbl">Rango de Edades</div><div class="val">' + $edadRangoStr + '</div><div class="sbl">El m&aacute;s joven vs el m&aacute;s veterano</div></div>')
$h.Add('<div class="st"><div class="lbl">Media Bloque Popa (B1-B2)</div><div class="val">' + $avgPopaStr + '</div></div>')
$h.Add('<div class="st"><div class="lbl">Media Bloque Central (B3-B4)</div><div class="val">' + $avgCentralStr + '</div></div>')
$h.Add('<div class="st"><div class="lbl">Media Bloque Proa (B5-B6)</div><div class="val">' + $avgProaStr + '</div></div>')
$h.Add('</div>')
$h.Add('<div class="info-box" style="font-size:11px"><strong>Para qu&eacute; sirve esto en futuras regatas:</strong> La edad media de la tripulaci&oacute;n cambia con cada regata seg&uacute;n la alineaci&oacute;n. Correlacionar la edad media con el tiempo real remado permitir&aacute; identificar si existe un umbral &oacute;ptimo de edad para esta tripulaci&oacute;n, y si la rotaci&oacute;n de remeros entre regatas afecta positiva o negativamente al rendimiento. En categor&iacute;a veteranos, factores como la gesti&oacute;n energ&eacute;tica y la t&eacute;cnica compensan la p&eacute;rdida de potencia bruta por edad.</div>')
$h.Add('</div>')

if ($alertaHcpHtml) { $alertaHcpHtml }

# -------- RECOMENDACIONES --------
$h.Add('<div class="stitle">Conclusiones T&eacute;cnicas Inmediatas</div>')
$h.Add('<div class="card"><div class="ch"><div class="ico ico-star">*</div><h2>Puntos de Acci&oacute;n Concretos tras la Radiograf&iacute;a F&iacute;sica</h2></div><ul class="rl">')

$ladoPesado = if ($difPeso -lt 0) { "estribor" } else { "babor" }
if ($absDif -gt 15) {
    $h.Add("<li><strong>Alerta de Trimado (Desequilibrio Cr&iacute;tico).</strong> Se rem&oacute; con una descompensaci&oacute;n lateral de <strong>$absDif kg</strong> hacia $ladoPesado. Esto es un freno hidrodin&aacute;mico severo: el bote escora, aumenta la fricci&oacute;n y obliga al patr&oacute;n a meter tim&oacute;n constantemente. Es imperativo redistribuir los pesos en futuras alineaciones para no regalar vatios al agua.</li>")
} elseif ($absDif -gt 5) {
    $h.Add("<li><strong>Desv&iacute;o de Trimado Leve.</strong> Diferencia lateral de <strong>$absDif kg</strong> hacia $ladoPesado. Situaci&oacute;n manejable pero requiere atenci&oacute;n en alineaciones futuras para no obligar al patr&oacute;n a corregir el rumbo.</li>")
} else {
    $h.Add("<li><strong>Trimado &Oacute;ptimo.</strong> El equilibrio lateral de masas fue excelente (diferencia de solo <strong>$absDif kg</strong>). Esto permiti&oacute; una navegaci&oacute;n plana minimizando el drag hidrodin&aacute;mico.</li>")
}

$frecBase = if ($aizd.analisis.frecuencia_boga_real) { $aizd.analisis.frecuencia_boga_real } else { "N/A" }
$h.Add("<li><strong>Gesti&oacute;n t&aacute;ctica de la Frecuencia.</strong> La embarcaci&oacute;n sostuvo una boga media de <strong>$frecBase p/min</strong> a lo largo de la regata. Es vital evaluar junto al cuerpo t&eacute;cnico si esta frecuencia permiti&oacute; suficiente agarre o si gener&oacute; fatiga prematura contra los elementos del campo.</li>")

if ($aizd.analisis.datos_garmin -and $aizd.analisis.datos_garmin.PSObject.Properties['desvio_distancia_m']) {
    $desvio = [int]$aizd.analisis.datos_garmin.desvio_distancia_m
    $absDesvio = [math]::Abs($desvio)
    if ($desvio -lt 0) {
        $secsAhorro = [math]::Round($absDesvio / 4.1, 1) # Aprox 4.1 m/s (ritmo de regata)
        $h.Add("<li><strong>Navegaci&oacute;n Milim&eacute;trica del Patr&oacute;n.</strong> La trazada GPS ahorr&oacute; <strong>$absDesvio metros</strong> netos sobre el campo oficial. Esto equivale a una inyecci&oacute;n de ~$secsAhorro segundos 'gratis' que mitig&oacute; el hundimiento del cron&oacute;metro.</li>")
    } elseif ($desvio -gt 0) {
        $secsPerdida = [math]::Round($absDesvio / 4.1, 1)
        $h.Add("<li><strong>Exceso de Metraje en Navegaci&oacute;n.</strong> El GPS marca un exceso de <strong>$absDesvio metros</strong> remados sobre la distancia oficial. Esto supone una p&eacute;rdida de ~$secsPerdida segundos regalados. Se debe auditar las viradas y la elecci&oacute;n de rumbo.</li>")
    } else {
        $h.Add("<li><strong>Navegaci&oacute;n de Precisi&oacute;n Oficial.</strong> La distancia remada coincide exactamente con el marcaje oficial del campo de regatas.</li>")
    }
}

$ritmoGeneralMs = if ($sa -gt 0) { $regata.distancia_m / $sa } else { 0 }
$ritmoGeneralFmt = if ($ritmoGeneralMs -gt 0) { 
    $rK = 1000/$ritmoGeneralMs; $rm = [math]::Floor($rK/60); $rs = [math]::Round($rK%60,0); "$($rm):$($rs.ToString('00')) min/km" 
} else { "N/A" }
$h.Add("<li><strong>Diagn&oacute;stico del D&eacute;ficit F&iacute;sico.</strong> El ritmo base promedio del bote se estableci&oacute; en <strong>$ritmoGeneralFmt</strong>. La brecha final total detectada frente al ganador de la jornada fue de <strong>+$diffFinAbs s</strong>. El objetivo prioritario a trabajar es el incremento del vatiaje aer&oacute;bico absoluto para lograr reducir este diferencial.</li>")
$h.Add('</ul></div>')
$h.Add('</div>')
$h.Add('<div class="ftr">')
if ($logo2Base64) {
    $h.Add('  <img src="data:image/jpeg;base64,' + $logo2Base64 + '" class="logo-footer" alt="Branding Aizburua">')
}
$h.Add('  <div>Club Aizburua &mdash; Liga AKK 11.1 &mdash; ' + $RegFecha + ' &mdash; ' + $RegLugar + '</div>')
$h.Add('</div>')
$h.Add('</body></html>')

$content = $h -join "`n"
[System.IO.File]::WriteAllText($htmlFile, $content, [System.Text.Encoding]::UTF8)

# --- SINCRONIZACION AUTOMATICA DE ESTADISTICAS (v6.9) ---
function Sync-RowerStats {
    param([string]$remerosFile, [string]$historicoFile)
    
    if (-not (Test-Path $remerosFile) -or -not (Test-Path $historicoFile)) { 
        Write-Host "Error: No se encuentran los archivos para sincronizar." -ForegroundColor Red
        return 
    }
    
    $remeros = Get-Content $remerosFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $historico = Get-Content $historicoFile -Raw -Encoding UTF8 | ConvertFrom-Json
    
    # Resetear contadores
    foreach ($r in $remeros) {
        if (-not $r.PSObject.Properties['regatas_temporada']) {
            $r | Add-Member -MemberType NoteProperty -Name 'regatas_temporada' -Value 0 -Force
        } else { $r.regatas_temporada = 0 }
    }

    foreach ($reg in $historico.regatas) {
        if (-not $reg.aizburua -or -not $reg.aizburua.alineacion) { continue }
        $nombresEnRegata = @()
        $ali = $reg.aizburua.alineacion
        
        $extract = {
            param($obj)
            if (-not $obj) { return $null }
            if ($obj -is [string]) { return $obj.ToUpper().Trim() }
            if ($obj.nombre) { return $obj.nombre.ToUpper().Trim() }
            return $null
        }

        # Patron y Proa
        $p = &$extract $ali.patron ; if ($p) { $nombresEnRegata += $p }
        $pr = &$extract $ali.proa ; if ($pr) { $nombresEnRegata += $pr }
        
        # Bancadas
        if ($ali.bancadas) {
            foreach ($bNum in $ali.bancadas.PSObject.Properties.Name) {
                $bn = $ali.bancadas.$bNum
                $b = &$extract $bn.B ; if ($b) { $nombresEnRegata += $b }
                $e = &$extract $bn.E ; if ($e) { $nombresEnRegata += $e }
            }
        }
        
        # Retrocompatibilidad
        foreach ($banda in @('babor', 'estribor')) {
            if ($ali.$banda) {
                foreach ($prop in $ali.$banda.PSObject.Properties) {
                    $n = &$extract $prop.Value ; if ($n) { $nombresEnRegata += $n }
                }
            }
        }

        $nombresEnRegata = $nombresEnRegata | Select-Object -Unique

        foreach ($nom in $nombresEnRegata) {
            # Logica de match robusta (v7.1)
            $match = $remeros | Where-Object { 
                ($_.nombre.ToUpper().Trim() -eq $nom) -or 
                ($_.PSObject.Properties['apodo'] -and $_.apodo.ToUpper().Trim() -eq $nom) -or
                ($nom -match "POTXE|J\.ANTONIO" -and ($_.apodo -eq "Potxe" -or $_.nombre -match "Antonio")) -or
                ($nom -match "JABIER" -and ($_.apodo -eq "Jabier" -or $_.nombre -match "Javier")) -or
                ($nom -match "I.AKI" -and $_.nombre -match "Iñaki")
            } | Select-Object -First 1
            if ($match) { $match.regatas_temporada++ }
        }
    }
    $remeros | ConvertTo-Json -Depth 10 | Set-Content $remerosFile -Encoding UTF8
}

Sync-RowerStats -remerosFile $plantillaPath -historicoFile $jsonPath

Write-Host "HTML generado: $htmlFile" -ForegroundColor Green
Write-Host "Estadisticas de remeros sincronizadas (v7.1)." -ForegroundColor Cyan
Write-Host "Recomendacion: Usa Chrome (Ctrl+P) si deseas guardar el informe como PDF."
Invoke-Item $htmlFile
