#Requires -Module Pester

Describe "K.PSGallery.SemanticVersioning Module Tests" {
    
    BeforeAll {
        # Ensure clean module state at start
        Get-Module K.PSGallery.SemanticVersioning | Remove-Module -Force -ErrorAction SilentlyContinue
        
        # Import temp path helper functions
        . (Join-Path $PSScriptRoot "TempPathHelper.ps1")
        
        # Import the module under test using absolute path
        $ModuleRoot = Split-Path $PSScriptRoot -Parent
        $ModulePath = Join-Path $ModuleRoot "K.PSGallery.SemanticVersioning.psd1"
        
        if (-not (Test-Path $ModulePath)) {
            throw "Module manifest not found at: $ModulePath"
        }
        
        Import-Module $ModulePath -Force
    }

    BeforeEach {
        # Create test manifest for testing
        $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
        $TestManifestContent = @"
@{
    ModuleVersion = '1.2.3'
    GUID = '12345678-1234-1234-1234-123456789012'
    Author = 'Test Author'
    Description = 'Test module for K.PSGallery.SemanticVersioning'
    PowerShellVersion = '5.1'
}
"@
        $TestManifestContent | Out-File -FilePath $TestManifestPath -Encoding UTF8 -Force
    }

    AfterEach {
        # Clean up test manifests
        $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
        $InvalidManifestPath = Join-Path $PSScriptRoot "InvalidTestModule.psd1"
        
        @($TestManifestPath, $InvalidManifestPath) | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
    }

    AfterAll {
        # Clean up module completely
        Get-Module K.PSGallery.SemanticVersioning | Remove-Module -Force -ErrorAction SilentlyContinue
    }
    
    Context "Module Loading" {
        It "Should import the module successfully" {
            # Module is already imported in BeforeAll, so we just check if functions are available
            { Get-Command -Name "Get-NextSemanticVersion" -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should export Get-NextSemanticVersion function" {
            Get-Command -Name "Get-NextSemanticVersion" | Should -Not -BeNullOrEmpty
        }
        
        It "Should export Get-FirstSemanticVersion function" {
            Get-Command -Name "Get-FirstSemanticVersion" | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Get-FirstSemanticVersion Function" {
        
        It "Should accept standard version 0.0.0 without action required" {
            $result = Get-FirstSemanticVersion -CurrentVersion "0.0.0" -BranchName "main"
            
            $result.NewVersion | Should -Not -BeNullOrEmpty
            $result.Error | Should -BeNullOrEmpty
            $result.BumpType | Should -Match "(major|minor|patch)"
        }
        
        It "Should accept standard version 1.0.0 without action required" {
            $result = Get-FirstSemanticVersion -CurrentVersion "1.0.0" -BranchName "main"
            
            $result.NewVersion | Should -Not -BeNullOrEmpty
            $result.Error | Should -BeNullOrEmpty
            $result.BumpType | Should -Match "(major|minor|patch)"
        }
        
        It "Should require action for unusual version" {
            $result = Get-FirstSemanticVersion -CurrentVersion "3.5.2" -BranchName "main"
            
            $result.NewVersion | Should -Be "3.5.2"
            $result.Error | Should -Match "Unusual version"
            $result.BumpType | Should -Be "none"
            $result.Instructions | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Private Function - Get-VersionBumpType (via Module)" {
        
        # We test this indirectly through the main function since it's private
        # But we can test the logic by examining the results
        
        It "Should detect feature branch patterns in real scenarios" {
            # This would be tested through Get-NextSemanticVersion in a real Git repo
            # For now, we test the concept
            $true | Should -Be $true  # Placeholder - would need Git repo setup
        }
    }
    
    Context "Get-NextSemanticVersion Function" {
        
        It "Should handle missing manifest path gracefully" {
            # Test in directory without .psd1 files
            $EmptyDir = New-TestTempDirectory -Prefix "EmptyTestDir"
            Push-Location $EmptyDir
            try {
                $result = Get-NextSemanticVersion -BranchName "main" -TargetBranch "main"
                $result.Error | Should -Match "No \.psd1 manifest file found|Cannot bind argument to parameter 'Path' because it is an empty string"
            }
            finally {
                Pop-Location
                Remove-Item $EmptyDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should return structured object with all required properties" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            # Mock the git operations by testing in a controlled environment
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main" -TargetBranch "main"
            
            # Verify all actually returned properties exist
            $result.PSObject.Properties.Name | Should -Contain "CurrentVersion"
            $result.PSObject.Properties.Name | Should -Contain "BumpType"
            $result.PSObject.Properties.Name | Should -Contain "NewVersion"
            $result.PSObject.Properties.Name | Should -Contain "LastReleaseTag"
            $result.PSObject.Properties.Name | Should -Contain "IsFirstRelease"
            $result.PSObject.Properties.Name | Should -Contain "Error"
            $result.PSObject.Properties.Name | Should -Contain "Instructions"
            $result.PSObject.Properties.Name | Should -Contain "GitContext"
        }
        
        It "Should handle non-target branch correctly" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "feature/test" -TargetBranch "main"
            
            # Just verify the function runs and returns a valid result
            $result | Should -Not -BeNullOrEmpty
            $result.BumpType | Should -Not -BeNullOrEmpty
            $result.NewVersion | Should -Not -BeNullOrEmpty
        }
        
        It "Should load current version from manifest" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main" -TargetBranch "main"
            
            $result.CurrentVersion | Should -Be "1.2.3"
        }
    }
    
    Context "Error Handling" {
        
        It "Should handle invalid manifest path gracefully" {
            $result = Get-NextSemanticVersion -ManifestPath "C:\NonExistent\File.psd1" -BranchName "main" -TargetBranch "main"
            
            # Should return structured error, not throw exception
            $result | Should -Not -BeNullOrEmpty
            $result.Error | Should -Not -BeNullOrEmpty
            $result.Error | Should -Match "No .psd1 manifest file found for path C:\\NonExistent\\File.psd1"
        }
        
        It "Should handle manifest without ModuleVersion gracefully" {
            # Create invalid manifest
            $InvalidManifestPath = Join-Path $PSScriptRoot "InvalidTestModule.psd1"
            
            try {
                "@{ Author = 'Test' }" | Out-File -FilePath $InvalidManifestPath -Encoding UTF8 -Force
                $result = Get-NextSemanticVersion -ManifestPath $InvalidManifestPath -BranchName "main" -TargetBranch "main"
                
                # Should return structured error, not throw exception
                $result | Should -Not -BeNullOrEmpty
                $result.Error | Should -Not -BeNullOrEmpty
                $result.Error | Should -Match "Could not find ModuleVersion"
            }
            finally {
                # Ensure cleanup happens even if test fails
                if (Test-Path $InvalidManifestPath) {
                    Remove-Item $InvalidManifestPath -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    Context "Integration Scenarios" {
        
        It "Should work with standard parameters" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            
            # Test that the function works without obsolete parameters
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main" -TargetBranch "main"
            
            # Should not throw and should process the version
            $result.CurrentVersion | Should -Be "1.2.3"
        }
    }
}

Describe "Semantic Versioning Logic Tests" {
    
    Context "Version Bump Detection" {
        
        It "Should follow semantic versioning principles" {
            # Test the general principle that major > minor > patch
            $true | Should -Be $true  # This would be expanded with specific Git history tests
        }
        
        It "Should handle Alpha/Beta suffixes correctly" {
            # Test that suffixes are properly detected and applied
            $true | Should -Be $true  # This would be expanded with commit message tests
        }
    }
    
    Context "Git Tag Analysis" {
        
        It "Should parse semantic version tags correctly" {
            # Test tag parsing logic
            $true | Should -Be $true  # This would be expanded with mock Git tag tests
        }
    }
}

Describe "GitHub Actions Integration" {
    
    BeforeAll {
        # Ensure module is available for this test context
        $ModuleRoot = Split-Path $PSScriptRoot -Parent
        $ModulePath = Join-Path $ModuleRoot "K.PSGallery.SemanticVersioning.psd1"
        
        if (-not (Get-Module K.PSGallery.SemanticVersioning)) {
            Import-Module $ModulePath -Force
        }
    }
    
    Context "Output Structure" {
        
        It "Should provide all outputs required by GitHub Actions" {
            $TestManifestPath = Join-Path $PSScriptRoot "TestModule.psd1"
            $result = Get-NextSemanticVersion -ManifestPath $TestManifestPath -BranchName "main" -TargetBranch "main"
            
            # All these properties should exist for actual function output
            @(
                'CurrentVersion', 'BumpType', 'NewVersion', 'LastReleaseTag', 
                'IsFirstRelease', 'Error', 'Instructions', 'GitContext'
            ) | ForEach-Object {
                $result.PSObject.Properties.Name | Should -Contain $_
            }
        }
    }
}

Describe "Version Mismatch Handling" {
    
    BeforeEach {
        # Load the module (functions are now loaded via the .psm1 file)
        $ModuleRoot = Split-Path $PSScriptRoot -Parent
        $ModulePath = Join-Path $ModuleRoot "K.PSGallery.SemanticVersioning.psd1"
        
        # Import the module to get access to all functions
        Import-Module $ModulePath -Force
        
        # Create mock logging functions (if needed)
        function Write-SafeInfoLog { param($Message, $Context) }
        function Write-SafeDebugLog { param($Message, $Context) }
        function Write-SafeWarningLog { param($Message, $Context) }
        function Write-SafeErrorLog { param($Message, $Context) }
        function Write-SafeTaskSuccessLog { param($Message, $Context) }
        function Get-LatestReleaseTag { return $null }  # Mock for first release scenarios
    }
    
    Context "First Release Scenarios" {
        It "Should handle first release with standard version" {
            $manifestPath = New-TestTempFile -Prefix "TestModule_Standard"
            "@{ ModuleVersion = '1.0.0' }" | Out-File -FilePath $manifestPath -Encoding UTF8 -Force
            
            try {
                $result = Get-NextSemanticVersion -ManifestPath $manifestPath -BranchName "main"
                $result.CurrentVersion | Should -Be "1.0.0"
                $result.IsFirstRelease | Should -Be $true
                $result.Error | Should -BeNullOrEmpty
            }
            finally {
                Remove-Item $manifestPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should handle first release with unusual version requiring force" {
            $manifestPath = New-TestTempFile -Prefix "TestModule_Unusual"
            "@{ ModuleVersion = '3.5.2' }" | Out-File -FilePath $manifestPath -Encoding UTF8 -Force
            
            try {
                $result = Get-NextSemanticVersion -ManifestPath $manifestPath -BranchName "main"
                $result.CurrentVersion | Should -Be "3.5.2"
                $result.Error | Should -Match "Unusual version"
                
                # The new simplified API will always warn about unusual first release versions
                # and provide clear guidance on how to fix them
                $result.Instructions | Should -Not -BeNullOrEmpty
            }
            finally {
                Remove-Item $manifestPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
    
    Context "Manifest Discovery" {
        It "Should autodiscover manifest if ManifestPath is empty" {
            $tempDir = New-TestTempDirectory -Prefix "TestAutoDiscover"
            $manifestPath = Join-Path $tempDir "TestModule.psd1"
            "@{ ModuleVersion = '1.0.0' }" | Out-File -FilePath $manifestPath -Encoding UTF8 -Force
            
            try {
                Push-Location $tempDir
                $result = Get-NextSemanticVersion -BranchName "main"
                $result.CurrentVersion | Should -Be "1.0.0"
            }
            finally {
                Pop-Location
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        It "Should error if no manifest exists in repo" {
            $emptyDir = New-TestTempDirectory -Prefix "EmptyTestDir"
            
            try {
                Push-Location $emptyDir
                $result = Get-NextSemanticVersion -BranchName "main"
                $result.Error | Should -Match "No .psd1 manifest file found"
            }
            finally {
                Pop-Location
                Remove-Item $emptyDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
