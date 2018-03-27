[CmdletBinding()]
Param(   
    [parameter(ParameterSetName="usage")]
    [switch] $usage,
    
    [parameter(ParameterSetName="configuration")]
    [parameter(ParameterSetName="schedule")]
    [parameter(ParameterSetName="manual")]
    [parameter(ParameterSetName="minutes")]
    [parameter(ParameterSetName="hours")]
    [parameter(ParameterSetName="days")]
    [parameter(ParameterSetName="reset-action")]
    [parameter(ParameterSetName="start")]
    [parameter(ParameterSetName="pause")]
    [parameter(ParameterSetName="resume")]
    [parameter(ParameterSetName="delete")]
    [parameter(ParameterSetName="list")]
    [int] $job,
    
    [parameter(ParameterSetName="configuration")]
    [parameter(ParameterSetName="schedule")]
    [parameter(ParameterSetName="manual")]
    [parameter(ParameterSetName="minutes")]
    [parameter(ParameterSetName="hours")]
    [parameter(ParameterSetName="days")]
    [parameter(ParameterSetName="reset-action")]
    [parameter(ParameterSetName="start")]
    [parameter(ParameterSetName="pause")]
    [parameter(ParameterSetName="resume")]
    [parameter(ParameterSetName="delete")]
    [parameter(ParameterSetName="list")]
    [int[]] $jobs,
    
    [parameter(ParameterSetName="configuration")]
    [parameter(ParameterSetName="schedule")]
    [parameter(ParameterSetName="manual")]
    [parameter(ParameterSetName="minutes")]
    [parameter(ParameterSetName="hours")]
    [parameter(ParameterSetName="days")]
    [parameter(ParameterSetName="reset-action")]
    [parameter(ParameterSetName="start")]
    [parameter(ParameterSetName="pause")]
    [parameter(ParameterSetName="resume")]
    [parameter(ParameterSetName="delete")]
    [parameter(ParameterSetName="list")]
    [int] $startPageIndex = 0,

    [parameter(ParameterSetName="list")]
    [switch] $list,
    
    [parameter(ParameterSetName="start")]
    [switch] $start,
    
    [parameter(ParameterSetName="pause")]
    [switch] $pause,
    
    [parameter(ParameterSetName="resume")]
    [switch] $resume,
    
    [parameter(ParameterSetName="delete")]
    [switch] $delete,
    
    [parameter(ParameterSetName="reset-action")]
    [string][validateset('full','permissions','minimum')] $reset,

    [parameter(ParameterSetName="schedule")]
    [switch] $schedule,
    
    [parameter(ParameterSetName="schedule")]
    [parameter(ParameterSetName="manual")]
    [switch] $manual,

    [parameter(ParameterSetName="schedule")]
    [parameter(ParameterSetName="minutes")]
    [int]$minutes,

    [parameter(ParameterSetName="schedule")]
    [parameter(ParameterSetName="hours")]
    [int]$hours,

    [parameter(ParameterSetName="schedule")]
    [parameter(ParameterSetName="days")]
    [int]$days,

    [parameter(ParameterSetName="configuration")]
    [string][validateset('none','source','destination','both')] $ignoreDeletes,

    [parameter(ParameterSetName="configuration")]
    [string][validateset('copy','source','destination','latest', 'failure')] $conflicts,

    [parameter(ParameterSetName="configuration")]
    [string][validateset('synchronize','publish','migrate','copy', 'taxonomy')] $type,

    [parameter(ParameterSetName="configuration")]
    [string[]] $emails,

    [parameter(ParameterSetName="configuration")]
    [string][validateset('source','destination','discriminator')] $email
)

function get-jobs {
    param(
        [switch] $excludeConventions = $true,
        [switch] $excludeChildren,
        [int] $pageIndex=0
    )
    ConvertFrom-Json (Invoke-WebRequest -Uri "http://localhost:9000/v1/jobs?excludeconventions=$excludeConventions&excludeChildren=$excludeChildren&pageIndex=$pageIndex").Content
}

function get-job {
    param([int] $id)
    ConvertFrom-Json (Invoke-WebRequest -Uri "http://localhost:9000/v1/jobs/$id").Content
}

function update-job {
    param($jobDefinition)
    $jobJson = (ConvertTo-Json $jobDefinition -Depth 20)
    Write-Verbose "Updating job definition $jobJson"
    $result = Invoke-WebRequest -Uri "http://localhost:9000/v1/jobs/$($jobDefinition.id)" -ContentType "application/json" -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($jobJson))
    if($result.StatusCode -ne 200) {
        throw $result.StatusDescription
    }
}

function delete-job {
    param([int] $id)
    $result = Invoke-WebRequest -Uri "http://localhost:9000/v1/jobs/$id" -Method Delete
    if($result.StatusCode -ne 200) {
        throw $result.StatusDescription
    }
}

function pause-job {
    param([int] $id)
    $result = Invoke-WebRequest -Uri "http://localhost:9000/v1/jobs/$($id)?pause=1" -Method Post
    if($result.StatusCode -ne 200) {
        throw $result.StatusDescription
    }
}

function resume-job {
    param([int] $id)
    $result = Invoke-WebRequest -Uri "http://localhost:9000/v1/jobs/$($id)?resume=1" -Method Post
    if($result.StatusCode -ne 200) {
        throw $result.StatusDescription
    }
}

function reset-job {
    param(
        [int] $id,
        [string]$reset="minimum"
    )
    $result = Invoke-WebRequest -Uri "http://localhost:9000/v1/jobs/$($id)?reset=$reset" -Method Post
    if($result.StatusCode -ne 200) {
        throw $result.StatusDescription
    }
}

function start-job {
    param([int] $id)
    $result = Invoke-WebRequest -Uri "http://localhost:9000/v1/jobs/$($id)?start=1" -Method Post
    if($result.StatusCode -ne 200) {
        throw $result.StatusDescription
    }
}

if($usage -eq $true) {
    Write-Output "Usage skysync-jobs -usage | [-verbose | -debug] [-job <int>] [-jobs @(<int>, <int>, ...>)] (-list | -delete | -start | -pause | -resume | -reset {minimum|full|permissions} | -schedule [-manual | -minutes <int> | -hours <int> -days <int>] | [-emailUser] [-emails @(<string>, <string>, ...>)] [-ignoreDeletes {none|both|source|destination}] [-conflicts {none|both|source|destination}] [-type {synchronize|publish|migrate|copy|taxonomy}])"
    exit 0
}

if($job -gt 0) {
    $jobs += $job
}

if($jobs.Length -gt 0) {
    $jobDefinitions = @()
    foreach($job in $jobs) {
        $jobDefinition = get-job $job
        if($jobDefinition -eq $null) {
            throw "Job $job not found"
        }
        $jobDefinitions += $jobDefinition
    }
}

if($jobDefinitions -eq $null) {
    $more=$true
    $pageIndex=$startPageIndex
    while($more -eq $true) {
        $currentJobDefinitions = get-jobs -pageIndex $pageIndex
        $jobDefinitions += $currentJobDefinitions
        $more = $currentJobDefinitions.Length -gt 0
        $pageIndex++
    }
}

if($PSBoundParameters['verbose'] -eq $true -or $PSBoundParameters['debug'] -eq $true -or $list -eq $true) {
    Write-Output "Number of jobs: $($jobDefinitions.Length)" "Jobs: [$(($jobDefinitions | Foreach { $_.id }) -join ', ')]"
    if($list -eq $true) {
        exit 0
    }
}

if($delete -eq $true) {
    $title = "Delete Jobs"
    $message = "Are you sure you want to delete the following jobs [$(($jobDefinitions | Foreach { $_.id }) -join ', ')]?"

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "Deletes all the jobs."

    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "Keeps all the jobs."

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 

    switch ($result) {
        0 {
            foreach($jobDefinition in $jobDefinitions) {
                delete-job $jobDefinition.id
            }
        }
    }
    exit 0
}

if($reset -ne '') {
    foreach($jobDefinition in $jobDefinitions) {
        reset-job -id $jobDefinition.id -reset $reset
    }
}

if($start -eq $true) {
    foreach($jobDefinition in $jobDefinitions) {
        start-job $jobDefinition.id
    }
    exit 0
}

if($pause -eq $true) {
    foreach($jobDefinition in $jobDefinitions) {
        pause-job $jobDefinition.id
    }
    exit 0
}

if($resume -eq $true) {
    foreach($jobDefinition in $jobDefinitions) {
        resume-job $jobDefinition.id
    }
    exit 0
}

if($schedule -eq $true) {
    if($manual -eq $true) {
        $scheduleDetails = ConvertFrom-Json "{'mode': 2}"
    }
    elseif($minutes -ne 0) {
        $scheduleDetails = ConvertFrom-Json "{'mode': 1, 'repeatInterval' : {'m' : $minutes}}"
    }
    elseif($hours -ne 0) {
        $scheduleDetails = ConvertFrom-Json "{'mode': 1, 'repeatInterval' : {'h' : $hours}}"
    }
    elseif($days -ne 0) {
        $scheduleDetails = ConvertFrom-Json "{'mode': 1, 'repeatInterval' : {'d' : $days}}"
    }
    else {
        $scheduleDetails = ConvertFrom-Json "{'mode': 1}"
    }

    foreach($jobDefinition in $jobDefinitions) {
        $jobDefinition = get-job $jobDefinition.id
        $jobDefinition.schedule = $scheduleDetails
        update-job $jobDefinition
    }
    exit 0
}

if($ignoreDeletes -ne '' -or $emails.Length -gt 0 -or $email -ne '' -or $type -ne '' -or $conflicts -ne '') {
    foreach($jobDefinition in $jobDefinitions) {
        $jobDefinition = get-job $jobDefinition.id

        if($ignoreDeletes -ne '') {
            switch ($ignoreDeletes) {
                'none' {
                    $jobDefinition.deletePropagationPolicy = 0
                }
                'source' {
                    $jobDefinition.deletePropagationPolicy = 1
                }
                'destination' {
                    $jobDefinition.deletePropagationPolicy = 2
                }
                'both' {
                    $jobDefinition.deletePropagationPolicy = 3
                }
            }
        }

        if($conflicts -ne '') {
            switch ($conflicts) {
                'copy' {
                    $jobDefinition.conflictResolutionPolicy = 0
                }
                'source' {
                    $jobDefinition.conflictResolutionPolicy = 2
                }
                'destination' {
                    $jobDefinition.conflictResolutionPolicy = 3
                }
                'latest' {
                    $jobDefinition.conflictResolutionPolicy = 1
                }
                'failure' {
                    $jobDefinition.conflictResolutionPolicy = 4
                }
            }
        }

        $appendEmails = $emails
        if($email -ne '') {
            $appendEmail = $null
            switch ($email) {
                'source' {
                    $appendEmail = $jobDefinition.source.connection.account.name
                }
                'destination' {
                    $appendEmail = $jobDefinition.destination.connection.account.name
                }
                'discriminator' {
                    $appendEmail = $jobDefinition.conventionDiscriminator
                }
            }
            if($appendEmails.Length -gt 0) {
                if($appendEmail -ne $null) {
                    $appendEmails += $appendEmail
                }
            } else {
                $appendEmails = $appendEmail
            }
        }

        if($appendEmails.Length -gt 0) {
            if($jobDefinition.emailNotification -eq $null) {
                $jobDefinition | Add-Member @{emailNotification=($appendEmails -join ',')}
            }
            else {
                $jobDefinition.emailNotification = ($appendEmails -join ',')
            }
        }

        if($type -ne '') {
            switch ($type) {
                'synchronize' {
                    $jobDefinition.transferType = 1
                }
                'publish' {
                    $jobDefinition.transferType = 2
                }
                'migrate' {
                    $jobDefinition.transferType = 3
                }
                'copy' {
                    $jobDefinition.transferType = 4
                }
                'taxonomy' {
                    $jobDefinition.transferType = 5
                }
            }
        }
        update-job $jobDefinition
    }

    exit 0
}
