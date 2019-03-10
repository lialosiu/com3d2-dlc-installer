# Import-Module -Name ($PSScriptRoot + "\Get-CRC32.ps1")


$targetCom3d2Dir = "E:\Games\Galgame\KISS\COM3D2"


$exists = Test-Path -LiteralPath "$targetCom3d2Dir\update.lst"
if (-not $exists) {
    Write-Output "not com3d2 path"
    exit
}

$targetFileVers = New-Object 'system.collections.generic.dictionary[string,string]'
$content = [IO.File]::ReadLines("$targetCom3d2Dir\update.lst")
$content | ForEach-Object {
    if (-not $_) {
        return
    }
    $r = $_.Split(",")
    $path = $r[0]
    $ver = $r[1]

    $targetFileVers[$path] = $ver
}

$canInstall = @()

Get-ChildItem -Directory | ForEach-Object {
    $itemPath = "$PSScriptRoot\$_"
    $updateLstDir = $itemPath
    $updateLstPath = "$updateLstDir\update.lst"
    if (!(Test-Path -LiteralPath $updateLstPath)) {
        # find com3d2 dir
        Get-ChildItem -LiteralPath $itemPath -Directory | ForEach-Object {
            $dirName = $_.ToString()
            $r = $dirName | Select-String -Pattern "^com3d2plg_(?!oh_).*$"
            if ($r) {
                $updateLstDir = $r.ToString().Trim()
                $updateLstDir = "$itemPath\$updateLstDir"
                $updateLstPath = "$updateLstDir\update.lst"
            }
        }
    }

    $s = $_.ToString()

    if (Test-Path -LiteralPath $updateLstPath) {
        $content = [IO.File]::ReadLines($updateLstPath)
        $content | ForEach-Object {
            $r = $_.Split(",")
            $type = $r[0]
            $fromPath = $r[1]
            $toPath = $r[2]
            $size = $r[3]
            $crc32 = $r[4]
            $ver =  $r[5]

            if ($fromPath -eq 0) {
                $fromPath = "data\$toPath"
            }

            # version check
            $versionCheckPass = 0
            $oldver = "0"
            if ($targetFileVers[$toPath]) {
                $oldver = $targetFileVers[$toPath]
                if ($ver -gt $targetFileVers[$toPath]) {
                    $versionCheckPass = 1
                } else {
                    $versionCheckPass = 0
                }
            } else {
                $oldver = "0"
                $versionCheckPass = 1
            }
            if ($versionCheckPass -eq 0) {
                return
            }

            # format path
            $_fromPath = "$updateLstDir\$fromPath"
            $_toPath = "$targetCom3d2Dir\$toPath"
            
            $fileSize = (Get-Item -LiteralPath $_fromPath).length
            # size check
            $sizeCheckPass = 0
            if ($size -ne $fileSize) {
                Write-Warning ("[SIZE NOT_MATCH][{0}] $_ " -f $fileSize)
            } else {
                $sizeCheckPass = 1
            }
            if ($sizeCheckPass -eq 0) {
                return
            }

            # # crc32 check
            # $file = [IO.File]::ReadAllBytes($_fromPath)
            # $crc32CheckPass = 0
            # $hash = Get-CRC32 -Buffer $file
            # $hash = "{0:x8}" -f $hash
            # if ($crc32 -ne $hash) {
            #     Write-Warning "[CRC32 NOT_MATCH][$hash] $_ "
            # } else {
            #     $crc32CheckPass = 1
            # }
            # if ($crc32CheckPass -eq 0) {
            #     return
            # }

            $crc32CheckPass = 1
            if ($versionCheckPass -and $sizeCheckPass -and $crc32CheckPass) {
                $canInstall += @{id=$toPath;s=$s;from=$_fromPath;to=$_toPath;fromver=$oldver;tover=$ver}
            }
        }
    } else {
        Write-Output $updateLstPath
    }
}

$readyToInstall = New-Object 'system.collections.generic.dictionary[string,Hashtable]'
$canInstall | ForEach-Object {
    if ($readyToInstall[$_.id]) {
        # check upper version
        # Write-Warning ("[{0}:{1}] [{2}:{3}]" -f $readyToInstall[$_.id].s, $readyToInstall[$_.id].tover, $_.s, $_.tover)
        if ($_.tover -gt $readyToInstall[$_.id].tover) {
            $readyToInstall[$_.id] = $_
        }
    } else {
        $readyToInstall[$_.id] = $_
    }
}

$readyToInstall.Values | ForEach-Object {
    Write-Output ("{0} {1} {2} -> {3}" -f $_.s,$_.id,$_.fromver,$_.tover)
}

$ready = Read-Host -Prompt 'Ready?(y/N)'
if ($ready -ne 'y' -or $ready -ne 'Y') {
    exit
}


# start install
$i = 0
$total = $readyToInstall.Values.Count
$readyToInstall.Values | ForEach-Object {
    $i++
    Write-Output ("[$i/$total] {0} {1} {2} -> {3}" -f $_.s,$_.id,$_.fromver,$_.tover)
    New-Item -ItemType File -Path $_.to -Force | Out-Null
    Copy-Item -LiteralPath $_.from -Destination $_.to -Force
    $targetFileVers[$_.id] = $_.tover
}

$updateListContent = ""
$targetFileVers.Keys | ForEach-Object {
    $updateListContent += ("{0},{1}" -f $_, $targetFileVers[$_])
    $updateListContent += [System.Environment]::NewLine
}

$updateListContent | Out-File -LiteralPath "$targetCom3d2Dir\update.lst" -Force -Encoding "utf8"
