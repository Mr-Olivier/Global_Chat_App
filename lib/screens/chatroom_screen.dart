// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/src/widgets/framework.dart';
// import 'package:flutter/src/widgets/placeholder.dart';
// import 'package:globalchat/providers/userProvider.dart';
// import 'package:provider/provider.dart';

// class ChatroomScreen extends StatefulWidget {
//   String chatroomName;
//   String chatroomId;

//   ChatroomScreen({
//     super.key,
//     required this.chatroomName,
//     required this.chatroomId,
//   });

//   @override
//   State<ChatroomScreen> createState() => _ChatroomScreenState();
// }

// class _ChatroomScreenState extends State<ChatroomScreen> {
//   var db = FirebaseFirestore.instance;

//   TextEditingController messageText = TextEditingController();

//   Future<void> sendMessage() async {
//     if (messageText.text.isEmpty) {
//       return;
//     }
//     Map<String, dynamic> messageToSend = {
//       "text": messageText.text,
//       "sender_name": Provider.of<UserProvider>(context, listen: false).userName,
//       "sender_id": Provider.of<UserProvider>(context, listen: false).userId,
//       "chatroom_id": widget.chatroomId,
//       "timestamp": FieldValue.serverTimestamp(),
//     };
//     messageText.text = "";

//     try {
//       await db.collection("messages").add(messageToSend);
//     } catch (e) {}
//   }

//   Widget singleChatItem({
//     required String sender_name,
//     required String text,
//     required String sender_id,
//   }) {
//     return Column(
//       crossAxisAlignment:
//           sender_id == Provider.of<UserProvider>(context, listen: false).userId
//               ? CrossAxisAlignment.end
//               : CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.only(left: 6.0, right: 6),
//           child: Text(
//             sender_name,
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//         ),
//         Container(
//           decoration: BoxDecoration(
//             color:
//                 sender_id ==
//                         Provider.of<UserProvider>(context, listen: false).userId
//                     ? Colors.grey[300]
//                     : Colors.blueGrey[900],
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(12.0),
//             child: Text(
//               text,
//               style: TextStyle(
//                 color:
//                     sender_id ==
//                             Provider.of<UserProvider>(
//                               context,
//                               listen: false,
//                             ).userId
//                         ? Colors.black
//                         : Colors.white,
//               ),
//             ),
//           ),
//         ),
//         SizedBox(height: 8),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text(widget.chatroomName)),
//       body: Column(
//         children: [
//           Expanded(
//             child: StreamBuilder(
//               stream:
//                   db
//                       .collection("messages")
//                       .where("chatroom_id", isEqualTo: widget.chatroomId)
//                       .limit(100)
//                       .orderBy("timestamp", descending: true)
//                       .snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.hasError) {
//                   print(snapshot.error);
//                   return Text("Some error has occured!");
//                 }

//                 var allMessages = snapshot.data?.docs ?? [];

//                 if (allMessages.length < 1) {
//                   return Center(child: Text("No messages here"));
//                 }
//                 return ListView.builder(
//                   reverse: true,
//                   itemCount: allMessages.length,
//                   itemBuilder: (BuildContext context, int index) {
//                     return Padding(
//                       padding: const EdgeInsets.all(8.0),
//                       child: singleChatItem(
//                         sender_name: allMessages[index]["sender_name"],
//                         text: allMessages[index]["text"],
//                         sender_id: allMessages[index]["sender_id"],
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//           Container(
//             color: Colors.grey[200],
//             child: Padding(
//               padding: const EdgeInsets.all(8.0),
//               child: Row(
//                 children: [
//                   Expanded(
//                     child: TextField(
//                       controller: messageText,
//                       decoration: InputDecoration(
//                         hintText: "Write message here...",
//                         border: InputBorder.none,
//                       ),
//                     ),
//                   ),
//                   InkWell(onTap: sendMessage, child: Icon(Icons.send)),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:globalchat/providers/userProvider.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

class ChatroomScreen extends StatefulWidget {
  final String chatroomName;
  final String chatroomId;

  const ChatroomScreen({
    Key? key,
    required this.chatroomName,
    required this.chatroomId,
  }) : super(key: key);

  @override
  State<ChatroomScreen> createState() => _ChatroomScreenState();
}

class _ChatroomScreenState extends State<ChatroomScreen>
    with TickerProviderStateMixin {
  final db = FirebaseFirestore.instance;
  final TextEditingController messageText = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _showEmoji = false;
  bool _isAttaching = false;
  Map<String, bool> _typingUsers = {};

  // Animation controllers
  late AnimationController _sendButtonController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _sendButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Listen for typing status
    _setupTypingListener();

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    messageText.dispose();
    _scrollController.dispose();
    _sendButtonController.dispose();
    _removeTypingStatus();
    super.dispose();
  }

  void _setupTypingListener() {
    // Listen for typing status from other users
    db
        .collection("chatrooms")
        .doc(widget.chatroomId)
        .collection("typing")
        .snapshots()
        .listen((snapshot) {
          final Map<String, bool> newTypingUsers = {};

          for (var doc in snapshot.docs) {
            final userId = doc.id;
            // Don't show current user as typing
            if (userId !=
                Provider.of<UserProvider>(context, listen: false).userId) {
              newTypingUsers[userId] = doc.data()['isTyping'] ?? false;
            }
          }

          setState(() {
            _typingUsers = newTypingUsers;
          });
        });
  }

  void _updateTypingStatus(bool isTyping) {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;

    db
        .collection("chatrooms")
        .doc(widget.chatroomId)
        .collection("typing")
        .doc(userId)
        .set({
          'isTyping': isTyping,
          'userName':
              Provider.of<UserProvider>(context, listen: false).userName,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  void _removeTypingStatus() {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;

    db
        .collection("chatrooms")
        .doc(widget.chatroomId)
        .collection("typing")
        .doc(userId)
        .delete();
  }

  Future<void> sendMessage() async {
    if (messageText.text.isEmpty) {
      return;
    }

    final String text = messageText.text;
    messageText.clear();

    // Clear typing status when sending
    _updateTypingStatus(false);
    setState(() {
      _isTyping = false;
    });

    // Play send animation
    _sendButtonController.forward().then(
      (_) => _sendButtonController.reverse(),
    );

    Map<String, dynamic> messageToSend = {
      "text": text,
      "sender_name": Provider.of<UserProvider>(context, listen: false).userName,
      "sender_id": Provider.of<UserProvider>(context, listen: false).userId,
      "chatroom_id": widget.chatroomId,
      "timestamp": FieldValue.serverTimestamp(),
      "read_by": [Provider.of<UserProvider>(context, listen: false).userId],
    };

    try {
      await db.collection("messages").add(messageToSend);

      // Scroll to bottom after sending
      _scrollToBottom();
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleTyping(String text) {
    final bool isCurrentlyTyping = text.isNotEmpty;

    if (_isTyping != isCurrentlyTyping) {
      setState(() {
        _isTyping = isCurrentlyTyping;
      });
      _updateTypingStatus(isCurrentlyTyping);
    }
  }

  Future<void> _markAsRead(String messageId) async {
    final userId = Provider.of<UserProvider>(context, listen: false).userId;

    await db.collection("messages").doc(messageId).update({
      "read_by": FieldValue.arrayUnion([userId]),
    });
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final messageTime = timestamp.toDate();

    // If it's today, show time only
    if (now.day == messageTime.day &&
        now.month == messageTime.month &&
        now.year == messageTime.year) {
      return DateFormat('h:mm a').format(messageTime);
    }

    // If it's within the last week, show day and time
    if (now.difference(messageTime).inDays < 7) {
      return timeago.format(messageTime, locale: 'en_short');
    }

    // Otherwise show date
    return DateFormat('MMM d').format(messageTime);
  }

  // Message bubble widget with animations and read receipt
  Widget _messageBubble({
    required String messageId,
    required String senderName,
    required String text,
    required String senderId,
    required Timestamp? timestamp,
    required List<dynamic> readBy,
  }) {
    final bool isCurrentUser =
        senderId == Provider.of<UserProvider>(context, listen: false).userId;
    final bool hasBeenRead = readBy.contains(
      Provider.of<UserProvider>(context, listen: false).userId,
    );

    if (!hasBeenRead && !isCurrentUser) {
      // Mark as read if not read yet and not sent by current user
      _markAsRead(messageId);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender name (only show for others)
          if (!isCurrentUser)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, bottom: 4.0),
              child: Text(
                senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ),

          // Message content
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color:
                  isCurrentUser
                      ? Colors.deepPurpleAccent.withOpacity(0.9)
                      : Colors.blueGrey[800],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              child: Text(
                text,
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),

          // Timestamp and read receipt
          Padding(
            padding: const EdgeInsets.only(top: 2.0, right: 4.0, left: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(fontSize: 10, color: Colors.black45),
                ),

                // Read receipt for sent messages
                if (isCurrentUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    readBy.length > 1 ? Icons.done_all : Icons.done,
                    size: 12,
                    color: readBy.length > 1 ? Colors.blue : Colors.black45,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Typing indicator widget
  Widget _buildTypingIndicator() {
    final typingUserNames =
        _typingUsers.entries
            .where((entry) => entry.value)
            .map((entry) => db.collection("users").doc(entry.key).get())
            .toList();

    if (typingUserNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait(typingUserNames),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final names =
            snapshot.data!
                .map((doc) => doc.data() as Map<String, dynamic>?)
                .where((data) => data != null)
                .map((data) => data!['name'] as String?)
                .where((name) => name != null)
                .toList();

        if (names.isEmpty) {
          return const SizedBox.shrink();
        }

        String typingText;
        if (names.length == 1) {
          typingText = '${names[0]} is typing...';
        } else if (names.length == 2) {
          typingText = '${names[0]} and ${names[1]} are typing...';
        } else {
          typingText = 'Several people are typing...';
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          child: Row(
            children: [
              const SizedBox(
                width: 35,
                child: Stack(
                  children: [
                    Positioned(
                      child: Text('•', style: TextStyle(fontSize: 30)),
                    ),
                    Positioned(
                      left: 8,
                      child: Text('•', style: TextStyle(fontSize: 30)),
                    ),
                    Positioned(
                      left: 16,
                      child: Text('•', style: TextStyle(fontSize: 30)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                typingText,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepPurpleAccent,
              child: Text(
                widget.chatroomName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatroomName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream:
                        db
                            .collection("chatrooms")
                            .doc(widget.chatroomId)
                            .collection("typing")
                            .where("isTyping", isEqualTo: true)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        return const Text(
                          "typing...",
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show chatroom info
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => _buildChatroomInfoSheet(),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages area
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  db
                      .collection("messages")
                      .where("chatroom_id", isEqualTo: widget.chatroomId)
                      .orderBy("timestamp", descending: true)
                      .limit(100)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final allMessages = snapshot.data?.docs ?? [];

                if (allMessages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.black12,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No messages yet",
                          style: TextStyle(color: Colors.black54, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Be the first to send a message!",
                          style: TextStyle(color: Colors.black38, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                // Group messages by date
                Map<String, List<DocumentSnapshot>> groupedMessages = {};

                for (var message in allMessages) {
                  final timestamp = message['timestamp'] as Timestamp?;
                  final date =
                      timestamp != null
                          ? DateFormat('yyyy-MM-dd').format(timestamp.toDate())
                          : 'Unknown';

                  if (!groupedMessages.containsKey(date)) {
                    groupedMessages[date] = [];
                  }

                  groupedMessages[date]!.add(message);
                }

                // Sort dates
                final sortedDates =
                    groupedMessages.keys.toList()
                      ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, dateIndex) {
                    final date = sortedDates[dateIndex];
                    final messagesForDate = groupedMessages[date]!;

                    // Format date for header
                    String headerText;
                    final messageDate = DateTime.parse(date);
                    final now = DateTime.now();

                    if (now.year == messageDate.year &&
                        now.month == messageDate.month &&
                        now.day == messageDate.day) {
                      headerText = 'Today';
                    } else if (now.subtract(const Duration(days: 1)).year ==
                            messageDate.year &&
                        now.subtract(const Duration(days: 1)).month ==
                            messageDate.month &&
                        now.subtract(const Duration(days: 1)).day ==
                            messageDate.day) {
                      headerText = 'Yesterday';
                    } else {
                      headerText = DateFormat('MMMM d, y').format(messageDate);
                    }

                    return Column(
                      children: [
                        // Date header
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                headerText,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Messages for this date
                        ...messagesForDate.map((messageDoc) {
                          final message =
                              messageDoc.data() as Map<String, dynamic>;

                          return _messageBubble(
                            messageId: messageDoc.id,
                            senderName: message["sender_name"] as String,
                            text: message["text"] as String,
                            senderId: message["sender_id"] as String,
                            timestamp: message["timestamp"] as Timestamp?,
                            readBy: message["read_by"] as List<dynamic>? ?? [],
                          );
                        }).toList(),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Typing indicator
          _buildTypingIndicator(),

          // Input area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                // Attachment button
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: Colors.grey[700]),
                  onPressed: () {
                    setState(() {
                      _isAttaching = !_isAttaching;
                      _showEmoji = false;
                    });
                  },
                ),

                // Message input field
                Expanded(
                  child: TextField(
                    controller: messageText,
                    onChanged: _handleTyping,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.emoji_emotions_outlined,
                          color:
                              _showEmoji
                                  ? Colors.deepPurpleAccent
                                  : Colors.grey[700],
                        ),
                        onPressed: () {
                          setState(() {
                            _showEmoji = !_showEmoji;
                            _isAttaching = false;
                          });
                        },
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),

                const SizedBox(width: 8),

                // Send button with animation
                AnimatedBuilder(
                  animation: _sendButtonController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (_sendButtonController.value * 0.2),
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.deepPurpleAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: sendMessage,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Attachment options
          if (_isAttaching) _buildAttachmentOptions(),

          // Emoji picker
          if (_showEmoji) _buildEmojiPicker(),
        ],
      ),
    );
  }

  // Add this method where there are other widget methods in the _ChatroomScreenState class
  Widget _buildChatroomInfoSheet() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Chatroom avatar
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.deepPurpleAccent,
            child: Text(
              widget.chatroomName[0].toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 40),
            ),
          ),
          const SizedBox(height: 16),

          // Chatroom name
          Text(
            widget.chatroomName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),

          const SizedBox(height: 24),

          // Any additional content you want in the info sheet
          Text('Chatroom ID: ${widget.chatroomId}'),
        ],
      ),
    );
  }

  // Add this method for emoji picker
  Widget _buildEmojiPicker() {
    // Simplified emoji picker
    final List<String> commonEmojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '😂',
      '🤣',
      '😊',
      '😇',
      '🙂',
      '🙃',
      '😉',
      '😌',
      '😍',
      '🥰',
      '😘',
      '😗',
      '😙',
      '😚',
      '😋',
      '😛',
      '😝',
      '😜',
      '🤪',
      '🤨',
      '🧐',
      '🤓',
      '😎',
      '🤩',
      '👍',
      '👎',
      '❤️',
      '🔥',
      '😢',
      '😭',
      '😡',
      '🥳',
      '🤔',
      '🙏',
    ];

    return Container(
      height: 200,
      color: Colors.grey[100],
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
        ),
        itemCount: commonEmojis.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              messageText.text = messageText.text + commonEmojis[index];
              // Place cursor at the end
              messageText.selection = TextSelection.fromPosition(
                TextPosition(offset: messageText.text.length),
              );
            },
            child: Center(
              child: Text(
                commonEmojis[index],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          );
        },
      ),
    );
  }

  // Add this method for attachment options
  Widget _attachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOptions() {
    return Container(
      height: 120,
      color: Colors.grey[100],
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _attachmentOption(
            icon: Icons.image,
            label: 'Photo',
            color: Colors.green,
            onTap: () {
              // Functionality to be implemented
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
            },
          ),
          _attachmentOption(
            icon: Icons.camera_alt,
            label: 'Camera',
            color: Colors.blue,
            onTap: () {
              // Functionality to be implemented
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
            },
          ),
          _attachmentOption(
            icon: Icons.file_copy,
            label: 'Document',
            color: Colors.orange,
            onTap: () {
              // Functionality to be implemented
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
            },
          ),
          _attachmentOption(
            icon: Icons.location_on,
            label: 'Location',
            color: Colors.red,
            onTap: () {
              // Functionality to be implemented
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Coming soon!')));
            },
          ),
        ],
      ),
    );
  }

  // Widget _attachmentOption({
  //   required IconData icon,
  //   required String label,
  //   required Color color,
  //   required VoidCallback onTap,
  // }) {
  //   return InkWell(
  //     onTap: onTap,
  //     child: Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Container(
  //           padding: const EdgeInsets.all(12),
  //           decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  //           child: Icon(icon, color: Colors.white, size: 24),
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           label,
  //           style: const TextStyle(fontSize: 12, color: Colors.black54),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}
