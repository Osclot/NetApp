
<#PSScriptInfo

.VERSION 1.0.0

.GUID 3d44bc04-7cc7-49f2-8d57-dba65f9411f0

.AUTHOR Colin Hearn

.COMPANYNAME Leidos

.COPYRIGHT

.TAGS

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Retreives information of snapshots taken in the last 24 hours. Daily maintenance. 

#> 
Param(
    [Parameter( Mandatory )]
    [String]
    $Controller
)
# All rw type vols
$priVols = Get-NcVol | Where-Object { $_.VolumeIdAttributes.Type -eq 'rw' }

$volSnapData = @{}

foreach ($vol in $priVols) {

    # Workload Type
    if ($vol.Name -like '*sq*') {
        # SQL 4 hours
        $workloadType = "SQL"
    }
    elseif ($vol.Name -like '*x*') {
        # Exchange 6 hours
        $workloadType = "Exchange"
    }
    elseif ($vol.Name -like '*vmfs*') {
        # VMFS 4 hours
        $workloadType = "VMFS"
    }
    elseif ( ($vol.Name -like '*fs*') -and ($vol.Name -notlike '*vmfs*') ) {
        # FS 1 hour
        $workloadType = "FS"
    }
    else {
        $workloadType = "Other"
    }

    # Snapshot Count
    $snapCount = $vol.VolumeSnapshotAttributes.SnapshotCount
    
    if ($snapCount -gt 0) {
        $volSnaps = Get-NcSnapshot -Volume $($vol.Name)
        $earliestSnap = $volSnaps[0].Created
        $lastSnap = $volSnaps[-1].Created
    }
    else {
        $volSnaps = "None"
        $lastSnap = "None"
    }
    # Snapshot Policy
    try {
        $currPolicy = $vol.VolumeSnapshotAttributes.SnapshotPolicy
    }
    catch {
        $currPolicy = "none"
    }

    $title = "$($vol.Name)_$($vol.Vserver)"
    $volSnapData += @{
        $title = @{
            VolName = $vol.Name
            WorkLoadType = $workloadType
            VolState = $vol.State
            Vserver = $vol.Vserver
            Aggr = $vol.Aggregate
            SnapshotPolicy = $currPolicy
            SnapCount = $snapCount
            LastSnapDate = $lastSnap
            EarliestSnapDate = $earliestSnap # add
        }
    }
    
}
# CSV Path. Create folder if it does not exist.
$currDate = Get-Date -Format MMddyyyy
$fileName = "\{0}_Vol_Protection_Status_{1}.csv" -f "$Controller","$currDate"
$filePath = "\\naeanrfkfs101v\admin_nrfk01$\TM_Cloud_Infrastructure\DailyVolumeProtectionChecks\$currDate"
$csvPath = $filePath+$fileName
$testPath = Test-Path -Path $filePath
if ($testPath -eq $false){
    New-Item -Path "\\naeanrfkfs101v\admin_nrfk01$\TM_Cloud_Infrastructure\DailyVolumeProtectionChecks\" -Name $currDate -ItemType "directory"
}
# Generate CSV and export
$headers = "VolName","WorkloadType","VolState","VServer","Aggr","SnapshotPolicy","SnapCount","LastSnapDate"
$headers -join "," | Out-File -FilePath $CsvPath -Encoding utf8
foreach ($volume in $volSnapData.Keys) {
    $csvOutput = """$($volSnapData.$volume.VolName)"",""$($volSnapData.$volume.WorkLoadType)"",""$($volSnapData.$volume.VolState)"",""$($volSnapData.$volume.Vserver)"",""$($volSnapData.$volume.Aggr)"",""$($volSnapData.$volume.SnapshotPolicy)"",""$($volSnapData.$volume.SnapCount)"",""$($volSnapData.$volume.LastSnapDate)"",""$($volSnapData.$volume.EarliestSnapDate)"""
    Add-Content -Path $CsvPath -Value $csvOutput
}
