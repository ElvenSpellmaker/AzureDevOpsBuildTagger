function Update-TagsAndLease
{
		param(
		[Parameter(Mandatory = $true)]
		[string]
		$Organisation,
		[Parameter(Mandatory = $true)]
		[string]
		$Project,
		[Parameter(Mandatory = $true)]
		[int]
		$DefinitionId,
		[Parameter(Mandatory = $true)]
		[int]
		$BuildId,
		[Parameter(Mandatory = $true)]
		[string]
		$BuildFor,
		[Parameter(Mandatory = $true)]
		[string]
		$AccessToken,
		[Parameter(Mandatory = $true)]
		[string]
		$TagName,
		[Parameter(Mandatory = $true)]
		[string]
		$AllTags,
		[Parameter(Mandatory = $true)]
		[int]
		$LeaseLength,
		[Parameter(Mandatory = $false)]
		[int]
		$OldLeaseLength = 1,
		[Parameter(Mandatory = $false)]
		[switch]
		$PersonalAccessToken
	)

	# Config
	## General
	$leaseIdKey = "LeaseId:"

	## URLs
	$baseUrl = "https://dev.azure.com/{0}/{1}/_apis/build" -f $Organisation, $Project
	$apiVersion = "api-version=7.0"

	$currentBuildTagsUrl = "${baseUrl}/builds/{1}/tags?{0}" -f $apiVersion, $BuildId

	$buildWithTagsUrl = "${baseUrl}/builds?{0}&tagFilters={1}&definitions={2}" -f $apiVersion, $TagName, $DefinitionId
	$tagsUpdateUrl = "${baseUrl}/builds/{{0}}/tags/?{0}" -f $apiVersion
	$leaseAddUrl = "${baseUrl}/retention/leases?{0}" -f $apiVersion
	$leaseGetByRunUrl = "${baseUrl}/retention/leases?&definitionId={{0}}&runId={{1}}&{0}" -f $apiVersion
	$leaseDeleteUrl = "${baseUrl}/retention/leases?ids={{0}}&{0}" -f $apiVersion
	$leaseUpdateUrl = "${baseUrl}/retention/leases/{{0}}?{0}" -f $apiVersion

	## Rest Set-up
	$contentType = "application/json";

	$headers = @{ Authorization = "Bearer ${AccessToken}" };

	if ($PersonalAccessToken)
	{
		$b64Pat = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("`:${AccessToken}"))
		$headers.Authorization = "Basic ${b64Pat}"
	}

	# Script

	$allTagsArray = $AllTags -split ","

	if (-not $allTagsArray.contains($TagName))
	{
		throw "'$TagName' is not in the AllTags list '$AllTags'"
	}

	# Get previous build with tag if it exists
	## Note: Get these _before_ tagging the current build so it doesn't appear in that list
	$oldBuilds = Invoke-RestMethod `
		-Uri $buildWithTagsUrl `
		-Method GET `
		-Headers $headers `
		-ContentType $contentType `
		-StatusCodeVariable 'statusCode'

	if ($statusCode -eq 203)
	{
		Write-Error "Possible PAT Detected, please run with ``-PersonalAccessToken``"
	}

	# Get current build tags
	$buildTags = Invoke-RestMethod `
		-Uri $currentBuildTagsUrl `
		-Method GET `
		-Headers $headers `
		-ContentType $contentType

	$buildTags = $buildTags.value

	function Get-LeaseFromTags
	{
		param(
		[Parameter(Mandatory = $true)]
			[AllowEmptyCollection()]
			[Array]
			$BuildTags
		)

		$leaseTag = $null
		$leaseId = $null

		foreach ($buildTag in $BuildTags)
		{
			$null, $tempLeaseId = $buildTag.Split($leaseIdKey)
			if ($null -ne $tempLeaseId)
			{
				$leaseTag = $buildTag
				$leaseId = $tempLeaseId

				break
			}
		}

		return @{
			leaseTag = $leaseTag
			leaseId = $leaseId
		}
	}

	function Update-LeaseForBuild
	{
		param(
			[Parameter(Mandatory = $true)]
			[int]
			$DefinitionId,
			[Parameter(Mandatory = $true)]
			[int]
			$BuildId,
			[Parameter(Mandatory = $true)]
			[string]
			$BuildFor,
			[Parameter(Mandatory = $true)]
			[int]
			$LeaseId,
			[Parameter(Mandatory = $true)]
			[AllowEmptyString()]
			[string]
			$LeaseTag,
			[Parameter(Mandatory = $true)]
			[int]
			$LeaseLength
		)

		$tagsBody = [ordered]@{
			leaseExists = $false
			tagsToAdd = @()
			tagsToRemove = @()
		}

		$lease = Invoke-RestMethod `
			-Uri $($leaseGetByRunUrl -f $DefinitionId, $BuildId) `
			-Method GET `
			-Headers $headers `
			-ContentType $contentType

		"yip: $(ConvertTo-Json $lease)" >> .\Invoke-RestMethod.log

		foreach ($lease in $lease.value)
		{
			if ($lease.leaseId -eq $LeaseId)
			{
				$tagsBody.leaseExists = $true

				break
			}
		}

		if ($tagsBody.leaseExists)
		{
			Write-Host "Lease exists"
			if ($lease.daysValid -ne $LeaseLength -or $lease.protectPipeline -ne $true)
			{
				if ($LeaseLength -eq 0)
				{
					Write-Host "Deleting Lease"
					$null = Invoke-RestMethod `
						-Uri $($leaseDeleteUrl -f $lease.leaseId) `
						-Method DELETE `
						-Headers $headers `
						-ContentType $contentType

					$tagsBody.tagsToRemove += $LeaseTag

					return $tagsBody
				}

				$leaseUpdateBody = [ordered]@{
					daysValid = $LeaseLength
					protectPipeline = $true
				}

				Write-Host "Updating Lease for build"
				$null = Invoke-RestMethod `
					-Uri $($leaseUpdateUrl -f $lease.leaseId) `
					-Method PATCH `
					-Headers $headers `
					-ContentType $contentType `
					-Body $(ConvertTo-Json $leaseUpdateBody)
			}

			return $tagsBody
		}

		## Make sure we remove the Old Lease ID if we had to create a new Lease
		$tagsBody.tagsToRemove += $LeaseTag

		if ($LeaseLength -eq 0)
		{
			return $tagsBody
		}

		$leaseAddBody = [ordered]@{
			daysValid = $LeaseLength
			definitionId = $DefinitionId
			ownerId = $BuildFor
			protectPipeline = $true
			runId = $BuildId
		}

		$lease = Invoke-RestMethod `
			-Uri $leaseAddUrl `
			-Method POST `
			-Headers $headers `
			-ContentType $contentType `
			-Body $(ConvertTo-Json @($leaseAddBody))

		## Add the new Lease ID to the Tags to add
		$tagsBody.tagsToAdd += "${leaseIdKey}$($lease.value[0].leaseId)"

		return $tagsBody
	}

	# Acquire lease if needed

	$leaseTags = Get-LeaseFromTags `
		-BuildTags $buildTags

	$leaseTag = $leaseTags.leaseTag
	$leaseId = $leaseTags.leaseId

	$leaseReturn = Update-LeaseForBuild `
		-DefinitionId $DefinitionId `
		-BuildId $BuildId `
		-BuildFor $BuildFor `
		-LeaseId $leaseId `
		-LeaseTag $leaseTag `
		-LeaseLength $LeaseLength

	$tagsToAdd = $leaseReturn.tagsToAdd
	$tagsToRemove = $leaseReturn.tagsToRemove

	# Tag our current build
	$tagsToAdd += $TagName

	$tagsUpdateBody = [ordered]@{
		tagsToAdd = $tagsToAdd
		tagsToRemove = $tagsToRemove
	}

	$currentBuildTags = Invoke-RestMethod `
		-Uri $($tagsUpdateUrl -f $BuildId) `
		-Method PATCH `
		-Headers $headers `
		-ContentType $contentType `
		-Body $(ConvertTo-Json $tagsUpdateBody)

	# If at least one build exists with Tags from a previous run, handle them...
	if (-not $oldBuilds.count)
	{
		return
	}

	foreach ($oldBuild in $oldBuilds.value)
	{
		if ($oldBuild.id -eq $BuildId)
		{
			Write-Host "Current Build is in the Old Builds list. Updating tags..."

			$oldBuild.tags = $currentBuildTags.value
		}

		$leaseTags = Get-LeaseFromTags -BuildTags $oldBuild.tags
		$leaseTag = $leaseTags.leaseTag
		$leaseId = $leaseTags.leaseId

		$allTagFound = $false
		foreach ($tag in $oldBuild.tags)
		{
			if (($oldBuild.id -eq $BuildId -or $tag -ne $TagName) -and $allTagsArray.Contains($tag))
			{
				$allTagFound = $true
				break
			}
		}

		# Remove tags
		$tagsUpdateBody = [ordered]@{
			tagsToAdd = @()
			tagsToRemove = @()
		}

		if ($oldBuild.id -ne $BuildId)
		{
			$tagsUpdateBody.tagsToRemove += $TagName
		}

		$leaseLength = $LeaseLength

		# If lease isn't needed any more then update the length to the Old length
		if (-not $allTagFound)
		{
			Write-Host "Lease is no longer protected by a current tag in the Tag List"

			$leaseLength = $OldLeaseLength
		}

		$leaseReturn = Update-LeaseForBuild `
				-DefinitionId $DefinitionId `
				-BuildId $oldBuild.id `
				-BuildFor $BuildFor `
				-LeaseId $leaseId `
				-LeaseTag $leaseTag `
				-LeaseLength $leaseLength

		$tagsUpdateBody.tagsToAdd += $leaseReturn.tagsToAdd
		$tagsUpdateBody.tagsToRemove += $leaseReturn.tagsToRemove

		if ($tagsUpdateBody.tagsToAdd.Count + $tagsUpdateBody.tagsToRemove.Count -eq 0)
		{
			return
		}

		# Add or Remove tags needed to be changed
		Write-Host "Update Old Build with Tags"
		$null = Invoke-RestMethod `
			-Uri $($tagsUpdateUrl -f $oldBuild.id) `
			-Method PATCH `
			-Headers $headers `
			-ContentType $contentType `
			-Body $(ConvertTo-Json $tagsUpdateBody)
	}
}
