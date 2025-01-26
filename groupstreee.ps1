function Convert-ToTree {
    param (
        [string]$filePath,
        [string]$outputPath
    )

    $lines = Get-Content $filePath
    $tree = @()
    $indentStack = @()

    $charPipe = [char]0x2502  # Unicode value for │
    $charL = [char]0x251C  # Unicode value for ├
    $charCorner = [char]0x2514  # Unicode value for └
    $charDash = [char]0x2500  # Unicode value for ─

    foreach ($line in $lines) {
        $indentLevel = ($line -replace '[^\s]', '').Length
        $content = $line.Trim()

        while ($indentStack.Count -gt $indentLevel) {
            $indentStack = $indentStack[0..($indentStack.Count - 2)]
        }

        $prefix = ''
        if ($indentStack.Count -gt 0) {
            $prefix = ($indentStack -join '') + "$charL$charDash"
        }

        $tree += $prefix + $content
        $indentStack += "$charPipe "
    }

    $tree[-1] = $tree[-1] -replace "$charL$charDash", "$charCorner$charDash"
    $tree | Out-File $outputPath -Encoding OEM
}

function Get-GroupName {
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupId
    )
	$group = Get-AzureADGroup -ObjectId $GroupId
    return $group.DisplayName
}

function Print-Recursion  {
    param (
        [Parameter(Mandatory=$true)]
        [string]$id,
		[string[]]$idlist
    )

	$recustring = ""
	foreach ($iditem in $idlist) {
		$itemname = Get-GroupName $iditem
		Write-Host $itemname ">" -NoNewLine -ForegroundColor Red
		$recustring = $recustring + $itemname + " > "
		"$spaces$displayname ($nbleaves)" | Out-File -FilePath "groupstree.tmp" -Append
	}
	$itemname = Get-GroupName $id
	Write-Host $itemname -ForegroundColor Red
	$recustring = $recustring + $itemname
	"$recustring" | Out-File -FilePath "groupstree.rec" -Append
}

function Get-DirectMemberCount {
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupId
    )
    $members = Get-AzureADGroupMember -ObjectId $GroupId -All $true
    $directMembers = $members | Where-Object { $_.ObjectType -ne "Group" }
    return $directMembers.Count
}

function Get-IdIndex {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$StringList,
        [Parameter(Mandatory=$true)]
        [string]$SearchString
    )

    # Find the index of the search string in the list
    $index = [Array]::IndexOf($StringList, $SearchString)

    # Return the index if found, otherwise return -1
    if ($index -ge 0) {
        return $index
    } else {
        return -1
    }
}


# Function to get nested groups recursively
function Get-NestedGroups {
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupId,
		[int]$indent,
		[string[]]$idlist
    )

    $nestedGroups = @()
    $members = Get-AzureADGroupMember -ObjectId $GroupId
    $spaces = " " * $indent
	$indent = $indent + 1
    foreach ($member in $members) {
        if ($member.ObjectType -eq "Group") {
			$newidlist = @()
			$newidlist = $idlist + $member.ObjectId
			$nbleaves = Get-DirectMemberCount $member.ObjectId 
			$displayname = $member.DisplayName
			Write-Host $spaces $member.DisplayName "($nbleaves)"
			"$spaces$displayname ($nbleaves)" | Out-File -FilePath "groupstree.tmp" -Append
			$found = Get-IdIndex $idlist $member.ObjectId
			if ($found -eq -1) {
				$nestedGroups += [PSCustomObject]@{
					DisplayName = $member.DisplayName + " [" + $member.ObjectId + "] (" + $nbleaves + ")"
					NestedGroups = Get-NestedGroups $member.ObjectId $indent $newidlist
				}
			} else {
				Print-Recursion $member.ObjectId $idlist
				#Write-Host $member.DisplayName " is recursive" -ForegroundColor Red
				return $nestedGroups
			}
        }
    }
    return $nestedGroups
}

Connect-AzureAD

Remove-Item -Path "groupstree.tmp" -Force
Remove-Item -Path "groupstree.rec" -Force

$allGroups = Get-AzureADMSGroup -All $true
Write-Host $allGroups.Count "Groups"  -ForegroundColor Yellow

$groupTree = @()
foreach ($group in $allGroups) {
	#Write-Host "+" $group.DisplayName
    if ($group.Id) {
		$listofids = @()
		$listofids += $group.Id 
		$nbleaves = Get-DirectMemberCount $group.Id
		$displayname = $group.DisplayName
		Write-Host $group.DisplayName "($nbleaves)"
		"$displayname ($nbleaves)" | Out-File -FilePath "groupstree.tmp" -Append
        $groupTree += [PSCustomObject]@{
            DisplayName = $group.DisplayName + " [" + $group.Id + "] (" + $nbleaves + ")"
            NestedGroups = Get-NestedGroups -GroupId $group.Id 1 $listofids
        }
    }
	else
	{
		Write-Host "Error"
	}
}

$filePath   = "groupstree.tmp"
$outputPath = "groupstree.txt"
#Convert-ToTree -filePath $filePath | ForEach-Object { Write-Output $_ }
Convert-ToTree -filePath $filePath -outputPath $outputPath
