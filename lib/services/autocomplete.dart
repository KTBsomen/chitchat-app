import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:http/http.dart' as http;

String baseurl =
    AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';

Future<List<Map<String, dynamic>>> autocompleteSchool(String q) async {
  print("baseurl: $baseurl");
  try {
    final response =
        await http.get(Uri.parse('$baseurl/autocomplete/school?q=$q'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load APIs: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching APIs: $e');
    return [];
  }
}

Future<List<Map<String, dynamic>>> autocompleteUniversity(String q) async {
  print("baseurl: $baseurl");
  try {
    final response =
        await http.get(Uri.parse('$baseurl/autocomplete/university?q=$q'));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } else {
      throw Exception('Failed to load APIs: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching APIs: $e');
    return [];
  }
}
