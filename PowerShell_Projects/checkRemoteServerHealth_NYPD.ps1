# 
# Author: Charles Bastian
#         Charles@CharlesBastian.com
# Date Created: 2015-05-01
# File Name: checkRemoteServerHealth_NYPD.ps1
# Description: PowerShell script test if 1pp servers are online.  If not start Abbott IOPs.  If so stop Abbott IOPs.
#


$serversOnline=0;
$servers="10.184.90.35","8.8.8.8","10.184.90.36","10.184.90.37";
foreach($s in $servers){
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

"Results: $serversOnline";

if($serversOnline -eq 0){
  "Starting IOP"
  #path to IOP
  & "C:\Users\Charles Bastian\Documents\Development\Test_IOP\iop.exe"
}else{
  "Stopping IOP"
  Stop-Process -processname iop*
}
