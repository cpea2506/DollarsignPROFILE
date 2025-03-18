# Module
Import-Module syntax-highlighting

# Alias
Set-Alias lg lazygit
Set-Alias cl clear
Set-Alias cat bat
Remove-Alias ls -Force -ErrorAction SilentlyContinue

$env:XDG_CONFIG_HOME = "$HOME/.config"

Function ls
{ 
    eza -a --icons --group-directories-first $args
}
Function ll
{ 
    ls -lha --git 
}
Function tree
{
    ls --tree --level=2 
}
function gcl
{
    git clone --recursive $args
}
function gp
{
    git pull $args
}

# Invoke
Invoke-Expression (&starship init powershell)
Invoke-Expression (&{(zoxide init powershell --cmd cd | Out-String)})

# Autocompletion
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadlineKeyHandler -Key Ctrl+u -Function RevertLine
Set-PSReadlineKeyHandler -Chord Ctrl+j -Function NextSuggestion
Set-PSReadlineKeyHandler -Chord Ctrl+k -Function PreviousSuggestion

function Invoke-Starship-PreCommand {
  $loc = $executionContext.SessionState.Path.CurrentLocation;
  $prompt = "$([char]27)]9;12$([char]7)"

  if ($loc.Provider.Name -eq "FileSystem")
  {
    $prompt += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
  }

  $host.ui.Write($prompt)
}

function Optimize-Assemblies {
    param (
        [string]$assemblyFilter,
        [string]$activity = "Native Image Installation"
    )

    $is64 = Get-WmiObject -Query "SELECT * FROM Win32_ComputerSystem" | ForEach-Object { $_.SystemType -match "x64" }

    try {
        $architecture = if ($is64) { "64" } else { "" }
        $ngenPath = "$($env:windir)\Microsoft.NET\Framework$($architecture)\v4.0.30319\ngen.exe"

        # Get a list of loaded assemblies
        $assemblies = [AppDomain]::CurrentDomain.GetAssemblies()

        # Filter assemblies based on the provided filter
        $filteredAssemblies = $assemblies | Where-Object { $_.FullName -ilike "$assemblyFilter*" }

        if ($filteredAssemblies.Count -eq 0) {
            Write-Host "No matching assemblies found for optimization."
            return
        }

        foreach ($assembly in $filteredAssemblies) {
            # Get the name of the assembly
            $name = [System.IO.Path]::GetFileName($assembly.Location)

            # Display progress
            Write-Progress -Activity $activity -Status "Optimizing $name"

            # Use Ngen to install the assembly
            Start-Process -FilePath $ngenPath -ArgumentList "install `"$($assembly.Location)`"" -Wait -WindowStyle Hidden
        }

        Write-Host "Optimization complete."
    } catch {
        Write-Host "An error occurred: $_"
    }
}
