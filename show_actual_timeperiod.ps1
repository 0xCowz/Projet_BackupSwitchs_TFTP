Import-Module Posh-SSH -ErrorAction Stop

$switchFile = "C:\switches.txt" 
$port      = 22
$username  = ""
$password  = "" 

if (-not (Test-Path $switchFile)) {
    Write-Host "fichier introuvable"
    exit 1
}

$switches = Get-Content $switchFile | Where-Object { $_ -and ($_ -notmatch '^#') }

Write-Host "lecture timeperiod sur $($switches.Count) switches"

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

        $priv = Wait-ForText -stream $shell -pattern "(?m)\S+#\s*$" -timeoutSec 8

        $shell.WriteLine("terminal length 0")
        Start-Sleep -Milliseconds 300

        $shell.WriteLine("show running-config | section archive")
        Start-Sleep -Seconds 3
        $archiveOut = $shell.Read()

        $timePeriod = "non trouve"
        if ($archiveOut -match "time-period\s+(\d+)") {
            $timePeriod = $matches[1]
        }

        Write-Host "$device -> $timePeriod"

        Remove-SSHSession -SessionId $session.SessionId | Out-Null
    }
    catch {
        Write-Host "fail $device"
    }
}

Write-Host "operation termine"
Read-Host ""
