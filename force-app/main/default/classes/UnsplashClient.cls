public with sharing class UnsplashClient {
  private static final String ENDPOINT = 'callout:Unsplash_API/search/photos';
  private static final String IMAGE_HOST = 'https://images.unsplash.com/';

  public static String findImageUrl(String itemName) {
    HttpRequest request = new HttpRequest();
    request.setMethod('GET');
    request.setEndpoint(
      ENDPOINT +
        '?query=' +
        EncodingUtil.urlEncode(itemName, 'UTF-8') +
        '&per_page=1'
    );
    request.setTimeout(10000);

    HttpResponse response;
    try {
      response = new Http().send(request);
    } catch (CalloutException caughtError) {
      throw new PurchaseToolException(
        'Unsplash is currently unavailable. Try again later.'
      );
    }

    if (response.getStatusCode() == 429) {
      throw new PurchaseToolException(
        'Unsplash request limit has been reached. Try again later.'
      );
    }
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      throw new PurchaseToolException(
        'Unsplash could not provide an image for this item.'
      );
    }

    Map<String, Object> payload;
    try {
      payload = (Map<String, Object>) JSON.deserializeUntyped(
        response.getBody()
      );
    } catch (JSONException caughtError) {
      throw new PurchaseToolException('Unsplash returned an invalid response.');
    }

    List<Object> results = (List<Object>) payload.get('results');
    if (results == null || results.isEmpty()) {
      throw new PurchaseToolException(
        'Unsplash did not find an image for this item.'
      );
    }

    Map<String, Object> photo = (Map<String, Object>) results[0];
    Map<String, Object> urls = (Map<String, Object>) photo.get('urls');
    String imageUrl = urls == null ? null : (String) urls.get('small');
    if (String.isBlank(imageUrl) || !imageUrl.startsWith(IMAGE_HOST)) {
      throw new PurchaseToolException(
        'Unsplash returned an unsupported image URL.'
      );
    }
    return imageUrl;
  }
}
