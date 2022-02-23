/**
 * @name HierarchyHandlerForReceivedAccounts
 * @description This class receives accounts that are new to DDMN from DDMI. They are the ETS-Cient child records.
 * So this class searches for the parent accounts and matches the child and parent by Client Number.
 * 
 * It also checks for duplicates and if there wasn't a parent found and notifies anyone that needs to be notified by email.
 * 
 * Used in AccountHierarchyHandler.cls
 * 
 * @author Creed Interactive (Andrew Frederick) 11/23/2021
 */
public without sharing class HierarchyHandlerForReceivedAccounts {

/**
 * FIELDS
 */

    private HierarchyHelper[] helpers {
        get {
            if( helpers == null ) helpers = new HierarchyHelper[]{};
            return helpers;
        }
        set;
    }

/**
 * CONSTRUCTOR
 */

    public HierarchyHandlerForReceivedAccounts( Account[] accounts ) {
        // make sure to check the parent path first which matches the new ETS-Client account's client number to a parent's 
        // client number, vision client number or SF_2_SF_Group_No__c
        helpers.add( new HierarchyHelperParentPath( accounts ) );
        helpers.add( new HierarchyHelperSiblingPath( accounts ) );
    }

/**
 * ACTION METHODS
 */

    /**
	 * @name build
	 * @description Builds the account hierarchy matching Client Number in Client_Number__c field
	 * or Client Number on Vision_Client_Number__c field on a potential parent 'Prospect' account. Also updates 
	 * parent account's record type and Type
	 * @return void
	 */
	public void build(){

        for( HierarchyHelper helper : helpers ){
            if( helper.accountsReceived.isEmpty() ) continue;

            helper.go();
            helper.checkErrors();
        }
    }

/**
 * UTILITY METHODS
 */

    /**
	 * @name getAccounts
	 * @description returns the parent accounts for updating
	 * @return Account[]
	 */
    public Account[] getAccounts(){
        Account[] accountsToUpdate = new Account[]{};

        for( HierarchyHelper helper : helpers ){
            accountsToUpdate.addAll( helper.accountsToUpdate );
        }

        return accountsToUpdate;
    }
}