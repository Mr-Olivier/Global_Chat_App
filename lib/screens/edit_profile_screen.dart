// import 'package:flutter/material.dart';
// import 'package:flutter/src/widgets/framework.dart';
// import 'package:flutter/src/widgets/placeholder.dart';
// import 'package:globalchat/providers/userProvider.dart';
// import 'package:provider/provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class EditProfileScreen extends StatefulWidget {
//   const EditProfileScreen({super.key});

//   @override
//   State<EditProfileScreen> createState() => _EditProfileScreenState();
// }

// class _EditProfileScreenState extends State<EditProfileScreen> {
//   Map<String, dynamic>? userData = {};

//   var db = FirebaseFirestore.instance;

//   TextEditingController nameText = TextEditingController();

//   var editProfileForm = GlobalKey<FormState>();
//   @override
//   void initState() {
//     nameText.text = Provider.of<UserProvider>(context, listen: false).userName;
//     // TODO: implement initState
//     super.initState();
//   }

//   void updateData() {
//     Map<String, dynamic> dataToUpdate = {
//       "name": nameText.text,
//     };

//     db
//         .collection("users")
//         .doc(Provider.of<UserProvider>(context, listen: false).userId)
//         .update(dataToUpdate);

//     Provider.of<UserProvider>(context, listen: false).getUserDetails();
//     Navigator.pop(context);
//   }

//   @override
//   Widget build(BuildContext context) {
//     var userProvider = Provider.of<UserProvider>(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Edit Profile"),
//         actions: [
//           InkWell(
//             onTap: () {
//               if (editProfileForm.currentState!.validate()) {
//                 updateData();
//                 // updating of the data on database
//               }
//             },
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Icon(Icons.check),
//             ),
//           )
//         ],
//       ),
//       body: Container(
//         width: double.infinity,
//         child: Padding(
//           padding: const EdgeInsets.all(8.0),
//           child: Form(
//             key: editProfileForm,
//             child: Column(children: [
//               TextFormField(
//                 autovalidateMode: AutovalidateMode.onUserInteraction,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return "Name cannot be empty.";
//                   }
//                 },
//                 controller: nameText,
//                 decoration: InputDecoration(label: Text("Name")),
//               )
//             ]),
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:globalchat/providers/userProvider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  Map<String, dynamic>? userData = {};
  final db = FirebaseFirestore.instance;
  bool _isLoading = false;
  bool _hasChanges = false;

  // Form controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // Avatar options
  final List<Color> avatarColorOptions = [
    Colors.deepPurpleAccent,
    Colors.pinkAccent,
    Colors.blueAccent,
    Colors.tealAccent,
    Colors.amberAccent,
    Colors.deepOrangeAccent,
    Colors.redAccent,
    Colors.greenAccent,
  ];

  int selectedColorIndex = 0;
  final GlobalKey<FormState> editProfileForm = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadUserData();

    // Listen for changes in text fields
    nameController.addListener(_checkIfChanged);
    bioController.addListener(_checkIfChanged);
    countryController.addListener(_checkIfChanged);
    phoneController.addListener(_checkIfChanged);

    // Set status bar color
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    countryController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _checkIfChanged() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    final bool hasNameChanged = nameController.text != userProvider.userName;
    final bool hasBioChanged = bioController.text != (userData?['bio'] ?? '');
    final bool hasCountryChanged =
        countryController.text != (userData?['country'] ?? '');
    final bool hasPhoneChanged =
        phoneController.text != (userData?['phone'] ?? '');

    final bool newHasChanges =
        hasNameChanged ||
        hasBioChanged ||
        hasCountryChanged ||
        hasPhoneChanged ||
        selectedColorIndex != (userData?['avatar_color_index'] ?? 0);

    if (newHasChanges != _hasChanges) {
      setState(() {
        _hasChanges = newHasChanges;
      });
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Provider.of<UserProvider>(context, listen: false).userId;
      final doc = await db.collection("users").doc(userId).get();

      if (doc.exists) {
        setState(() {
          userData = doc.data();

          // Initialize controllers with current values
          nameController.text = userData?['name'] ?? '';
          bioController.text = userData?['bio'] ?? '';
          countryController.text = userData?['country'] ?? '';
          phoneController.text = userData?['phone'] ?? '';
          selectedColorIndex = userData?['avatar_color_index'] ?? 0;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!editProfileForm.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Provider.of<UserProvider>(context, listen: false).userId;

      // Data to update
      final Map<String, dynamic> dataToUpdate = {
        'name': nameController.text,
        'bio': bioController.text,
        'country': countryController.text,
        'phone': phoneController.text,
        'avatar_color_index': selectedColorIndex,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await db.collection("users").doc(userId).update(dataToUpdate);

      // Update the provider
      Provider.of<UserProvider>(context, listen: false).getUserDetails();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      // Reset changes flag
      setState(() {
        _hasChanges = false;
      });

      // Go back to previous screen
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        actions: [
          // Save button
          _hasChanges
              ? _isLoading
                  ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                  : IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _updateProfile,
                    tooltip: 'Save Changes',
                  )
              : const IconButton(
                icon: Icon(Icons.check, color: Colors.grey),
                onPressed: null,
                tooltip: 'No Changes',
              ),
        ],
        elevation: 0,
      ),
      body:
          _isLoading && userData == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Form(
                  key: editProfileForm,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar preview and selection
                        _buildAvatarSection(),

                        const SizedBox(height: 32),

                        // Name field
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Name cannot be empty';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Bio field
                        TextFormField(
                          controller: bioController,
                          decoration: const InputDecoration(
                            labelText: 'Bio',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.info_outline),
                            hintText: 'Tell us about yourself',
                          ),
                          maxLines: 3,
                        ),

                        const SizedBox(height: 16),

                        // Country field
                        TextFormField(
                          controller: countryController,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Country cannot be empty';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Phone field
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone_outlined),
                            hintText: 'e.g. +1 234 567 8901',
                          ),
                          keyboardType: TextInputType.phone,
                        ),

                        const SizedBox(height: 32),

                        // Privacy settings section
                        _buildPrivacySection(),

                        const SizedBox(height: 32),

                        // Save button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurpleAccent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed:
                                _hasChanges && !_isLoading
                                    ? _updateProfile
                                    : null,
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text(
                                      'Save Changes',
                                      style: TextStyle(fontSize: 16),
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildAvatarSection() {
    return Column(
      children: [
        // Current avatar preview
        Hero(
          tag: 'profile_avatar_edit',
          child: CircleAvatar(
            radius: 60,
            backgroundColor: avatarColorOptions[selectedColorIndex],
            child: Text(
              nameController.text.isNotEmpty
                  ? nameController.text[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Color options
        const Text(
          'Choose Avatar Color',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 12),

        // Color picker
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: avatarColorOptions.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final isSelected = index == selectedColorIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedColorIndex = index;
                  });
                  _checkIfChanged();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: avatarColorOptions[index],
                    shape: BoxShape.circle,
                    border:
                        isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                            : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        // These switches don't update the database yet - functionality to be added
        SwitchListTile(
          title: const Text('Show online status'),
          subtitle: const Text('Allow others to see when you are online'),
          value: userData?['show_online_status'] ?? true,
          onChanged: (value) {
            setState(() {
              userData = {...userData!, 'show_online_status': value};
              _hasChanges = true;
            });
          },
        ),

        SwitchListTile(
          title: const Text('Show read receipts'),
          subtitle: const Text(
            'Let others know when you have read their messages',
          ),
          value: userData?['show_read_receipts'] ?? true,
          onChanged: (value) {
            setState(() {
              userData = {...userData!, 'show_read_receipts': value};
              _hasChanges = true;
            });
          },
        ),
      ],
    );
  }
}
