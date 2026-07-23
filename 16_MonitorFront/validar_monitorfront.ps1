param(
    [string]$Database = "TSTPONTO",
    [string]$Hostname = "163.176.143.73",
    [int]$Port = 49470,
    [string]$User = "dba",
    [Parameter(Mandatory = $true)]
    [string]$Password,
    [string]$DtMonitor = "1900-01-01 00:00:00",
    [string]$Completa = "F",
    [string[]]$EmpresaSets = @("1", "1,2")
)

$ErrorActionPreference = "Stop"

function New-Connection {
    param(
        [string]$Database,
        [string]$Hostname,
        [int]$Port,
        [string]$User,
        [string]$Password
    )

    $connectionString = "Driver={IBM DB2 ODBC DRIVER};Database=$Database;Hostname=$Hostname;Port=$Port;Protocol=TCPIP;Uid=$User;Pwd=$Password;"
    $connection = [System.Data.Odbc.OdbcConnection]::new($connectionString)
    $connection.Open()
    return $connection
}

function Invoke-Scalar {
    param(
        [System.Data.Odbc.OdbcConnection]$Connection,
        [string]$Sql,
        [int]$Timeout = 0
    )

    $command = $Connection.CreateCommand()
    $command.CommandTimeout = $Timeout
    $command.CommandText = $Sql
    return $command.ExecuteScalar()
}

function Get-QueryForEmpresaSet {
    param(
        [string]$Path,
        [string]$EmpresaSet,
        [string]$DtMonitor,
        [string]$Completa
    )

    $sql = Get-Content -Path $Path -Raw
    $sql = $sql -replace "(?is)(FROM\s+DBA\.EMPRESA\s+EMPRESA)(\s*\))", "`$1`r`n    WHERE EMPRESA.IDEMPRESA IN ($EmpresaSet)`$2"
    $sql = $sql -replace ":RA_DTMONITOR", "TIMESTAMP('$DtMonitor')"
    $sql = $sql -replace ":RA_COMPLETA", "'$Completa'"
    $sql = $sql -replace "(?is)\s+ORDER\s+BY\s+1\s*,\s*2\s*$", ""

    return $sql
}

function Measure-Query {
    param(
        [System.Data.Odbc.OdbcConnection]$Connection,
        [string]$Name,
        [string]$Sql
    )

    $countSql = "SELECT COUNT(*) FROM ($Sql) AS MONITOR_QUERY"
    $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
    $count = Invoke-Scalar -Connection $Connection -Sql $countSql
    $elapsed.Stop()

    [pscustomobject]@{
        Consulta = $Name
        Linhas = [int64]$count
        Segundos = [math]::Round($elapsed.Elapsed.TotalSeconds, 3)
    }
}

$basePath = Split-Path -Parent $MyInvocation.MyCommand.Path
$queries = @(
    [pscustomobject]@{
        Name = "Sem cenario fiscal"
        Path = Join-Path $basePath "SelectProdutosSemCenarioFiscal_v2.txt"
    },
    [pscustomobject]@{
        Name = "Com cenario fiscal"
        Path = Join-Path $basePath "SelectProdutosComCenarioFiscal_v2.txt"
    }
)

$connection = New-Connection -Database $Database -Hostname $Hostname -Port $Port -User $User -Password $Password
try {
    Write-Host "Empresas da base:"
    $empresasSql = @"
SELECT
    E.IDEMPRESA,
    E.UF,
    COUNT(PPP.IDPRODUTO) AS QTD_POLITICA_PRECO
FROM
    DBA.EMPRESA E
    LEFT JOIN DBA.POLITICA_PRECO_PRODUTO PPP ON (
        PPP.IDEMPRESA = E.IDEMPRESA
    )
GROUP BY
    E.IDEMPRESA,
    E.UF
ORDER BY
    E.IDEMPRESA
FETCH FIRST 20 ROWS ONLY
"@
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 0
    $command.CommandText = $empresasSql
    $reader = $command.ExecuteReader()
    while ($reader.Read()) {
        Write-Host ("  IDEMPRESA={0}; UF={1}; QTD_POLITICA_PRECO={2}" -f $reader.GetValue(0), $reader.GetValue(1), $reader.GetValue(2))
    }
    $reader.Close()

    foreach ($empresaSet in $EmpresaSets) {
        Write-Host ""
        Write-Host "Filtro EMPRESAS_BASE: IDEMPRESA IN ($empresaSet)"
        foreach ($query in $queries) {
            $sql = Get-QueryForEmpresaSet -Path $query.Path -EmpresaSet $empresaSet -DtMonitor $DtMonitor -Completa $Completa
            $result = Measure-Query -Connection $connection -Name $query.Name -Sql $sql
            Write-Host ("  {0}: linhas={1}; segundos={2}" -f $result.Consulta, $result.Linhas, $result.Segundos)
        }
    }
}
finally {
    $connection.Close()
}
