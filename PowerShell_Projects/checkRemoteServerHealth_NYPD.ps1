# 
# Author: Charles Bastian
#         Charles@CharlesBastian.com
# Date Created: 2015-05-01
# File Name: checkRemoteServerHealth_NYPD.ps1
# Description: PowerShell script test if 1pp servers are online.  If not start Abbott IOPs.  If so stop Abbott IOPs.
# 
# Steps requested from NYPD:
# 1. Can Abbott talk to 1PP RasTracs.
# 2. Can Abbott talk to 1PP SQL.
#   2a. Check that 50% of devices are reporting to 1PP.
# 3. Is Abbott receiving data from test device (need new IOP for testing)?
##
# Set Variables
##
# Current Epoch Timestamp minus 1 hour
#$currentEpoch=Get-Date -UFormat "%s";
#$currentEpoch=[int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime()-uformat %s));
$currentEpoch=[int][double]::Parse((1429052916))-3600

# Whether to Failover or not
$failOver="No";

# Test #1 Variables
$serversOnline=0;
$servers="10.184.90.35","10.184.90.36","10.184.90.37";

# Test #2 Variables
$sqlServersOnline=0;
$sqlServers="10.184.90.38","10.184.90.39";

# Test #2a Variables
$percentReporting=0;
$sqlServers="10.184.90.38","10.184.90.39";

##
# Start Functions
##
##
# Simple SQL Query Function
## 
function sqlQuery($sqlDbName1,$s1,$sqlQuery1){
  $userName="sa";
  $passWord="Ir0c99**";
  $connectionString="server=$s1;database=$sqlDbName1;user id=$userName;password=$passWord";
  $sqlConnection=New-Object System.Data.SqlClient.SqlConnection($connectionString);
  $sqlCmd=New-Object System.Data.SqlClient.SqlCommand;
  $sqlCmd.CommandText=$sqlQuery1;
  $sqlCmd.Connection=$sqlConnection;
  $sqlAdapter=New-Object System.Data.SqlClient.SqlDataAdapter;
  $sqlAdapter.SelectCommand=$sqlCmd;
  $dataSet=New-Object System.Data.DataSet;
  $sqlAdapter.Fill($dataSet) >$null;
  $sqlConnection.Close();
  clear;
  $data=$dataSet.Tables[0].Rows[0][0].toString();
  return $data;
}

# Send email with test results.
function createEmail($serversOnline,$sqlServersOnline,$numVehicles,$reportingVehicles,$percentReporting,$failOver){
  $currentTimeStamp=Get-Date -UFormat "%Y-%m-%d %H:%M";
  $msgBody="Current Timestamp: $currentTimeStamp <br />";
  $msgBody+="Servers Online: $serversOnline <br />";
  $msgBody+="SQL Servers Online: $sqlServersOnline <br />";
  $msgBody+="Total Vehicles: $numVehicles <br />";
  $msgBody+="Total Vehicles Reporting: $reportingVehicles <br />";
  $msgBody+="Percent Vehicles Reporting: $percentReporting <br />";
  $msgBody+="<strong>Failover: $failOver </strong><br />";
  
  $esRecipients="nypd-rastrac@nypd.org";
  $esSubject="NYPD Abbott Failover Status";
  $esBody=$msgBody;
  $esFrom='RastracAlerts@nypd.org';
  $esSmtpServer='10.192.5.1';
    ##### Begin Authentication Stuff #####
    #$esSmtpUser='';
    #$esSmtpPassword='';
    #$esSmtpServer='secure.emailsrvr.com';
    #Create the credentials for the smtpauth connection;
    #$credentials=New-Object System.Net.NetworkCredential($esSmtpUser,$esSmtpPassword);
    ##### End Authentication Stuff #####
  #Create the message
  $message=New-Object System.Net.Mail.MailMessage $esFrom,$esRecipients,$esSubject,$esBody;
  $message.IsBodyHTML=$true;
  # Set up server connection
  $smtpClient=New-Object System.Net.Mail.SmtpClient $esSmtpServer,25;
  $smtpClient.Timeout=100000;
  $smtpClient.UseDefaultCredentials=$false;
    ##### Begin Authentication Stuff #####
    #$smtpClient.EnableSsl=$true;
    #$smtpClient.Credentials=$credentials;
    ##### End Authentication Stuff #####
  #Send the message
  $smtpClient.Send($message);
  Write-Host "Message sent.";
}


##
# End Functions
##
##
# Run Tests
##

# TEST #1
foreach($s in $servers){
  "Trying Server: $s";
  if($serversOnline -eq 1){
    break;
  }

  if(!(Test-Connection -Cn $s -BufferSize 16 -Count 1 -ea 0 -quiet)){
    "Problem connecting to $s"
    "Flushing DNS"
    ipconfig /flushdns | out-null
    
    "Registering DNS"
    ipconfig /registerdns | out-null

    "Re-pinging $s"
    if(!(Test-Connection -Cn $s -BufferSize 16 -Count 1 -ea 0 -quiet)){
      "Problem still exists in connecting to $s"
      $serversOnline=0;
    }else{
      "Resolved problem connecting to $s"
      $serversOnline=1;
    }
  }else{
    $serversOnline=1;
  }
}

# TEST #2
foreach($s in $sqlServers){
  "Trying SQL Server: $s";
  if($sqlServersOnline -eq 1){
    break;
  }

  if(!(Test-Connection -Cn $s -BufferSize 16 -Count 1 -ea 0 -quiet)){
    "Problem connecting to $s"
    "Flushing DNS"
    ipconfig /flushdns | out-null
    
    "Registering DNS"
    ipconfig /registerdns | out-null

    "Re-pinging $s"
    if(!(Test-Connection -Cn $s -BufferSize 16 -Count 1 -ea 0 -quiet)){
      "Problem still exists in connecting to $s"
      $sqlServersOnline=0;
    }else{
      "Resolved problem connecting to $s"
      $sqlServersOnline=1;
    }
  }else{
    $sqlServersOnline=1;
  }
}

if($sqlServersOnline -ge 1){
  #TEST 2a
  foreach($s in $sqlServers){
    "Trying SQL Query: $s";
    if($reportingVehicles -ge 1 -and $numVehicles -ge 1){
      "Breaking out";
      break;
    }
    # Get total number of vehicles.
    $sqlDbName="Demo_Settings";
    $sqlQuery="SELECT DISTINCT COUNT([ID]) AS count FROM [$sqlDbName].[dbo].[DEFAULT_VEHICLES]";
    $numVehicles=sqlQuery $sqlDbName $s $sqlQuery;

    # Get reporting number of vehicles.
    $sqlDbName="Demo_State";
    $sqlQuery="SELECT DISTINCT COUNT([Vehicle_ID]) AS count FROM [$sqlDbName].[dbo].[LAST_POSITION_STATE] WHERE Date_Time>$currentEpoch";
    $reportingVehicles=sqlQuery $sqlDbName $s $sqlQuery;
  }
}

# Figure percentage of total vehicles reporting.
if($numVehicles -ge 0 -and $reportingVehicles -ge 0){
  $percentReporting=($reportingVehicles/$numVehicles)*100;# 2>&1 | out-null;
}


# TEST #3
##
# Check on updates in the last hour from the Abbott Test Device.
##

"Server Results: $serversOnline";
"SQL Results: $sqlServersOnline";
"Reporting Vehicle Results: $percentReporting%";
"Results from test 3 go here";

##
# Process Results of the tests and turn on or turn off the Abbott IOPs
##
if(($serversOnline -eq 0) -and ($sqlServersOnline -eq 0) -and ($percentReporting -le 50)){
  "Starting IOP"
  #path to IOP
  #& "C:\Users\Charles Bastian\Documents\Development\Test_IOP\iop.exe"
  $failOver="Yes";
}else{
  "Stopping IOP"
  #Stop-Process -processname iop*
  $failOver="No";
}

createEmail $serversOnline $sqlServersOnline $numVehicles $reportingVehicles $percentReporting $failOver;
exit;

