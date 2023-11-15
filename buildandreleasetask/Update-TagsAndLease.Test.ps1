Describe "Update-TagsAndLease" {

	BeforeAll {
		. $PSScriptRoot/Update-TagsAndLease.ps1

		$defaultArgs = @{
			Organisation = "testorg"
			Project = "testproject"
			DefinitionId = 102
			BuildId = 25402
			BuildFor = "User:00000000-0000-0000-0000-000000000000"
			AccessToken = "abcd1234"
			TagName = "SIT"
			AllTags = "SIT,PAT-EUN,PAT-EUW,PROD-EUN,PROD-EUW"
			# Leases over 100 days are considered "forever" by Azure DevOps
			LeaseLength = "36865"
		}

		# Invoke-RestMethod mock setup
		$defaultHeader = @{
			Authorization = "Bearer $($defaultArgs.AccessToken)"
		}

		# Mock Write-Host
		Mock `
			-Command Write-Host `
			-MockWith { }

		Mock `
			-Command Invoke-RestMethod `
			-MockWith {
				$logName = "Invoke-RestMethod.log"
				"URI: $Uri" >> $logName
				"Body: $Body" >> $logName
				throw "Invoke-RestMethod called but no mock, logging to '${logName}'!"
			}
	}

	Context "Basic tests" {
		It "will tag a build and acquire a lease" {
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=SIT&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags?api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=25402&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseAddBody = @'
[
  {
    "daysValid": 36865,
    "definitionId": 102,
    "ownerId": "User:00000000-0000-0000-0000-000000000000",
    "protectPipeline": true,
    "runId": 25402
  }
]
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 132
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?api-version=7.0" `
					-and $Method -eq "POST" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseAddBody -replace "`r"
				}

			$tagsAddBody = @'
{
  "tagsToAdd": [
    "LeaseId:132",
    "SIT"
  ],
  "tagsToRemove": [
    ""
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{ }
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody
				}

			Update-TagsAndLease @defaultArgs

			Should -InvokeVerifiable
			Should -Invoke Invoke-RestMethod -Exactly 5
		}

		It "will tag a build and acquire a lease, using a PAT" {
			# Set up custom parameters
			$args = $defaultArgs
			$args += @{"PersonalAccessToken" = $true}

			$header = @{
				Authorization = "Basic OmFiY2QxMjM0"
			}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=SIT&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $header.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags?api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $header.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=25402&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $header.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseAddBody = @'
[
  {
    "daysValid": 36865,
    "definitionId": 102,
    "ownerId": "User:00000000-0000-0000-0000-000000000000",
    "protectPipeline": true,
    "runId": 25402
  }
]
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 132
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?api-version=7.0" `
					-and $Method -eq "POST" `
					-and $Headers.Authorization -eq $header.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseAddBody -replace "`r"
				}

			$tagsAddBody = @'
{
  "tagsToAdd": [
    "LeaseId:132",
    "SIT"
  ],
  "tagsToRemove": [
    ""
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{ }
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $header.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody
				}

			Update-TagsAndLease @args

			Should -InvokeVerifiable
			Should -Invoke Invoke-RestMethod -Exactly 5
		}

		It "will tag a build and acquire a lease, and remove tags from old build with valid lease ID" {
			# Adding a Tag to the current build
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								id = 4000
								tags = @("SIT", "LeaseId:102")
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=SIT&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags?api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=25402&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseAddBody = @'
[
  {
    "daysValid": 36865,
    "definitionId": 102,
    "ownerId": "User:00000000-0000-0000-0000-000000000000",
    "protectPipeline": true,
    "runId": 25402
  }
]
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 132
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?api-version=7.0" `
					-and $Method -eq "POST" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseAddBody -replace "`r"
				}

			$tagsAddBody = @'
{
  "tagsToAdd": [
    "LeaseId:132",
    "SIT"
  ],
  "tagsToRemove": [
    ""
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith { } `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody
				}

			# Update the old build(s)
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 102
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=4000&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseUpdateBodyString = @'
{
  "daysValid": 1,
  "protectPipeline": true
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith { } `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases/102?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseUpdateBodyString
				}

			$tagsAddBody2 = @'
{
  "tagsToAdd": [],
  "tagsToRemove": [
    "SIT"
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/4000/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody2
				}

			Update-TagsAndLease @defaultArgs

			Should -InvokeVerifiable
			Should -Invoke Invoke-RestMethod -Exactly 8
		}

		It "will not remove tags and lease if re-run on same build, with valid lease ID" {
			# Adding a Tag to the current build (but it already has it)
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								id = 25402
								tags = @("SIT", "LeaseId:132")
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=SIT&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 2
						value = @("SIT", "LeaseId:132")
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags?api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 132
								daysValid = 36865
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=25402&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$tagsAddBody = @'
{
  "tagsToAdd": [
    "SIT"
  ],
  "tagsToRemove": []
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 2
						value = @(
							"SIT",
							"LeaseId:132"
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody
				}

			Update-TagsAndLease @defaultArgs

			Should -InvokeVerifiable
			Should -Invoke Invoke-RestMethod -Exactly 5
		}

		It "will tag a build and acquire a lease, and remove tags and lease from old build with valid lease ID" {
			$args = $defaultArgs
			$args.OldLeaseLength = 0

			# Adding a Tag to the current build
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								id = 4000
								tags = @("SIT", "LeaseId:102")
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=SIT&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags?api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=25402&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseAddBody = @'
[
  {
    "daysValid": 36865,
    "definitionId": 102,
    "ownerId": "User:00000000-0000-0000-0000-000000000000",
    "protectPipeline": true,
    "runId": 25402
  }
]
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 132
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?api-version=7.0" `
					-and $Method -eq "POST" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseAddBody -replace "`r"
				}

			$tagsAddBody = @'
{
  "tagsToAdd": [
    "LeaseId:132",
    "SIT"
  ],
  "tagsToRemove": [
    ""
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith { } `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody
				}

			# Update the old build(s)
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 102
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=4000&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith { } `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?ids=102&api-version=7.0" `
					-and $Method -eq "DELETE" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

				$tagsAddBody2 = @'
{
  "tagsToAdd": [],
  "tagsToRemove": [
    "SIT",
    "LeaseId:102"
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/4000/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody2
				}

			Update-TagsAndLease @args

			Should -InvokeVerifiable
			Should -Invoke Invoke-RestMethod -Exactly 8
		}

		It "will tag a build and acquire a lease, and remove tags from old build with valid lease ID and other Env tags" {
			# Adding a Tag to the current build
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								id = 4000
								tags = @("SIT", "PAT-EUN", "LeaseId:102")
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=SIT&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags?api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=25402&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseAddBody = @'
[
  {
    "daysValid": 36865,
    "definitionId": 102,
    "ownerId": "User:00000000-0000-0000-0000-000000000000",
    "protectPipeline": true,
    "runId": 25402
  }
]
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 132
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?api-version=7.0" `
					-and $Method -eq "POST" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseAddBody -replace "`r"
				}

			$tagsAddBody = @'
{
  "tagsToAdd": [
    "LeaseId:132",
    "SIT"
  ],
  "tagsToRemove": [
    ""
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith { } `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody
				}

			# Update the old build(s)
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 102
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=4000&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

				$tagsAddBody2 = @'
{
  "tagsToAdd": [],
  "tagsToRemove": [
    "SIT"
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/4000/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody2
				}

			Update-TagsAndLease @defaultArgs

			Should -InvokeVerifiable
			Should -Invoke Invoke-RestMethod -Exactly 7
		}
	}

	Context "PAT Tests" {
		It "will fail and ask if you're using a PAT" -Tag Foo {
			$script:statusCode = 0

			Mock `
				-Command Write-Error `
				-Verifiable `
				-MockWith {
					throw [Exception]::new("Possible PAT Detected, please run with ``-PersonalAccessToken``")
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					$script:statusCode = 203
					return "Doesn't matter really..."
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=SIT&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $StatusCodeVariable -eq "statusCode"
				}

			{ Update-TagsAndLease @defaultArgs } `
				| Should -Throw -ExpectedMessage "Possible PAT Detected, please run with ``-PersonalAccessToken``"

			Should -InvokeVerifiable
			Should -Invoke Write-Error -Exactly 1
			Should -Invoke Invoke-RestMethod -Exactly 1

			# Should -Be -ActualValue $script:statusCode -ExpectedValue 203
		}

	}

	Context "Invalid Lease Tests" {
		It "will not remove tags and lease if re-run on same build and renew invalid lease" {
			# Adding a Tag to the current build (but it already has it)
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								id = 25402
								tags = @("Foo", "SIT", "PAT-EUN", "LeaseId:10000")
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=SIT&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 4
						value = @("Foo", "SIT", "PAT-EUN", "LeaseId:10000")
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags?api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$script:leaseGetCount = 0

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					$leaseGetCount = $script:leaseGetCount++

					if ($leaseGetCount -gt 0)
					{
						$lease = @(
							@{
								leaseId = 132
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
					else
					{
						$lease = @()
					}

					return @{
						count = $leaseGetCount
						value = $lease
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=25402&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseAddBody = @'
[
  {
    "daysValid": 36865,
    "definitionId": 102,
    "ownerId": "User:00000000-0000-0000-0000-000000000000",
    "protectPipeline": true,
    "runId": 25402
  }
]
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 132
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?api-version=7.0" `
					-and $Method -eq "POST" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseAddBody -replace "`r"
				}

			$tagsAddBody = @'
{
  "tagsToAdd": [
    "LeaseId:132",
    "SIT"
  ],
  "tagsToRemove": [
    "LeaseId:10000"
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 4
						value = @(
							"Foo",
							"SIT",
							"PAT-EUN",
							"LeaseId:132"
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody
				}

			Update-TagsAndLease @defaultArgs

			Should -InvokeVerifiable
			Should -Invoke Invoke-RestMethod -Exactly 6
		}

		It "will tag a build with a new lease for invalid lease ID, and remove tags from old build with invalid lease ID and change the lease" {
			# Adding a Tag to the current build
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 2
						value = @(
							@{
								id = 4000
								tags = @("SIT", "PAT-EUN", "LeaseId:200")
							},
							@{
								id = 25402
								tags = @("SIT", "LeaseId:300")
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=SIT&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 2
						value = @("SIT", "LeaseId:300")
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags?api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$script:leaseGetCount = 0

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					$leaseGetCount = $script:leaseGetCount++

					if ($leaseGetCount -gt 0)
					{
						$lease = @(
							@{
								leaseId = 132
								daysValid = 36865
								protectPipeline = $true
							}
						)
					}
					else
					{
						$lease = @()
					}

					return @{
						count = $leaseGetCount
						value = $lease
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=25402&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseAddBody = @'
[
  {
    "daysValid": 36865,
    "definitionId": 102,
    "ownerId": "User:00000000-0000-0000-0000-000000000000",
    "protectPipeline": true,
    "runId": 25402
  }
]
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 132
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?api-version=7.0" `
					-and $Method -eq "POST" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseAddBody -replace "`r"
				}

			$tagsAddBody = @'
{
  "tagsToAdd": [
    "LeaseId:132",
    "SIT"
  ],
  "tagsToRemove": [
    "LeaseId:300"
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 2
						value = @(
							"SIT"
							"LeaseId:132"
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody
				}

			# Update the old builds
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=4000&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseAddBodyString2 = @'
[
  {
    "daysValid": 36865,
    "definitionId": 102,
    "ownerId": "User:00000000-0000-0000-0000-000000000000",
    "protectPipeline": true,
    "runId": 4000
  }
]
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 102
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?api-version=7.0" `
					-and $Method -eq "POST" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseAddBodyString2
				}

			$tagsAddBodyString2 = @'
{
  "tagsToAdd": [
    "LeaseId:102"
  ],
  "tagsToRemove": [
    "SIT",
    "LeaseId:200"
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith { } `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/4000/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBodyString2
				}

			Update-TagsAndLease @defaultArgs

			Should -InvokeVerifiable
			Should -Invoke Invoke-RestMethod -Exactly 9
		}
	}

	Context "Invalid Tags Passed" {
		It "TagName passed is not in AllTags list" {
			$newArgs = $defaultArgs
			$newArgs.TagName = "Foo"

			{ Update-TagsAndLease @newArgs } `
				| Should -Throw -ExpectedMessage "'Foo' is not in the AllTags list 'SIT,PAT-EUN,PAT-EUW,PROD-EUN,PROD-EUW'"

			Should -InvokeVerifiable
			Should -Invoke Invoke-RestMethod -Exactly 0
		}
	}

	Context "Complex Tests" -Tag "Foo" {
		It "will tag a build with a new lease for missing lease ID, and remove tags and lease from old build with invalid lease ID" -Tag "Foo" {
			$args = $defaultArgs
			$args.OldLeaseLength = 0
			$args.TagName = "PROD-EUN"

			# Adding a Tag to the current build
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 3
						value = @(
							@{
								id = 1000
								tags = @("Prod-EUN", "LeaseId:500")
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds?api-version=7.0&tagFilters=PROD-EUN&definitions=102" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 2
						value = @("PAT-EUN") # Missing LeaseID
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags?api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=25402&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$leaseAddBody = @'
[
  {
    "daysValid": 36865,
    "definitionId": 102,
    "ownerId": "User:00000000-0000-0000-0000-000000000000",
    "protectPipeline": true,
    "runId": 25402
  }
]
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 1
						value = @(
							@{
								leaseId = 132
								daysValid = $defaultArgs.LeaseLength
								protectPipeline = $true
							}
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?api-version=7.0" `
					-and $Method -eq "POST" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $leaseAddBody -replace "`r"
				}

			$tagsAddBody = @'
{
  "tagsToAdd": [
    "LeaseId:132",
    "PROD-EUN"
  ],
  "tagsToRemove": [
    ""
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 2
						value = @(
							"SIT"
							"LeaseId:132"
						)
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/25402/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsAddBody
				}

			# Update the old builds
			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith {
					return @{
						count = 0
						value = @()
					}
				} `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/retention/leases?&definitionId=102&runId=1000&api-version=7.0" `
					-and $Method -eq "GET" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json"
				}

			$tagsUpdateBodyString = @'
{
  "tagsToAdd": [],
  "tagsToRemove": [
    "PROD-EUN",
    "LeaseId:500"
  ]
}
'@

			Mock `
				-Command Invoke-RestMethod `
				-Verifiable `
				-MockWith { } `
				-ParameterFilter {
					$Uri -eq "https://dev.azure.com/testorg/testproject/_apis/build/builds/1000/tags/?api-version=7.0" `
					-and $Method -eq "PATCH" `
					-and $Headers.Authorization -eq $defaultHeader.Authorization `
					-and $ContentType -eq "application/json" `
					-and $Body -replace "`r","" -eq $tagsUpdateBodyString
				}

			Update-TagsAndLease @defaultArgs

			Should -InvokeVerifiable
			# Get Builds with tag PROD-EUN
			# Get Current Build (25402)
			# Get Lease for Current Build
			# Acquire Lease for Current Build
			# Update Current Build Tags
			# Old Build - Get Lease
			# Old Build - Update Tags
			Should -Invoke Invoke-RestMethod -Exactly 7
		}
	}
}
