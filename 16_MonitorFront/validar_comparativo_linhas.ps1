param(
    [string]$Database = "NOPONTO",
    [string]$User = "dba",
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [int]$IdEmpresa = 1,
    [string]$DtMonitor = "1900-01-01 00:00:00",
    [string]$Completa = "F",
    [string]$ConsultaFiltro = ""
)

$ErrorActionPreference = "Stop"

function Invoke-Db2 {
    param(
        [string]$Sql,
        [string]$Label
    )

    $tempFile = Join-Path $env:TEMP ("monitorfront_count_{0}.sql" -f ([guid]::NewGuid().ToString("N")))
    try {
        Set-Content -Path $tempFile -Value $Sql -Encoding ASCII
        $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
        $output = & db2 -x -tf $tempFile 2>&1
        $exitCode = $LASTEXITCODE
        $elapsed.Stop()

        [pscustomobject]@{
            Label = $Label
            ExitCode = $exitCode
            Seconds = [math]::Round($elapsed.Elapsed.TotalSeconds, 3)
            Output = ($output -join "`n").Trim()
        }
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force
        }
    }
}

function Get-PreparedQuery {
    param(
        [string]$Path,
        [int]$IdEmpresa,
        [string]$Uf,
        [string]$DtMonitor,
        [string]$Completa
    )

    $sql = Get-Content -Path $Path -Raw

    if ($Path -like "*_v2.txt") {
        $sql = $sql -replace "(?is)(FROM\s+DBA\.EMPRESA\s+EMPRESA)(\s*\))", "`$1`r`n    WHERE EMPRESA.IDEMPRESA = $IdEmpresa`$2"
    }
    else {
        $sql = $sql -replace ":RA_IDEMPRESA", [string]$IdEmpresa
        $sql = $sql -replace ":RA_UF", "'$Uf'"
    }

    # Normaliza literais historicos para execucao no CLP sem alterar a regra logica.
    $sql = $sql -replace "(?<!CAST\()'1900-01-01 00:00:00'", "CAST('1900-01-01 00:00:00' AS TIMESTAMP)"

    # A base NOPONTO nao expoe IDMSG em PRODUTO_TRIBUTACAO_VIEW; neutraliza apenas a coluna de saida para permitir COUNT(*).
    $sql = $sql -replace "PRODUTO_TRIBUTACAO_VIEW\.IDMSG", "CAST(NULL AS INTEGER) AS IDMSG"
    $sql = $sql -replace "CAST\s*\(\s*:RA_DTMONITOR\s+AS\s+TIMESTAMP\s*\)", "TIMESTAMP('$DtMonitor')"
    $sql = $sql -replace ":RA_DTMONITOR", "TIMESTAMP('$DtMonitor')"
    $sql = $sql -replace ":RA_COMPLETA", "'$Completa'"
    $sql = $sql -replace "(?is)\s+ORDER\s+BY\s+1\s*,\s*2\s*$", ""

    return $sql
}

function Measure-Count {
    param(
        [string]$Name,
        [string]$Sql
    )

    $countSql = "SELECT COUNT(*) FROM ($Sql) AS MONITOR_QUERY;"
    $result = Invoke-Db2 -Sql $countSql -Label $Name
    $line = ($result.Output -split "`n" | Where-Object { $_.Trim() -match "^\d+$" } | Select-Object -Last 1)
    if ($null -eq $line) {
        $line = ""
    }

    [pscustomobject]@{
        Consulta = $Name
        Linhas = $line.Trim()
        Segundos = $result.Seconds
        ExitCode = $result.ExitCode
        Output = $result.Output
    }
}

function Get-CenarioKeyCountSql {
    param(
        [string]$Sql
    )

    $selectIndex = $Sql.IndexOf("SELECT DISTINCT", [System.StringComparison]::OrdinalIgnoreCase)
    if ($selectIndex -lt 0) {
        return $null
    }

    $prefix = $Sql.Substring(0, $selectIndex)
    $match = [regex]::Match($Sql, "(?is)CFMSG\.IDMSGSAI\s+AS\s+IDMSG\s+(FROM\s+.*)$")
    if (-not $match.Success) {
        return $null
    }

    $fromPart = $match.Groups[1].Value
    return "$prefix SELECT COUNT(*) FROM (SELECT DISTINCT TMP.IDPRODUTO, TMP.IDSUBPRODUTO, TMP.IDEMPRESA $fromPart) AS MONITOR_KEYS;"
}

$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
$queries = @(
    [pscustomobject]@{ Name = "Sem cenario original"; Path = Join-Path $basePath "SelectProdutosSemCenarioFiscal.txt" },
    [pscustomobject]@{ Name = "Sem cenario v2"; Path = Join-Path $basePath "SelectProdutosSemCenarioFiscal_v2.txt" },
    [pscustomobject]@{ Name = "Com cenario original"; Path = Join-Path $basePath "SelectProdutosComCenarioFiscal.txt" },
    [pscustomobject]@{ Name = "Com cenario v2"; Path = Join-Path $basePath "SelectProdutosComCenarioFiscal_v2.txt" }
)

if ($ConsultaFiltro -ne "") {
    $queries = $queries | Where-Object { $_.Name -like "*$ConsultaFiltro*" }
}

& db2 connect to $Database user $User using $Password | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao conectar no banco $Database."
}

try {
    $ufSql = "SELECT UF FROM DBA.EMPRESA WHERE IDEMPRESA = $IdEmpresa;"
    $ufResult = Invoke-Db2 -Sql $ufSql -Label "UF empresa"
    $uf = (($ufResult.Output -split "`n" | Where-Object { $_.Trim() -match "^[A-Z]{2}$" } | Select-Object -Last 1).Trim())
    if ([string]::IsNullOrWhiteSpace($uf)) {
        throw "Nao foi possivel identificar UF da empresa $IdEmpresa."
    }

    Write-Host ("Banco={0}; IDEMPRESA={1}; UF={2}; RA_COMPLETA={3}; RA_DTMONITOR={4}" -f $Database, $IdEmpresa, $uf, $Completa, $DtMonitor)

    foreach ($query in $queries) {
        $sql = Get-PreparedQuery -Path $query.Path -IdEmpresa $IdEmpresa -Uf $uf -DtMonitor $DtMonitor -Completa $Completa
        $result = Measure-Count -Name $query.Name -Sql $sql
        if ($result.ExitCode -eq 0) {
            Write-Host ("{0}: linhas={1}; segundos={2}" -f $result.Consulta, $result.Linhas, $result.Segundos)
        }
        else {
            Write-Host ("{0}: ERRO em {1}s" -f $result.Consulta, $result.Segundos)
            $errors = $result.Output -split "`n" | Where-Object { $_ -match "SQL\d{4}[A-Z]|SQLSTATE|SQL0437W|Codigo|Código" }
            Write-Host ($errors -join "`n")

            if ($query.Name -like "Com cenario*") {
                $keyCountSql = Get-CenarioKeyCountSql -Sql $sql
                if ($null -ne $keyCountSql) {
                    $keyResult = Invoke-Db2 -Sql $keyCountSql -Label "$($query.Name) chaves"
                    $keyLine = ($keyResult.Output -split "`n" | Where-Object { $_.Trim() -match "^\d+$" } | Select-Object -Last 1)
                    if ($keyResult.ExitCode -eq 0 -and $null -ne $keyLine) {
                        Write-Host ("{0}: chaves_distintas={1}; segundos={2}" -f $query.Name, $keyLine.Trim(), $keyResult.Seconds)
                    }
                    else {
                        Write-Host ("{0}: ERRO tambem na contagem por chaves em {1}s" -f $query.Name, $keyResult.Seconds)
                    }
                }
            }
        }
    }
}
finally {
    & db2 connect reset | Out-Host
}
