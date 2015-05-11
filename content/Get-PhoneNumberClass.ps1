<#
.SYNOPSIS
	Classifies phone numbers based on the gold/silver/bronze classifications

.PARAMETER Number
	A phone number (digits only) to test

.PARAMETER Details
	Returns detailed results for a single Number instead of just the class

.PARAMETER Slow
	Uses the alternate method of of classifying numbers that's slower. This is for demonstration and shouldn't ever normally be used

.PARAMETER Pipeline
    An array of phone numbers to test

.EXAMPLE
    Get-PhoneNumberClass.ps1 7005551212
    Figure out what the class is for a given number (7005551212 in this case)
    This returns just the class of the specified number

.EXAMPLE
    Get-PhoneNumberClass.ps1 7005551212 -Details
    Figure out what the class is for a given number (7005551212 in this case)
    This returns an object with the Number, Class and Reason for classification

.EXAMPLE
    Get-ListOfPhoneNumbers | Get-PhoneNumberClass.ps1
    Classifies all numbers returned by the Get-ListOfPhoneNumbers command
    Returns an object for each of the numbers with the Number, Class and Reason for classification

.NOTES
	Version 1.0.0 (2015-05-08)
	Written by Paul Vaillant
    Classifications come from @StaleHansen from his #msignite presenatation

.LINK
	http://paul.vaillant.ca/help/Get-PhoneNumberClass.html
#>
[CmdletBinding()]
param(
	[Parameter(Mandatory=$true, ParameterSetName="cli", Position=0)][long]$Number,
    [Parameter(ParameterSetName="cli")][switch]$Details,
    [Parameter(ParameterSetName="pipeline", ValueFromPipeline = $true)][long[]]$Pipeline,
    [Parameter(Mandatory=$true, ParameterSetName="test")][switch]$Test,
    [Parameter(ParameterSetName="test")][int][ValidateRange(1,1000000)]$RunSize = 100,
    [Parameter()][switch]$Slow
)

BEGIN {
    # the only thing we do in begin is setup the regex rules we'll use below
    $CLASSES = @{
        Gold = @{
            doubleTriple = "(\d)\1(\d)\2{2}$";
            doubleDouble0 = "(\d)\1(\d)\2{1}0$";
            triple0 = "(\d)\1{2}0$";
            same4 = "(\d)\1{3}$";
            sequential4 = "(?:0(?=1)|1(?=2)|2(?=3)|3(?=4)|4(?=5)|5(?=6)|6(?=7)|7(?=8)|8(?=9)|9(?=0)){3}\d$"
        };
        Silver = @{
            double0 = "(\d)\1{1}0$";
            bond = "007$";
            twoDigitPattern = "(\d{2})\1$"
        };
        Bronze = @{
            double = "(\d)\1$";
            endsIn0 = "0$"
        }
    }

    $GOLD_RE = @()
    $GOLD_REASONS = @()
    $CLASSES["Gold"].GetEnumerator() | foreach {
        $GOLD_RE += $_.Value
        $GOLD_REASONS += $_.Key
    }

    $SILVER_RE = @()
    $SILVER_REASONS = @()
    $CLASSES["Silver"].GetEnumerator() | foreach {
        $SILVER_RE += $_.Value
        $SILVER_REASONS += $_.Key
    }

    $BRONZE_RE = @()
    $BRONZE_REASONS = @()
    $CLASSES["Bronze"].GetEnumerator() | foreach {
        $BRONZE_RE += $_.Value
        $BRONZE_REASONS += $_.Key
    }

    # this is an example of how to combine all the regex together into one and
    # still make it readable using white space, commenting and capture group names
    # SEE https://msdn.microsoft.com/en-us/library/yd1hzczs.aspx#Whitespace
    # because it's all combined, if you want to add to this regex you'll need to
    # make sure you update the \# placeholders as necessary
    $CLASS_RE = "(?x)
    (?:
        (?<Gold_doubleTriple>(\d)\1(\d)\2{2})
        |
        (?<Gold_doubleDouble0>(\d)\3(\d)\4 0)
        |
        (?<Gold_triple0>(\d)\5{2}0)
        |
        (?<Gold_same4>(\d)\6{3})
        |
        (?<Gold_sequential4>(?:0(?=1)|1(?=2)|2(?=3)|3(?=4)|4(?=5)|5(?=6)|6(?=7)|7(?=8)|8(?=9)|9(?=0)){3}\d)
        |
        (?<Silver_double0>(\d)\7 0)
        |
        (?<Silver_bond>007)
        |
        (?<Silver_twoDigitPattern>(\d{2})\8)
        |
        (?<Bronze_double>(\d)\9)
        |
        (?<Bronze_endsIn0>0)
    )$"

    function ClassifySlowOptimized($number) {
        Write-Verbose "Classifying $number (slow optimized)"
        $class = ""
        $reason = ""
        for($i = 0; $i -lt $GOLD_RE.Length; $i++) {
            if($number -match $GOLD_RE[$i]) {
                $class = "Gold"
                $reason = $GOLD_REASONS[$i]
                break
            }
        }
        if(!$class) {
            for($i = 0; $i -lt $SILVER_RE.Length; $i++) {
                if($number -match $SILVER_RE[$i]) {
                    $class = "Silver"
                    $reason = $SILVER_REASONS[$i]
                    break
                }
            }
        }
        if(!$class) {
            for($i = 0; $i -lt $BRONZE_RE.Length; $i++) {
                if($number -match $BRONZE_RE[$i]) {
                    $class = "Bronze"
                    $reason = $BRONZE_REASONS[$i]
                    break
                }
            }
        }
        if(!$class) {
            $class = "Ordinary"
        }
        @{Number = $number; Class = $class; Reason = $reason}
    }

    function ClassifySlow($number) {
        Write-Verbose "Classifying $number (slow)"
        $class = "Ordinary"
        $reason = ""
        foreach($c in @("Gold","Silver","Bronze")) {
            $CLASSES[$c].GetEnumerator() | foreach {
                if($number -match $_.Value) {
                    $class = $c
                    $reason = $_.Key
                    break
                }
            }
        }
        @{Number = $number; Class = $class; Reason = $reason}
    }

    function ClassifyFast($number) {
        Write-Verbose "Classifying $number (fast)"
        $class = "Ordinary"
        $reason = ""
        if($number -match $CLASS_RE) {
            $class,$reason = $($matches.Keys | ? { $_ -notmatch "^[0-9]+$" }) -split '_'
        }
        @{Number = $number; Class = $class; Reason = $reason}
    }

    # we could do this another way, by having a function called Classify
    # that checked the $Slow parameter each time, but in the case of
    # a large number of piped values that would be dont once for each
    # value instead of how it's done below which is once per script call
    if($Script:Slow) {
        new-alias -Scope script -Name Classify -Value ClassifySlowOptimized
    } else {
        new-alias -Scope script -Name Classify -Value ClassifyFast
    }
}

PROCESS {
    if($PSCmdlet.ParameterSetName -eq "test")
    {
        # generate test numbers
        $numbers = 0..$RunSize | %{ Get-Random -Minimum 1991000000 -Maximum 9999999999 }

        Measure-Command { foreach($n in $numbers) { ClassifyFast $n | out-null } } |
            select @{n='Name';e={'Fast'}},TotalMilliseconds

        Measure-Command { foreach($n in $numbers) { ClassifySlow $n | out-null } } |
            select @{n='Name';e={'Slow'}},TotalMilliseconds

        Measure-Command { foreach($n in $numbers) { ClassifySlowOptimized $n | out-null } } |
            select @{n='Name';e={'Slow Optimized'}},TotalMilliseconds
    }
    elseif($PSCmdlet.ParameterSetName -eq "pipeline")
    {
        Write-Verbose "Classifying values from pipeline"
        foreach($n in $Pipeline) {
            Classify $n
        }
    }
    else
    {
        Write-Verbose "Classifying value from cli"
        $c = Classify $Number
        if($Details) {
            $c
        } else {
            $c.Class
        }
    }
}
