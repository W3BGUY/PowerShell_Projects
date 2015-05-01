# 
# Author: Charles Bastian
#         Charles@CharlesBastian.com
# Date Created: 2015-04-17
# File Name: findErrorsInLast5Minutes.ps1
# Description: PowerShell script to find "ERROR" in log files.
#
Get-ChildItem -Path C:\PROGRA~2\IBM\WEBSPH~1\errors\ -Filter "*.fdc" | 
  Where-Object {$_.LastWriteTime -gt (Get-Date).AddMinutes(-1) -AND $_.Attributes -ne "Directory"} | 
    ForEach-Object{
		  if(Get-Content $_.FullName | Select-String -Pattern "ERROR"){
			  exit 5
			}
		}