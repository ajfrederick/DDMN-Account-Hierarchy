public with sharing class AccountController {

  public static boolean HasRun = false;
  //static Id AcctRecTypeId;

//----------------------------------------------------------------------------------------
  static void DeleteTasks(set<id> OppIds){
    
    system.debug('**** IN DeleteTasks');
    
    list<Task> tasks = new list<Task>();
    
    system.debug('*** OppIds:' + OppIds);
    
    if(!OppIds.isEmpty()){
      tasks = [Select Id From Task Where WhatId IN:OppIds];
      
      system.debug('*** TASKS FROM OPP IDS:' + tasks);
      
      //CHECK TO CLOSE THE TASK INSTEAD OF DELETING
      
      if(!tasks.isEmpty()){
        system.debug('***** DELETING TASKS');
        try{
          delete tasks;  
        }catch(system.exception e){
          system.debug('** ERROR DELETING TASKS:' + e.getMessage());
        }
        
      }  
    }
    
  }
//----------------------------------------------------------------------------------------
  /*
  static void ClearAccountContractFlag(set<id> AccountIds){

    //CLEAR THE Create Contract FLAG IF IT WAS SET ON THE ACCOUNT
    
    list<Account> Accounts = new list<Account>(
        [Select Id, CreateContract__c From Account Where Id IN:AccountIds]
      );
    
    if(!Accounts.isEmpty()){
      
      for(Account a : Accounts){
        if(a.CreateContract__c == true){
          a.CreateContract__c = false;  
        }
      }
      
      update Accounts;
      
    }
  }
  */
//----------------------------------------------------------------------------------------
  static RecordType GetAutoOppRecordType(){
    
    //GET THE RECORDTYPE ON THE OPPORTUNITY FOR "Existing group (non-pooled)"
    RecordType OppRecType = [Select Id, Name, DeveloperName, sObjectType 
                From RecordType 
                Where sObjectType = 'Opportunity' 
                And DeveloperName = 'Existing_Business'
                Limit 1
                ];
                
    return OppRecType;
                  
  }
//----------------------------------------------------------------------------------------
  static RecordType GetNonPooledRecType(){
    
    //GET THE RECORDTYPE ON THE OPPORTUNITY FOR "Existing group (non-pooled)"
    RecordType AcctRecType = [Select Id, Name, DeveloperName, sObjectType 
                From RecordType 
                Where sObjectType = 'Account' 
                And DeveloperName = 'Non_Pooled'
                Limit 1
                ];
                
    return AcctRecType;
    
  }
//----------------------------------------------------------------------------------------
  static RecordType GetRenewalTaskRecType(){
    
    //GET THE RECORDTYPE ON THE OPPORTUNITY FOR "Existing group (non-pooled)"
    RecordType TaskRecType = [Select Id, Name, DeveloperName, sObjectType 
                From RecordType 
                Where sObjectType = 'Task' 
                And DeveloperName = 'Delta_Dental_MN'
                Limit 1
                ];
                
    return TaskRecType;
    
  }
//----------------------------------------------------------------------------------------
  public static void CreateNewContracts(set<id> AccountIds){
    
    system.debug('***** IN CreateNewContracts CONTROLLER ****');
    
    list<Account> Accounts = new list<Account>();
    list<Opportunity> OppsToCreate = new list<Opportunity>();
    
    date StartDate;
    date EndDate;
    date ContractStartDate;
    date ContractEndDate;
  
    integer ContractDays = 0;
    integer ContractMonths = 0;
    integer ContractYear = 0;
    integer NumberOfYears = 0; 
    
    map<id, Account> mapAccts = new map<id, Account>();    

    RecordType ExistBusiRecType = GetAutoOppRecordType(); 
                  
    if(!AccountIds.isEmpty()){
      
      Accounts = [Select Id, Name, OwnerId, RecordTypeId, Contract_Start_Date__c, Contract_End_Date__c, 
                Contract_Length__c, Renewal_lead_days__c
            From Account
            Where Id IN: AccountIds];
      
    }
    
    if(!Accounts.isEmpty()){
      
      for(Account a : Accounts){
        
        StartDate = a.Contract_Start_Date__c;
        EndDate = a.Contract_End_Date__c;
        
        //CHECK TO MAKE SURE THERE IS A START DATE AND END DATE
        if(StartDate != null && EndDate != null){
          
          ContractDays = StartDate.daysBetween(EndDate);
          ContractMonths = StartDate.monthsBetween(EndDate);
          
          if (EndDate.day() > StartDate.day()){
             ContractMonths++;
          }
          
          system.debug('**** ContractMonths On INSERT:' + ContractMonths);
          
          NumberOfYears = ContractMonths / 12;
          
          system.debug('*****  StartDate:' + StartDate);
          system.debug('*****  EndDate:' + EndDate);
          system.debug('*****  ContractMonths:' + ContractMonths);
          system.debug('*****  NumberOfYears:' + NumberOfYears);
          
          for(integer x = 1; x <= NumberOfYears; x++){
            
            ContractStartDate = StartDate.addYears(x);
            ContractEndDate = ContractStartDate.addYears(1) - 1;
            ContractYear = ContractEndDate.year();
            
            system.debug('****  ContractStartDate:' + ContractStartDate);
            system.debug('****  ContractEndDate:' + ContractEndDate);
            system.debug('****  ContractYear:' + ContractYear);
            
            Opportunity opp = new Opportunity();
            
            //IF THIS IS THE LAST OPP IN THE LOOP THEN SET IT TO RENEWAL
            if(x == NumberOfYears){
              opp.Type = 'Renewal';
            }else{
              opp.Type =   'Mid-Contract';
            }
            
            //try{
              opp.RecordTypeId = ExistBusiRecType.Id;
            //}catch(system.exception e){
            //  system.debug('**** RECORDTYPE DOES NOT EXIST');
            //}
            
            opp.Name = a.Name + ' ' + opp.Type + ' ' + string.valueOf(ContractStartDate.year());
            opp.StageName = 'Upcoming Renewal';
            opp.OwnerId = a.OwnerId;
            opp.AccountId = a.Id;
            opp.CloseDate = ContractStartDate;
            
            opp.AutoCreated__c = true;
            
            OppsToCreate.add(opp);
            
          }  // END OF FOR LOOP
          
        }
        
      }
      
    }
    
    if(!OppsToCreate.isEmpty()){
      
      //try{
        insert OppsToCreate;  
      //}catch(system.exception e){
       //    system.debug('*** ERROR CREATING OPPS:' + e.getMessage());
      //}
      
    }
    
    //CLEAR THE CREATE CONTRACT FLAG
    //if(!Accounts.isEmpty()){
    //  ClearAccountContractFlag(AccountIds);
    //}
    
    //CREATE TASKS
    CreateRenewalTasks(Accounts, OppsToCreate);
    
  }
//----------------------------------------------------------------------------------------
  public static void UpdateContracts(map<id, Account> NewAcctMap, map<id, Account> OldAcctMap){
    
    system.debug('***** IN UpdateContracts CONTROLLER ****');
    
    date OldStartDate;
    date OldEndDate;
    date StartDate;
    date EndDate;  
    date ContractStartDate;
    date ContractEndDate;
    integer NumberOfYears = 0; 
    integer ContractMonths = 0;
    integer ContractYear = 0;
    integer ContractDays = 0;
    set<id> OppTaskIds = new set<id>();
    
    list<Opportunity> ExistingOpps = new list<Opportunity>();
    list<Opportunity> ContractOpps = new list<Opportunity>();
    Map<Id, Opportunity> ContractOppsUpdates = new Map<Id, Opportunity>(); 
    list<Opportunity> ContractOppsInserts = new list<Opportunity>();
    
    list<Opportunity> OppsToDelete = new list<Opportunity>();
    //set<id> OppIdsToDelete = new set<id>();
      
    map<id, list<Opportunity>> mapAcctOpps = new map<id, list<Opportunity>>();
    
    RecordType OppRecType = GetAutoOppRecordType();
                        
    //ORDERED BY CLOSE DATE SO IT IS SORTED CORRECTLY LATER WHEN LOOPING
    ExistingOpps = [Select Id, Name, CloseDate, Type, AccountId, StageName
            ,Account.Name, Account.OwnerId  //Added 10/21/14 
                  From Opportunity
                  Where AccountId IN: NewAcctMap.keyset()
                    //And AutoCreated__c = true
                    And RecordTypeId =: OppRecType.Id  //Existing group (non-pooled)
                    And (Type = 'Renewal' OR Type = 'Mid-contract')
                  Order by CloseDate asc
                  ];
    
    system.debug('**** ExistingOpps SIZE:' + ExistingOpps.size());
    
    //THERE ARE NO EXISTING OPPS FOR THE ACCOUNT
    if(ExistingOpps.isEmpty()){
        system.debug('*** CREATING NEW OPPS FROM UPDATE');
        CreateNewContracts(NewAcctMap.keySet());
    }else{
    
      //LOOPS THROUGH THE OPPS AND CREATES SEPARATE MAP LISTS PER ACCOUNTID
      for(Opportunity o : ExistingOpps){
                      
        if(mapAcctOpps.containsKey(o.AccountId)){
          mapAcctOpps.get(o.AccountId).add(o);
        }else{
          mapAcctOpps.put(o.AccountId, new list<Opportunity>{o});
        }
      }
            
      //LOOP THROUGH EACH LIST OF OPPS FOR EACH ACCOUNTID
      for(Id AcctId : mapAcctOpps.keySet()){
        
        //GET THE CURRENT ACCOUNT RECORD
        Account currentAccount = newAcctMap.get(AcctId);
        
        OldStartDate = oldAcctMap.get(AcctId).Contract_Start_Date__c;
        OldEndDate = oldAcctMap.get(AcctId).Contract_End_Date__c;
        StartDate = currentAccount.Contract_Start_Date__c;
        EndDate = currentAccount.Contract_End_Date__c;
        ContractDays = StartDate.daysBetween(EndDate);
        ContractMonths = StartDate.monthsBetween(EndDate);
          
        if(EndDate.day() > StartDate.day()){
           ContractMonths++;
        }
          
        NumberOfYears = ContractMonths / 12;
        
        system.debug('*****  ContractMonths On UPDATE:' + ContractMonths);
        system.debug('*****  Old Acct StartDate:' + OldStartDate);
        system.debug('*****  Old Acct EndDate:' + OldEndDate);
        system.debug('*****  Updated Acct StartDate:' + StartDate);
        system.debug('*****  Updated Acct EndDate:' + EndDate);
        system.debug('*****  Updated ContractMonths:' + ContractMonths);
        system.debug('*****  Updated NumberOfYears:' + NumberOfYears);
        
        //MAKE SURE THERE IS A START DATE AND END DATE
        if(StartDate != null && EndDate != null){
          
          map<date, Opportunity> mapOppClosed = new map<date, Opportunity>();

          //CHECK IF THE CONTRACT DATES CHANGED
          //if(StartDate != OldStartDate || EndDate != OldEndDate){
          
            //LOOP THROUGH EACH OPP IN EACH LIST OF OPPS AND LINK THE CLOSE DATE TO OPP RECORD                  
            for(Opportunity opp : mapAcctOpps.get(AcctId)){
              mapOppClosed.put(opp.CloseDate, opp);
            }  
            
            system.debug('**** mapOppClosed:' + mapOppClosed);
            
            //LOOP THROUGH THE # OF YEARS TO CREATE THE CONTRACT
            for(integer x = 1; x <= NumberOfYears; x++){
              
              ContractStartDate = StartDate.addYears(x);
              ContractEndDate = ContractStartDate.addYears(1) - 1;
              ContractYear = ContractEndDate.year();
            
              system.debug('****  UPDATED ContractStartDate:' + ContractStartDate);
              system.debug('****  UPDATED ContractEndDate:' + ContractEndDate);
              system.debug('****  UPDATED ContractYear:' + ContractYear);
              
              // CHECK IF THERE IS AN EXISTING OPP WITH THE START DATE MATCHING THE OPP CLOSE DATE
              // IF THERE IS AN EXISTING OPP WITH A MATCHING CLOSE DATE
              // CHECK IF IT SHOULD BE A RENEWAL OR MID-CONTRACT
              if(mapOppClosed.get(ContractStartDate) != null){
                
                Opportunity ExistingOpp = mapOppClosed.get(ContractStartDate);
                
                system.debug('***** UPDATING EXISTING OPP:' + ExistingOpp);
                
                //IF THIS IS THE LAST OPP IN THE LOOP THEN SET IT TO RENEWAL
                if(x == NumberOfYears){
                  ExistingOpp.Type = 'Renewal';
                }else{
                  ExistingOpp.Type =   'Mid-Contract';
                }
                
                //10/21/14 - ADDED TO CHANGE THE OPP NAME BASED ON THE OppType
                ExistingOpp.Name = currentAccount.Name + ' ' + ExistingOpp.Type + ' ' + string.valueOf(ContractStartDate.year());
                
                ContractOpps.add(ExistingOpp);
                ContractOppsUpdates.put(ExistingOpp.Id, ExistingOpp);
                
                //OppTaskIds.add(ExistingOpp.Id);
                
              }else{
                
                system.debug('***** CREATING NEW OPP FOR DATE CHANGE');
                Opportunity opp = new Opportunity();  
                
                //IF THIS IS THE LAST OPP IN THE LOOP THEN SET IT TO RENEWAL
                if(x == NumberOfYears){
                  opp.Type = 'Renewal';
                }else{
                  opp.Type =   'Mid-Contract';
                }
              
                opp.RecordTypeId = OppRecType.Id;
                opp.Name = currentAccount.Name + ' ' + opp.Type + ' ' + string.valueOf(ContractStartDate.year());
                opp.StageName = 'Upcoming Renewal';
                opp.OwnerId = currentAccount.OwnerId;
                opp.AccountId = currentAccount.Id;
                opp.CloseDate = ContractStartDate;
                opp.AutoCreated__c = true;
                ContractOpps.add(opp);
                ContractOppsInserts.add(opp);
        
              }
            
            }  //END FOR LOOP
            


            if(!ContractOppsUpdates.isEmpty()){          
              update ContractOppsUpdates.values();
            }

            if(!ContractOppsInserts.isEmpty()){
              upsert ContractOppsInserts;
            }
            
            // CHECK IF THERE ARE ANY OPPS THAT ARE PAST THE CONTRACT END DATE 
            // THAT NEED TO BE DELETED
            for(Opportunity o : mapAcctOpps.get(AcctId)){
              if(o.CloseDate > EndDate.addYears(1)){
                OppsToDelete.add(o);
                OppTaskIds.add(o.Id);
              }
            }
                        
          //}  //END CHECKING IF DATES CHANGED
          
        }  //END CHECKING FOR START/END DATE = NULL
        
      }  //END LOOP THROUGH EACH OPP LIST IN MAP
    
      //CLEARS Create Contract FLAG ON ACCOUNTS
      //ClearAccountContractFlag(NewAcctMap.keySet());
      
      //DELETE OLD TASKS
      system.debug('**** TASK OPP IDS TO DELETE:' + OppTaskIds);
      DeleteTasks(OppTaskIds);
      
      //CREATE TASKS
      CreateRenewalTasks(NewAcctMap.values(), ContractOppsInserts);
      
      if(!OppsToDelete.isEmpty()){
        delete OppsToDelete;
      }
            
    }  //END Else FOR ExistingOpps
  
    
  }
//----------------------------------------------------------------------------------------
  public static void CreateRenewalTasks(list<Account> accounts, list<Opportunity> opps){
    
    system.debug('**** IN CreateRenewalTasks');
    system.debug('*** ACCOUNTS LIST:' + accounts);
    system.debug('*** OPPS LIST:' + opps);
    
    list<Task> tasks = new list<Task>();
    map<id, Account> mapAccounts = new map<Id, Account>();
    integer days;
    date StartDate;
    date EndDate;
    integer Years;
    date TaskDueDate;
    integer LeadTime;
    
    RecordType NonPooledRecType = GetNonPooledRecType();
    RecordType TaskRecType = GetRenewalTaskRecType();
    
    if(!accounts.isEmpty()){
      for(Account a : accounts){
        mapAccounts.put(a.Id, a);
      }  
    }
    
    if(!opps.isEmpty()){
      
      for(Opportunity opp : opps){
        
        if(mapAccounts.get(opp.AccountId).RecordTypeId == NonPooledRecType.Id){
          
          //TaskOppId.add(opp.Id);
          
          StartDate = mapAccounts.get(opp.AccountId).Contract_Start_Date__c;
          EndDate = mapAccounts.get(opp.AccountId).Contract_End_Date__c;
          Years = StartDate.daysBetween(EndDate) / 365;
          LeadTime = integer.valueOf(mapAccounts.get(opp.AccountId).Renewal_lead_days__c);
          days = integer.valueOf(StartDate.daysBetween(opp.CloseDate));
          
          //TaskDueDate = StartDate.addDays(days) - LeadTime - 60;
          TaskDueDate = StartDate.addDays(days) - LeadTime;    
                    
          system.debug('**** StartDate:' + StartDate);
          system.debug('**** EndDate:' + EndDate);
          system.debug('**** DueDate:' + TaskDueDate);
          system.debug('**** LeadTime:' + LeadTime);
          system.debug('**** OppCloseDate:' + opp.CloseDate);
          system.debug('********** OPP TASK DAYS BETWEEN CLOSE AND START:' + days);
          system.debug('*****  OPP OWNERID:' + opp.OwnerId);
          
          Task t = new Task();
          t.WhatId = opp.Id;
          t.Subject = opp.Name;
          t.Category__c = 'Renewal';
          t.RecordTypeId = TaskRecType.Id;
          t.Type = 'To Do';
          t.Type__c = 'To Do';
          t.OwnerId = mapAccounts.get(opp.AccountId).OwnerId;
          t.ActivityDate = TaskDueDate;
          t.IsReminderSet = true;
          t.AutoCreated__c = true;
          
          TaskDueDate = TaskDueDate - 61;
          
          Datetime reminder = Datetime.newInstance(
              TaskDueDate.year(),
              TaskDueDate.month(),
              TaskDueDate.day(),
              8,0,0  
             );
          
          Date renewal = Date.newInstance(
              reminder.year(), 
              reminder.month(), 
              reminder.day()
            );
          
          t.ReminderDateTime = reminder;
          t.Renewal_Start__c = renewal;
          tasks.add(t);
          
        
        }// END IF ACCT REC TYPE IS NON-POOLED
        
      }  //END OPPS LOOP 
      
    }
    
    //Insert New Tasks
    if(!tasks.isEmpty()){
      insert tasks;
    }
    
  }
//----------------------------------------------------------------------------------------

}