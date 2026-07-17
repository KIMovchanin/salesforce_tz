public with sharing class ItemCatalogService {
  private static final Integer MAX_SEARCH_LENGTH = 100;
  private static final Integer MAX_RESULTS = 500;

  public static List<Item__c> search(
    String family,
    String type,
    String searchTerm
  ) {
    String normalizedFamily = normalize(family);
    String normalizedType = normalize(type);
    String normalizedSearch = normalize(searchTerm);

    if (
      normalizedSearch != null &&
      normalizedSearch.length() > MAX_SEARCH_LENGTH
    ) {
      throw new PurchaseToolException(
        'Search text cannot exceed 100 characters.'
      );
    }

    List<String> conditions = new List<String>();
    Map<String, Object> bindValues = new Map<String, Object>();

    if (normalizedFamily != null) {
      conditions.add('Family__c = :family');
      bindValues.put('family', normalizedFamily);
    }
    if (normalizedType != null) {
      conditions.add('Type__c = :type');
      bindValues.put('type', normalizedType);
    }
    if (normalizedSearch != null) {
      conditions.add(
        '(Name LIKE :searchPattern OR Description__c LIKE :searchPattern)'
      );
      bindValues.put('searchPattern', '%' + normalizedSearch + '%');
    }

    String query =
      'SELECT Id, Name, Description__c, Type__c, Family__c, Image__c, Price__c, AvailableQuantity__c ' +
      'FROM Item__c';
    if (!conditions.isEmpty()) {
      query += ' WHERE ' + String.join(conditions, ' AND ');
    }
    query += ' ORDER BY Name LIMIT ' + MAX_RESULTS;

    return Database.queryWithBinds(query, bindValues, AccessLevel.USER_MODE);
  }

  public static Map<String, List<String>> getFilterOptions() {
    if (
      !Item__c.Type__c.getDescribe().isAccessible() ||
      !Item__c.Family__c.getDescribe().isAccessible()
    ) {
      throw new PurchaseToolException(
        'You do not have access to item filters.'
      );
    }

    return new Map<String, List<String>>{
      'types' => activePicklistValues(Item__c.Type__c.getDescribe()),
      'families' => activePicklistValues(Item__c.Family__c.getDescribe())
    };
  }

  private static List<String> activePicklistValues(
    Schema.DescribeFieldResult fieldDescription
  ) {
    List<String> values = new List<String>();
    for (Schema.PicklistEntry entry : fieldDescription.getPicklistValues()) {
      if (entry.isActive()) {
        values.add(entry.getValue());
      }
    }
    return values;
  }

  private static String normalize(String value) {
    return String.isBlank(value) ? null : value.trim();
  }
}
