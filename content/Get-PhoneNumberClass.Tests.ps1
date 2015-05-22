# run this test file using Invoke-Pester

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
$cmd = "$here\$sut"

Describe "Get-PhoneNumberClass" {
    $TestCases = @(
        @{Number = 7000011222; Class = "Gold"; Reason = "doubleTriple"},
        @{Number = 7000033440; Class = "Gold"; Reason = "doubleDouble0"},
        @{Number = 7000005555; Class = "Gold"; Reason = "same4"},
        @{Number = 7000006660; Class = "Gold"; Reason = "triple0"},
        @{Number = 7000007890; Class = "Gold"; Reason = "sequential4"},
        @{Number = 7005242110; Class = "Silver"; Reason = "double0"},
        @{Number = 7005242007; Class = "Silver"; Reason = "bond"},
        @{Number = 7005223434; Class = "Silver"; Reason = "twoDigitPattern"},
        @{Number = 7005224511; Class = "Bronze"; Reason = "double"},
        @{Number = 7005242390; Class = "Bronze"; Reason = "endsIn0"},
        @{Number = 7002398201; Class = "Ordinary"; Reason = ""}
    )

    Context "When numbers are passed by the command line" {
        It "identifies <Number> as <Class>" -TestCases $TestCases {
            param($Number, $Class, $Reason)

            $c = & $cmd -Number $Number
            $c | Should Be $Class
        }
    }

    Context "When numbers are passed by the command line with Slow" {
        It "identifies <Number> as <Class>" -TestCases $TestCases {
            param($Number, $Class, $Reason)

            $c = & $cmd -Number $Number -Slow
            $c | Should Be $Class
        }
    }

    Context "When numbers are passed by the command line with Details" {
        It "identifies <Number> as <Class> because of <Reason>" -TestCases $TestCases {
            param($Number, $Class, $Reason)

            $c = & $cmd -Number $Number -Details
            $c.Number | Should Be $Number
            $c.Class | Should Be $Class
            $c.Reason | Should Be $Reason
        }
    }

    Context "When numbers are passed by the command line with Details and Slow" {
        It "identifies <Number> as <Class> because of <Reason>" -TestCases $TestCases {
            param($Number, $Class, $Reason)

            $c = & $cmd -Number $Number -Details -Slow
            $c.Number | Should Be $Number
            $c.Class | Should Be $Class
            $c.Reason | Should Be $Reason
        }
    }

    Context "When numbers are passed by the pipeline" {
        It "identifies <Number> as <Class> because of <Reason>" -TestCases $TestCases {
            param($Number, $Class, $Reason)

            $c = $Number | & $cmd
            $c.Number | Should Be $Number
            $c.Class | Should Be $Class
            $c.Reason | Should Be $Reason
        }

        It "identifies all numbers in the pipeline" {
            $results = $TestCases | %{ $_.Number } | & $cmd
            foreach($t in $TestCases) {
                $r = $results | ? Number -eq $t.Number
                #$r | Should Exist
                $r.Number | Should Be $t.Number
                $r.Class  | Should Be $t.Class
                $r.Reason | Should Be $t.Reason
            }
        }
    }

    Context "When numbers are passed by the pipeline with Slow" {
        It "identifies <Number> as <Class> because of <Reason>" -TestCases $TestCases {
            param($Number, $Class, $Reason)

            $c = $Number | & $cmd -Slow
            $c.Number | Should Be $Number
            $c.Class | Should Be $Class
            $c.Reason | Should Be $Reason
        }

        It "identifies all numbers in the pipeline" {
            $results = $TestCases | %{ $_.Number } | & $cmd -Slow
            foreach($t in $TestCases) {
                $r = $results | ? Number -eq $t.Number
                #$r | Should Exist
                $r.Number | Should Be $t.Number
                $r.Class  | Should Be $t.Class
                $r.Reason | Should Be $t.Reason
            }
        }
    }

    Context "When a performance test is specified" {
        $ExpectedAlgorithms = @("Fast", "Slow")
        It "returns a list of algorithms and their total milliseconds" {
            [array]$results = & $cmd -Test
            $results.Length | Should Be $ExpectedAlgorithms.Length
            foreach($algo in $ExpectedAlgorithms) {
                $r = $results | where Name -eq $algo
                # in the latest Pester this is the same as
                # $r | Should Exist
                $r | Should Not Be $null
                $r.TotalMilliseconds | Should Match "^\d+\.\d+$"
            }
        }
    }
}
