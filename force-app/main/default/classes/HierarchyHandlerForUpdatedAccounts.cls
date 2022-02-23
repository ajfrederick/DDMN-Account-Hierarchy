/**
 * @name HierarchyHandlerForUpdatedAccounts
 * @description creates a new 'parent' account and turns the updated account into the child 'ETS-Client' account.
 * 
 * Used in AccountHierarchyHandler.cls
 * 
 * @author Creed Interactive (Andrew Frederick) 11/23/2021
 */
public without sharing class HierarchyHandlerForUpdatedAccounts {

    private Account[] accountsUpdated {
        get {
            if( accountsUpdated == null ) accountsUpdated = new Account[]{};
            return accountsUpdated;
        }
        set;
    }

    public Map<Id, Account> parentAccountsToInsertByChildId {
        get {
            if( parentAccountsToInsertByChildId == null ) parentAccountsToInsertByChildId = new Map<Id, Account>();
            return parentAccountsToInsertByChildId;
        }
        set;
    }

    public Account[] failedParentAccounts {
        get {
            if( failedParentAccounts == null ) failedParentAccounts = new Account[]{};
            return failedParentAccounts;
        }
        set;
    }

    protected HierarchyErrors.FailedParentCreationErrorMessage errorMessage {get;set;}

    public HierarchyHandlerForUpdatedAccounts( Account[] accounts ) {
        accountsUpdated = accounts;
        errorMessage = new HierarchyErrors.FailedParentCreationErrorMessage();
    }

/**
 * ACTION METHODS
 */

    /**
	 * @name build
	 * @description Called on AccountTrigger on before update.
	 * Builds the account hierarchy matching Client Number in Client_Number__c field
	 * or Client Number on Vision_Client_Number__c field on a potential parent 'Prospect' account. Also updates 
	 * parent account's record type and Type
	 * @return void
	 */
	public void build(){
        if( accountsUpdated.isEmpty() ) return;

		for( Account account : accountsUpdated ){
            createParent(account);
		}
    }

/**
 * UTIL METHODS
 */

    /**
	 * @name createParent
	 * @description Creates a parent account by cloning the account that was updated by DDMI. The account that was updated is
     * one that DDMN sent to DDMI initally as the Prosepect Account record. It was updated to have a Client External Id 
     * which means it was processed in ETS.
	 * @param Account childAccount
	 * @return void
	 */
    private void createParent( Account childAccount ){
        Account newParentAccount = childAccount.clone();

        AccountHierarchyHandler.updateParentAccount( newParentAccount );
 
        newParentAccount.Client_External_Id__c = null; // reset Client_External_Id__c since this record won't be connected to DDMI

        parentAccountsToInsertByChildId.put(childAccount.Id, newParentAccount);
    }

    /**
	 * @name updateChildAccounts
	 * @description This updates the accounts that were updated by DDMI and turns them into ETS-Client Child records and
     * also updates the parentId to the newly created and now inserted parent Accounts
     * This method is called in AccountHierarchyHandler.cls and after it has inserted the Parent Accounts.
	 * @param Account childAccount
	 * @return void
	 */
    public void updateChildAccounts(){
        if( parentAccountsToInsertByChildId.isEmpty() ) return;

        // In the case that the 'old parent' now 'new child' has children 
        // lets reparent the children to the new parent made (cloned) above.
        Set<Id> childAccountIds = new Set<Id>(); 

        for( Account childAccount : accountsUpdated ){
            Account parentAccount = parentAccountsToInsertByChildId.get(childAccount.Id);

            if( parentAccount.Id == null ){
                failedParentAccounts.add(childAccount); // use child account because it has an Id and we can use that for the error email
                continue;
            }

            AccountHierarchyHandler.updateChildAccount( childAccount, parentAccount.Id );

            childAccount.Prospect_Type__c = null; // clear the prospect type since this once was a 'Prospect' account.

            childAccountIds.add( childAccount.Id );
        }

        Boolean hasErrors = checkErrors();

        if( !hasErrors ){
            reparentChildren( childAccountIds );

            resetSalesforceOriginIdOnParents();
        }
    }

    /**
	 * @name reparentChildren
	 * @description This covers the case where two new clients are submitted to DDMI (usually dental and vision) and one of them that
     * was sent to us (usually vision) comes first. We need to reparent to the newly created (cloned) parent.
	 * @param Set<Id> childAccountIds
	 * @return void
	 */
    private void reparentChildren( Set<Id> childAccountIds ){

        Account[] grandChildrenToBeReparented = new Account[]{};

        try {

            grandChildrenToBeReparented.addAll([SELECT   
                                            Id,
                                            ParentId
                                                FROM Account
                                                WHERE ParentId IN :childAccountIds]);
        } catch( Exception e ){
            creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler(e);
            handler.debug();
        }


        if( grandChildrenToBeReparented.isEmpty() ) return; // exit if there are none.


        Map<Id, Account[]> grandChildrenByChildAccountId = new Map<Id, Account[]>();

        for( Account account : grandChildrenToBeReparented ){

            if( grandChildrenByChildAccountId.containsKey(account.ParentId) ){
                grandChildrenByChildAccountId.get(account.ParentId).add(account);
            } else {
                grandChildrenByChildAccountId.put( account.ParentId, new Account[]{account} );
            }
        }
        
        Account[] accountsToBeUpdated = new Account[]{};

        for( Id childId : childAccountIds ){
            Account parentAccount = parentAccountsToInsertByChildId.get(childId);
            Account[] grandChildren = grandChildrenByChildAccountId.get(childId);

            if( parentAccount == null || grandChildren == null ) continue;

            for( Account account : grandChildren ){
                account.ParentId = parentAccount.Id;
                accountsToBeUpdated.add(account);
            }
        }

        try {

            update accountsToBeUpdated;

        } catch( Exception e ){
            creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler(e);
            handler.handle();
        }
    }

    /**
	 * @name resetSalesforceOriginIdOnParents
	 * @description We need to reset the Salesforce_Origin_Id__c because other processes like wv6_RecordTypeHandler.cls 
     * depends on it. 
     * 
     * For example we found out (on 2/18/22) that Renewals are being attached to this "new" parent because it's a clone and
     * the Salesforce_Origin_Id__c has the same of the now "child" account. This causes the Record Type Handler to find 2 
     * accountsand it is not "smart" enought to determine which one to choose. That should change but we can't buffer against 
     * that with this.
     * 
	 * @param none
	 * @return void
	 */
    private void resetSalesforceOriginIdOnParents(){
        Account[] accountsToBeUpdated = new Account[]{};

        for( Account parentAccount : parentAccountsToInsertByChildId.values() ){
            if( parentAccount.Id == parentAccount.Salesforce_Origin_Id__c ) continue;

            parentAccount.Salesforce_Origin_Id__c = parentAccount.Id;

            accountsToBeUpdated.add( parentAccount );
        }

        try {

            update accountsToBeUpdated;

        } catch( Exception e ){
            creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler(e);
            handler.handle();
        }
    }

    /**
	 * @name getAccounts
	 * @description returns the parent accounts that need to be inserted
	 * @return Account[]
	 */
    public Account[] getAccounts(){
        return parentAccountsToInsertByChildId.values();
    }

    /**
	 * @name checkErrors
	 * @description throws error if any parents failed to insert
	 * @return Boolean
	 */
    private Boolean checkErrors(){
        Boolean hasErrors = false;

        if( failedParentAccounts.isEmpty() ) return hasErrors;

        String message = 'There was an error building the hierarchy upon updating an account to an ETS-Child and creating a parent';

        message = errorMessage != null ? errorMessage.getMessage( failedParentAccounts ) : message;

        try {

            throw new HierarchyException( message );

        } catch( Exception e ){
			creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler( e );

            for( String email : AccountHierarchyHandler.emailsForErrorMessages ){
			    handler.addAddress(email);
            }

			handler.handle();

            hasErrors = true;
        }

        return hasErrors;
    }

/**
 * CLASSES
 */
    public class HierarchyException extends Exception {}
}