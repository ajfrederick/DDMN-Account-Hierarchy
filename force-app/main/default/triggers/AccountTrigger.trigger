trigger AccountTrigger on Account (after insert, after update, before update) {


    if( Trigger.isBefore && Trigger.isUpdate ) {
        //wv6_AccountHierarchyHandler.buildHierarchy(trigger.new, trigger.oldMap);
        AccountHierarchyHandler.buildHierarchy( Trigger.oldMap, Trigger.newMap );
    }


    if(trigger.isAfter) {
 
        string TriggerName = 'AccountTrigger';
        //system.debug('****** EXECUTE TRIGGER:' + TriggerCheckController.RunTrigger(TriggerName));
        
        system.debug('**** AccountTrigger Size:' + trigger.size);
        
        RecordType NonPooledRecType = [Select id, Name, DeveloperName From RecordType Where SobjectType = 'Account' And DeveloperName = 'Non_Pooled'];
        
        set<id> AcctIds = new set<id>();
        
        if(!TriggerCheckController.RunTrigger(TriggerName)){
            
            system.debug('*** TRIGGER IS DISABLED IN CUSTOM SETTINGS');
        
        }else{
            
            if(trigger.isInsert){
                
                system.debug('*** BEGIN TRIGGER INSERT ***');
                
                //CHECK IF THE Create Contract CHECKBOX IS SELECTED ON THE ACCOUNT RECORD
                for(Account acct : trigger.new){
                    
                    //ONLY CHECK IF ACCOUNT RECORDTYPE IS NON-POOLED
                    if( acct.RecordTypeId == NonPooledRecType.Id && 
                        acct.Status__c == 'Active' && 
                        acct.Account_level__c != 'Group'
                    ){
                        if(acct.Contract_Start_date__c != null && acct.Contract_End_date__c != null){
                            AcctIds.add(acct.Id);
                        }
                    }
                }
                
                if(!AcctIds.isEmpty()){
                    AccountController.CreateNewContracts(AcctIds);  
                }
                
            }// END isInsert
            else if(trigger.isUpdate){
                
                system.debug('**** BEGIN TRIGGER UPDATE ****');
                
                map<id, Account> mapOldAccts = new map<id, Account>();
                map<id, Account> mapNewAccts = new map<id, Account>();
                
                for(Account acc : trigger.new){
                //ONLY CHECK IF ACCOUNT RECORDTYPE IS NON-POOLED
                    if( acc.RecordTypeId == NonPooledRecType.Id && 
                        acc.Status__c == 'Active' &&
                        acc.Account_level__c != 'Group'
                    ){
                    
                        if(acc.Contract_Start_date__c != null && acc.Contract_End_date__c != null){
                            
                            //CHECK IF Execute All Triggers IS ACTIVE FOR DOING A MASS UPDATE
                            //ADD ALL ACCOUNTS TO MAP
                            if(TriggerCheckController.ENABLE_ALL_TRIGGERS == true){
                                
                                system.debug('**** ADDING ALL ACCOUNTS TO UPDATE MAP');
                                    AcctIds.add(acc.Id);
                                    mapNewAccts.put(acc.Id, trigger.newMap.get(acc.Id));
                                    mapOldAccts.put(acc.Id, trigger.oldMap.get(acc.Id));
                        
                            }else{                      
                                    
                                    if(
                                        acc.Contract_Start_date__c != trigger.oldMap.get(acc.Id).Contract_Start_date__c ||
                                        acc.Contract_End_date__c != trigger.oldMap.get(acc.Id).Contract_End_date__c ||
                                        acc.Renewal_lead_days__c != trigger.oldMap.get(acc.Id).Renewal_lead_days__c
                                    ){
                                        system.debug('**** ADDING ACCOUNT ' + acc.Name + ' TO UPDATE MAP');
                                        AcctIds.add(acc.Id);
                                        mapNewAccts.put(acc.Id, trigger.newMap.get(acc.Id));
                                        mapOldAccts.put(acc.Id, trigger.oldMap.get(acc.Id));
                                    }       
                            }
                            
                        }   //END CHECK IF DATES ARE NULL   
                        
                    }   //END CHECK FOR RECORDTYPE
                            
                }   //END TRIGGER.NEW LOOP
                
                system.debug('**** # OF ACCOUNTS TO UPDATE:' + AcctIds.size()); 
                if(!AcctIds.isEmpty()){
                    AccountController.UpdateContracts(mapNewAccts, mapOldAccts);    
                }           
            }   //END isUpdate
            
        }
        
    }   //END Else OF TRIGGER DISABLED CHECK     
    
    if(trigger.isAfter && !AccountTotalEnrollRollup.isaccounttotalinrollup && !AccountTotalEnrollRollup.isAsynchronousApex() && !AccountTotalEnrollRollup.isIntegrationUser()) {
         Set<Id> accIds = Trigger.newMap.keySet();
        AccountTotalEnrollRollup.setcountTotalEnrollRollUpASC(accIds);
    }
        
}