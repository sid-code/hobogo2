import 'package:http/http.dart' as http;

class Submit {
  String post(String json, String url) {
    http.post(url, body: json).then((response) {
      print("Response status: ${response.statusCode}");
      print("Response status: ${response.body}");
      if(response.statusCode == 200){
        return response.body;
      } else {
        return response.statusCode;
      }
    });
  }
}
