/**
 * @name AccountChildrenClientNumbers
 * @description test class for AccountChildrenClientNumbers.cls
 * 
 * @author Creed Interactive (Andrew Frederick) 11/19/2021
 */
@isTest
public class AccountChildrenClientNumbersTest {

    @TestSetup
    static void makeData(){

        Account parent = new Account(
            Name = 'New Pooled',
            Client_Number__c = '123456',
            SF_2_SF_Group_No__c = '123456'
        );

        insert parent;

        Account child = new Account(
            Name = 'New ETS',
            ParentId = parent.Id,
            Client_Number__c = '123456'
        );

        insert child;
    }

    @isTest
    public static void testExtension(){
        Account parent = [SELECT Id FROM Account WHERE ParentId = null];
        Account child = [SELECT Id FROM Account WHERE ParentId = :parent.Id];

        PageReference newPage = Page.AccountChildrenClientNumbers;
        newPage.getParameters().put('Id', String.valueOf(parent.Id) );

        Test.setCurrentPage(newPage);
        
        ApexPages.StandardController stdController = new ApexPages.StandardController(parent);

        AccountChildrenClientNumbers extension = new AccountChildrenClientNumbers( stdController );
        
        Account[] children = extension.getChildrenAccounts();

        System.assertEquals( 1, children.size() );
        System.assertEquals( children[0].Id, child.Id );
    }
}