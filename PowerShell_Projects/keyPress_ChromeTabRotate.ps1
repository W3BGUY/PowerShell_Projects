# 
# Author: Charles Bastian
#         Charles@CharlesBastian.com
# Date Created: 2015-04-28
# File Name: keyPress_ChromeTabRotate.ps1
# Description: PowerShell script to rotate through the tabs of an open Chrome browser.
#
while(1 -eq 1){
  $wshell=New-Object -ComObject wscript.shell;
  $wshell.AppActivate('Google Chrome');
  Sleep 5;
  $wshell.SendKeys('^{PGDN}');
} 