param([string]$Message = "Done")
# Plays a sound and sends a push to the phone via ntfy.sh.
# The channel name is read from ntfy_topic.local.txt (next to this script, not committed to git).
$topicFile = Join-Path $PSScriptRoot "ntfy_topic.local.txt"
try { [System.Media.SystemSounds]::Exclamation.Play() } catch {}
if (-not (Test-Path $topicFile)) { Write-Output "notify: ntfy_topic.local.txt not found"; exit 0 }
$topic = (Get-Content -Raw -Path $topicFile).Trim()
if ((-not $topic) -or ($topic -like "PUT_YOUR*")) { Write-Output "notify: channel name not set"; exit 0 }
try {
    Invoke-RestMethod -Method Post -Uri ("https://ntfy.sh/" + $topic) -Body ([System.Text.Encoding]::UTF8.GetBytes($Message)) | Out-Null
    Write-Output "notify: sent"
} catch {
    Write-Output ("notify: failed - " + $_.Exception.Message)
}
exit 0
