import 'dart:convert';
import 'package:chitchat/appstate/variables.dart';
import 'package:http/http.dart' as http;

String baseurl =
    AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
Uri buildURI(endpoint, {required String q, String? state, String? district}) {
  if (state != null && district != null) {
    return (Uri.parse('$endpoint?q=$q&state=$state&district=$district'));
  } else if (state != null) {
    return (Uri.parse('$endpoint?q=$q&state=$state'));
  } else {
    return Uri.parse('$endpoint?q=$q');
  }
}

Future<List<Map<String, dynamic>>> autocompleteSchool(String q,
    {String? state, String? district}) async {
  print("baseurl: $baseurl");
  try {
    final response = await http.get(buildURI('$baseurl/autocomplete/school',
        q: q, state: state, district: district));

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

Future<List<Map<String, dynamic>>> autocompleteUniversity(String q,
    {String? state, String? district}) async {
  print("baseurl: $baseurl");
  try {
    final response = await http.get(buildURI('$baseurl/autocomplete/university',
        q: q, state: state, district: district));

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

Future<List<Map<String, dynamic>>> autocompletecollege(String q,
    {String? state, String? district}) async {
  print("baseurl: $baseurl");
  try {
    final response = await http.get(buildURI('$baseurl/autocomplete/college',
        q: q, state: state, district: district));

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

/// Fetches from both College and University APIs and merges the results
Future<List<Map<String, dynamic>>> autocompleteCollegeAndUniversity(String q,
    {String? state, String? district}) async {
  print("baseurl: $baseurl - fetching from both college and university APIs");
  try {
    // Call both APIs in parallel
    final results = await Future.wait([
      autocompletecollege(q, state: state, district: district),
      autocompleteUniversity(q, state: state, district: district),
    ]);

    final collegeResults = results[0];
    final universityResults = results[1];

    // Normalize university results to match college format for display
    final normalizedUniversity = universityResults.map((item) {
      return {
        'Name of the college': item['Name of the University'] ?? '',
        'Affiliated To University': item['Name of the University'] ?? '',
        'College address': item['Address'] ?? '',
        'State': item['state'] ?? '',
        'type': 'university',
        ...item,
      };
    }).toList();

    // Merge both lists
    final merged = [...collegeResults, ...normalizedUniversity];

    // Remove duplicates based on name (case-insensitive)
    final seen = <String>{};
    final unique = merged.where((item) {
      final name = (item['Name of the college'] ?? '').toString().toLowerCase();
      if (seen.contains(name)) return false;
      seen.add(name);
      return true;
    }).toList();

    return unique;
  } catch (e) {
    print('Error fetching merged college/university APIs: $e');
    return [];
  }
}
