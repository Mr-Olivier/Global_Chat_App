// import 'package:flutter/material.dart';
// import 'package:flutter/src/widgets/framework.dart';
// import 'package:flutter/src/widgets/placeholder.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:globalchat/providers/userProvider.dart';
// import 'package:globalchat/screens/edit_profile_screen.dart';
// import 'package:provider/provider.dart';

// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({super.key});

//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends State<ProfileScreen> {
//   Map<String, dynamic>? userData = {};

//   @override
//   Widget build(BuildContext context) {
//     var userProvider = Provider.of<UserProvider>(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(""),
//       ),
//       body: Container(
//         width: double.infinity,
//         child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
//           CircleAvatar(radius: 50, child: Text(userProvider.userName[0])),
//           SizedBox(height: 8),
//           Text(userProvider.userName,
//               style: TextStyle(fontWeight: FontWeight.bold)),
//           SizedBox(height: 8),
//           Text(userProvider.userEmail),
//           ElevatedButton(
//               onPressed: () {
//                 Navigator.push(context, MaterialPageRoute(builder: (context) {
//                   return EditProfileScreen();
//                 }));
//               },
//               child: Text("Edit Profile"))
//         ]),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:globalchat/providers/userProvider.dart';
import 'package:globalchat/screens/edit_profile_screen.dart';
import 'package:globalchat/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final db = FirebaseFirestore.instance;
  Map<String, dynamic>? userData = {};
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Stats
  int _totalMessages = 0;
  int _totalChatrooms = 0;
  List<String> _participatedChatroomIds = [];
  List<Map<String, dynamic>> _recentChatrooms = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _loadUserStats();

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
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Provider.of<UserProvider>(context, listen: false).userId;

      // Get user's message count
      final messagesQuery =
          await db
              .collection("messages")
              .where("sender_id", isEqualTo: userId)
              .get();

      _totalMessages = messagesQuery.docs.length;

      // Extract chatroom IDs
      final Set<String> chatroomIds =
          messagesQuery.docs
              .map((doc) => (doc.data())["chatroom_id"] as String)
              .toSet();

      _totalChatrooms = chatroomIds.length;
      _participatedChatroomIds = chatroomIds.toList();

      // Get recent chatrooms details
      if (_participatedChatroomIds.isNotEmpty) {
        final List<Map<String, dynamic>> recentRooms = [];

        // Get up to 5 most recent chatrooms
        final chatroomsToFetch = _participatedChatroomIds.take(5).toList();

        for (final chatroomId in chatroomsToFetch) {
          final chatroomDoc =
              await db.collection("chatrooms").doc(chatroomId).get();

          if (chatroomDoc.exists) {
            final chatroomData = chatroomDoc.data() as Map<String, dynamic>;

            // Get last message timestamp
            final lastMessageQuery =
                await db
                    .collection("messages")
                    .where("chatroom_id", isEqualTo: chatroomId)
                    .orderBy("timestamp", descending: true)
                    .limit(1)
                    .get();

            Timestamp? lastActivity;
            if (lastMessageQuery.docs.isNotEmpty) {
              lastActivity =
                  lastMessageQuery.docs.first.data()["timestamp"] as Timestamp?;
            }

            recentRooms.add({
              "id": chatroomId,
              "name": chatroomData["chatroom_name"] as String? ?? "Unknown",
              "last_activity": lastActivity,
            });
          }
        }

        // Sort by most recent activity
        recentRooms.sort((a, b) {
          final aTimestamp = a["last_activity"] as Timestamp?;
          final bTimestamp = b["last_activity"] as Timestamp?;

          if (aTimestamp == null && bTimestamp == null) {
            return 0;
          } else if (aTimestamp == null) {
            return 1;
          } else if (bTimestamp == null) {
            return -1;
          }

          return bTimestamp.compareTo(aTimestamp);
        });

        _recentChatrooms = recentRooms;
      }

      setState(() {
        _isLoading = false;
      });

      // Start animation after data is loaded
      _animationController.forward();
    } catch (e) {
      print("Error loading user stats: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Generate a random pastel color for avatars
  Color _getAvatarColor(String seed) {
    final random = Random(seed.hashCode);

    // Generate light color (pastel)
    return Color.fromRGBO(
      200 + random.nextInt(55), // R: 200-255
      200 + random.nextInt(55), // G: 200-255
      200 + random.nextInt(55), // B: 200-255
      1.0,
    );
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userName = userProvider.userName;
    final userEmail = userProvider.userEmail;

    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    expandedHeight: 200.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: Colors.deepPurpleAccent,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.deepPurpleAccent.shade700,
                              Colors.deepPurpleAccent,
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Background pattern
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.1,
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 5,
                                      ),
                                  itemCount: 20,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return Icon(
                                      Icons.chat_bubble_outline,
                                      color: Colors.white,
                                      size: 20,
                                    );
                                  },
                                ),
                              ),
                            ),

                            // User info
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Hero(
                                    tag: 'profile_avatar',
                                    child: CircleAvatar(
                                      radius: 50,
                                      backgroundColor: Colors.white,
                                      child: CircleAvatar(
                                        radius: 48,
                                        backgroundColor: _getAvatarColor(
                                          userName,
                                        ),
                                        child: Text(
                                          userName.isNotEmpty
                                              ? userName[0].toUpperCase()
                                              : "?",
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      // Edit profile button
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          ).then((_) {
                            // Refresh user stats when returning
                            _loadUserStats();
                          });
                        },
                      ),

                      // Sign out button
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Sign Out'),
                                  content: const Text(
                                    'Are you sure you want to sign out?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _signOut();
                                      },
                                      child: const Text('Sign Out'),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Content
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Basic info card
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Basic Information',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _infoItem(
                                      icon: Icons.email_outlined,
                                      title: 'Email',
                                      value: userEmail,
                                    ),
                                    const Divider(),
                                    _infoItem(
                                      icon: Icons.location_on_outlined,
                                      title: 'Country',
                                      value: 'Loading...',
                                      // We'll fetch this from Firestore
                                      isLoading: true,
                                    ),
                                    const Divider(),
                                    _infoItem(
                                      icon: Icons.calendar_today_outlined,
                                      title: 'Member Since',
                                      value:
                                          FirebaseAuth
                                                      .instance
                                                      .currentUser
                                                      ?.metadata
                                                      .creationTime !=
                                                  null
                                              ? '${FirebaseAuth.instance.currentUser!.metadata.creationTime!.day}/${FirebaseAuth.instance.currentUser!.metadata.creationTime!.month}/${FirebaseAuth.instance.currentUser!.metadata.creationTime!.year}'
                                              : 'Unknown',
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Stats section
                            const Text(
                              'Activity Statistics',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Stats cards
                            Row(
                              children: [
                                // Messages count
                                Expanded(
                                  child: _statCard(
                                    title: 'Messages',
                                    value: _totalMessages.toString(),
                                    icon: Icons.message_outlined,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Chatrooms count
                                Expanded(
                                  child: _statCard(
                                    title: 'Chatrooms',
                                    value: _totalChatrooms.toString(),
                                    icon: Icons.chat_outlined,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Recent chatrooms
                            if (_recentChatrooms.isNotEmpty) ...[
                              const Text(
                                'Recent Chatrooms',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              ..._recentChatrooms.map((chatroom) {
                                final name = chatroom["name"] as String;
                                final lastActivity =
                                    chatroom["last_activity"] as Timestamp?;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getAvatarColor(name),
                                      child: Text(
                                        name.isNotEmpty ? name[0] : "?",
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    title: Text(name),
                                    subtitle:
                                        lastActivity != null
                                            ? Text(
                                              'Last active: ${_formatTimestamp(lastActivity)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            )
                                            : null,
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    onTap: () {
                                      // Navigate to chatroom
                                      // To be implemented
                                      Navigator.pop(context);
                                    },
                                  ),
                                );
                              }).toList(),
                            ],

                            const SizedBox(height: 40),

                            // Support options
                            const Text(
                              'Support',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _supportOption(
                              icon: Icons.help_outline,
                              title: 'Help Center',
                              subtitle: 'Get help with GlobalChat',
                              onTap: () {
                                // To be implemented
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Coming soon!')),
                                );
                              },
                            ),

                            _supportOption(
                              icon: Icons.security_outlined,
                              title: 'Privacy Settings',
                              subtitle: 'Manage your privacy',
                              onTap: () {
                                // To be implemented
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Coming soon!')),
                                );
                              },
                            ),

                            _supportOption(
                              icon: Icons.info_outline,
                              title: 'About',
                              subtitle: 'About GlobalChat v1.0.0',
                              onTap: () {
                                // Show about dialog
                                showAboutDialog(
                                  context: context,
                                  applicationName: 'GlobalChat',
                                  applicationVersion: 'v1.0.0',
                                  applicationLegalese: '© 2023 GlobalChat',
                                  children: [
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Connect with people around the world through real-time messaging.',
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 40),

                            // Account actions
                            const Text(
                              'Account',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            _accountOption(
                              icon: Icons.logout,
                              title: 'Sign Out',
                              color: Colors.red,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder:
                                      (context) => AlertDialog(
                                        title: const Text('Sign Out'),
                                        content: const Text(
                                          'Are you sure you want to sign out?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                              _signOut();
                                            },
                                            child: const Text('Sign Out'),
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
                ],
              ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();

    // If it's today, show time only
    if (now.day == messageTime.day &&
        now.month == messageTime.month &&
        now.year == messageTime.year) {
      return 'Today, ${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
    }

    // If it's yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.day == messageTime.day &&
        yesterday.month == messageTime.month &&
        yesterday.year == messageTime.year) {
      return 'Yesterday, ${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
    }

    // Otherwise show date
    return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
  }

  Widget _infoItem({
    required IconData icon,
    required String title,
    required String value,
    bool isLoading = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              isLoading
                  ? const SizedBox(
                    height: 14,
                    width: 100,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepPurpleAccent,
                      ),
                    ),
                  )
                  : Text(value, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2, // Fixed from 'a' to a numeric value
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.deepPurpleAccent),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _accountOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        onTap: onTap,
      ),
    );
  }
}
