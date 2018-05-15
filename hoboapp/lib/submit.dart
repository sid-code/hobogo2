import 'package:http/http.dart' as http;

class Submit {
  String body;
  int statusCode;
  //wow hacky idk how to use futures and NO DOCS ON THIS PACKAGE
  bool done = false;
  void post(String json, String url) {
    done = false;
    http.post(url, body: json).then((response) {
      print("Response status: ${response.statusCode}");
      print("Response status: ${response.body}");
      body = response.body;
      statusCode = response.statusCode;
      done = true;
    });
  }
}
