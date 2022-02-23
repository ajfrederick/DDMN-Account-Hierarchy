/**
 * @name AccountHierarchyHandlerTest
 * @description test AccountHierarchyHandler.cls
 * 
 * @author Creed Interactive (Andrew Frederick) 11/23/2021
 */
@isTest
public class AccountHierarchyHandlerTest {
   
/**
 * FIELDS
 */

    private static final Id pooled = AccountHierarchyHandler.getRecordTypeId('Pooled');
    private static final Id prospect = AccountHierarchyHandler.getRecordTypeId('Prospect');
    private static final Id etsClient = AccountHierarchyHandler.getRecordTypeId('ETS_Client');
    
    private static final Id DDMIConnectionId = wv6_ConnectionHelper.getConnectionId('RHSC');

/**
 * TEST METHODS
 */

    /**
     * @name testUpdateFromDDMI
     * @description This simulates a prospect account being shared to DDMI and then DDMI updating the shared record
     * to have a Client External Id which is the marker that indicates that the record's data has been entered into ETS.
     * Then an ETL tool used by DDMI called Inforamtic updates the account record in DDMI's Salesforce which updates
     * the account in DDMN to have a Client External Id amoungst many other fields but this is the move that is meaningful
     * to this automation. 
     * 
     * This path will transform the 'Prospect' Account in DDMN into the 'ETS-Client' child and insert a new parent
     * into the database that is a clone of the child record previous to it's transormation.
     * 
     * @return void
     */
    @isTest
    public static void testUpdateFromDDMI(){
        // make parent Account
        Account parentAccount = new Account(
            Name = 'Test Parent Account',
            Prospect_Type__c = 'Pooled',
            Client_Number__c = '123456',
            Product_Type__c = 'Dental',
            Type = 'Prospect',
            RecordTypeId = prospect
        );

        insert parentAccount;

        // create a connection to DDMI
        PartnerNetworkRecordConnection pnrc = new PartnerNetworkRecordConnection(
            LocalRecordId = parentAccount.Id,
            ConnectionId = DDMIConnectionId,
            SendClosedTasks = false,
            SendOpenTasks = false,
            SendEmails = false
        );

        insert pnrc;

        // Mimic an update in DDMI
        parentAccount.Client_External_Id__c = 'ceid123';

        update parentAccount;

        Account newParentAccount;

        try {

            // really child account at this point
            parentAccount = [SELECT 
                                    Id,
                                    Name,
                                    ParentId,
                                    RecordTypeId,
                                    Client_Number__c,
                                    Client_External_Id__c
                                        FROM Account 
                                        WHERE Id = :parentAccount.Id];

            newParentAccount = [SELECT 
                                    Id,
                                    Name,
                                    RecordTypeId,
                                    Client_External_Id__c
                                        FROM Account 
                                        WHERE Client_Number__c = :parentAccount.Client_Number__c
                                        AND Id != :parentAccount.Id
                                        AND ParentId = null];
        } catch( Exception e ){
            System.debug(e);
        }

        System.assertNotEquals( null, newParentAccount );
        System.assertEquals( parentAccount.Name, newParentAccount.Name );

        System.assertEquals( null, newParentAccount.Client_External_Id__c );
        System.assertEquals( pooled, newParentAccount.RecordTypeId );

        System.assertEquals( etsClient, parentAccount.RecordTypeId );
        System.assertEquals( newParentAccount.Id, parentAccount.ParentId );
    }

    /**
     * @name testReceiveFromDDMIParentPath
     * @description This simulates a prospect account being shared to DDMI and then DDMI sends DDMN a new account
     * record
     * 
     * This path will make the 'Prospect' Account in DDMN into the parent account. It also uses the client number 
     * and vision client number to match the parent to the child
     * 
     * @return void
     */
    @isTest
    public static void testReceiveFromDDMIParentPath(){

        // make parent Account
        Account parentAccount = new Account(
            Name = 'Test Parent Account',
            Prospect_Type__c = 'Pooled',
            Client_Number__c = '123456',
            Vision_Client_Number__c = 'V23456',
            SF_2_SF_Group_No__c = '222333;123456;V23456',
            Product_Type__c = 'Dental',
            Type = 'Prospect',
            RecordTypeId = prospect
        );

        insert parentAccount;

        // make child Account with matching client number to parent client number
        Account childAccountClientNumber = new Account(
            Name = 'Test Child Account',
            Client_Number__c = '123456',
            Client_External_Id__c = 'ceid34'
        );

        insert childAccountClientNumber;

        // We have to do this instead of run an update with a Client External Id because one of the criteria to 
        // process account is if it has a "ConnectionRecievedId". Unfortunately that field is not writable so we
        // have to it this way.
        HierarchyHandlerForReceivedAccounts receivedHandler = new HierarchyHandlerForReceivedAccounts( new Account[]{childAccountClientNumber} );
        receivedHandler.build();

        update childAccountClientNumber;
        update receivedHandler.getAccounts(); // update the parent accounts
        

        try {
            
            // still parent account
            parentAccount = [SELECT 
                                Id,
                                ParentId,
                                RecordTypeId,
                                Client_Number__c,
                                Client_External_Id__c
                                    FROM Account 
                                    WHERE Id = :parentAccount.Id];

            childAccountClientNumber = [SELECT 
                                            Id,
                                            ParentId,
                                            RecordTypeId,
                                            Client_Number__c,
                                            Client_External_Id__c
                                                FROM Account 
                                                WHERE Id = :childAccountClientNumber.Id];

        } catch( Exception e ){
            System.debug(e);
        }

        System.assertEquals( pooled, parentAccount.RecordTypeId );

        System.assertEquals( etsClient, childAccountClientNumber.RecordTypeId );
        System.assertEquals( parentAccount.Id, childAccountClientNumber.ParentId );



        // make child Account with matching client number to parent VISION client number
        Account childAccountVisionClientNumber = new Account(
            Name = 'Test Child Account',
            Client_Number__c = 'V23456',
            Client_External_Id__c = 'ceid45'
        );

        insert childAccountVisionClientNumber;

        // We have to do this instead of run an update with a Client External Id because one of the criteria to 
        // process account is if it has a "ConnectionRecievedId". Unfortunately that field is not writable so we
        // have to it this way.
        receivedHandler = new HierarchyHandlerForReceivedAccounts( new Account[]{childAccountVisionClientNumber} );
        receivedHandler.build();

        update childAccountVisionClientNumber;

        try {

            childAccountVisionClientNumber = [SELECT 
                                Id,
                                ParentId,
                                RecordTypeId,
                                Client_Number__c,
                                Client_External_Id__c
                                    FROM Account 
                                    WHERE Id = :childAccountVisionClientNumber.Id];

        } catch( Exception e ){
            System.debug(e);
        }

        System.assertEquals( etsClient, childAccountVisionClientNumber.RecordTypeId );
        System.assertEquals( parentAccount.Id, childAccountVisionClientNumber.ParentId );



        // make child Account with matching the FIRST client number in the parent SF_2_SF_Group_No__c
        Account childAccountSF2SFGroupNo = new Account(
            Name = 'Test Child Account',
            Client_Number__c = '222333',
            Client_External_Id__c = 'ceid67'
        );

        insert childAccountSF2SFGroupNo;

        // We have to do this instead of run an update with a Client External Id because one of the criteria to 
        // process account is if it has a "ConnectionRecievedId". Unfortunately that field is not writable so we
        // have to it this way.
        receivedHandler = new HierarchyHandlerForReceivedAccounts( new Account[]{childAccountSF2SFGroupNo} );
        receivedHandler.build();

        update childAccountSF2SFGroupNo;

        try {

            childAccountVisionClientNumber = [SELECT 
                                Id,
                                ParentId,
                                RecordTypeId,
                                Client_Number__c,
                                Client_External_Id__c
                                    FROM Account 
                                    WHERE Id = :childAccountSF2SFGroupNo.Id];

        } catch( Exception e ){
            System.debug(e);
        }

        System.assertEquals( etsClient, childAccountSF2SFGroupNo.RecordTypeId );
        System.assertEquals( parentAccount.Id, childAccountSF2SFGroupNo.ParentId );
    }

    /**
     * @name testReceiveFromDDMISiblingPath
     * @description This simulates a prospect account being shared to DDMI and then DDMI sends DDMN a new account
     * record
     * 
     * This path will match potential sibling ETS-Client records either by Service Type Id or Customer Unique Association Id.
     * It then uses the sibling's ParentId to create the hierarchy.
     * 
     * @return void
     */
    @isTest
    public static void testReceiveFromDDMISiblingPath(){

        // make parent Account
        Account parentAccount = new Account(
            Name = 'Test Parent Account',
            Client_Number__c = '123456',
            Product_Type__c = 'Dental',
            Type = 'Prospect',
            RecordTypeId = pooled
        );

        insert parentAccount;

        // make sibling account the will be used to find the parent
        Account siblingAccount = new Account(
            Name = 'Test Child Sibling Account',
            ParentId = parentAccount.Id,
            RecordTypeId = etsClient,
            Client_Number__c = '123456',
            Client_External_Id__c = 'ceid34',
            Customer_Unique_Association_Id__c = 'cuid12',
            Service_Type_Id__c = 'stid34'
        );

        insert siblingAccount;

        // simulate sharing of new child account with Customer Unique Assocation Id to match siblings
        Account childAccountWithCUID = new Account(
            Name = 'Test Child Account with Customer Unique Association Id',
            Client_Number__c = '777888',
            Client_External_Id__c = 'ceid89',
            Customer_Unique_Association_Id__c = 'cuid12'
        );

        insert childAccountWithCUID;

        // We have to do this instead of run an update with a Client External Id because one of the criteria to 
        // process account is if it has a "ConnectionRecievedId". Unfortunately that field is not writable so we
        // have to it this way.
        HierarchyHandlerForReceivedAccounts receivedHandler = new HierarchyHandlerForReceivedAccounts( new Account[]{childAccountWithCUID} );
        receivedHandler.build();

        update childAccountWithCUID;
        

        try {

            childAccountWithCUID = [SELECT 
                                Id,
                                ParentId,
                                RecordTypeId,
                                Client_Number__c,
                                Client_External_Id__c
                                    FROM Account 
                                    WHERE Id = :childAccountWithCUID.Id];

        } catch( Exception e ){
            System.debug(e);
        }

        System.assertEquals( etsClient, childAccountWithCUID.RecordTypeId );
        System.assertEquals( parentAccount.Id, childAccountWithCUID.ParentId );




        // simulate sharing of new child account with Customer Unique Assocation Id to match siblings
        Account childAccountWithSTID = new Account(
            Name = 'Test Child Account With Service Type Id',
            Client_Number__c = '111222',
            Client_External_Id__c = 'ceid01',
            Service_Type_Id__c = 'stid34'
        );

        insert childAccountWithSTID;

        // We have to do this instead of run an update with a Client External Id because one of the criteria to 
        // process account is if it has a "ConnectionRecievedId". Unfortunately that field is not writable so we
        // have to it this way.
        receivedHandler = new HierarchyHandlerForReceivedAccounts( new Account[]{childAccountWithSTID} );
        receivedHandler.build();

        update childAccountWithSTID;
        

        try {

            childAccountWithSTID = [SELECT 
                                Id,
                                ParentId,
                                RecordTypeId,
                                Client_Number__c,
                                Client_External_Id__c
                                    FROM Account 
                                    WHERE Id = :childAccountWithSTID.Id];

        } catch( Exception e ){
            System.debug(e);
        }

        System.assertEquals( parentAccount.Id, childAccountWithSTID.ParentId );
        System.assertEquals( etsClient, childAccountWithSTID.RecordTypeId );
    }

    /**
     * @name testDuplicateParentError
     * @description This tests the error if two parents are found with the same Client Number.
     * @return void
     */
    @isTest
    public static void testDuplicateParentError(){

        // make parent Account
        Account parentAccount = new Account(
            Name = 'Test Parent Account',
            Prospect_Type__c = 'Pooled',
            Client_Number__c = '123456',
            Product_Type__c = 'Dental',
            Type = 'Prospect',
            RecordTypeId = prospect
        );

        insert parentAccount;

        // make parent Account
        Account parentAccount2 = new Account(
            Name = 'Test Parent Account 2',
            Prospect_Type__c = 'Pooled',
            Client_Number__c = '123456',
            Product_Type__c = 'Dental',
            Type = 'Prospect',
            RecordTypeId = prospect
        );

        insert parentAccount2;

        // make child Account with matching client number to parent client number
        Account childAccount = new Account(
            Name = 'Test Child Account',
            Client_Number__c = '123456',
            Client_External_Id__c = 'ceid34'
        );

        insert childAccount;

        Integer numberOfEmailInvocations = 0;

        Test.startTest();

            // We have to do this instead of run an update with a Client External Id because one of the criteria to 
            // process account is if it has a "ConnectionRecievedId". Unfortunately that field is not writable so we
            // have to it this way.
            HierarchyHandlerForReceivedAccounts receivedHandler = new HierarchyHandlerForReceivedAccounts( new Account[]{childAccount} );
            receivedHandler.build();

            update childAccount;

            numberOfEmailInvocations = Limits.getEmailInvocations();

        Test.stopTest();

        System.assertEquals( 1, numberOfEmailInvocations ); 
    }

    /**
     * @name testFailedParentMisMatchError
     * @description This tests the error when two or more siblings are found and there are different parents
     * @return void
     */
    @isTest
    public static void testFailedParentMisMatchError(){
        
        // make parent Account
        Account parentAccount = new Account(
            Name = 'Test Parent Account',
            Client_Number__c = '123456',
            Product_Type__c = 'Dental',
            Type = 'Prospect',
            RecordTypeId = pooled
        );

        insert parentAccount;

        // make sibling account the will be used to find the parent
        Account siblingAccount = new Account(
            Name = 'Test Child Sibling Account',
            ParentId = parentAccount.Id,
            RecordTypeId = etsClient,
            Client_Number__c = '123456',
            Client_External_Id__c = 'ceid34',
            Customer_Unique_Association_Id__c = 'cuid12'
        );

        insert siblingAccount;

        // make parent Account for mismatch
        Account parentAccountMismatch = new Account(
            Name = 'Test Mismatch Parent Account',
            Client_Number__c = '111222',
            Product_Type__c = 'Dental',
            Type = 'Prospect',
            RecordTypeId = pooled
        );

        insert parentAccountMismatch;

        // make mismatched sibling with "matched" Customer Unique Association Id but different ParentId
        Account siblingAccountMismatch = new Account(
            Name = 'Test Mismatch Child Sibling Account',
            ParentId = parentAccountMismatch.Id,
            RecordTypeId = etsClient,
            Client_Number__c = '111222',
            Client_External_Id__c = 'ceid53',
            Customer_Unique_Association_Id__c = 'cuid12'
        );

        insert siblingAccountMismatch;

        // simulate sharing of new child account with Customer Unique Assocation Id to match siblings
        Account childAccountWithCUID = new Account(
            Name = 'Test Child Account with Customer Unique Association Id',
            Client_Number__c = '777888',
            Client_External_Id__c = 'ceid89',
            Customer_Unique_Association_Id__c = 'cuid12'
        );

        insert childAccountWithCUID;

        Integer numberOfEmailInvocations = 0;

        Test.startTest();

            // We have to do this instead of run an update with a Client External Id because one of the criteria to 
            // process account is if it has a "ConnectionRecievedId". Unfortunately that field is not writable so we
            // have to it this way.
            HierarchyHandlerForReceivedAccounts receivedHandler = new HierarchyHandlerForReceivedAccounts( new Account[]{childAccountWithCUID} );
            receivedHandler.build();

            update childAccountWithCUID;

            numberOfEmailInvocations = Limits.getEmailInvocations();

        Test.stopTest();

        System.assertEquals( 1, numberOfEmailInvocations );
    }
}