$ErrorActionPreference = 'Stop'

$outDir = Join-Path (Get-Location) 'dbadmin_catalog'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$connectionString = 'DSN=DBADMIN'
$connection = [System.Data.Odbc.OdbcConnection]::new($connectionString)

try {
    $connection.Open()

    $tables = $connection.GetSchema('Tables') |
        Where-Object {
            $_.TABLE_NAME -and
            $_.TABLE_TYPE -notmatch 'SYSTEM|GLOBAL TEMPORARY|LOCAL TEMPORARY'
        } |
        Sort-Object TABLE_SCHEM, TABLE_NAME

    $columns = $connection.GetSchema('Columns') |
        Where-Object { $_.TABLE_NAME } |
        Sort-Object TABLE_SCHEM, TABLE_NAME, ORDINAL_POSITION

    $tables |
        Select-Object TABLE_CAT, TABLE_SCHEM, TABLE_NAME, TABLE_TYPE, REMARKS |
        Export-Csv -Path (Join-Path $outDir 'tables.csv') -NoTypeInformation -Encoding UTF8

    $columns |
        Select-Object TABLE_CAT, TABLE_SCHEM, TABLE_NAME, COLUMN_NAME, ORDINAL_POSITION, TYPE_NAME, DATA_TYPE, COLUMN_SIZE, DECIMAL_DIGITS, IS_NULLABLE, COLUMN_DEF, REMARKS |
        Export-Csv -Path (Join-Path $outDir 'columns.csv') -NoTypeInformation -Encoding UTF8

    [pscustomobject]@{
        OutputDirectory = $outDir
        TableCount = @($tables).Count
        ColumnCount = @($columns).Count
    } | ConvertTo-Json -Depth 3
}
finally {
    if ($connection.State -ne 'Closed') {
        $connection.Close()
    }
    $connection.Dispose()
}
