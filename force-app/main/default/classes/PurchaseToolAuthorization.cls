public with sharing class PurchaseToolAuthorization {
  public static Boolean isCurrentUserManager() {
    List<User> users = [
      SELECT IsManager__c
      FROM User
      WHERE Id = :UserInfo.getUserId()
      WITH USER_MODE
      LIMIT 1
    ];
    return !users.isEmpty() && users[0].IsManager__c;
  }
}
