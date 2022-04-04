# $currentDir = Get-Location
# $dataFileDir = "$currentDir\Data"

# default org to work
$defaultOrgName = $null

$objectNames = @("AA_Object__c", "AB_Object__c", "AC_Object__c")

$configJson = sfdx config:get defaultusername --json | ConvertFrom-Json
$configJsonPath = $configJson[0].result.path
$projDir = $configJsonPath.SubString(0, $configJsonPath.indexOf(".sfdx") - 1)

if ($defaultOrgName -eq $null) {
    $defaultOrgName = $configJson[0].result.value
}

$dataFileDir = "$projDir\Data"
if (-not(Test-Path -Path $dataFileDir)) {
    Write-Host "Creating folder $dataFileDir..."
    New-Item -Path $projDir -Name "Data" -ItemType "directory" | Out-Null
}

$recordTypeCsvFile = "$dataFileDir\RecordType.csv"
$aaCsvFile = "$dataFileDir\AA_Object__c.csv"
$abCsvFile = "$dataFileDir\AB_Object__c.csv"
$acCsvFile = "$dataFileDir\AC_Object__c.csv"


########### queries ############
$recordTypeQueryStr = "SELECT Id, DeveloperName FROM RecordType WHERE SobjectType IN ('"
foreach($obj in $objectNames) {
    $recordTypeQueryStr += "$obj','"
}

$recordTypeQueryStr = $recordTypeQueryStr.subString(0, $recordTypeQueryStr.length - 2)
$recordTypeQueryStr += ") ORDER BY SobjectType"

$aaQueryStr = "SELECT Id, RecordTypeId, Type__c, Desc__c, AA_Object__c FROM AA_Object__c"
$abQueryStr = "SELECT Id, Name, AA_Object__c FROM AB_Object__c"
$acQueryStr = "SELECT Id, Name, AA_Object__c, AB_Object__c FROM AC_Object__c"

# not work since double quotes are missing
# sfdx force:data:soql:query -r csv -q $aaQueryStr | Out-File $aaCsvFile
# sfdx force:data:soql:query -r csv -q $abQueryStr | Out-File $abCsvFile
# sfdx force:data:soql:query -r csv -q $acQueryStr | Out-File $acCsvFile

Write-Host "Exporting data..."

Write-Host "Record Types"
sfdx force:data:soql:query -r csv -q $recordTypeQueryStr -u $defaultOrgName | ConvertFrom-Csv | Export-Csv -NoTypeInformation -Path $recordTypeCsvFile
Write-Host "AA Objects"
sfdx force:data:soql:query -r csv -q $aaQueryStr -u $defaultOrgName | ConvertFrom-Csv | Export-Csv -NoTypeInformation -Path $aaCsvFile
Write-Host "AB Objects"
sfdx force:data:soql:query -r csv -q $abQueryStr -u $defaultOrgName | ConvertFrom-Csv | Export-Csv -NoTypeInformation -Path $abCsvFile
Write-Host "AC Objects"
sfdx force:data:soql:query -r csv -q $acQueryStr -u $defaultOrgName | ConvertFrom-Csv | Export-Csv -NoTypeInformation -Path $acCsvFile