/**
 * @name HierarchyAccountSorter
 * @description Sorts out accounts based on certain criteria.
 * 
 * Used in wv6_AccountHierarchyHandler.cls
 * 
 * @author Creed Interactive (Andrew Frederick) 11/23/2021
 */
public without sharing class HierarchyAccountSorter {

/**
 * FIELDS
 */
    
    private Map<Id, Account> oldMap {get;set;}
    private Map<Id, Account> newMap {get;set;}

    private Account[] accountsReceived {
        get {
            if( accountsReceived == null ) accountsReceived = new Account[]{};
            return accountsReceived;
        }
        set;
    }

    private Account[] accountsUpdated {
        get {
            if( accountsUpdated == null ) accountsUpdated = new Account[]{};
            return accountsUpdated;
        }
        set;
    }

    // to be able to check if the account record is shared with DDMI and was sent by DDMN
    private Set<Id> sentSharedAccountIds {
        get {
            if( sentSharedAccountIds == null ) sentSharedAccountIds = new Set<Id>();
            return sentSharedAccountIds;
        }
        set;
    }
    
    private static final Id DDMIConnectionId = wv6_ConnectionHelper.getConnectionId('RHSC');

/**
 * CONSTRUCTOR
 */

    public HierarchyAccountSorter( Map<Id, Account> om, Map<Id, Account> nm ){
        oldMap = om;
        newMap = nm;
    }

/**
 * ACTION METHODS
 */

    public void sort(){
        getSentSharedAccountIds();
        
        for( Id accId : newMap.keyset() ){
            Account accountOld = oldMap.get(accId);
            Account accountNew = newMap.get(accId);

            if( isReceivedFromDDMI( accountNew ) ){
                accountsReceived.add( accountNew );
            } else
            if( isUpdatedFromDDMI( accountOld, accountNew ) ){
                accountsUpdated.add( accountNew );
            }
        }
    }

/**
 * UTIL METHODS
 */

    /**
     * @name isReceivedFromDDMI
     * @description 
     * 1) make sure it has a connectionId and that it matches the connection to DDMI as there may be multiple sf2sf connects.
     * 2) make sure it doesn't already have a parent. If it has a parent it was already processed.
     * 3) make sure it has a client external Id. This field is filled out but an Informatica job from ETS in DDMI's Salesforce
     * if it's not null then that means that it was actually processed in ETS first
     * 4) Lastly make sure we aren't processing any accounts that have a recordtypeid of either ETS-Client, Pooled or Non-Pooled
     * @return Boolean
     */
    private Boolean isReceivedFromDDMI( Account account ){
        Boolean shouldProcess = account.ConnectionReceivedId == DDMIConnectionId && account.ParentId == null && account.Client_External_Id__c != null;

        String[] recordTypeIds = new String[]{};
        //recordTypeIds.add( AccountHierarchyHandler.getRecordTypeId('ETS_Client') );
        recordTypeIds.add( AccountHierarchyHandler.getRecordTypeId('Pooled') );
        recordTypeIds.add( AccountHierarchyHandler.getRecordTypeId('Non_pooled') );
        
System.debug(recordTypeIds);

        for( String recordTypeId : recordTypeIds ){
            if( account.RecordTypeId == recordTypeId ){
                shouldProcess = false;
                break;
            }
        }

        return shouldProcess;
    }

    /**
     * @name isUpdatedFromDDMI
     * @description 
     * 1) check if the account was shared and sent from DDMN to DDMI
     * 2) make sure it doesn't already have a parent. if it does then it was already processed
     * 3) make sure the client external Id value was changed to actually have a value. Client External Id will
     * have a value once it's update by ETS informatic job over in DDMN.
     * 4) Lastly if it's already an ETS-Client then no need to process. It already has been.
     * @return Boolean
     */
    private Boolean isUpdatedFromDDMI( Account accountOld, Account accountNew ){
        Boolean shouldProcess = sentSharedAccountIds.contains(accountNew.Id) && accountNew.ParentId == null && accountNew.Client_External_Id__c != null;

        String[] recordTypeIds = new String[]{};
        recordTypeIds.add( AccountHierarchyHandler.getRecordTypeId('ETS_Client') );

        for( String recordTypeId : recordTypeIds ){
            if( accountNew.RecordTypeId == recordTypeId ){
                shouldProcess = false;
                break;
            }
        }

        return shouldProcess;
    }

    /**
     * @name getSentSharedAccountIds
     * @description gets the PartnerNetworkRecordConnection records to check if the account was shared to DDMI from DDMN
     * This will weed out accounts that have not been shared to DDMI yet. We have to do this because Salesforce retired
     * ConnectSentId in api version 13.
     * @return Boolean
     */
    private void getSentSharedAccountIds(){
        PartnerNetworkRecordConnection[] pnrcs = new PartnerNetworkRecordConnection[]{};

        try {

            pnrcs.addAll([SELECT
                            Id,
                            LocalRecordId
                                FROM PartnerNetworkRecordConnection
                                WHERE LocalRecordId IN :newMap.keySet()
                                AND ConnectionId = :DDMIConnectionId]);

        } catch( Exception e ){

        }

        for( PartnerNetworkRecordConnection pnrc : pnrcs ){
            sentSharedAccountIds.add(pnrc.LocalRecordId);
        }
    }

    /**
     * @name getReceived
     * @description returns the accounts that were received from DDMI
     * @return Account[]
     */
    public Account[] getReceived(){
        return accountsReceived;
    }

    /**
     * @name getReceived
     * @description returns the accounts that were updated from DDMI
     * @return Account[]
     */
    public Account[] getUpdated(){
        return accountsUpdated;
    }
}