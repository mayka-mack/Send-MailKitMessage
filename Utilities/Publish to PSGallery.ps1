

####################################
# Author:       Eric Austin
# Create date:  May 2021
# Description:  Publish Send-MailKitMessage to the PowerShell Gallery
####################################

#versioning is not particularly simple (https://docs.microsoft.com/en-us/dotnet/standard/library-guidance/versioning)
# Listed in documentation           | What I see
# --------------------------------- | ----------
# PSGallery module manifest version | PSGallery module manifest version
# Not referenced                    | .csproj "Version" / "Product Version" in Windows Explorer; does not affect runtime
# Assembly version                  | .csproj "AssemblyVersion"; not shown in Windows Explorer; does affect runtime
# Assembly file version             | .csproj "FileVersion"; shown in Windows Explorer; does not affect runtime
# Assembly informational version    | Ignore

Try {

    #common variables
    $CurrentDirectory=[string]::IsNullOrWhiteSpace($PSScriptRoot) ? (Get-Location).Path : $PSScriptRoot;
    $ErrorActionPreference = "Stop";
    
    #project elements
    $ModuleName = "Send-MailKitMessage";
    $ManifestName = "Send-MailKitMessage.psd1";
    $CSProjFileName = "Send-MailKitMessage.csproj";
    $ProjectCSProjFilePath = Join-Path -Path $CurrentDirectory -ChildPath ".." -AdditionalChildPath "Project", $CSProjFileName;
    $ProjectReleaseDirectory = Join-Path -Path $CurrentDirectory -ChildPath ".." -AdditionalChildPath "Project, bin, Release, netstandard2.0";

    #published module elements
    $PublishedModuleDownloadDirectory = Join-Path -Path $CurrentDirectory -ChildPath "Published module";
    $PublishedModuleDirectory = [string]::Empty;
    $PublishedManifest = [hashtable]::new();
    $PublishedCSProjFile = [xml]::new();

    #updated module version values
    $UpdatedManifestVersion = [string]::Empty;
    $UpdatedManifestPrereleaseString = [string]::Empty;
    $UpdatedCSProjVersion = [string]::Empty;
    $UpdatedCSProjAssemblyVersion = [string]::Empty;
    $UpdatedCSProjFileVersion = [string]::Empty;

    #script elements
    $DefaultProgressPreferenceValue = "Continue";
    $ValuesConfirmed = [string]::Empty;

    #--------------#

    Write-Host ""
    Write-Host "Downloading latest module published to the PowerShell Gallery...";

    #clear out the published module download directory if it exists
    if (Test-Path -Path $PublishedModuleDownloadDirectory)
    {
        foreach ($File in (Get-ChildItem -Path $PublishedModuleDownloadDirectory))
        {
            Remove-Item -Path $File."FullName" -Recurse -Force;
        }
    }
    else    #create the directory if it does not already exist
    {
        New-Item -ItemType Directory -Path $PublishedModuleDownloadDirectory | Out-Null;
    }

    #download the module from the PowerShell gallery ("Find-Module returns the newest version of a module if no parameters are used that limit the version" - https://learn.microsoft.com/en-us/powershell/module/powershellget/find-module?view=powershell-7.3")
    $ProgressPreference = "SilentlyContinue";
    Find-Module -Repository "PSGallery" -Name $ModuleName -AllowPrerelease | Save-Module -Path $PublishedModuleDownloadDirectory;
    $ProgressPreference = $DefaultProgressPreferenceValue;

    #throw an exception if the module is not present
    if ((Get-ChildItem -Path $PublishedModuleDownloadDirectory | Measure-Object | Select-Object -Property "Count" -ExpandProperty "Count") -eq 0)
    {
        Throw "The downloaded module could not be found";
    }

    #get the published module directory (the use of Get-ChildItem is due to Save-Module saving the downloaded module using the module version without preview suffixes as the directory name)
    $PublishedModuleDirectory = Get-ChildItem -Path (Join-Path $PublishedModuleDownloadDirectory -ChildPath $ModuleName) | Select-Object -Property "FullName" -ExpandProperty "FullName";

    #get the published module manifest data
    $PublishedManifest = Import-PowerShellDataFile -Path (Join-Path -Path $PublishedModuleDirectory -ChildPath $ManifestName);

    #get the published csproj file data
    $PublishedCSProjFile = [xml](Get-Content -Raw -Path (Join-Path -Path $PublishedModuleDirectory -ChildPath $CSProjFileName));
    
    #display the current versions
    Write-Host "The published module manifest version is $($PublishedManifest."ModuleVersion" + ([string]::IsNullOrWhiteSpace($PublishedManifest."PrivateData"."PSData"."Prerelease") ? [string]::Empty : ($PublishedManifest."PrivateData"."PSData"."Prerelease".Contains("-") ? [string]::Empty : "-") + $PublishedManifest."PrivateData"."PSData"."Prerelease"))";
    Write-Host "The published csproj version is $($PublishedCSProjFile."Project"."PropertyGroup"."Version")";
    Write-Host "The published csproj assembly version is $($PublishedCSProjFile."Project"."PropertyGroup"."AssemblyVersion")";
    Write-Host "The published csproj file version is $($PublishedCSProjFile."Project"."PropertyGroup"."FileVersion")";
    
    #prompt for new values
    Do {

        #updated manifest version
        Do {
            Write-Host "";
            Write-Host "First: the module manifest version (the version the PSGallery uses)";
            Write-Host "Versioning is MAJOR.MINOR.PATCH";
            Write-Host "MAJOR version when you make incompatible API changes";
            Write-Host "MINOR version when you add functionality in a backwards compatible manner";
            Write-Host "PATCH version when you make backwards compatible bug fixes";
            Write-Host "The published module manifest version is $($PublishedManifest."ModuleVersion")";
            $UpdatedManifestVersion = (Read-Host "Enter new module version (the prerelease value, if applicable, will be obtained next)");
        }
        Until (-not ([string]::IsNullOrWhiteSpace($UpdatedManifestVersion)));
        
        #manifest prerelease string (dash is not required https://docs.microsoft.com/en-us/powershell/scripting/gallery/concepts/module-prerelease-support?view=powershell-7.1)
        Write-Host "";
        Write-Host "Second, the prerelease value (if applicable; gets appended on to the module manifest version)";
        if ([string]::IsNullOrWhiteSpace($PublishedManifest."PrivateData"."PSData"."Prerelease"))
        {
            Write-Host "The published module manifest does not have a prerelease value";

        }
        else
        {
            Write-Host "The published module prerelease value is `"$($PublishedManifest."PrivateData"."PSData"."Prerelease")`"";
        }
        $UpdatedManifestPrereleaseString = (Read-Host "Enter the new prerelease value, ie `"preview1`" (no dash) (if no prerelease value is applicable just hit Enter)");
        
        #updated csproj version (shows as "Product Version" when viewing the file properties in Windows Explorer; does not affect runtime; just set to the same value as the $UpdatedManifestVersion and include the prerelease value if applicable)
        Write-Host "";
        Write-Host "The csproj version (doesn't affect anything; shows as `"Product Version`" when viewing the file properties in Windows Explorer) has no conventions and will be set to the same value as the updated module manifest version";
        Write-Host "The published csproj version is $($PublishedCSProjFile."Project"."PropertyGroup"."Version")";
        $UpdatedCSProjVersion = $UpdatedManifestVersion + ([string]::IsNullOrWhiteSpace($UpdatedManifestPrereleaseString) ? [string]::Empty : ($UpdatedManifestPrereleaseString.Contains("-") ? [string]::Empty : "-") + $UpdatedManifestPrereleaseString);
        Write-Host "The updated csproj version will be $UpdatedCSProjVersion";

        #updated csproj assembly version
        Write-Host "";
        Write-Host "The csproj assembly version (affects the runtime; does not get shown in Windows Explorer) should be set to the MAJOR version of the updated module manifest version";
        Write-Host "The published csproj assembly version is $($PublishedCSProjFile."Project"."PropertyGroup"."AssemblyVersion")";
        $UpdatedCSProjAssemblyVersion = $UpdatedManifestVersion.Substring(0, ($UpdatedManifestVersion).IndexOf(".")) + ".0.0";
        Write-Host "The updated csproj assembly version will be $UpdatedCSProjAssemblyVersion";

        #updated file version
        Write-Host "";
        Write-Host "The csproj file version (doesn't affect anything; shows as `"File Version`" when viewing the file properties in Windows Explorer) should be set to MAJOR.MINOR.BUILD.REVISION";
        Write-Host "The published csproj file version is $($PublishedCSProjFile."Project"."PropertyGroup"."FileVersion")";
        [int]$Revision = ($PublishedCSProjFile."Project"."PropertyGroup"."FileVersion").Substring($PublishedCSProjFile."Project"."PropertyGroup"."FileVersion".LastIndexOf(".") + 1);
        $Revision++;
        $UpdatedCSProjFileVersion = $UpdatedManifestVersion + "." + $Revision.ToString();
        Write-Host "The updated csproj file version will be $UpdatedCSProjFileVersion";
        
        Write-Host "";
        Write-Host "The new module manifest version will be $($UpdatedManifestVersion + ([string]::IsNullOrWhiteSpace($UpdatedManifestPrereleaseString) ? [string]::Empty : ($UpdatedManifestPrereleaseString.Contains("-") ? [string]::Empty : "-") + $UpdatedManifestPrereleaseString))";
        Write-Host "The new csproj version will be $UpdatedCSProjVersion";
        Write-Host "The new csproj assembly version will be $UpdatedCSProjAssemblyVersion";
        Write-Host "The new csproj file version will be $UpdatedCSProjFileVersion";

        Write-Host "";
        $ValuesConfirmed = (Read-Host "Proceed with publishing? (`"y`" to proceed, `"n`" to re-enter values)");

    }
    Until ($ValuesConfirmed -eq "y");

    #update the .csproj file
    Write-Host "Updating the .csproj file...";
    $CSProjFile = [xml](Get-Content -Raw -Path $ProjectCSProjFilePath);
    $CSProjFile."Project"."PropertyGroup"."Version" = $UpdatedCSProjVersion;
    $CSProjFile."Project"."PropertyGroup"."AssemblyVersion" = $UpdatedCSProjAssemblyVersion;
    $CSProjFile."Project"."PropertyGroup"."FileVersion" = $UpdatedCSProjFileVersion;
    $CSProjFile.Save($ProjectCSProjFilePath);

    #run dotnet publish
    Write-Host "Building the project...";
    dotnet publish $ProjectCSProjFilePath --configuration "Release" --output $PublishDirectory /p:Version=$UpdatedCSProjVersion /p:AssemblyVersion=$UpdatedCSProjAssemblyVersion /p:FileVersion=$UpdatedCSProjFileVersion;

    #copy the published manifest to the Release directory
    Copy-Item -Path (Join-Path -Path $PublishedModuleDirectory -ChildPath $ManifestName) -Destination $ProjectReleaseDirectory;

    #update the manifest in the Release directory (note that the module manifest update process ensures all required assemblies are present)
    Write-Host "Updating the module manifest...";
    Update-ModuleManifest -Path (Join-Path -Path $ProjectReleaseDirectory -ChildPath $ManifestName) -ModuleVersion $UpdatedManifestVersion -Prerelease $UpdatedManifestPrereleaseString;

    #publish the module
    #Write-Host "Publishing module to the PSGallery...";
    #Publish-Module -Path $PublishDirectory -Repository PSGallery -NuGetApiKey $env:PowerShellGalleryAPIKey;

    Write-Host "Success";

}
Catch {
    Throw $Error[0];
}
Finally {
    #clean up published module download
    foreach ($File in (Get-ChildItem -Path $PublishedModuleDownloadDirectory))
    {
        Remove-Item -Path $File."FullName" -Recurse -Force;
    }

    #reset the progress preference variable
    $ProgressPreference = $DefaultProgressPreferenceValue;
}
