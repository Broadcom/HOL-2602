# -------- CONFIG --------
$clusterName   = "cluster-wld01-01a"
$rpNames        = @("Production", "Development", "Staging")
$parentResourcePool = $null
$tags  = @("cloud:vcf","enabled:yes")
$additionalTags = @("Production:location:las","Development:location:lon","Staging:location:tko", "Production:environment:prd","Development:environment:dev","Staging:environment:stg")
# ------------------------

try {
    if ( -not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
        Write-Host "Installing VMware.PowerCLI..." -ForegroundColor Cyan
        $currentPolicy = Get-ExecutionPolicy
        if ($currentPolicy -in 'Undefined', 'Restricted') {Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force}
        Install-Module VMware.PowerCLI -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module VMware.PowerCLI -ErrorAction Stop | Out-Null
} catch {
    Write-Error "Failed to install/import VMware.PowerCLI: $($_.Exception.Messsage)"
    exit 1
}

# Connect to vCenter
try {
    $si = Connect-VIServer -Server vc-wld01-a.site-a.vcf.lab -User administrator@wld.sso -Password 'VMware123!VMware123!' -ErrorAction Stop
    Write-Host "Connected to vCenter: $($si.Name)" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to vCenter: $($_.Exception.Message)"
    exit 1
}


# Get the cluster
$compute = Get-Cluster -Name $clusterName -ErrorAction SilentlyContinue
if (-not $compute) {
    Get-VMHost -Name $clusterName -ErrorAction SilentlyContinue 
}
if (-not $compute) {
    Write-Error "Cluster/Host '$clusterName' not found."
    exit 1
}

$rootRp = Get-ResourcePool -Location $compute -ErrorAction Stop | Where-Object { $_.Parent -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl] -or $_.Parent -is  [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl] } | Select-Object -First 1
$parentRp =$rootRp

if ($parentResourcePool) {
    $parentRp = Get-ResourcePool -Name $parentResourcePool -Location $compute -ErrorAction SilentlyContinue
    if (-not $parentRp) {
        Write-Error "Parent Resource Pool '$parentResourcePool' not found under '$clusterName'"
        exit 1
    }
}

# Create the resource pools
foreach ($name in $rpNames) {
    $rp = Get-ResourcePool -Name $name -Location $compute -ErrorAction SilentlyContinue
    if ($rp) {
        Write-Host "Resource Pool '$name' already exists, skipping creation." -ForegroundColor Yellow
    } else {
        Write-Host "Creating Resource Pool '$name' under '$clusterName'..." -ForegroundColor Cyan
    $rp = New-ResourcePool -Name $name -Location $parentRp -ErrorAction Stop
    }

    foreach ($tag in $tags) {
        if ($tag -notmatch ":") {
            Write-Warning "Tag '$tag' does not contain a category, skipping assignment."
            continue
        }

        $parts = $tag -split ":"
        $category = $parts[0].Trim()
        $value = $parts[1].Trim()

        $cat = Get-TagCategory -Name $category -ErrorAction SilentlyContinue

        if (-not $cat) {
            $cat = New-TagCategory -Name $category -Cardinality Single -EntityType ResourcePool
            Write-Host "Created Tag Category: '$($cat.Name)'."
        }

        $t = Get-Tag -Name $value -Category $cat -ErrorAction SilentlyContinue
        if (-not $t) {
            $t = New-Tag -Name $value -Category $cat -ErrorAction Stop
            Write-Host "Created Tag: '$($t.Name)' in category '$($cat.Name)'."
        }

        $assigned = Get-TagAssignment -Entity $rp | Where-Object { $_.Tag.Name -eq $t.Name -and $_.Tag.Category.Name -eq $cat.Name }
        if (-not $assigned) {
            Write-Host "Assigning tag '$($cat.Name):$($t.Name)' to resource pool '$($rp.Name)'..." -ForegroundColor Cyan
            New-TagAssignment -Entity $rp -Tag $t | Out-Null
        } else {
            Write-Host "Tag '$($cat.Name):$($t.Name)' is already assigned to resource pool '$($rp.Name)', skipping assignment." -ForegroundColor Yellow
            continue
        }
    }

    foreach ($tag in $additionalTags) {
        if ($tag -notmatch ":") {
            Write-Warning "Tag '$tag' does not contain a category, skipping assignment."
            continue
        }

        $parts = $tag -split ":"
        $rp = Get-ResourcePool -Name $parts[0].Trim() -Location $parentRp -ErrorAction Stop
        $category = $parts[1].Trim()
        $value = $parts[2].Trim()

        $cat = Get-TagCategory -Name $category -ErrorAction SilentlyContinue

        if (-not $cat) {
            $cat = New-TagCategory -Name $category -Cardinality Single -EntityType ResourcePool
            Write-Host "Created Tag Category: '$($cat.Name)'."
        }

        $t = Get-Tag -Name $value -Category $cat -ErrorAction SilentlyContinue
        if (-not $t) {
            $t = New-Tag -Name $value -Category $cat -ErrorAction Stop
            Write-Host "Created Tag: '$($t.Name)' in category '$($cat.Name)'."
        }

        $assigned = Get-TagAssignment -Entity $rp | Where-Object { $_.Tag.Name -eq $t.Name -and $_.Tag.Category.Name -eq $cat.Name }
        if (-not $assigned) {
            Write-Host "Assigning tag '$($cat.Name):$($t.Name)' to resource pool '$($rp.Name)'..." -ForegroundColor Cyan
            New-TagAssignment -Entity $rp -Tag $t | Out-Null
        } else {
            Write-Host "Tag '$($cat.Name):$($t.Name)' is already assigned to resource pool '$($rp.Name)', skipping assignment." -ForegroundColor Yellow
            continue
        }
    }
}

