# 
# Author: Charles Bastian
#         Charles@CharlesBastian.com
# Date Created: 2015-03-20
# File Name: getServerDiskSpace.ps1
# Description: PowerShell script log into remote servers and email a report on their disk space.
# NOTE: Required Files:
#           computerNames.txt: list of computer names or IP addresses for servers to check. One per line.
#           secureString.txt: Windows encrypted password for the administrator account on the computers.
#
clear;
$user="administrator";
$pw=Get-Content ".\secureString.txt" | convertto-securestring;
$creds=new-object -typename System.Management.Automation.PSCredential -argumentlist $user,$pw;
$file=get-Content .\computerNames.txt;
$outFile=".\resultFile.txt";
if(Test-Path $outFile){
	Remove-Item $outFile;
}
foreach($args in $file){
  $test='';
  $computerData='';
  $error='';
  if(!(Test-Connection -ComputerName $args -Count 1 -Quiet)){
    $computerData=$computerData+"ERROR: Unable to connect to "+$args+" using Administrator and normal password.`nReceived Error: RPC Server unavailable`n";
  }else{
    try{
      $test=get-WmiObject win32_logicaldisk -credential $creds -computername $args -Filter "Drivetype=3";
      $computerData=$test | ft SystemName,DeviceID,VolumeName,@{Label="Total Size";Expression={$_.Size/1gb-as[int]}},@{Label="Free Size";Expression={$_.freespace/1gb-as[int]}} -autosize;
    }catch{
      $error=($_.Exception.Message | out-string);
      if($error.length -le 5){
        $error="Unknown Error ["+$error+"]";
      }
      $computerData="ERROR: Unable to connect to "+$args+" using Administrator and normal password.`nReceived Error: "+$error+"`n";
    }
  }
  out-file -filepath $outFile -inputobject $computerData -append -encoding ASCII;
}

Function createEmail{
  $msgBody=(Get-Content $outFile | out-string);
  $esRecipients="ServerAdmin@navcomp.com";
  $esSubject="Drive Disk Space Report";
  $esBody=$msgBody;
  $esFrom='ServerAdmin@navcomp.com';
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
createEmail;
exit;