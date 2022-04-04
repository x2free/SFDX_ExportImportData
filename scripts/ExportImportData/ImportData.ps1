#
# import csv, and get the result, then build a map from old record ids to new ids. It's better to save this map into local file so that may use it for next release
# then iterate related files to update reference based on above map, and save to a temp worksapce
# finally, import the csvs from temp worksapce

$configJson = sfdx config:get defaultusername --json | ConvertFrom-Json
$configJsonPath = $configJson[0].result.path
$projDir = $configJsonPath.SubString(0, $configJsonPath.indexOf(".sfdx") - 1)
$dataFileDir = "$projDir\Data"


$processBlock = {


}

function BuildFieldIdMap {
    param ([Parameter(Mandatory,ValueFromPipeline)]$csv, $from, $to)
    process {
        $key2RecordMap = @{}
        $records = $csv #| ConvertFrom-Csv

        foreach ($record in $records) {
            if ($null -eq $record.$from) {
                continue
            }
            $key2RecordMap.Add($record.$from, $record.$to)
        }

        return $key2RecordMap
    }
}

function upsertRecords {
    param (
        $type, $csvPath, $extId, $isClone = $false
    )
    process {
        # if $isClone is true, clear Ids
        if ($isClone -eq $true) {
            $records = Import-Csv -Path $csvPath
            foreach ($record in $records) {
                $record.Id = $null
            }

            $tmpFile = New-TemporaryFile
            $csvPath = $tmpFile.FullName
            # $randomNum = Get-Random
            # $csvPath = "$($ENV:Temp)\sf-data\$randomNum.csv"

            $records | Export-Csv -Path $csvPath -NoTypeInformation
        }

        # $upsertResult = sfdx force:data:bulk:upsert -s $type -f $csvPath -i $extId

        # Write-Host $upsertResult
        # # Check batch #1â€™s status with the command:
        # # sfdx force:data:bulk:status -i 7500t000005MUrxAAG -b 7510t000006VpIWAA0

        # $jobResult = Invoke-Expression -Command $upsertResult[1].ToString()
        # # === Batch Status
        # # jobId:                   7500t000005MUrxAAG
        # # state:                   Completed
        # # createdDate:             2022-03-20T14:37:54.000Z
        # # systemModstamp:          2022-03-20T14:37:54.000Z
        # # numberRecordsProcessed:  26
        # # numberRecordsFailed:     26
        # # totalProcessingTime:     255
        # # apiActiveProcessingTime: 18
        # # apexProcessingTime:      0

        # $jobStatus = $jobResult | Where-Object {$_.startsWith("state")}

        # while (-not $jobStatus.endsWith("Completed")) {
        #     Start-Sleep -Seconds 10
        #     $jobStatus = Invoke-Expression -Command $upsertResult[1] | Where-Object {$_.startsWith("state")}
        # }

        ################# get batch job result #########################
        $apexResult = sfdx force:apex:execute -f .\getBatchJobResult.cls

        $newRecords = New-Object System.Collections.Generic.List[System.String]
        $isRecordFound = $false
        foreach ($line in $apexResult) {
            if ($line.endsWith("Result - Start -:")) {
                $isRecordFound = $true
                continue
            }

            if ($isRecordFound -eq $false) {
                continue
            }

            if ($line.endsWith("Result - End -")) {
                break
            }

            $newRecords.add($line)
        }
        ################# get batch job result #########################

        if ($isClone) {
            Remove-Item -Force -Path $csvPath
        }

        $queryStr = "SELECT Id, $extId FROM $type WHERE $ExtId IN "
        $queryResult = sfdx force:data:soql:query -r csv -q $queryStr | Import-Csv

        return BuildFieldIdMap -csv $queryResult -from $extId -to "Id"
    }
}

function updateReference {
    param (
        $csv,
        $extIdField,
        $oldRecId2ExtIdMap,
        $extId2NewRecIdMap
    )
    process {
        foreach ($record in $csv) {
            if ($null -eq $record.$extIdField) {
                continue
            }
            $record.$extIdField = $extId2NewRecIdMap[$oldRecId2ExtIdMap[$record.Id]]
        }
    }
}

& $processBlock