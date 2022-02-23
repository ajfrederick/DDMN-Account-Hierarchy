/**
 * @name AccountChildrenClientNumbers
 * @description This is an extension for the Visualforce Page by the same name. The page is used on the pooled and non-pooled
 * account record pages to display all the client numbers for the ETS-Client Children.
 * 
 * @author Creed Interactive (Andrew Frederick) 11/19/2021
 */
public without sharing class AccountChildrenClientNumbers {

    private Account account {get;set;}

    private Account[] children {
        get {
            if( children == null ) children = new Account[]{};
            return children;
        }
        set;
    }

    public AccountChildrenClientNumbers( ApexPages.StandardController stdController ) {
        account = (Account) stdController.getRecord();

        getChildren();
    }

    public Account[] getChildrenAccounts(){
        return children;
    }

    private void getChildren(){

        try {

            children.addAll([SELECT
                                Id,
                                Name,
                                Client_Number__c,
                                Funding_Type__c,
                                RecordType.Name,
                                OwnerId,
                                Owner.FirstName,
                                Owner.LastName
                                    FROM Account
                                    WHERE ParentId = :account.Id
                                    AND Inactive__c = false
                                    AND Client_Number__c != null
                                    ORDER BY Client_Number__c asc
                                    LIMIT 300]);

        } catch( Exception e ){
            System.debug( 'Trouble finding children to roll up client numbers for this parent: ' + e.getMessage() );
        }
    }
}