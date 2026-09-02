param(
  [string]$DashboardsDir = "$PSScriptRoot/../gitops/addons/grafana/dashboards"
)

$resolved = Resolve-Path $DashboardsDir
$prom = '{"type":"prometheus","uid":"prometheus"}'

Get-ChildItem $resolved -Filter *.json | ForEach-Object {
  $c = Get-Content $_.FullName -Raw

  # Datasource fixes
  $c = $c -replace '\$\{DS_PROMETHEUS\}', 'prometheus'
  $c = $c -replace '"datasource"\s*:\s*"Prometheus"', "`"datasource`": $prom"
  $c = $c -replace '"datasource"\s*:\s*\{\s*"type"\s*:\s*"prometheus"\s*,\s*"uid"\s*:\s*"[^"]*"\s*\}', "`"datasource`": $prom"
  $c = $c -replace '"datasource"\s*:\s*\{\s*"uid"\s*:\s*"[^"]*"\s*,\s*"type"\s*:\s*"prometheus"\s*\}', "`"datasource`": $prom"
  $c = $c -replace '"type"\s*:\s*"datasource"\s*,\s*"uid"\s*:\s*"-- Mixed --"', '"type":"prometheus","uid":"prometheus"'

  # Repair broken escapes / PromQL from previous script runs
  $c = $c -replace 'resource=\\\\"cpu\\\\"', 'resource=\"cpu\"'
  $c = $c -replace 'resource=\\\\"memory\\\\"', 'resource=\"memory\"'
  $c = $c -replace 'kube_node_status_capacity\{resource=\\"cpu\\"\}\{', 'kube_node_status_capacity{resource=\"cpu\", '
  $c = $c -replace 'kube_node_status_capacity\{resource=\\"memory\\"\}\{', 'kube_node_status_capacity{resource=\"memory\", '

  # kube-state-metrics metric compatibility (KSM 2.x / modern kube-prometheus-stack)
  $c = $c -replace 'unit=\\"core\\"', 'resource=\"cpu\"'
  $c = $c -replace 'unit=\\"byte\\"', 'resource=\"memory\"'
  $c = $c -replace 'machine_cpu_cores\{', 'kube_node_status_capacity{resource=\"cpu\", '
  $c = $c -replace 'machine_memory_bytes\{', 'kube_node_status_capacity{resource=\"memory\", '
  $c = $c -replace 'machine_cpu_cores', 'kube_node_status_capacity{resource=\"cpu\"}'
  $c = $c -replace 'machine_memory_bytes', 'kube_node_status_capacity{resource=\"memory\"}'

  # Remove import metadata
  $c = $c -replace '"__inputs"\s*:\s*\[[^\]]*\]\s*,', ''
  $c = $c -replace '"__requires"\s*:\s*\[[^\]]*\]\s*,', ''

  Set-Content -Path $_.FullName -Value $c -Encoding UTF8 -NoNewline
  Write-Output "fixed $($_.Name)"
}
