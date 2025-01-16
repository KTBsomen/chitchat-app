import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:chitchat/appstate/variables.dart';
import 'package:chitchat/components/friendcircle.dart';
import 'package:chitchat/main.dart';
import 'package:chitchat/screens/home.dart';
import 'package:chitchat/screens/recomandedgroups.dart';
import 'package:chitchat/services/autocomplete.dart';
import 'package:chitchat/services/fileUploader.dart';
import 'package:chitchat/services/user.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:page_transition/page_transition.dart';

import '../components/AdvancedTextFormField.dart';

import 'profilePrivet.dart';
import 'profilePublic.dart';

import 'package:http/http.dart' as http;

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formKeys2 = GlobalKey<FormState>();
  final _formKeys3 = GlobalKey<FormState>();

  int _stepIndex = 0;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();
  String? _name, _birthday, _username, _educationalBackground, _profilePicPath;
  String? _school, _college, _university, _class, _semester, _year;
  bool _isUsernameValid = false;
  bool _isCheckingUsername = false;
  Timer? _debounce; // Simulate API call for username validation
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
    ),
  );
  bool _canProcess = true;
  bool _isBusy = false;

  Future<void> checkUsername(String username) async {
    setState(() => _isCheckingUsername = true);

    try {
      final response = await http.get(
        Uri.parse('$baseurl/check/username?username=$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isUsernameValid = data['valid'];
          _isCheckingUsername = false;
        });
      } else {
        setState(() {
          _isUsernameValid = false;
          _isCheckingUsername = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUsernameValid = false;
        _isCheckingUsername = false;
      });
    }
  }

  void _nextStep() {
    if ((_stepIndex == 0 && _formKey.currentState!.validate()) ||
        (_stepIndex == 1 && _formKeys2.currentState!.validate()) ||
        (_stepIndex == 2 && _formKeys3.currentState!.validate())) {
      if (_stepIndex == 0) _formKey.currentState!.save();
      if (_stepIndex == 1) _formKeys2.currentState!.save();
      if (_stepIndex == 2) _formKeys3.currentState!.save();
      setState(() => _stepIndex++);
    }
  }

  void _previousStep() {
    setState(() => _stepIndex--);
  }

  // Pick image with ImagePicker
  Future<void> _pickProfilePic() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profilePicPath = pickedFile.path);

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      bool faceDetected = faces.isNotEmpty;
      if (!faceDetected) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("Face not detected! For better reach, use a face photo."),
          backgroundColor: Colors.orange,
        ));
      }
    }
  }

  S3Uploader? uploader;

  String baseurl =
      AppVariables.get<String>('baseurl')!.trim() ?? 'http://localhost:3000';
  ValueNotifier<FileUploadProgress> _progressNotifier =
      ValueNotifier<FileUploadProgress>(
    FileUploadProgress(fileName: 'Uploading...'),
  );

  @override
  void initState() {
    super.initState();
    uploader = S3Uploader(
      presignedUrlEndpoint: "$baseurl/api/get-batch-upload-urls",
      progressNotifier: _progressNotifier,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      GoogleSignInAccount? googleUser =
          AppVariables.get<GoogleSignInAccount>('userProfile');
      if (googleUser == null) {
        // Handle the case where the user is not signed in
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Not Signed In'),
              content: const Text('Please sign in to continue'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                ),
              ],
            );
          },
        );
      }
    });
  }

  // Submit the form
  void _submitForm() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Registering...'),
          content: UploadProgressWidget(progressNotifier: _progressNotifier),
          actions: <Widget>[
            TextButton(
              child: const Text('ok'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    GoogleSignInAccount? googleUser =
        AppVariables.get<GoogleSignInAccount>('userProfile');
    List<String?> value = [googleUser?.photoUrl];
    if (_profilePicPath != null) {
      // Upload image to S3
      value = await uploader!.uploadFiles(
          files: [_profilePicPath],
          compressionParams: {'width': 100, 'quality': 100},
          showPresignedUrlProgress: true);
      print("Image uploaded to S3: $value");
    }
    print("googleUser: ${googleUser?.email}");
    final formData = {
      "name": _name,
      "email": googleUser?.email,
      "birthday": _birthday,
      "username": _username,
      "educationLevel": _educationalBackground,
      "school": _school,
      "college": _college,
      "university": _university,
      "userClass": _class,
      "semester": _semester,
      "year": _year,
      "profilePic": value[0] ?? googleUser?.photoUrl,
      "role": "appTest",
      "fcmToken": AppVariables.get("fcmToken") ?? "",
    };

    // Replace this with your POST API call
    print("Submitting form: $formData");
    http.Response response = await http.post(
      Uri.parse('$baseurl/register'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(formData),
    );
    print("Response: ${response.body}");
    if (response.statusCode == 201) {
      print("Registration successful");
      print("Response: ${response.body}");
      print("Response: ${response.body}");
      // If the server returns an OK response, parse the JSON
      final data = jsonDecode(response.body);
      Map<String, dynamic> user = data['user'] as Map<String, dynamic>;
      print("User: $user");
      await UserService.setAccessToken(data['token']);
      await UserService.setUserId(user['_id']);
      AppVariables.update("serverProfile", user);

      // Registration successful
      Navigator.pushReplacement(
        context,
        PageTransition(
            child: Recomandedgroups(), type: PageTransitionType.bottomToTop),
      );
    } else {
      // Registration failed

      _progressNotifier.value = _progressNotifier.value.copyWith(
          stage: UploadStage.failed,
          errorMessage: jsonDecode(response.body)["error"]);
      print("Registration failed");
      print("Response: ${response.body}");
    }
  }

  Widget schoolNameWidget(BuildContext context) {
    return AdvancedTextFormField(
      debounceDuration: Duration(milliseconds: 800),
      autoFillOnSelection: false,
      asyncSuggestions: (p0) async {
        print(p0);
        return autocompleteSchool(p0);
      },
      validator: (value) => value!.isEmpty ? "School Name is required" : null,
      suggestionBuilder: (context, suggestion) {
        print(suggestion.runtimeType);
        return ListTile(
          title: Text(
            suggestion["school_name"],
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            "${suggestion["village"]}, ${suggestion["block"]}, ${suggestion["district"]}, ${suggestion["state"]}",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.black54,
              height: 1.2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        );
      },
      decoration: const InputDecoration(labelText: "School Name"),
      onSelected: (p0, p1) {
        p1.text = p0["school_name"];
        _school = p0["school_name"];
        print("Selected: $p0");
      },
    );
  }

  Widget collegeNameWidget(BuildContext context) {
    return AdvancedTextFormField(
      decoration: const InputDecoration(labelText: "College Name"),
      debounceDuration: Duration(milliseconds: 800),
      autoFillOnSelection: false,
      asyncSuggestions: (p0) async {
        print(p0);
        return autocompleteSchool(p0);
      },
      validator: (value) => value!.isEmpty ? "College Name is required" : null,
      suggestionBuilder: (context, suggestion) {
        print(suggestion.runtimeType);
        return ListTile(
          title: Text(
            suggestion["school_name"],
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            "${suggestion["village"]}, ${suggestion["block"]}, ${suggestion["district"]}, ${suggestion["state"]}",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.black54,
              height: 1.2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        );
      },
      onSelected: (value, controller) {
        controller.text = value["school_name"];
        _college = value["school_name"];
      },
    );
  }

  Widget universityNameWidget(BuildContext context) {
    return AdvancedTextFormField(
      decoration: const InputDecoration(labelText: "University Name"),
      onSaved: (value) => _university = value,
      debounceDuration: Duration(milliseconds: 800),
      autoFillOnSelection: false,
      asyncSuggestions: (p0) async {
        print(p0);
        return autocompleteUniversity(p0);
      },
      validator: (value) =>
          value!.isEmpty ? "University Name is required" : null,
      suggestionBuilder: (context, suggestion) {
        print(suggestion.runtimeType);
        return ListTile(
          title: Text(
            suggestion["Name of the University"],
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            "${suggestion["Address"]}, ${suggestion["state"]}, ${suggestion["Zip"]}",
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.black54,
              height: 1.2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
        );
      },
      onSelected: (value, controller) {
        controller.text = value["Name of the University"];
        _university = value["Name of the University"];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        cardTheme: CardTheme(
          color: const Color.fromARGB(67, 66, 66, 66),
          elevation: 10,
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 12, 12, 38),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color.fromARGB(255, 85, 0, 150),
          unselectedItemColor: Colors.grey,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 12, 12, 38),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 1, 1, 186),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(
                  height: 20,
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 600),
                    style: TextStyle(
                      fontSize: _stepIndex == 3 ? 20 : 30,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: Colors.white,
                    ),
                    child: Text(
                      _stepIndex == 3
                          ? "You are all set! \nJust submit now."
                          : "Just some little details about you",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
                Stepper(
                  physics: ClampingScrollPhysics(),
                  elevation: 3,
                  currentStep: _stepIndex,
                  onStepContinue: _stepIndex < 3 ? _nextStep : _submitForm,
                  onStepCancel: _stepIndex > 0 ? _previousStep : null,
                  steps: [
                    // Step 1: Basic Info
                    Step(
                      label: const Text(
                        "Basic Info",
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 18),
                      ),
                      title: const Text(
                        "Basic Info",
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 18),
                      ),
                      isActive: _stepIndex >= 0,
                      content: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              decoration:
                                  const InputDecoration(labelText: "Name"),
                              validator: (value) => value!.isEmpty ||
                                      value.length < 3
                                  ? "Name is required and must be 3 characters long "
                                  : null,
                              onChanged: (value) => _name = value,
                              autofocus: true,
                            ),
                            TextFormField(
                              controller: _birthdayController,
                              decoration: const InputDecoration(
                                  labelText: "Birthday",
                                  hintText: "DD/MM/YYYY",
                                  suffixIcon: Icon(Icons.calendar_today)),
                              keyboardType: TextInputType.datetime,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return "Birthday is required";
                                }
                                try {
                                  List<String> parts = value.split('/');
                                  if (parts.length != 3)
                                    return "Invalid date format";

                                  int day = int.parse(parts[0]);
                                  int month = int.parse(parts[1]);
                                  int year = int.parse(parts[2]);

                                  DateTime date = DateTime(year, month, day);
                                  if (date.isAfter(DateTime.now())) {
                                    return "Birthday cannot be in the future";
                                  }
                                  if (date.isBefore(DateTime(1900))) {
                                    return "Birthday cannot be before 1900";
                                  }
                                  return null;
                                } catch (e) {
                                  return "Invalid date format";
                                }
                              },
                              onChanged: (value) => _birthday = value,
                              readOnly: true,
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                print(picked);
                                if (picked != null) {
                                  _birthday =
                                      "${picked.day}/${picked.month}/${picked.year}";
                                  _birthdayController.text = _birthday!;
                                }
                              },
                            ),
                            TextFormField(
                              controller: _usernameController,
                              validator: (value) {
                                if (_isCheckingUsername) {
                                  return "Checking UserName availability...";
                                }
                                if (value!.isEmpty) {
                                  return "UserName is required";
                                }
                                if (!_isUsernameValid) {
                                  return "Username is not available";
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: "Username",
                                hintStyle: TextStyle(
                                  color:
                                      const Color.fromARGB(199, 158, 158, 158),
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                ),
                                hintText:
                                    "try ${AppVariables.get<GoogleSignInAccount>("userProfile")?.email.split('@')[0]} Or instagram id" ??
                                        "Use instagram username",
                                suffixIcon: _isCheckingUsername
                                    ? const CircularProgressIndicator()
                                    : Icon(
                                        _isUsernameValid
                                            ? Icons.check
                                            : Icons.error,
                                        color: _isUsernameValid
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                              ),
                              onChanged: (value) {
                                _username = value;
                                if (_debounce?.isActive ?? false) {
                                  _debounce!.cancel();
                                }
                                _debounce = Timer(
                                    const Duration(milliseconds: 500), () {
                                  checkUsername(value);
                                });
                              },
                              onSaved: (newValue) => _username = newValue!,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Step 2: Educational Background
                    Step(
                      title: const Text(
                        "Education",
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 18),
                      ),
                      isActive: _stepIndex >= 1,
                      content: Form(
                        key: _formKeys2,
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                  labelText: "Educational Background"),
                              items: [
                                "School",
                                "College",
                                "University",
                                "Passout"
                              ]
                                  .map((e) => DropdownMenuItem(
                                      value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (value) => setState(
                                  () => _educationalBackground = value),
                              onSaved: (value) =>
                                  _educationalBackground = value,
                            ),
                            if (_educationalBackground == "School")
                              Column(
                                children: [
                                  TextFormField(
                                    decoration: const InputDecoration(
                                        labelText: "Class"),
                                    onChanged: (value) => _class = value,
                                    onSaved: (value) => _class = value,
                                  ),
                                  schoolNameWidget(context)
                                ],
                              ),
                            if (_educationalBackground == "University" ||
                                _educationalBackground == "College")
                              Column(
                                children: [
                                  TextFormField(
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Please enter your Semester";
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                        labelText: "Semester"),
                                    onChanged: (value) => _semester = value,
                                  ),
                                  collegeNameWidget(context),
                                  schoolNameWidget(context)
                                ],
                              ),
                            if (_educationalBackground == "Passout")
                              Column(
                                children: [
                                  TextFormField(
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Please enter Year";
                                      }
                                      return null;
                                    },
                                    decoration: const InputDecoration(
                                        labelText: "Year"),
                                    onChanged: (value) => _year = value,
                                    onSaved: (value) => _year = value,
                                  ),
                                  universityNameWidget(context),
                                  collegeNameWidget(context),
                                  schoolNameWidget(context)
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Step 3: Profile Picture
                    Step(
                      title: const Text(
                        "Profile Picture",
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 18),
                      ),
                      isActive: _stepIndex >= 2,
                      content: Form(
                        key: _formKeys3,
                        child: Column(
                          children: [
                            if (_profilePicPath != null)
                              Image.file(File(_profilePicPath!), height: 150),
                            ElevatedButton(
                              onPressed: _pickProfilePic,
                              child: const Text("Upload Profile Picture"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Step 4: Review & Submit
                    Step(
                      title: const Text(
                        "Review",
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 18),
                      ),
                      isActive: _stepIndex >= 3,
                      content: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundImage: _profilePicPath != null
                                        ? FileImage(File(_profilePicPath!))
                                        : null,
                                    child: _profilePicPath == null
                                        ? const Icon(Icons.person, size: 50)
                                        : null,
                                  ),
                                  const SizedBox(
                                    height: 16,
                                    width: 16,
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        _name ?? '',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      Text(
                                        '@${_username ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                      Text(
                                        '🎂${_birthday ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Educational Details',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_school != null)
                                ListTile(
                                  leading: const Icon(Icons.school),
                                  title: Text('School: ${_school!}'),
                                ),
                              if (_college != null)
                                ListTile(
                                  leading: const Icon(Icons.school),
                                  title: Text('College: ${_college!}'),
                                ),
                              if (_university != null)
                                ListTile(
                                  leading: const Icon(Icons.school),
                                  title: Text('University: ${_university!}'),
                                ),
                              if (_year != null)
                                ListTile(
                                  leading: const Icon(Icons.school),
                                  title: Text('Year: ${_year!}'),
                                ),
                              const SizedBox(height: 16),
                              // ElevatedButton(
                              //   onPressed: () {
                              //     // Handle submit action here
                              //   },
                              //   child: const Text("Submit"),
                              // ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  controlsBuilder: (context, details) {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: <Widget>[
                              ElevatedButton(
                                style: _stepIndex >= 3
                                    ? ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(
                                            255, 5, 191, 17),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      )
                                    : ElevatedButton.styleFrom(
                                        backgroundColor: const Color.fromARGB(
                                            255, 1, 1, 186),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                onPressed: details.onStepContinue,
                                child: _stepIndex < 3
                                    ? const Text('NEXT')
                                    : const Text('SUBMIT'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: details.onStepCancel,
                                child: const Text('BACK'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
