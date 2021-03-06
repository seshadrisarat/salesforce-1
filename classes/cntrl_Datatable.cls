public  class cntrl_Datatable {
    
    public class ResultWrapper {
        
        @AuraEnabled
        public list<SObject> lstSObject;
        @AuraEnabled
        public list<wrapFields> lstFields;
        @AuraEnabled
        public String baseURL;
        
        public ResultWrapper(list<SObject> lstSObject, list<wrapFields> lstFields,String baseURL) {
            
            this.lstSObject = lstSObject;
            this.lstFields  = lstFields;
            this.baseURL = baseURL;
        }
    }
    public class wrapFields
    {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public String type;
        @AuraEnabled
        public Boolean isRef;
        @AuraEnabled
        public String lkupRelAPI;
        @AuraEnabled
        public String lkupRelName;
        @AuraEnabled
        public String invalidField;
        
        public wrapFields(String fieldName,
                         String label,
                         String type,
                         Boolean isRef,
                         String lkupRelAPI,
                         String lkupRelName,
                         String invalidField
                        )
        {
            this.fieldName = fieldName;
            this.label = label;
            this.type = type;
            this.isRef = isRef;
            this.lkupRelAPI = lkupRelAPI;
            this.lkupRelName = lkupRelName;
            this.invalidField = invalidField;
        }
    }
    
    @AuraEnabled
    public static boolean deleteRecord(ID recId) {
        try {
            Database.delete(recId);
            return true;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
  
    @AuraEnabled
    public static ResultWrapper loadData(String objectAPIName, String lstFields, String filterCriteria, Boolean isRelatedList, String RelatedListFieldAPI, String recID) {
        
        String errMsg = '';
        Schema.DescribeSObjectResult result = Schema.getGlobalDescribe().get(objectAPIName).getDescribe();
        //object level access
        if(!result.isAccessible()){
            errMsg = 'Insufficient Privileges';
            throw new AuraHandledException( errMsg );
        }
        map<String, String> customlabel = new map<String, String>();
        String[] flds = lstFields.split(',');
      	wrapFields[] lstWrapfields = getFldMap(flds, objectAPIName);
          
        String[] RelFields = new String[]{};
           
        String strQuery = '';
        set<String> uniqueFields = new set<String>();
        for(wrapFields fld : lstWrapfields){
            uniqueFields.add(fld.fieldName.toLowerCase());
            if(String.isNotBlank(fld.lkupRelName)){
                uniqueFields.add(fld.lkupRelName.toLowerCase());
            }
        }
        list<String> queryFields = new list<String>();
        queryFields.addAll(uniqueFields);
        strQuery = String.join(queryFields, ',');
        
        String finalQuery = 'SELECT '+strQuery+' FROM '+objectAPIName;
        
        if(String.isNotBlank(filterCriteria)){
            finalQuery += ' WHERE '+filterCriteria;
        }
        if(isRelatedList && String.isNotBlank(RelatedListFieldAPI) && String.isNotBlank(recID)){
            System.debug('isRelatedList--->'+isRelatedList);
            finalQuery += finalQuery.contains('WHERE') ? ' AND '+RelatedListFieldAPI+ ' =\''+recID+'\'' : ' WHERE '+RelatedListFieldAPI + ' =\''+recID+'\'';
        }
        finalQuery += ' LIMIT 1000';
        //System.debug('final---> '+finalQuery);
        list<sObject> records = Database.query(finalQuery);
        String baseURL = URL.getSalesforceBaseUrl().toExternalForm();
        return new ResultWrapper(records, lstWrapfields, baseURL);
    }
    
    private static wrapFields[] getFldMap(String[] flds, String objName) {
        Map<String, Schema.SObjectType> gdMap = Schema.getGlobalDescribe();
        Schema.Describesobjectresult rootObj = gdMap.get(objName).getDescribe();
        Map<String, Schema.SObjectField> rootFldMap = rootObj.fields.getMap();
        String strInvalidField = '';
        wrapFields[] fldMap = new wrapFields[]{};
        
        
        for(String key1 : flds) {
            String customLabel = key1.substringBetween('(',')');
            String key = key1.substringBefore('(').toLowerCase();
            key = rootFldMap.containsKey(key) ? rootFldMap.get(key).getDescribe().getName() : key; 
            String[] tempArry = key.split('\\.');
            
            if(tempArry.size() > 1) {
                Integer lstSize = tempArry.size();
                String finalFld = tempArry[lstSize-1].toLowerCase(); 
                
                Schema.Describesobjectresult finalObj;
                Schema.DescribeFieldResult finalFldRes;
                
                String[] actLabelArry = new String[]{};
                    String actLabel = '';
                
                if(lstSize > 2) {
                    for(Integer i=0;i<=lstSize-2;i++) {
                        String tempFld = tempArry[i].toLowerCase();
                        
                        if(tempFld.endsWith('__r')) {
                            tempFld = tempFld.removeEnd('__r') + '__c';
                        }
                        else {
                            tempFld += 'Id';
                        }
                        
                        strInvalidField = tempFld;
                        if(rootFldMap.containsKey(tempFld) || finalObj.fields.getMap().containsKey(tempFld)) {
                            strInvalidField = '';
                            if(i == 0) {
                                Schema.DescribeFieldResult dfr = rootFldMap.get(tempFld).getDescribe();
                                Schema.sObjectType[] refs = dfr.getReferenceTo();
                                
                                finalObj = refs[0].getDescribe();
                                actLabelArry.add(dfr.getLabel());
                            }
                            else {
                                Schema.DescribeFieldResult dfr = finalObj.fields.getMap().get(tempFld).getDescribe();
                                Schema.sObjectType[] refs = dfr.getReferenceTo();
                                
                                finalObj = refs[0].getDescribe();
                                actLabelArry.add(dfr.getLabel());
                            }
                        }
                    }
                    actLabel = String.join(actLabelArry,' > ');
                }
                else {
                    String tempFld = tempArry[0].toLowerCase();
                    
                    if(tempFld.endsWith('__r')) {
                        tempFld = tempFld.removeEnd('__r') + '__c';
                    }
                    else {
                        tempFld += 'Id';
                    }
                    strInvalidField = tempFld;
                    if(rootFldMap.containsKey(tempFld)) {
                        strInvalidField = '';
                        Schema.DescribeFieldResult dfr = rootFldMap.get(tempFld).getDescribe();
                        Schema.sObjectType[] refs = dfr.getReferenceTo();
                        
                        finalObj = refs[0].getDescribe();
                    }
                }
                
                Map<String, Schema.SObjectField> fieldMapTemp = finalObj.fields.getMap();
                
                strInvalidField = finalFld;
                if(fieldMapTemp.containsKey(finalFld)) {
                    strInvalidField = '';
                    Schema.DescribeFieldResult dfrTemp = fieldMapTemp.get(finalFld).getDescribe();
                    
                    actLabel += ((actLabel != '')?('.' + dfrTemp.getLabel()):(dfrTemp.getLabel()));
                    
                    String fldType = String.valueOf(dfrTemp.getType());
                    if(String.isNotBlank(customLabel)){
                        actLabel = customLabel;
                    }
                    fldMap.add(createFldMap(key, actLabel, dfrTemp,strInvalidField));
                }
                else {
                    String strlabel = '';
                    if(String.isNotBlank(customLabel)){
                        strlabel = customLabel;
                    }
                    fldMap.add(createFldMap(key,strlabel,null,strInvalidField)); 
                }
            }
            else {
                strInvalidField = key;
                if(rootFldMap.containsKey(key)) {
                    Schema.DescribeFieldResult dfr = rootFldMap.get(key).getDescribe();
                    // field level access permission
                    if(dfr.isAccessible()) {
                        strInvalidField = '';
                        String strlabel = dfr.getLabel();
                        if(String.isNotBlank(customLabel)){
                            strlabel = customLabel;
                        }
                        fldMap.add(createFldMap(key,strlabel,dfr,strInvalidField));
                    }
                }
                else {
                    String strlabel = '';
                    if(String.isNotBlank(customLabel)){
                        strlabel = customLabel;
                    }
                    fldMap.add(createFldMap(key,strlabel,null,strInvalidField)); 
                }
            }
        }
        return fldMap;
    }
    
    private static wrapFields createFldMap(String apiName, String lbl, Schema.DescribeFieldResult dfr, String strInvalidField) {
        if(dfr != null) {
            String fldType = String.valueOf(dfr.getType());
            String lkupRelName = '';
            String lkupRelApiName = apiName;
            Boolean isRef;
            Integer decimalPlaceLngth = dfr.getScale();
            
            if(fldType == 'REFERENCE') {
                String[] tempArry = apiName.split('\\.');
                
                String[] relNameArry = new String[]{};
                    
                    if(tempArry.size()>2) {
                        for(Integer i=0;i<=tempArry.size()-2;i++) {
                            relNameArry.add(tempArry[i]);
                        }
                        
                        lkupRelName = String.join(relNameArry,'.')+'.'+dfr.getRelationshipName()+'.Name';
                    }
                else if(tempArry.size()==2) {
                    lkupRelName = tempArry[0]+'.'+dfr.getRelationshipName()+'.Name';
                }
                else {
                    lkupRelName = dfr.getRelationshipName()+'.Name';
                }
                isRef = true;
                
                // Id or Name should link to the record being displayed in the table
            } 
            else if(apiName == 'Id') {
                lkupRelName = apiName;
                isRef = true;
            } 
            else if(apiName == 'Name') {
                lkupRelName = apiName;
                lkupRelApiName = 'Id';
                isRef = true;
            } 
            else {
                isRef = false;
            }
            return new wrapFields(apiName,lbl,fldType,isRef,lkupRelApiName,lkupRelName,strInvalidField);
        }
        else {
            return new wrapFields(apiName,'','',false,'','',strInvalidField);            
        }
    }

    @AuraEnabled
    public static String searchRecords_cntrl(String objectAPIName,String lstFields,String RelatedListFieldAPI,Boolean isRelatedList,String recID,String searchKeyword){
        String SPACE = ' ';
        String SOQL;
        String WhereCOndition = 'WHERE'+SPACE+RelatedListFieldAPI+SPACE+'!='+SPACE+'\''+recID+'\'';
        String str_keywork = '\''+searchKeyword+'*\'';
        SOQL ='FIND'+SPACE+str_keywork+SPACE+'IN ALL FIELDS RETURNING'+SPACE+objectAPIName+SPACE+'('+SPACE+lstFields+SPACE+WhereCOndition+')'; 
        System.debug('SOQL' +SOQL);
        List<List<SObject>> searchList = search.query(SOQL);
        System.debug('searchList' +searchList);
        return JSON.serialize(searchList);
    }
}