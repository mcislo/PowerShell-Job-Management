$SqlServer = "SQL2016";
$SqlDatabase = "MySkySync";

$SqlConnectionString = "Data Source={0};Initial Catalog={1};Integrated Security=False;User ID=SkySync;Password=xxxxx" -f $SqlServer, $SqlDatabase;
$SqlQuery = @"
 SELECT ID, Name 
  FROM Jobs WITH (NOLOCK)
  WHERE (ScheduleMode = 1)
  ORDER BY ID;
"@;

$SqlCommand = New-Object -TypeName System.Data.SqlClient.SqlCommand;
$SqlCommand.CommandText = $SqlQuery;
$SqlConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection -ArgumentList $SqlConnectionString;
$SqlCommand.Connection = $SqlConnection;

$SqlConnection.Open();
try {
    $SqlDataReader = $SqlCommand.ExecuteReader();

    #Fetch data and write out to files
    while ($SqlDataReader.Read()) {
        Write-Host $SqlDataReader.GetString($SqlDataReader.GetOrdinal("Name"));
        #Write-Host $SqlDataReader.GetInt64($SqlDataReader.GetOrdinal("ID"));
        $argList = "-job {0} -pause " -f $SqlDataReader.GetInt64($SqlDataReader.GetOrdinal("ID"));
        Write-Host ((Split-Path $MyInvocation.InvocationName) + "\skysync-jobs.ps1 $argList") -Verbose  
        Invoke-Expression ((Split-Path $MyInvocation.InvocationName) + "\skysync-jobs.ps1 $argList") -Verbose  
    }
} finally {
    $SqlConnection.Close();
    $SqlConnection.Dispose();
}