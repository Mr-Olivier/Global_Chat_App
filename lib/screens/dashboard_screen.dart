// import 'package:flutter/material.dart';
// import 'package:flutter/src/widgets/framework.dart';
// import 'package:flutter/src/widgets/placeholder.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:globalchat/providers/userProvider.dart';
// import 'package:globalchat/screens/chatroom_screen.dart';
// import 'package:globalchat/screens/profile_screen.dart';
// import 'package:globalchat/screens/splash_screen.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:provider/provider.dart';

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen> {
//   var user = FirebaseAuth.instance.currentUser;
//   var db = FirebaseFirestore.instance;

//   var scaffoldKey = GlobalKey<ScaffoldState>();

//   List<Map<String, dynamic>> chatroomsList = [];
//   List<String> chatroomsIds = [];

//   void getChatrooms() {
//     db.collection("chatrooms").get().then((dataSnapshot) {
//       for (var singleChatroomData in dataSnapshot.docs) {
//         chatroomsList.add(singleChatroomData.data());
//         chatroomsIds.add(singleChatroomData.id.toString());
//       }

//       setState(() {});
//     });
//   }

//   @override
//   void initState() {
//     getChatrooms();
//     // TODO: implement initState
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     var userProvider = Provider.of<UserProvider>(context);

//     return Scaffold(
//         key: scaffoldKey,
//         appBar: AppBar(
//           title: Text("Global Chat"),
//           leading: InkWell(
//             onTap: () {
//               scaffoldKey.currentState!.openDrawer();
//             },
//             child: Padding(
//               padding: const EdgeInsets.all(6.0),
//               child: CircleAvatar(
//                   radius: 20, child: Text(userProvider.userName[0])),
//             ),
//           ),
//         ),
//         drawer: Drawer(
//             child: Container(
//                 child: Column(children: [
//           SizedBox(height: 50),
//           ListTile(
//             onTap: () async {
//               Navigator.push(context, MaterialPageRoute(builder: (context) {
//                 return ProfileScreen();
//               }));
//             },
//             leading: CircleAvatar(child: Text(userProvider.userName[0])),
//             title: Text(userProvider.userName,
//                 style: TextStyle(fontWeight: FontWeight.bold)),
//             subtitle: Text(userProvider.userEmail),
//           ),
//           ListTile(
//               onTap: () async {
//                 Navigator.push(context, MaterialPageRoute(builder: (context) {
//                   return ProfileScreen();
//                 }));
//               },
//               leading: Icon(Icons.people),
//               title: Text("Profile")),
//           ListTile(
//               onTap: () async {
//                 await FirebaseAuth.instance.signOut();
//                 Navigator.pushAndRemoveUntil(context,
//                     MaterialPageRoute(builder: (context) {
//                   return SplashScreen();
//                 }), (route) {
//                   return false;
//                 });
//               },
//               leading: Icon(Icons.logout),
//               title: Text("Logout"))
//         ]))),
//         body: ListView.builder(
//             itemCount: chatroomsList.length,
//             itemBuilder: (BuildContext context, int index) {
//               String chatroomName = chatroomsList[index]["chatroom_name"] ?? "";

//               return ListTile(
//                 onTap: () {
//                   Navigator.push(context, MaterialPageRoute(builder: (context) {
//                     return ChatroomScreen(
//                       chatroomName: chatroomName,
//                       chatroomId: chatroomsIds[index],
//                     );
//                   }));
//                 },
//                 leading: CircleAvatar(
//                     backgroundColor: Colors.blueGrey[900],
//                     child: Text(
//                       chatroomName[0],
//                       style: TextStyle(color: Colors.white),
//                     )),
//                 title: Text(chatroomName),
//                 subtitle: Text(chatroomsList[index]["desc"] ?? ""),
//               );
//             }));
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:globalchat/providers/userProvider.dart';
import 'package:globalchat/screens/chatroom_screen.dart';
import 'package:globalchat/screens/profile_screen.dart';
import 'package:globalchat/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final db = FirebaseFirestore.instance;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> chatroomsList = [];
  List<String> chatroomsIds = [];

  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;

  // Tab controller for different chat categories
  int _selectedTabIndex = 0;
  final List<String> _tabs = ['All Chats', 'Recent', 'Favorites'];

  @override
  void initState() {
    super.initState();
    getChatrooms();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

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
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> getChatrooms() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dataSnapshot = await db.collection("chatrooms").get();

      final List<Map<String, dynamic>> rooms = [];
      final List<String> ids = [];

      for (var doc in dataSnapshot.docs) {
        final data = doc.data();

        // Get last message for this chatroom
        final lastMessageQuery =
            await db
                .collection("messages")
                .where("chatroom_id", isEqualTo: doc.id)
                .orderBy("timestamp", descending: true)
                .limit(1)
                .get();

        Map<String, dynamic>? lastMessage;
        if (lastMessageQuery.docs.isNotEmpty) {
          lastMessage = lastMessageQuery.docs.first.data();
        }

        // Add more data to the chatroom
        final enhancedData = {
          ...data,
          "last_message": lastMessage,
          "unread_count": 0, // Will be implemented with proper logic
        };

        rooms.add(enhancedData);
        ids.add(doc.id);
      }

      // Sort by last message timestamp (newest first)
      rooms.sort((a, b) {
        final aLastMessage = a["last_message"] as Map<String, dynamic>?;
        final bLastMessage = b["last_message"] as Map<String, dynamic>?;

        final aTimestamp = aLastMessage?["timestamp"] as Timestamp?;
        final bTimestamp = bLastMessage?["timestamp"] as Timestamp?;

        if (aTimestamp == null && bTimestamp == null) {
          return 0;
        } else if (aTimestamp == null) {
          return 1;
        } else if (bTimestamp == null) {
          return -1;
        }

        return bTimestamp.compareTo(aTimestamp);
      });

      // Update state
      setState(() {
        chatroomsList = rooms;
        chatroomsIds = ids;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching chatrooms: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
      } else {
        // Focus on search field
        FocusScope.of(context).requestFocus(FocusNode());
      }
    });

    if (_isSearching) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  List<Map<String, dynamic>> _getFilteredChatrooms() {
    if (_searchQuery.isEmpty) {
      return chatroomsList;
    }

    return chatroomsList.where((chatroom) {
      final name = (chatroom["chatroom_name"] as String?)?.toLowerCase() ?? '';
      final desc = (chatroom["desc"] as String?)?.toLowerCase() ?? '';

      return name.contains(_searchQuery) || desc.contains(_searchQuery);
    }).toList();
  }

  void _createNewChatroom() {
    // Show dialog to create new chatroom
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final descController = TextEditingController();

        return AlertDialog(
          title: const Text('Create New Chatroom'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Chatroom Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
              ),
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  // Create new chatroom
                  final newChatroom = {
                    "chatroom_name": nameController.text,
                    "desc": descController.text,
                    "created_by":
                        Provider.of<UserProvider>(
                          context,
                          listen: false,
                        ).userId,
                    "created_at": FieldValue.serverTimestamp(),
                  };

                  try {
                    final docRef = await db
                        .collection("chatrooms")
                        .add(newChatroom);

                    // Add initial system message
                    await db.collection("messages").add({
                      "text":
                          "Welcome to ${nameController.text}! This chatroom was created by ${Provider.of<UserProvider>(context, listen: false).userName}.",
                      "sender_name": "System",
                      "sender_id": "system",
                      "chatroom_id": docRef.id,
                      "timestamp": FieldValue.serverTimestamp(),
                      "read_by": [],
                    });

                    Navigator.pop(context);

                    // Refresh chatrooms list
                    getChatrooms();

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Chatroom created successfully!')),
                    );
                  } catch (e) {
                    Navigator.pop(context);

                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating chatroom: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final filteredChatrooms = _getFilteredChatrooms();

    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title:
            _isSearching
                ? AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _animationController,
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search chatrooms...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        onChanged: _performSearch,
                      ),
                    );
                  },
                )
                : const Text(
                  "GlobalChat",
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        leading: InkWell(
          onTap: () {
            scaffoldKey.currentState!.openDrawer();
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Hero(
              tag: 'profile_avatar',
              child: CircleAvatar(
                backgroundColor: Colors.deepPurpleAccent,
                child: Text(
                  userProvider.userName.isNotEmpty
                      ? userProvider.userName[0].toUpperCase()
                      : "?",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
        actions: [
          // Search button
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.black87,
            ),
            onPressed: _toggleSearch,
          ),

          // More options button
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => _buildMoreOptionsSheet(),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Tab bar for categories
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.black12, width: 1.0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: List.generate(
                  _tabs.length,
                  (index) => _buildTab(index),
                ),
              ),
            ),
          ),

          // Chatrooms list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredChatrooms.isEmpty
                    ? _buildEmptyState()
                    : AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: filteredChatrooms.length,
                        itemBuilder: (BuildContext context, int index) {
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _buildChatroomItem(
                                  chatroom: filteredChatrooms[index],
                                  chatroomId:
                                      chatroomsIds[chatroomsList.indexOf(
                                        filteredChatrooms[index],
                                      )],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      // FAB for creating new chatroom
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewChatroom,
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (_searchQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No chatrooms found for "$_searchQuery"',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No chatrooms available',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: _createNewChatroom,
            icon: const Icon(Icons.add),
            label: const Text('Create a new chatroom'),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    final isSelected = _selectedTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.deepPurpleAccent : Colors.transparent,
              width: 2.0,
            ),
          ),
        ),
        child: Text(
          _tabs[index],
          style: TextStyle(
            color: isSelected ? Colors.deepPurpleAccent : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildChatroomItem({
    required Map<String, dynamic> chatroom,
    required String chatroomId,
  }) {
    final chatroomName = chatroom["chatroom_name"] as String? ?? "Unnamed";
    final chatroomDesc = chatroom["desc"] as String? ?? "";
    final lastMessage = chatroom["last_message"] as Map<String, dynamic>?;
    final unreadCount = chatroom["unread_count"] as int? ?? 0;

    // Format last message preview
    String lastMessageText = "No messages yet";
    String lastMessageSender = "";
    String timeAgo = "";

    if (lastMessage != null) {
      lastMessageText = lastMessage["text"] as String? ?? "";
      lastMessageSender = lastMessage["sender_name"] as String? ?? "";

      // Limit message preview length
      if (lastMessageText.length > 30) {
        lastMessageText = lastMessageText.substring(0, 30) + "...";
      }

      // Format timestamp
      final timestamp = lastMessage["timestamp"] as Timestamp?;
      if (timestamp != null) {
        timeAgo = _formatTimestamp(timestamp);
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ChatroomScreen(
                    chatroomName: chatroomName,
                    chatroomId: chatroomId,
                  ),
            ),
          ).then((_) {
            // Refresh chatrooms list when returning from chatroom
            getChatrooms();
          });
        },
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.blueGrey[900],
          child: Text(
            chatroomName.isNotEmpty ? chatroomName[0].toUpperCase() : "?",
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chatroomName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (timeAgo.isNotEmpty)
              Text(
                timeAgo,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Expanded(
                child:
                    lastMessageSender.isNotEmpty
                        ? RichText(
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: '$lastMessageSender: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(text: lastMessageText),
                            ],
                          ),
                        )
                        : Text(
                          lastMessageText,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurpleAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    final userProvider = Provider.of<UserProvider>(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header with user info
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.deepPurpleAccent.shade700,
                    Colors.deepPurpleAccent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.deepPurpleAccent.shade200,
                      child: Text(
                        userProvider.userName.isNotEmpty
                            ? userProvider.userName[0].toUpperCase()
                            : "?",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userProvider.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userProvider.userEmail,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            const SizedBox(height: 16),
            _drawerItem(
              icon: Icons.home_outlined,
              title: 'Home',
              isSelected: true,
              onTap: () {
                Navigator.pop(context);
              },
            ),
            _drawerItem(
              icon: Icons.people_outline,
              title: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),
            _drawerItem(
              icon: Icons.star_outline,
              title: 'Favorite Chats',
              onTap: () {
                Navigator.pop(context);
                // To be implemented
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
              },
            ),
            _drawerItem(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () {
                Navigator.pop(context);
                // To be implemented
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
              },
            ),
            _drawerItem(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                // To be implemented
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
              },
            ),

            const Spacer(),

            // Logout option
            _drawerItem(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () async {
                Navigator.pop(context);

                // Show confirmation dialog
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                );

                if (shouldLogout == true) {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SplashScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
            ),

            // App version
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'GlobalChat v1.0.0',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.deepPurpleAccent : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.deepPurpleAccent : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: Colors.deepPurple.withOpacity(0.1),
    );
  }

  Widget _buildMoreOptionsSheet() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sheet header
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Options
          _moreOption(
            icon: Icons.refresh,
            title: 'Refresh Chatrooms',
            onTap: () {
              Navigator.pop(context);
              getChatrooms();
            },
          ),
          _moreOption(
            icon: Icons.add_circle_outline,
            title: 'Create New Chatroom',
            onTap: () {
              Navigator.pop(context);
              _createNewChatroom();
            },
          ),
          _moreOption(
            icon: Icons.sort,
            title: 'Sort Chatrooms',
            onTap: () {
              Navigator.pop(context);
              // To be implemented
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
            },
          ),
          _moreOption(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              Navigator.pop(context);
              // To be implemented
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
            },
          ),
        ],
      ),
    );
  }

  Widget _moreOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepPurpleAccent),
      title: Text(title),
      onTap: onTap,
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();

    // If it's today
    if (now.day == messageTime.day &&
        now.month == messageTime.month &&
        now.year == messageTime.year) {
      // Format as time (e.g., "14:23")
      return '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
    }

    // If it's yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.day == messageTime.day &&
        yesterday.month == messageTime.month &&
        yesterday.year == messageTime.year) {
      return 'Yesterday';
    }

    // If it's within the last week
    if (now.difference(messageTime).inDays < 7) {
      const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekDays[messageTime.weekday - 1];
    }

    // Otherwise, show the date
    return '${messageTime.day}/${messageTime.month}';
  }
}
