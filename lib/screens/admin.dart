import 'package:cached_network_image/cached_network_image.dart';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/services/user.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:page_transition/page_transition.dart';

class AdminLoginPage extends StatefulWidget {
  @override
  _AdminLoginPageState createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  String baseUrl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
  bool isLoading = false;
  List<dynamic>? _users;
  List<dynamic>? _filteredUsers;
  final _searchController = TextEditingController();
  String? _adminToken;
  void _checkAdminToken() async {
    setState(() => isLoading = true);

    String? token = await AppVariables.get<String>('adminToken');
    print('Admin token: $token');
    if (token != null) {
      setState(() {
        _adminToken = token;
      });
      await fetchUsers(token);
    }
    setState(() => isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _checkAdminToken();
    _searchController.addListener(_filterUsers);
  }

  void _filterUsers() {
    if (_users != null) {
      final query = _searchController.text.toLowerCase();
      setState(() {
        _filteredUsers = _users!.where((user) {
          final name = (user['name'] ?? '').toLowerCase();
          final email = (user['email'] ?? '').toLowerCase();
          return name.contains(query) || email.contains(query);
        }).toList();
      });
    }
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': emailController.text,
          'password': passwordController.text,
        }),
      );
      print(response.body);
      if (response.statusCode == 200) {
        final loginData = jsonDecode(response.body);
        _adminToken = loginData['token'];
        AppVariables.update('adminToken', _adminToken);

        await fetchUsers(_adminToken!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed')),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchUsers(String adminToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/users'),
        headers: {'admin-token': "Bearer $adminToken"},
      );

      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _filteredUsers = _users;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching users: $e')),
      );
    }
  }

  Future<void> _loginAsUser(Map<String, dynamic> user) async {
    final userToken = user['accessToken'];
    final userId = user['_id'];

    if (userToken == null || userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User data is missing access token or ID.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await UserService.clearUserData();
      await UserService.setAccessToken(userToken);
      await UserService.setUserId(userId);
      await UserService.setLoggedIn(true);
      await UserService.fetchMyProfile();

      Navigator.pushReplacement(
        context,
        PageTransition(
          isIos: true,
          type: PageTransitionType.leftToRight,
          child: HomePage(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to login as user: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Panel')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : _users == null
              ? _buildLoginForm()
              : _buildUserList(),
    );
  }

  Widget _buildLoginForm() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: emailController,
            decoration: InputDecoration(labelText: 'Email'),
          ),
          SizedBox(height: 16),
          TextField(
            controller: passwordController,
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: login,
            child: Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search by name or email',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(25.0)),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredUsers?.length ?? 0,
            itemBuilder: (context, index) {
              final user = _filteredUsers![index];
              return ListTile(
                leading: CircleAvatar(
                  child: CachedNetworkImage(imageUrl: user['profilePic'] ?? ''),
                ),
                title: Text(user['name'] ?? 'No Name'),
                subtitle: Text(user['email'] ?? 'No Email'),
                onTap: () => _loginAsUser(user),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
