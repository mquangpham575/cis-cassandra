param (
    [Parameter(Mandatory=$true)]
    [ValidateSet("start", "stop", "status")]
    $Action
)

$RG = "rg-cis-cassandra"

switch ($Action) {
    "start" {
        Write-Host "🚀 Waking up the cluster nodes..." -ForegroundColor Cyan
        $ids = az vm list -g $RG --query "[].id" -o tsv
        az vm start --ids $ids
        Write-Host "✅ Nodes are starting up. Please wait 2-3 minutes for Cassandra to initialize." -ForegroundColor Green
    }
    "stop" {
        Write-Host "💤 Putting the cluster to sleep (Deallocating to save COST)..." -ForegroundColor Yellow
        $ids = az vm list -g $RG --query "[].id" -o tsv
        az vm deallocate --ids $ids
        Write-Host "✅ Nodes deallocated. Your credits are now safe." -ForegroundColor Green
    }
    "status" {
        Write-Host "🔍 Current Cluster Power Status:" -ForegroundColor Cyan
        az vm list -g $RG -d --query "[].{Name:name, State:powerState}" --output table
    }
}
