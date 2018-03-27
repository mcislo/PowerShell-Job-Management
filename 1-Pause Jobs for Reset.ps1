# SQL Server to be used
$SqlServer = "dev"; #"localhost";
# SQL Database to be used
$SqlDatabase = "SkySyncHector"; #"DatabaseName";
# SQL Database User and Password, if not entered will use integrated security
$SqlUser = "";
$SqlPassword = "";

if ($SqlUser -eq "") {
	$SqlAuth = "Integrated Security=SSPI;"
} else {
	$SqlAuth = "User ID={0}; Password={1};" -f $SqlUser, $SqlPassword 
}
$SqlConnectionString = "Data Source={0};Initial Catalog={1};{2}" -f $SqlServer, $SqlDatabase, $SqlAuth;
$SqlConnection = New-Object -TypeName System.Data.SqlClient.SqlConnection -ArgumentList $SqlConnectionString;
$SqlConnection.Open();
if ($SqlConnection.State -ne "Open") {
	Write-Error "Could not connect to Server $($SqlServer)";
	exit;
}

try {
	$SqlCommand = New-Object -TypeName System.Data.SqlClient.SqlCommand;
	$SqlCommand.CommandText = @"
-- Delete all running jobs so won't start again
DELETE QRTZ_FIRED_TRIGGERS;
"@;
	$SqlCommand.Connection = $SqlConnection;
	$SqlCommand.ExecuteNonQuery();

	$SqlCommand = New-Object -TypeName System.Data.SqlClient.SqlCommand;
	$SqlCommand.CommandText = @"
-- Delete all recovering jobs running
DELETE QRTZ_SIMPLE_TRIGGERS
 WHERE (TRIGGER_GROUP = 'RECOVERING_JOBS');
"@;
	$SqlCommand.Connection = $SqlConnection;
	$SqlCommand.ExecuteNonQuery();

	$SqlCommand = New-Object -TypeName System.Data.SqlClient.SqlCommand;
	$SqlCommand.CommandText = @"
-- Pause all Master Jobs
UPDATE QRTZ_TRIGGERS
 SET TRIGGER_STATE = 'PAUSED'
 WHERE (JOB_GROUP = 'Conventions');
"@;
	$SqlCommand.Connection = $SqlConnection;
	$SqlCommand.ExecuteNonQuery();

	$SqlCommand = New-Object -TypeName System.Data.SqlClient.SqlCommand;
	$SqlCommand.CommandText = @"
-- Pause all Normal and Child Scheduled Jobs
UPDATE QRTZ_TRIGGERS
 SET TRIGGER_STATE = 'PAUSED'
 WHERE (
  (JOB_GROUP = 'Transfers')
  AND (ISNUMERIC(TRIGGER_NAME) = 1)
 );
"@;
	$SqlCommand.Connection = $SqlConnection;
	$SqlCommand.ExecuteNonQuery();

	$SqlCommand = New-Object -TypeName System.Data.SqlClient.SqlCommand;
	$SqlCommand.CommandText = @"
-- Pause all set to Start Normal and Child Manual Jobs
DELETE QRTZ_TRIGGERS
 WHERE (
  (JOB_GROUP = 'Transfers')
  AND (SUBSTRING(TRIGGER_NAME, 1, 3) = 'MT_')
 );
"@;
	$SqlCommand.Connection = $SqlConnection;
	$SqlCommand.ExecuteNonQuery();

} finally {
	$SqlConnection.Close();
	$SqlConnection.Dispose();
}

Write-Host "All Jobs Set to Paused";