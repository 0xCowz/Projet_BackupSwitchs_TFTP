Import-Module Posh-SSH -ErrorAction Stop

$switchFile = "C:\switches.txt"
$port      = 22
$username  = ""
$password  = ""
$newPeriod = 43800

if (-not (Test-Path $switchFile)) {
    Write-Host "fichier introuvable"
    exit 1
}

$switches = Get-Content $switchFile | Where-Object { $_ -and ($_ -notmatch '^#') }

Write-Host "demarrage config sur $($switches.Count) switches"

function Wait-ForText {
    param(
        [Renci.SshNet.ShellStream]$stream,
        [string]$pattern,
        [int]$timeoutSec = 10
    )
    $limit = (Get-Date).AddSeconds($timeoutSec)
    $output = ""
    while ((Get-Date) -lt $limit) {
        Start-Sleep -Milliseconds 150
        $chunk = $stream.Read()
        if ($chunk) { $output += $chunk }
        if ($output -match $pattern) { return ,($true, $output) }
    }
    return ,($false, $output)
}

foreach ($device in $switches) {
    try {
        $securePass = ConvertTo-SecureString $password -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($username, $securePass)
        $session = New-SSHSession -ComputerName $device -Port $port -Credential $cred -AcceptKey -ErrorAction Stop
        $shell = New-SSHShellStream -SessionId $session.SessionId -TerminalName "vt100"

        Start-Sleep -Milliseconds 400
        $shell.WriteLine("")
        $shell.WriteLine("enable")
        $found = Wait-ForText -stream $shell -pattern "(?i)password:" -timeoutSec 6
        if ($found[0]) { $shell.WriteLine($password) }

        Wait-ForText -stream $shell -pattern "(?m)\S+#\s*$" -timeoutSec 8 | Out-Null
        $shell.WriteLine("terminal length 0")
        Start-Sleep -Milliseconds 300

        Write-Host "$device config en cours"

        $shell.WriteLine("configure terminal")
        Start-Sleep -Milliseconds 300
        $shell.WriteLine("archive")
        Start-Sleep -Milliseconds 300

        $shell.WriteLine("no time-period")
        Start-Sleep -Milliseconds 200
        $shell.WriteLine("no write-memory")
        Start-Sleep -Milliseconds 200

        $shell.WriteLine("write-memory")
        Start-Sleep -Milliseconds 200
        $shell.WriteLine("time-period $newPeriod")
        Start-Sleep -Milliseconds 200

        $shell.WriteLine("exit")
        Start-Sleep -Milliseconds 200
        $shell.WriteLine("end")
        Start-Sleep -Milliseconds 200
        $shell.WriteLine("wr")
        Start-Sleep -Seconds 4

        $shell.WriteLine("show run | section archive")
        Start-Sleep -Seconds 3
        $verify = $shell.Read()

        $okPeriod = $verify -match "time-period\s+$newPeriod"
        $okWrite  = $verify -match "write-memory"

        if ($okPeriod -and $okWrite) {
            Write-Host "operation $device reussite"
        }
        else {
            Write-Host "fail $device"
        }

        Remove-SSHSession -SessionId $session.SessionId | Out-Null
    }
    catch {
        Write-Host "fail $device"
    }
}

Write-Host "operation termine"
