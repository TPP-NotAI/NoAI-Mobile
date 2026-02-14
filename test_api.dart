import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final baseUrl = 'https://noai-lm-production.up.railway.app';

  print('--- API TEST START ---');
  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$baseUrl/api/v1/detect/text'),
  );
  request.fields['content'] =
      "As an AI language model, I am designed to assist users with their queries and provide helpful information. My training data includes a vast amount of text from the internet, which allows me to understand and generate human-like responses across a wide range of topics.";
  request.fields['models'] = 'gpt-5.2,o3';

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  print('STATUS: ${response.statusCode}');
  print('RAW_BODY_START');
  print(response.body);
  print('RAW_BODY_END');
  print('--- API TEST END ---');
}
