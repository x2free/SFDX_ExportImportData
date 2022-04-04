Set-StrictMode -Version 3.0

# row looks up to col
#       AA    AB      AC
# AA    X
# AB    X
# AC    X     X
$block = {
    $objectName2MyTableMap = @{}
    $objectSequence = $null

    $objectNames = @("AB_Object__c", "AA_Object__c", "AC_Object__c")

    $recordTypeQuery = "SELECT Id, DeveloperName FROM RecordType WHERE SobjectType IN ('"
    foreach ($obj in $objectNames) {
        $recordTypeQuery += "$obj','"
    }

    $recordTypeQuery = $recordTypeQuery.subString(0, $recordTypeQuery.length - 2)
    $recordTypeQuery += ") ORDER BY SobjectType"

    try {
        $recordTypes = sfdx force:data:soql:query -r csv -q $recordTypeQuery | ConvertFrom-Csv
    }
    catch [System.Management.Automation.RuntimeException]{
        $_.getType()
    }
    catch {
        $_.getType()
    }


    $myTables = loadMetadata -objectNames $objectNames
    $objectSequence = getProcessSequence $myTables

    Write-Host $objectSequence
}

function loadMetadata {
    param (
        $objectNames
    )


    # $objectName2MyTableMap = @{}
    foreach ($objectName in $objectNames) {
        $objectJson = sfdx force:schema:sobject:describe --json -s $objectName | ConvertFrom-Json # | Out-Null
        # {
        #     "status": 0,
        #     "result": {
        #       "actionOverrides": [],
        #       "activateable": false,
        #       "associateEntityType": null,
        #       "associateParentEntity": null,
        #       "childRelationships": [],
        #       "fields": [
        #         {
        #             "aggregatable": true,
        #             "aiPredictionField": false,
        #             "autoNumber": false,
        #             "byteLength": 18,
        #             "calculated": false,
        #             "calculatedFormula": null,
        #             "cascadeDelete": false,
        #             "caseSensitive": false,
        #             "compoundFieldName": null,
        #             "controllerName": null,
        #             "createable": true,
        #             "custom": false,
        #             "defaultValue": null,
        #             "defaultValueFormula": null,
        #             "defaultedOnCreate": true,
        #             "dependentPicklist": false,
        #             "deprecatedAndHidden": false,
        #             "digits": 0,
        #             "displayLocationInDecimal": false,
        #             "encrypted": false,
        #             "externalId": false,
        #             "extraTypeInfo": null,
        #             "filterable": true,
        #             "filteredLookupInfo": null,
        #             "formulaTreatNullNumberAsZero": false,
        #             "groupable": true,
        #             "highScaleNumber": false,
        #             "htmlFormatted": false,
        #             "idLookup": false,
        #             "inlineHelpText": null,
        #             "label": "Owner ID",
        #             "length": 18,
        #             "mask": null,
        #             "maskType": null,
        #             "name": "OwnerId",
        #             "nameField": false,
        #             "namePointing": true,
        #             "nillable": false,
        #             "permissionable": false,
        #             "picklistValues": [],
        #             "polymorphicForeignKey": true,
        #             "precision": 0,
        #             "queryByDistance": false,
        #             "referenceTargetField": null,
        #             "referenceTo": [
        #               "Group",
        #               "User"
        #             ],
        #             "relationshipName": "Owner",
        #             "relationshipOrder": null,
        #             "restrictedDelete": false,
        #             "restrictedPicklist": false,
        #             "scale": 0,
        #             "searchPrefilterable": false,
        #             "soapType": "tns:ID",
        #             "sortable": true,
        #             "type": "reference",
        #             "unique": false,
        #             "updateable": true,
        #             "writeRequiresMasterRead": false
        #           }
        #        ]
        #     }
        # }

        $curObject = $null
        if ($objectName2MyTableMap.ContainsKey($objectName)) {
            $curObject = $objectName2MyTableMap[$objectName]
        }
        else {
            $curObject = [MyTable]::new($objectName, $null)
            $objectName2MyTableMap.Add($objectName, $curObject)
        }

        # get look up fields
        foreach ($field in $objectJson.result.fields) {
            # lookup to another object
            if ("reference" -ieq $field.type) {
                foreach($refTo in $field.referenceTo) {
                    if ($objectNames.Contains($refTo)) {
                        if ($objectName -ieq $refTo) {
                            $curObject.selfLookup = $true
                            # self-lookup, do not change counter
                            continue
                        }

                        $lookupTo = $null

                        if ($objectName2MyTableMap.ContainsKey($refTo)) {
                            $lookupTo = $objectName2MyTableMap[$refTo]
                        }
                        else {
                            $lookupTo = [MyTable]::new($refTo, $null)
                            $objectName2MyTableMap.Add($refTo, $lookupTo)
                        }

                        $curObject.AddReference($field.name, $lookupTo)
                    }
                }
            }
            elseif ($field.externalId -and $field.unique) {
                # external Id
                $curObject.primaryKey = $field.name
            }
        }
    }

    return $objectName2MyTableMap.values
}

function getProcessSequence {
    param (
        $myTables
    )

    # Name                           Value
    # ----                           -----
    # AA_Object__c                   AA_Object__c -  => refer to: 0, be refered: 2, self lookup: True
    # AB_Object__c                   AB_Object__c -  => refer to: 1, be refered: 1, self lookup: False
    # AC_Object__c                   AC_Object__c -  => refer to: 2, be refered: 0, self lookup: False

    $objectWithSequence = New-Object System.Collections.Generic.List[string]
    $queue = New-Object System.Collections.Queue

    # foreach ($key in $myTables) {
    #     # if (0 -eq $myTables[$key].referCount) {
    #     #     $queue.Enqueue($key)
    #     # }
    # }
    foreach ($item in $myTables) {
        if (0 -eq $item.referCount) {
            $queue.Enqueue($item.tableName)
        }
    }

    while (0 -ne $queue.Count) {
        $objName = $queue.Dequeue()
        foreach($object in $objectName2MyTableMap[$objName].references) {
            $object.referCount --

            if (0 -eq $object.referCount) {
                $queue.Enqueue($object.tableName)
            }
        }
        $objectWithSequence.add($objName)
    }

    # Write-Host $objectWithSequence

    # $objectWithSequence.Reverse
    $objectWithSequence.Reverse()
    return $objectWithSequence
}


class MyTable {
    [string] $tableName
    [string] $primaryKey
    [bool] $selfLookup
    # [int] $referToCount
    [int] $referCount

    [System.Collections.Generic.List[MyTable]]$references
    [System.Collections.Generic.List[ReferenceField]]$lookupFields

    MyTable([string]$tableName, [string]$externalIdField = $null) {
        $this.tableName = $tableName
        $this.references = New-Object System.Collections.Generic.List[MyTable]
        $this.lookupFields = New-Object System.Collections.Generic.List[ReferenceField]
        # $this.referToCount = 0
        $this.referCount = 0
        $this.selfLookup = $false

        if ($null -eq $externalIdField) {
            $this.primaryKey = "Id"
        }
        else {
            $this.primaryKey = $externalIdField
        }
    }

    [System.Collections.Generic.List[MyTable]]AddReference([string]$fieldName, [MyTable]$table) {
        # $this.referToCount ++
        $table.referCount ++
        $field = [ReferenceField]::new($fieldName, $table.tableName)
        $this.lookupFields.add($field)
        $this.references.Add($table)

        return $this.references
    }

    [string]ToString() {
        return ("{0} - {1} => refer count: {2}, self lookup: {3}" -f $this.tableName, $this.primaryKey, $this.referCount, $this.selfLookup)
    }
}

class ReferenceField {
    [string]$fieldName
    [string]$tableName
    ReferenceField ([string]$field, [string]$table) {
        $this.fieldName = $field
        $this.tableName = $table
    }
}


& $block