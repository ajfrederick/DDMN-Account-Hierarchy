/**
 * @name HierarchyErrors
 * @description Utility class for generating error messages that will be sent out via email
 * 
 * @author Creed Interactive (Andrew Frederick) 11/23/2021
 */
public class HierarchyErrors {

    public interface HierarchyErrorMessage {
        String getMessage( Map<String, Account[]> errorAccounts, Map<String, Account> accounts );
    }
    
    public class DuplicateParentErrorMessage implements HierarchyErrorMessage {
    
        public DuplicateParentErrorMessage(){

        }
    
        public String getMessage( Map<String, Account[]> errorAccountsByExternalId, Map<String, Account> accountsByExternalId ){
            String message = '<br/><br/>While attempting to build the account hierarchy between parent Customer Account and child ETS Account a duplicate parent was found.';
            message += ' Here is a list of duplicate parent customer accounts to new ETS child accounts: <br/><br/>';
    
            for( String clientNumber : errorAccountsByExternalId.keySet() ){
                message += getMessageDetails( errorAccountsByExternalId.get(clientNumber), accountsByExternalId.get(clientNumber), clientNumber );
            }
            
            return message;
        }
    
        private String getMessageDetails( Account[] duplicateParentAccounts, Account childAccount, String clientNumber ){
            String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
            String childHref = instanceUrl + '/' + childAccount.Id;
    
            String message = '<b>Client Number: ' + clientNumber + '</b><br/>';
            message += 'ETS-Client Account:<br/><a href="' + childHref + '" target="blank">' + childAccount.Name + '</a><br/>';
            message += 'Parent Accounts:<br/>';
    
            for( Account parentAccount : duplicateParentAccounts ){
                String parentHref = instanceUrl + '/' + parentAccount.Id;
                message += '<a href="' + parentHref + '" target="blank">' + parentAccount.Name + '</a><br/>';
            }
            
            return message;
        }
    }

    public class SiblingParentMismatchErrorMessage implements HierarchyErrorMessage {
    
        public SiblingParentMismatchErrorMessage(){

        }
    
        public String getMessage( Map<String, Account[]> errorAccountsByExternalId, Map<String, Account> accountsByExternalId ){
            String message = '<br/><br/>While attempting to build the account hierarchy between parent Customer Account and child ETS Account the system attempted ';
            message += 'to find its parent via its sibling. In the process the child ETS-Client record sibling was matched by either the Customer Unique Association Id ';
            message += 'or Service Type Id. There were several possible sibling accounts found but some of them have different parents.<br/><br/>';
            message += 'Since there were siblings with different parents the system was unable to determine which parent to use. <br/><br/>';
            message += 'Here is a list of child what should be ETS child accounts where the parent could not be determined: <br/><br/>';
    
            for( String customId : errorAccountsByExternalId.keySet() ){
                message += getMessageDetails( errorAccountsByExternalId.get(customId), accountsByExternalId.get(customId) );
            }
            
            return message;
        }
    
        private String getMessageDetails( Account[] siblingAccounts, Account childAccount ){
            String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
            String childHref = instanceUrl + '/' + childAccount.Id;

            String message = '<b>Newly received ETS-Client Account:</b><br/><a href="' + childHref + '" target="blank">' + childAccount.Name + '</a><br/>';
            
            if( childAccount.Customer_Unique_Association_Id__c != null ){
                message += 'Customer Unique Association Id: ' + childAccount.Customer_Unique_Association_Id__c + '<br/>';
            } else
            if( childAccount.Service_Type_Id__c != null ){
                message += 'Service Type Id: ' + childAccount.Service_Type_Id__c + '<br/>';
            }

            message += '<br/>';
            message += '<b>Sibling Accounts:</b><br/>';
            
            Map<Id, Account[]> siblingsByParents = new Map<Id, Account[]>();

            for( Account siblingAccount : siblingAccounts ){
                Id pId = siblingAccount.ParentId;

                if( siblingsByParents.containsKey( pId ) ){
                    siblingsByParents.get( pId ).add( siblingAccount );
                } else {
                    siblingsByParents.put( pId, new Account[]{siblingAccount} );
                }
            }

            for( Id parentId : siblingsByParents.keySet() ){
                String parentHref = instanceUrl + '/' + parentId;

                message += 'Parent Account:<br/>';
                message += '<a href="' + parentHref + '" target="blank">' + siblingsByParents.get(parentId)[0].Parent.Name + '</a><br/><br/>';
                message += 'Matched Siblings:<br/>';
                
                for( Account siblingAccount : siblingsByParents.get(parentId) ){
                    String siblingHref = instanceUrl + '/' + siblingAccount.Id;

                    message += '<a href="' + siblingHref + '" target="blank">' + siblingAccount.Name + '</a><br/>';

                    if( siblingAccount.Customer_Unique_Association_Id__c != null ){
                        message += 'Customer Unique Association Id: ' + siblingAccount.Customer_Unique_Association_Id__c + '<br/>';
                    } else
                    if( siblingAccount.Service_Type_Id__c != null ){
                        message += 'Service Type Id: ' + siblingAccount.Service_Type_Id__c + '<br/>';
                    } 
                }

                message += '<br/>';
            }
         
            return message;
        }
    }

    public class FailedParentCreationErrorMessage {
    
        public FailedParentCreationErrorMessage(){

        }
    
        public String getMessage( Account[] failedParents ){
            String message = '<br/><br/>While attempting to build the account hierarchy between parent Customer Account and child ETS Account the system failed to insert some parent records.';
            message += 'Since the creation of the parent account failed the account record remained a Prospect record. <br/><br/>';
            message += 'Here is a list of child what should be ETS child accounts where the parent failed to be created: <br/><br/>';
    
            for( Account account : failedParents ){
                message += getMessageDetails( account );
            }
            
            return message;
        }
    
        private String getMessageDetails( Account childAccount ){
            String instanceUrl = URL.getOrgDomainUrl().toExternalForm();
            String childHref = instanceUrl + '/' + childAccount.Id;
    
            String message = 'Account:<br/><a href="' + childHref + '" target="blank">' + childAccount.Name + '</a><br/>';
         
            return message;
        }
    }
    
}