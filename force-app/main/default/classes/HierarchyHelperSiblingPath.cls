/**
 * @name HierarchyHelperSiblingPath
 * @description helps find matched accounts for the hierarchy by traversing horizontally and matching 
 * by either Customer Unique Association Id or Service Type Id.
 * 
 * Used in HierarchyHandlerForReceivedAccounts.cls
 * 
 * @author Creed Interactive (Andrew Frederick) 11/23/2021
 */
public without sharing class HierarchyHelperSiblingPath extends HierarchyHelper {

/**
 * CONSTRUCTOR
 */

    public HierarchyHelperSiblingPath( Account[] accounts  ){
        super( accounts );

        errorMessage = new HierarchyErrors.SiblingParentMismatchErrorMessage();
    }

/**
 * ACTION METHODS
 */

    /**
     * @name build
     * @description builds the hierarchy
     * @return void
     */
    protected override void build( String customId ){
        if( !matchedAccountsByExternalId.containsKey(customId) ) return;

        Account childAccount = accountsByExternalId.get(customId);
        Account[] siblingAccounts = matchedAccountsByExternalId.get(customId);

        if( isValid( siblingAccounts ) ){
            AccountHierarchyHandler.updateChildAccount( childAccount, siblingAccounts[0].ParentId );
        } else {
            errorAccountsByExternalId.put( customId, siblingAccounts );
        }
    }

    /**
     * @name setChildAccounts
     * @description builds the maps of accounts received from DDMI keyed on all of the following:
     * 1) Customer Unique Association Id OR
     * 2) Service Type Id
     * 
     * Checks for possible sibling association. That's what these fields are for along with some other processes 
     * between DDMN and DDMI. but basically they mark sibling relationships as well. If an account has made it this far 
     * then it will have either of the to fields filled with a value.
     * 
     * @param Account account
     * @return void
     */
    protected override void setChildAccounts( Account account ) {
        if( account.ParentId != null ) return;

        // the PEIP group is a special use case where they all have the same customer Unique Association Id AND more than one parent
        // to avoid sending out hundreds of error emails a day let's always skip this group for now 12/16/2021
        if( account.Name.contains('(PEIP)') ) return; 
        
        String cuid = account.Customer_Unique_Association_Id__c != null ? account.Customer_Unique_Association_Id__c.toUpperCase() : null;
        String stid = account.Service_Type_Id__c != null ? account.Service_Type_Id__c.toUpperCase() : null;

        // It will mostly be "either or" of these fields but juuuust in case Let's do AND/OR
        if( !String.isBlank(cuid) ){
            accountsByExternalId.put( cuid, account );
        }

        if( !String.isBlank(stid) ){
            accountsByExternalId.put( stid, account );
        }
    }

    /**
     * @name getMatchedAccounts
     * @description gets potential sibling accounts matched by either Customer Association Id (Dental) or Service Type Id (Vision)
     * @return void
     */
    protected override void getMatchedAccounts(){
        Account[] siblingAccounts = query();

        for( Account siblingAccount : siblingAccounts ){
            String cuid = siblingAccount.Customer_Unique_Association_Id__c != null ? siblingAccount.Customer_Unique_Association_Id__c.toUpperCase() : null;
            String stid = siblingAccount.Service_Type_Id__c != null ? siblingAccount.Service_Type_Id__c.toUpperCase() : null;

            // It will mostly be "either or" of these fields but juuuust in case Let's do AND/OR
            if( !String.isBlank(cuid) ){
                placeMatch( siblingAccount, cuid );
            }
    
            if( !String.isBlank(stid) ){
                placeMatch( siblingAccount, stid );
            }
        }
    }

/**
 * UTILITY METHODS
 */

     /**
     * @name isValid
     * @description checks to make sure all sibling accounts are indeed siblings
     * @return Boolean
     */
    private Boolean isValid( Account[] siblingAccounts ){
        Boolean areSibilings = true;

        for( Account siblingAccount : siblingAccounts ){

            for( Account siblingAccount1 : siblingAccounts ){
                if( siblingAccount.ParentId != siblingAccount1.ParentId ){
                    areSibilings = false;
                    break;
                }
            }

            if( !areSibilings ) break;
        }

        return areSibilings;
    }
  
/**
 * QUERY METHODS
 */

    /**
     * @name query
     * @description gets the parent accounts filtered by
     * 1) Customer Assocation Unique Id or Service Type Id
     * 2) Accounts that aren't the account that are being processed right now 
     * 3) Record Type == ETS_Client
     * 4) And Accounts that already have a parent (so we don't query the accounts being processed)
     * @return Account[]
    */
    private Account[] query(){
        Set<String> customIds = accountsByExternalId.keyset();

        Account[] siblingAccounts = new Account[]{};

        if( customIds.isEmpty() ){
            return siblingAccounts;
        }

        try {

            Set<Id> recordTypeIds = new Set<Id>();
            recordTypeIds.add(AccountHierarchyHandler.getRecordTypeId( 'ETS_Client' ));

            siblingAccounts.addAll([SELECT 
                            Id,
                            Name,
                            ParentId,
                            Parent.Name,
                            Customer_Unique_Association_Id__c,
                            Service_Type_Id__c
                                FROM Account
                                WHERE (
                                    Customer_Unique_Association_Id__c IN :customIds
                                    OR Service_Type_Id__c IN :customIds
                                )
                                AND RecordTypeId IN :recordTypeIds
                                AND ParentId != null]);

        } catch( Exception e ){
            creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler( e );
            handler.debug();
        }

        return siblingAccounts;
    }
}