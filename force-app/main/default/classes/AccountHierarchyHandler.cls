/**
 * @name AccountHierarchyHandler
 * @description 
 * 
 * Logic to enure that process accounts that need to be built into a hierarchy where the 'ETS-Client' record is the child
 * and the prospect or customer account is the parent.
 * 
 * When sf2sf feature creates a record it does NOT run an insert operations. It triggers an update only 
 * so we have to run this on a before update trigger since we also have to update the records themselves.
 * 
 * This replaced Wave6's wv6_AccountHierarchyHandler.cls
 * 
 * @author Creed Interactive (Andrew Frederick) 11/23/2021
 */
public without sharing class AccountHierarchyHandler {

/**
 * FIELDS
 */
    
    // A list of record type developer/api names that we will use to get the recordType Ids to use below
    private static final String[] RecordTypeNames = new String[]{
        'ETS_Client',
        'Prospect',
        'Pooled',
        'Non_pooled'
    };
    
    private static Map<String, Id> RecordTypeIdsByName = new Map<String, Id>();

    /**
     * This static block is to ensure there are no problems constructing the class when accessing the Schema describe and the 
     * getRecordTypeInfosByDeveloperName. If the record type was deleted or the name was changed then you will
     * incur an 'attempt to de-referece a null object error'. 
     *
     * With this, if an account, that was once a prospect or is an ETS-client child record, is coming out with no record type 
     * then someone has either deleted the record type or changed it's name
     */
    static {

        DescribeSobjectResult describe = Account.SObjectType.getDescribe();

        Map<String, Schema.RecordTypeInfo> recordTypes = describe.getRecordTypeInfosByDeveloperName();

        for( String name : RecordTypeNames ){

            if( recordTypes.containsKey( name ) ){
                RecordTypeIdsByName.put( name, recordTypes.get( name ).getRecordTypeId() );
            } else {
                RecordTypeIdsByName.put( name, null ); // this will only happen if the record type was deleted or the name was changed for the list above
            }
        }   
    }

    // list of email addresses that will be notified when errors are found. These will be stored as custom settings
    public static String[] emailsForErrorMessages = new String[]{};

    /**
     * This gets emails for users to be notified of errors like Duplicate parents found. The user Ids are stored as
     * Custom Metadata Types so they can be dynamically added and removed post deploy.
     */
    static {

        Account_Hierarchy_Error_Recipient__mdt[] recipients = Account_Hierarchy_Error_Recipient__mdt.getAll().values();

        String[] userIds = new String[]{};

        for( Account_Hierarchy_Error_Recipient__mdt recipient : recipients ){
            String userId = recipient.User_Id__c;

            if( !(userId instanceof Id) ) continue;

            userIds.add( userId );
        }

        User[] users = new User[]{};

        try {

            users.addAll([SELECT 
                            Id, 
                            Email 
                                FROM User 
                                WHERE Id IN :userIds]);

        } catch( Exception e ){
            creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler(e);
            handler.debug();
        }

        for( User user : users ){
            emailsForErrorMessages.add( user.Email );
        }
    }
    
/**
 * TRIGGER METHODS
 */

    /**
     * @name buildHierarchy
     * @description Called on AccountTrigger on before update. sorts out the accounts to make sure we're dealing with the right ones
     * then is the account was received from DDMI handle it one way and if it was updated via the connection on a record DDMN shared to DDMI
     * then handle it that way. Look at class definitions for how they get handled.
     * @param Map<Id, Account> oldMap
     * @param Map<Id, Account> newMap
     * @return void
     */
    public static void buildHierarchy( Map<Id, Account> oldMap, Map<Id, Account> newMap ) {
        Account[] accountsToUpsert = new Account[]{};

        HierarchyAccountSorter sorter = new HierarchyAccountSorter( oldMap, newMap );
        sorter.sort();
        
        HierarchyHandlerForReceivedAccounts receivedHandler = new HierarchyHandlerForReceivedAccounts( sorter.getReceived() );
        receivedHandler.build();

        HierarchyHandlerForUpdatedAccounts updatedHandler = new HierarchyHandlerForUpdatedAccounts( sorter.getUpdated() );
        updatedHandler.build();

        accountsToUpsert.addAll( receivedHandler.getAccounts() );
        accountsToUpsert.addAll( updatedHandler.getAccounts() );

        try {
            upsert accountsToUpsert;
        } catch( Exception e ){
            creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler(e);
            handler.handle();
        }

        updatedHandler.updateChildAccounts();
    }
    
/**
 * UTIL METHODS
 */
    /**
     * @name updateChildAccount
     * @description Updates the child ETS-Client received from DDMI
     * @param Account childAccount
     * @param Account parentAccount
     * @return void
     */
    public static void updateChildAccount( Account childAccount, Id parentId ){
        // this is temporary code in case disaster strikes in the initial launch. Can be removed eventually if need be.
        childAccount.Pre_Hierarchy_Record_Type_Id__c = childAccount.RecordTypeId;

        childAccount.ParentId = parentId;
        childAccount.RecordTypeId = getRecordTypeId( 'ETS_Client' );
        childAccount.Type = 'Customer';
    }

    /**
     * @name updateParentAccount
     * @description Updates parent account if and only if it is a Prospect Account
     * @param Account parentAccount
     * @return void
     */
    public static void updateParentAccount( Account parentAccount ){

        // if this isn't a prospect account the jet outta here!
        if( parentAccount.RecordTypeId != getRecordTypeId( 'Prospect' ) ) return;

        // this is temporary code in case disaster strikes in the initial launch. Can be removed eventually if need be.
        parentAccount.Pre_Hierarchy_Record_Type_Id__c = parentAccount.RecordTypeId; 
        
        // update to pooled or non-pooled depending on Prospect Type
        if( parentAccount.Prospect_Type__c == 'Pooled' ){
            parentAccount.RecordTypeId = getRecordTypeId( 'Pooled' );
        } else 
        if( parentAccount.Prospect_Type__c == 'Non-Pooled' ){
            parentAccount.RecordTypeId = getRecordTypeId( 'Non_pooled' );
        }
        
        parentAccount.Type = 'Customer';
    }

    /**
     * @name getRecordTypeId
     * @description get RecordTypeId by name
     * @param String name
     * @return Id
     */
    public static Id getRecordTypeId( String name ){
        Id recordTypeId;
        
        try {

            recordTypeId = RecordTypeIdsByName.get( name );

            if( recordTypeId == null ){
                throw new RecordTypeException('Record Type ' + name + ' for Accounts does not exist. Or the developer is searching for this record type on the wrong Object.');
            }

        } catch( Exception e ){
            creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler(e);
            handler.handle();
        }

        return recordTypeId;
    }

/**
 * CLASSES
 */
    public class RecordTypeException extends Exception {}
}