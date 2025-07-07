# Module
Import-Module syntax-highlighting

# Alias
Set-Alias lg lazygit
Set-Alias cl clear
Set-Alias cat bat
Remove-Alias ls -Force -ErrorAction SilentlyContinue

$env:XDG_CONFIG_HOME = "$HOME/.config"
$env:FZF_DEFAULT_COMMAND = "rg --files . 2> nul"

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
function IsVirtualTerminalProcessingEnabled
{
    $MethodDefinitions = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
'@
    $kernel32 = Add-Type -MemberDefinition $MethodDefinitions -Name 'Kernel32' -Namespace 'Win32' -PassThru
    $hConsoleHandle = $kernel32::GetStdHandle(-11) # STD_OUTPUT_HANDLE
    $mode = 0
    $kernel32::GetConsoleMode($hConsoleHandle, [ref]$mode) >$null

    if ($mode -band 0x0004)
    { # 0x0004 ENABLE_VIRTUAL_TERMINAL_PROCESSING
        return $true
    }

    return $false
}

if ((! [System.Console]::IsOutputRedirected) -and (IsVirtualTerminalProcessingEnabled))
{
    Set-PSReadLineOption -PredictionViewStyle ListView -PredictionSource History -HistoryNoDuplicates
}

Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadlineKeyHandler -Key Ctrl+u -Function RevertLine
Set-PSReadlineKeyHandler -Chord Ctrl+j -Function NextSuggestion
Set-PSReadlineKeyHandler -Chord Ctrl+k -Function PreviousSuggestion

function Invoke-Starship-PreCommand
{
    $loc = $executionContext.SessionState.Path.CurrentLocation;
    $prompt = "$([char]27)]9;12$([char]7)"

    if ($loc.Provider.Name -eq "FileSystem")
    {
        $prompt += "$([char]27)]9;9;`"$($loc.ProviderPath)`"$([char]27)\"
    }

    $host.ui.Write($prompt)
}

function Optimize-Assemblies
{
    param (
        [string]$AssemblyFilter = "Microsoft.PowerShell.*",
        [string]$Activity = "Native Image Installation"
    )

    $originalPath = $env:Path

    # Find all ngen.exe instances
    $ngenExecutables = Get-ChildItem -Path "$Env:SystemRoot\Microsoft.NET" -Recurse -Filter "ngen.exe" -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName -Unique

    try
    {
        # Set path for dependency resolution
        $env:Path = [Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()

        # Filter loaded assemblies
        $filteredAssemblies = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.Location -and $_.FullName -ilike "$AssemblyFilter*" }

        if ($filteredAssemblies.Count -eq 0)
        {
            Write-Host "No matching assemblies found for optimization." -ForegroundColor Yellow
            return
        }

        foreach ($assembly in $filteredAssemblies)
        {
            $assemblyPath = $assembly.Location
            $assemblyName = [System.IO.Path]::GetFileName($assemblyPath)

            Write-Progress -Activity $Activity -Status "Optimizing $assemblyName"

            foreach ($ngenPath in $ngenExecutables)
            {
                try
                {
                    Start-Process -FilePath $ngenPath -ArgumentList "install `"$assemblyPath`"" -Wait -WindowStyle Hidden
                } catch
                {
                    Write-Warning "Failed to NGEN $assemblyName with $ngenPath"
                }
            }
        }

        foreach ($ngenPath in $ngenExecutables)
        {
            try
            {
                Start-Process -FilePath $ngenPath -ArgumentList "ExecuteQueuedItems" -Wait -WindowStyle Hidden
            } catch
            {
                Write-Warning "Failed to execute queued items in $ngenPath"
            }
        }

        Write-Host "Optimization complete." -ForegroundColor Green
    } catch
    {
        Write-Error "An error occurred: $_"
    } finally
    {
        $env:Path = $originalPath
    }
}
