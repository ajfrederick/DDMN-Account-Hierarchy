/**
 * @name HierarchyHelper
 * @description abstract class for:
 * 
 * HierarchyHandlerParentHelper.cls
 * HierarchyHandlerSiblingHelper.cls
 * 
 * @author Creed Interactive (Andrew Frederick) 11/23/2021
 */
public abstract without sharing class HierarchyHelper {

/**
 * FIELDS
 */

    // list of accounts from trigger which were received from DDMI
    public Account[] accountsReceived {
        get {
            if( accountsReceived == null ) accountsReceived = new Account[]{};
            return accountsReceived;
        }
        set;
    }

    // list of accounts received from DDMI keyed on an external Id (Client Number, Vision Client Number, Customer Unique Assoction Id, Service Type Id)
    public Map<String, Account> accountsByExternalId {
        get {
            if( accountsByExternalId == null ) accountsByExternalId = new Map<String, Account>();
            return accountsByExternalId;
        }
        set;
    }

    // Parent or sibling accounts by their external Id
    public Map<String, Account[]> matchedAccountsByExternalId {
        get {
            if( matchedAccountsByExternalId == null ) matchedAccountsByExternalId = new Map<String, Account[]>();
            return matchedAccountsByExternalId;
        }
        set;
    }

    // list of accounts that hit an invalid path (e.g. parents that have same client number, siblings that don't have the same parent, etc.)
    public Map<String, Account[]> errorAccountsByExternalId {
        get {
            if( errorAccountsByExternalId == null ) errorAccountsByExternalId = new Map<String, Account[]>();
            return errorAccountsByExternalId;
        }
        set;
    }

    // list of parent accounts to update
    public Account[] accountsToUpdate {
        get {
            if( accountsToUpdate == null ) accountsToUpdate = new Account[]{};
            return accountsToUpdate;
        }
        set;
    }

    // classes that construct error message. this gets set in constructor of sub classes.
    protected HierarchyErrors.HierarchyErrorMessage errorMessage {get;set;}

/**
 * CONSTUCTOR
 */

    public HierarchyHelper( Account[] accounts ){
        accountsReceived = accounts;
    }

/**
 * ABSTRACT METHODS
 */

protected abstract void setChildAccounts( Account account );
protected abstract void getMatchedAccounts();
protected abstract void build( String externalId );

/**
 * ACTION METHODS
 */

    public void go(){

        for( Account account : accountsReceived ){
            setChildAccounts( account );
        }

        getMatchedAccounts();

        for( String externalId : accountsByExternalId.keyset() ){
            build( externalId );
        }
    }

/**
 * UTILITY METHODS
 */

    protected void placeMatch( Account acccount, String externalId ){
        if( String.isBlank(externalId) ) return;

        if( matchedAccountsByExternalId.containsKey(externalId) ){
            matchedAccountsByExternalId.get( externalId ).add( acccount );
        } else {
            matchedAccountsByExternalId.put( externalId, new Account[]{ acccount } ); 
        }
    }

    public void checkErrors(){
        if( errorAccountsByExternalId.isEmpty() ) return;

        String message = 'There was an error building the hierarchy upon recieving an ETS-Child';

        message = errorMessage != null ? errorMessage.getMessage( errorAccountsByExternalId, accountsByExternalId ) : message;

        try {

            throw new HierarchyException( message );

        } catch( Exception e ){
			creedint.CreedExceptionHandler handler = new creedint.CreedExceptionHandler( e );

            for( String email : AccountHierarchyHandler.emailsForErrorMessages ){
			    handler.addAddress(email);
            }

			handler.handle();
        }
    }

/**
 * CLASSES
 */

    public class HierarchyException extends Exception {}
}