param([string]$Message = "checkpoint", [string]$Tag)
$ErrorActionPreference = "Stop"
git add -A
$need = $true; try { git diff --staged --quiet; $need = $false } catch { $need = $true }
if ($need) {
  git commit -m $Message
  if ($Tag) { git tag -a $Tag -m $Message }
  try { git push -u origin (git rev-parse --abbrev-ref HEAD) } catch {}
  Write-Host "Committed & pushed: $Message"
} else {
  Write-Host "Nothing to commit."
}
