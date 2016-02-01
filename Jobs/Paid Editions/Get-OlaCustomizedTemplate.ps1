<#
.Synopsis
   In an array of strings, replace !!var!! by the contents of $var
.DESCRIPTION
   Based on a input template consisting in a an array of strings, replace all occurences of !!var!! by the contents of $var or write a warning in verbose mode.
.EXAMPLE
  $foo="bar"; @("this is a test","foo is !!foo!!")
.INPUTS
    [String[]]
.OUTPUTS
   [String[]]
.NOTES
   Use of !! has been chosen because in many languages such as SQL, $var creates confusion with built-in structures
.FUNCTIONALITY
   For each line Replace any !!variablename!! by its contents if it exists, or issues a warning
#>
Function Get-OlaCustomizedTemplate {

Process {
 [RegEx]::replace($_,'!!([\w]+)!!',{param($Match) $v=$Match.Groups[1].Value; if (Test-Path Variable:$($v)) { Get-Variable $v -ValueOnly } else { Write-Verbose "$v does'nt exist but is used"; "!!$v!!" } } ) 
}

}

<#
.Synopsis
   Process a directory full of OLa related templates
.DESCRIPTION
   Takes a directory where files named ola-*-template.sql are; for each file do variable substitution and create the associated ola-*.sql file in the output directory
.EXAMPLE
   New-OlaCustomizedScripts -Inpath '.\Templates' -OutPath 'C:\temp'
.INPUTS
   String[]
.OUTPUTS
   String[]
#>
Function New-OlaCustomizedScripts {
param(
[string]$InPath,
[string]$OutPath
)

Get-ChildItem -Path $InPath  -filter 'ola-*-template.sql' | `% {
  $TargetName = $_ -replace '-template', ''
  if ($OutPath) {
   $TargetName = Join-Path $OutPath $TargetName
  } else {
   $TargetName = Join-Path $InPath $TargetName
  }

  Get-Content $_.FullName | Get-OlaCustomizedTemplate | Set-Content $TargetName -Force

}

}