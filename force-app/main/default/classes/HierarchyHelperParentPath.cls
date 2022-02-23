/**
 * @name HierarchyHelperParentPath
 * @description helps find matched accounts for the hierarchy by traversing vertical and matching by either 
 * client number AND/OR vision client number
 * 
 * Used in HierarchyHandlerForReceivedAccounts.cls
 * 
 * @author Creed Interactive (Andrew Frederick) 11/23/2021
 */
public without sharing class HierarchyHelperParentPath extends HierarchyHelper {

/**
 * CONSTRUCTOR
 */

    public HierarchyHelperParentPath( Account[] accounts  ){
        super( accounts );

        errorMessage = new HierarchyErrors.DuplicateParentErrorMessage();
    }

/**
 * ACTION METHODS
 */

    /**
     * @name build
     * @description builds the hierarchy
     * @return void
     */
    protected override void build( String clientNumber ){
        if( !matchedAccountsByExternalId.containsKey(clientNumber) ) return;

        Account childAccount = accountsByExternalId.get(clientNumber);
        Account[] parentAccounts = matchedAccountsByExternalId.get(clientNumber);


        if( isValid( parentAccounts ) ){
            Account parentAccount = parentAccounts[0];

            AccountHierarchyHandler.updateChildAccount( childAccount, parentAccount.Id );
            AccountHierarchyHandler.updateParentAccount( parentAccount );

            accountsToUpdate.add( parentAccount );
        } else 
        if( !parentAccounts.isEmpty() ){
            errorAccountsByExternalId.put( clientNumber, parentAccounts );
            
            // update the child account's record type so it's clear to the user that is an ETS-Client and one that needs rectification
            childAccount.RecordTypeId = AccountHierarchyHandler.getRecordTypeId( 'ETS_Client' );
            childAccount.Type = 'Customer';
        }
    }

    /**
     * @name setChildAccounts
     * @description builds the maps of accounts received from DDMI keyed on all of the following:
     * 1) Client Number
     * 2) Vision Client Number
     * @param Account account
     * @return void
     */
    protected override void setChildAccounts( Account account ) {
        if( account.ParentId != null ) return;
        
        String clientNumber = account.Client_Number__c != null ? account.Client_Number__c.toUpperCase() : null;

        if( String.isBlank(clientNumber) ) return;

        // add the client number weather it has an accidental leading 0 or not
        accountsByExternalId.put(clientNumber, account);

        /**
         * Roosevelt sometimes adds a leading 0 which will cause the client number to have 7 digits.
         *
         * As 8/20/2021 the client number is supposed to only have 6 digits due to DDMN's billing software.
         * So if it has 7 and if it starts with a 0, remove the 0.
         *
         * NOTE: IF ETS leading zero problem is resolved, DITCH this code! This code is most likely a temporary catch case.
         */
        if( clientNumber.length() > 6 ){
            accountsByExternalId.put(clientNumber.removeStart('0'), account);
        /**
         * we also want to get parents that may have inappropriately had a leading zero added to it's client number
         * so let's a add a 0 to the client number but only in the key value which then will be included in the query below.
         */
        } else {
            accountsByExternalId.put(clientNumber.leftPad(7, '0'), account); 
        }
    }

    /**
     * @name getMatchedAccounts
     * @description returns accounts that are parents to the newly created/shared accounts from DDMI. 
     * Matched by Client_Number__c or Vision_Client_Number__c
     * @return void
     */
    protected override void getMatchedAccounts() {
        Account[] parentAccounts = query();

        for( Account parentAccount : parentAccounts ){
            String clientNumber = parentAccount.Client_Number__c != null ? parentAccount.Client_Number__c.toUpperCase() : null;
            String visionClientNumber = parentAccount.Vision_Client_Number__c != null ? parentAccount.Vision_Client_Number__c.toUpperCase() : null;

            placeMatch( parentAccount, clientNumber );
            placeMatch( parentAccount, visionClientNumber );

            /** 
             * we need to do this as a bit of a 'relic precaution' slash sometimes there will be more than one client number that
             * is stored in this field. The initial conversion on 11/29/2019 populated this field primarily but it is also used
             * in the case the parent account changed in some manor requiring multiple client numbers
             * 
             * TODO find more elegant way to store multiple Client Numbers in the data schema. The SF_2_SF_Group_No__c field is
             * a bit of a relic.
             */
            if( !String.isBlank( parentAccount.SF_2_SF_Group_No__c ) ){
                String[] oldClientNumbers = parentAccount.SF_2_SF_Group_No__c.split(';');

                for( String oldClientNumber : oldClientNumbers ){
                    placeMatch( parentAccount, oldClientNumber );
                }
            }
        }
    }

/**
 * UTILITY METHODS
 */

    /**
     * @name isValid
     * @description If matchedAccountsByExternalId has accounts that have different Ids then there are 
     * duplicate parent accounts with the same Client Number and we have a data integrity issue.
     * 
     * We need human intervention.
     * @param Account[] parentAccounts
     * @return Boolean
     */
    private Boolean isValid( Account[] parentAccounts ){
        Boolean isValid = true;

        for( Account account : parentAccounts ){

            for( Account account1 : parentAccounts ){

                if( account.Id != account1.Id ){
                    isValid = false;
                    break;
                }
            }

            if( !isValid ) break;
        }

        return isValid;
    }
   
/**
 * QUERY METHODS
 */

    /**
     * @name query
     * @description gets the parent accounts filtered by record type and client number or vision client number
     * @return Account[]
    */
    private Account[] query(){
        Set<String> clientNumbers = accountsByExternalId.keyset();

        Account[] parentAccounts = new Account[]{};

        if( clientNumbers.isEmpty() ){
            return parentAccounts;
        }

        String[] sf2sfGroupNumberFilters = new String[]{};

        for( String clientNumber : clientNumbers ){
            String wildCardClientNumber = '\'%' + clientNumber + '%\'';

            sf2sfGroupNumberFilters.add( 'SF_2_SF_Group_No__c LIKE ' + wildCardClientNumber ); 
        }

        try {

            Set<Id> recordTypeIds = new Set<Id>();
            recordTypeIds.add(AccountHierarchyHandler.getRecordTypeId( 'Prospect' ));
            recordTypeIds.add(AccountHierarchyHandler.getRecordTypeId( 'Pooled' ));
            recordTypeIds.add(AccountHierarchyHandler.getRecordTypeId( 'Non_pooled' ));

            // We have to use dynamic SOQL here to check SF_2_SF_Group_No__c field
            String query = 'SELECT ';
            query += 'Id, ';
            query += 'Name, ';
            query += 'Client_Number__c, ';
            query += 'Vision_Client_Number__c, ';
            query += 'SF_2_SF_Group_No__c, ';
            query += 'Prospect_Type__c, ';
            query += 'RecordTypeId ';
                query += 'FROM Account ';
            
            String filter = ' WHERE ';
            filter += '( ';

            if( !sf2sfGroupNumberFilters.isEmpty() ){
                filter +=  String.join(sf2sfGroupNumberFilters, ' OR ');
                filter += ' OR ';
            }

            filter += 'Client_Number__c IN :clientNumbers ';
            filter += 'OR Vision_Client_Number__c IN :clientNumbers ';
            filter += ') ';
            filter += 'AND RecordTypeId IN :recordTypeIds ';
            filter += 'AND ParentId = null';

            parentAccounts.addAll( (Account[]) Database.query( query + filter ) );

        } catch( Exception e ){
            creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler( e );
            handler.debug();
        }

        return parentAccounts;
    }
}