# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License.

<#
.Synopsis
   Tests for GitHubAssignees.ps1 module
#>

# This is common test code setup logic for all Pester test files
$root = Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path)
. (Join-Path -Path $root -ChildPath 'Tests\Common.ps1')

# Backup the user's configuration before we begin, and ensure we're at a pure state before running
# the tests.  We'll restore it at the end.
$configFile = New-TemporaryFile

try
{
    Backup-GitHubConfiguration -Path $configFile
    Reset-GitHubConfiguration
    Set-GitHubConfiguration -DisableTelemetry # We don't want UT's to impact telemetry
    Set-GitHubConfiguration -LogRequestBody # Make it easier to debug UT failures

    $repo = New-GitHubRepository -RepositoryName ([Guid]::NewGuid().Guid) -AutoInit
    $issue = New-GitHubIssue -Uri $repo.svn_url -Title "Test issue"

    Describe 'Getting a valid assignee' {

        Context 'For getting a valid assignee' {
            $assigneeList = @(Get-GitHubAssignee -Uri $repo.svn_url)

            It 'Should have returned the one assignee' {
                $assigneeList.Count | Should be 1
            }

            $assigneeUserName = $assigneeList[0].login

            It 'Should have returned an assignee with a login'{
                $assigneeUserName | Should not be $null
            }

            $hasPermission = Test-GitHubAssignee -Uri $repo.svn_url -Assignee $assigneeUserName

            It 'Should have returned an assignee with permission to be assigned to an issue'{
                $hasPermission | Should be $true
            }

        }
    }

    Describe 'Adding and removing an assignee to an issue'{

        Context 'For adding an assignee to an issue'{
            $assigneeList = @(Get-GitHubAssignee -Uri $repo.svn_url)
            $assigneeUserName = $assigneeList[0].login
            $assignees = @($assigneeUserName)
            New-GithubAssignee -Uri $repo.svn_url -Issue $issue.number -Assignee $assignees
            $issue = Get-GitHubIssue -Uri $repo.svn_url -Issue $issue.number

            It 'Should have assigned the user to the issue' {
                $issue.assignee.login | Should be $assigneeUserName
            }

            Remove-GithubAssignee -Uri $repo.svn_url -Issue $issue.number -Assignee $assignees
            $issue = Get-GitHubIssue -Uri $repo.svn_url -Issue $issue.number

            It 'Should have removed the user from issue' {
                $issue.assignees.Count | Should be 0
            }
        }
    }

    Remove-GitHubRepository -Uri $repo.svn_url
}
finally
{
    # Restore the user's configuration to its pre-test state
    Restore-GitHubConfiguration -Path $configFile
}
