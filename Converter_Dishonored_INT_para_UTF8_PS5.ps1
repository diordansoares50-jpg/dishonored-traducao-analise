<##
 DISHONORED - CONVERSOR PARA UTF-8
 Compatível com Windows PowerShell 5.1 e PowerShell 7+

 Cria cópias UTF-8 dos arquivos .int das pastas Tribo_INT e
 DeepSeek_INT, sem modificar os arquivos originais.
##>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " DISHONORED - CONVERSOR PARA UTF-8" -ForegroundColor Cyan
Write-Host " Compatível com Windows PowerShell 5.1 / PowerShell 7" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

function Test-IntFolder {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }
    return @(
        Get-ChildItem -LiteralPath $Path -Filter "*.int" -File -Recurse -ErrorAction SilentlyContinue
    ).Count -gt 0
}

function Find-RepositoryRoot {
    $candidates = @(
        (Join-Path $env:USERPROFILE "Desktop\dishonored-traducao-analise"),
        (Join-Path $env:USERPROFILE "Documents\dishonored-traducao-analise"),
        (Join-Path $env:USERPROFILE "Downloads\dishonored-traducao-analise")
    )

    foreach ($candidate in $candidates) {
        $tribo = Join-Path $candidate "Tribo_INT"
        $deep = Join-Path $candidate "DeepSeek_INT"
        if ((Test-IntFolder $tribo) -and (Test-IntFolder $deep)) { return $candidate }
    }
    return $null
}

function Decode-File {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)

    if ($bytes.Length -eq 0) {
        return [PSCustomObject]@{ Text=""; Encoding="Vazio"; Bytes=0 }
    }

    # UTF-16 LE BOM: FF FE
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $enc = New-Object System.Text.UnicodeEncoding($false, $true)
        return [PSCustomObject]@{
            Text=$enc.GetString($bytes,2,$bytes.Length-2); Encoding="UTF-16 LE"; Bytes=$bytes.Length
        }
    }

    # UTF-16 BE BOM: FE FF
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $enc = New-Object System.Text.UnicodeEncoding($true, $true)
        return [PSCustomObject]@{
            Text=$enc.GetString($bytes,2,$bytes.Length-2); Encoding="UTF-16 BE"; Bytes=$bytes.Length
        }
    }

    # UTF-8 BOM: EF BB BF
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $enc = New-Object System.Text.UTF8Encoding($false, $true)
        return [PSCustomObject]@{
            Text=$enc.GetString($bytes,3,$bytes.Length-3); Encoding="UTF-8 BOM"; Bytes=$bytes.Length
        }
    }

    # UTF-8 estrito, sem BOM
    try {
        $enc = New-Object System.Text.UTF8Encoding($false, $true)
        $text = $enc.GetString($bytes)
        return [PSCustomObject]@{ Text=$text; Encoding="UTF-8"; Bytes=$bytes.Length }
    }
    catch {}

    # Fallback Windows-1252
    try {
        $enc = [System.Text.Encoding]::GetEncoding(1252)
        $text = $enc.GetString($bytes)
        return [PSCustomObject]@{ Text=$text; Encoding="Windows-1252"; Bytes=$bytes.Length }
    }
    catch {
        throw "Não foi possível decodificar o arquivo."
    }
}

# Localizar automaticamente o repositório
$RepoRoot = Find-RepositoryRoot

if (-not $RepoRoot) {
    Write-Host "Não encontrei automaticamente o repositório." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Informe o caminho da pasta principal do repositório."
    Write-Host "Exemplo: C:\Users\Usuario\Desktop\dishonored-traducao-analise"
    Write-Host ""
    $RepoRoot = Read-Host "Caminho do repositório"
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        Write-Host "Nenhum caminho informado. Encerrando." -ForegroundColor Red
        exit 1
    }
    $RepoRoot = $RepoRoot.Trim().Trim('"')
}

$TriboSource = Join-Path $RepoRoot "Tribo_INT"
$DeepSource = Join-Path $RepoRoot "DeepSeek_INT"
$TriboOutput = Join-Path $RepoRoot "Tribo_INT_UTF8"
$DeepOutput = Join-Path $RepoRoot "DeepSeek_INT_UTF8"

if (-not (Test-IntFolder $TriboSource)) {
    Write-Host "ERRO: não encontrei arquivos .int em:" -ForegroundColor Red
    Write-Host $TriboSource
    exit 1
}
if (-not (Test-IntFolder $DeepSource)) {
    Write-Host "ERRO: não encontrei arquivos .int em:" -ForegroundColor Red
    Write-Host $DeepSource
    exit 1
}

Write-Host "Repositório encontrado:" -ForegroundColor Green
Write-Host $RepoRoot
Write-Host ""
Write-Host "Origem Tribo:" -ForegroundColor DarkGray
Write-Host $TriboSource
Write-Host "Origem DeepSeek:" -ForegroundColor DarkGray
Write-Host $DeepSource
Write-Host ""

Write-Host "O script criará somente:" -ForegroundColor Cyan
Write-Host "  $TriboOutput"
Write-Host "  $DeepOutput"
Write-Host ""
Write-Host "Os arquivos originais NÃO serão modificados." -ForegroundColor Green
Write-Host ""

$answer = Read-Host "Digite S para continuar"
if ($answer -notmatch "^[sS]$") {
    Write-Host "Operação cancelada. Nenhum arquivo foi alterado." -ForegroundColor Yellow
    exit 0
}

New-Item -ItemType Directory -Force -Path $TriboOutput | Out-Null
New-Item -ItemType Directory -Force -Path $DeepOutput | Out-Null

# UTF-8 com BOM, apenas para as cópias de análise
$Utf8Bom = New-Object System.Text.UTF8Encoding($true)

$Results = New-Object System.Collections.Generic.List[object]
$Errors = New-Object System.Collections.Generic.List[object]

function Convert-IntFolder {
    param(
        [string]$SourceRoot,
        [string]$OutputRoot,
        [string]$SourceName
    )

    $files = @(
        Get-ChildItem -LiteralPath $SourceRoot -Filter "*.int" -File -Recurse |
        Where-Object { $_.Name -notmatch "_bkp\.int$" } |
        Sort-Object FullName
    )

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "Convertendo: $SourceName" -ForegroundColor DarkCyan
    Write-Host "Arquivos encontrados: $($files.Count)" -ForegroundColor DarkCyan
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan

    $count = 0

    foreach ($file in $files) {
        $count++
        try {
            $decoded = Decode-File $file.FullName

            # Mantém a estrutura relativa da pasta de origem
            $relative = $file.FullName.Substring($SourceRoot.Length).TrimStart('\','/')
            $destination = Join-Path $OutputRoot $relative
            $destinationDirectory = Split-Path -Parent $destination

            if (-not (Test-Path -LiteralPath $destinationDirectory)) {
                New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
            }

            [System.IO.File]::WriteAllText($destination, $decoded.Text, $Utf8Bom)

            $Results.Add([PSCustomObject]@{
                Origem=$SourceName
                Arquivo=$relative
                Codificacao=$decoded.Encoding
                BytesOriginais=$decoded.Bytes
                Status="OK"
                Destino=$destination
            })

            if (($count % 25) -eq 0 -or $count -eq 1 -or $count -eq $files.Count) {
                Write-Host ("  {0}/{1} - {2} [{3}]" -f $count,$files.Count,$file.Name,$decoded.Encoding) -ForegroundColor DarkGray
            }
        }
        catch {
            $message = $_.Exception.Message
            $Errors.Add([PSCustomObject]@{
                Origem=$SourceName
                Arquivo=$file.FullName
                Erro=$message
            })
            Write-Host "  ERRO: $($file.Name)" -ForegroundColor Red
            Write-Host "  $message" -ForegroundColor Red
        }
    }

    Write-Host "Finalizado: $SourceName" -ForegroundColor Green
}

Write-Host ""
Write-Host "[1/3] Convertendo Tribo..." -ForegroundColor Yellow
Convert-IntFolder -SourceRoot $TriboSource -OutputRoot $TriboOutput -SourceName "Tribo"

Write-Host ""
Write-Host "[2/3] Convertendo DeepSeek..." -ForegroundColor Yellow
Convert-IntFolder -SourceRoot $DeepSource -OutputRoot $DeepOutput -SourceName "DeepSeek"

Write-Host ""
Write-Host "[3/3] Gerando relatórios..." -ForegroundColor Yellow

$ReportCsv = Join-Path $RepoRoot "Conversao_UTF8_Relatorio.csv"
$ErrorCsv = Join-Path $RepoRoot "Conversao_UTF8_Erros.csv"
$SummaryTxt = Join-Path $RepoRoot "Conversao_UTF8_Resumo.txt"

$Results | Export-Csv -LiteralPath $ReportCsv -NoTypeInformation -Delimiter ';' -Encoding UTF8
$Errors | Export-Csv -LiteralPath $ErrorCsv -NoTypeInformation -Delimiter ';' -Encoding UTF8

$triboOk = @($Results | Where-Object { $_.Origem -eq "Tribo" -and $_.Status -eq "OK" }).Count
$deepOk = @($Results | Where-Object { $_.Origem -eq "DeepSeek" -and $_.Status -eq "OK" }).Count
$utf16LE = @($Results | Where-Object { $_.Codificacao -eq "UTF-16 LE" }).Count
$utf8 = @($Results | Where-Object { $_.Codificacao -eq "UTF-8" -or $_.Codificacao -eq "UTF-8 BOM" }).Count
$win1252 = @($Results | Where-Object { $_.Codificacao -eq "Windows-1252" }).Count
$empty = @($Results | Where-Object { $_.Codificacao -eq "Vazio" }).Count

@"
============================================================
DISHONORED - CONVERSÃO PARA UTF-8
============================================================

REPOSITÓRIO:
$RepoRoot

ORIGEM TRIBO:
$TriboSource

ORIGEM DEEPSEEK:
$DeepSource

SAÍDAS:
$TriboOutput
$DeepOutput

------------------------------------------------------------
RESULTADO
------------------------------------------------------------

Arquivos Tribo convertidos:       $triboOk
Arquivos DeepSeek convertidos:    $deepOk
Erros:                             $($Errors.Count)

------------------------------------------------------------
CODIFICAÇÕES DETECTADAS
------------------------------------------------------------

UTF-16 LE:                         $utf16LE
UTF-8 / UTF-8 BOM:                 $utf8
Windows-1252:                      $win1252
Arquivos vazios:                   $empty

------------------------------------------------------------
ARQUIVOS DE RELATÓRIO
------------------------------------------------------------

Conversao_UTF8_Relatorio.csv
Conversao_UTF8_Erros.csv
Conversao_UTF8_Resumo.txt

------------------------------------------------------------
IMPORTANTE
------------------------------------------------------------

As pastas originais Tribo_INT e DeepSeek_INT NÃO foram alteradas.
As novas pastas *_UTF8 são apenas cópias para análise.
NÃO use as cópias *_UTF8 diretamente no jogo.
"@ | Set-Content -LiteralPath $SummaryTxt -Encoding UTF8

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host " CONVERSÃO CONCLUÍDA" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Tribo convertidos:    $triboOk" -ForegroundColor Cyan
Write-Host "DeepSeek convertidos: $deepOk" -ForegroundColor Cyan
if ($Errors.Count -eq 0) {
    Write-Host "Erros:                0" -ForegroundColor Green
} else {
    Write-Host "Erros:                $($Errors.Count)" -ForegroundColor Yellow
    Write-Host "Consulte: $ErrorCsv" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Pastas criadas:" -ForegroundColor Cyan
Write-Host "  $TriboOutput"
Write-Host "  $DeepOutput"
Write-Host ""
Write-Host "Nenhum arquivo original foi modificado." -ForegroundColor Green
Write-Host ""
