import 'package:http/http.dart' as http;
import 'dart:async';

class Submit {
  String responseBody;
  int statusCode;
  Completer<Response> completer = new Completer<Response>();
  Future<Response> post(String json, String url) async {
    http.post(url, body: json).then((response) {
      Response r = new Response(response.statusCode, response.body);
      completer.complete(r);
    });
    return completer.future;
  }
}

class Response {
  String responseBody;
  int statusCode;
  Response(int code, String body) {
    responseBody = body;
    statusCode = code;
  }
}
