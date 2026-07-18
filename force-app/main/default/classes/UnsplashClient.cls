public with sharing class UnsplashClient {
  private static final String SEARCH_ENDPOINT = 'callout:Unsplash_API/search/photos';
  private static final String CALLOUT_PREFIX = 'callout:Unsplash_API';
  private static final String IMAGE_HOST = 'https://images.unsplash.com/';
  private static final String PROFILE_PATTERN = '^https://unsplash\\.com/[@A-Za-z0-9._-]+/?$';
  private static final String DOWNLOAD_PATTERN = '^https://api\\.unsplash\\.com(/photos/[A-Za-z0-9_-]+/download(?:\\?(?:[A-Za-z0-9._~!$&()*+,;=:@/?-]|%[0-9A-Fa-f]{2})*)?)$';
  private static final String ATTRIBUTION_PARAMETERS = '?utm_source=item_purchase_tool&utm_medium=referral';

  public class Photo {
    public String imageUrl { get; private set; }
    public String photographerName { get; private set; }
    public String photographerUrl { get; private set; }
    private String downloadPath;

    private Photo(
      String imageUrl,
      String photographerName,
      String photographerUrl,
      String downloadPath
    ) {
      this.imageUrl = imageUrl;
      this.photographerName = photographerName;
      this.photographerUrl = photographerUrl;
      this.downloadPath = downloadPath;
    }
  }

  public static Photo findPhoto(String itemName) {
    HttpResponse response = sendGet(
      SEARCH_ENDPOINT +
        '?query=' +
        EncodingUtil.urlEncode(itemName, 'UTF-8') +
        '&per_page=1'
    );
    requireSuccess(
      response,
      'Unsplash could not provide an image for this item.'
    );

    Map<String, Object> payload = parsePayload(response.getBody());
    List<Object> results = listValue(payload.get('results'));
    if (results == null || results.isEmpty()) {
      throw new PurchaseToolException(
        'Unsplash did not find an image for this item.'
      );
    }

    Map<String, Object> photo = mapValue(results[0]);
    String imageUrl = valueFromNestedMap(photo, 'urls', 'small');
    String downloadLocation = valueFromNestedMap(
      photo,
      'links',
      'download_location'
    );
    Map<String, Object> user = mapValue(photo, 'user');
    String photographerName = stringValue(
      user == null ? null : user.get('name')
    );
    String profileUrl = valueFromNestedMap(user, 'links', 'html');

    if (
      String.isBlank(imageUrl) ||
      imageUrl.length() > 255 ||
      !imageUrl.startsWith(IMAGE_HOST)
    ) {
      throw new PurchaseToolException(
        'Unsplash returned an unsupported image URL.'
      );
    }
    if (String.isBlank(photographerName) || photographerName.length() > 255) {
      throw new PurchaseToolException(
        'Unsplash returned incomplete photographer attribution.'
      );
    }
    if (
      String.isBlank(profileUrl) ||
      profileUrl.length() + ATTRIBUTION_PARAMETERS.length() > 255 ||
      !Pattern.matches(PROFILE_PATTERN, profileUrl)
    ) {
      throw new PurchaseToolException(
        'Unsplash returned an unsupported photographer URL.'
      );
    }

    if (String.isBlank(downloadLocation) || downloadLocation.length() > 2000) {
      throw new PurchaseToolException(
        'Unsplash returned an unsupported download endpoint.'
      );
    }
    Matcher downloadMatcher = Pattern.compile(DOWNLOAD_PATTERN)
      .matcher(downloadLocation);
    if (!downloadMatcher.matches()) {
      throw new PurchaseToolException(
        'Unsplash returned an unsupported download endpoint.'
      );
    }

    return new Photo(
      imageUrl,
      photographerName,
      profileUrl + ATTRIBUTION_PARAMETERS,
      downloadMatcher.group(1)
    );
  }

  public static void trackDownload(Photo photo) {
    if (photo == null || String.isBlank(photo.downloadPath)) {
      throw new PurchaseToolException(
        'Unsplash image selection could not be registered.'
      );
    }
    HttpResponse response = sendGet(CALLOUT_PREFIX + photo.downloadPath);
    requireSuccess(response, 'Unsplash could not register the selected image.');
  }

  private static HttpResponse sendGet(String endpoint) {
    HttpRequest request = new HttpRequest();
    request.setMethod('GET');
    request.setEndpoint(endpoint);
    request.setHeader('Accept-Version', 'v1');
    request.setTimeout(10000);
    try {
      return new Http().send(request);
    } catch (CalloutException caughtError) {
      throw new PurchaseToolException(
        'Unsplash is currently unavailable. Try again later.'
      );
    }
  }

  private static void requireSuccess(
    HttpResponse response,
    String failureMessage
  ) {
    if (response.getStatusCode() == 429) {
      throw new PurchaseToolException(
        'Unsplash request limit has been reached. Try again later.'
      );
    }
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      throw new PurchaseToolException(failureMessage);
    }
  }

  private static Map<String, Object> parsePayload(String body) {
    Object parsed;
    try {
      parsed = JSON.deserializeUntyped(body);
    } catch (Exception caughtError) {
      throw new PurchaseToolException('Unsplash returned an invalid response.');
    }
    Map<String, Object> payload = mapValue(parsed);
    if (payload == null) {
      throw new PurchaseToolException('Unsplash returned an invalid response.');
    }
    return payload;
  }

  private static String valueFromNestedMap(
    Map<String, Object> source,
    String mapKey,
    String valueKey
  ) {
    Map<String, Object> nested = mapValue(source, mapKey);
    return nested == null ? null : stringValue(nested.get(valueKey));
  }

  private static Map<String, Object> mapValue(
    Map<String, Object> source,
    String key
  ) {
    return source == null ? null : mapValue(source.get(key));
  }

  private static Map<String, Object> mapValue(Object value) {
    try {
      return (Map<String, Object>) value;
    } catch (TypeException caughtError) {
      return null;
    }
  }

  private static List<Object> listValue(Object value) {
    try {
      return (List<Object>) value;
    } catch (TypeException caughtError) {
      return null;
    }
  }

  private static String stringValue(Object value) {
    try {
      return (String) value;
    } catch (TypeException caughtError) {
      return null;
    }
  }
}
