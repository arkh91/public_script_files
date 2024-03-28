echo Running the file...

curl "https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/iran-firewall-range2.txt" --output "C:\Users\Arkh91\Documents\Restrict_IP_range_Integrated_file\iran-firewall-range2.txt"

@echo off
setlocal enabledelayedexpansion
FOR /F "tokens=1,2 delims=	" %%G IN (C:\Users\Arkh91\Documents\Restrict_IP_range_Integrated_file\iran-firewall-range2.txt) DO (
    SET startIP=%%G
    SET endIP=%%H
    IF "!startIP:~0,1!" GEQ "0" IF "!startIP:~0,1!" LEQ "9" (
        echo Blocking IP range !startIP! to !endIP!
        netsh advfirewall firewall add rule name="Block IP Range !startIP!-!endIP!" dir=in action=block remoteip=!startIP!-!endIP!
        netsh advfirewall firewall add rule name="Block IP Range !startIP!-!endIP!" dir=out action=block remoteip=!startIP!-!endIP!
    )
)
echo Done.
pause



del C:\Users\Arkh91\Documents\Restrict_IP_range_Integrated_file\iran-firewall-range2.txt

REM curl "https://raw.githubusercontent.com/arkh91/public_script_files/main/firewall/Restrict_IP_range_Integrated_file.bat" --output "C:\Users\Arkh91\Documents\Restrict_IP_range_Integrated_file\iran-firewall-range2.txt"
