import 'package:http/http.dart' as http;

class Submit {
  void post(String json, String url) {
    http.post(url, body: json).then((response) {
      print("Response status: ${response.statusCode}");
      print("Response status: ${response.body}");
    });
  }
}
