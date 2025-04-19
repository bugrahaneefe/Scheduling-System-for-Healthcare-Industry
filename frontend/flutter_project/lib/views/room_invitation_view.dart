import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project491/views/home_view.dart';
import '../managers/auth_services.dart';
import 'room_view.dart';

class RoomInvitationView extends StatefulWidget {
  final String roomId;
  final bool returnToHome; // Add this parameter

  const RoomInvitationView({
    Key? key,
    required this.roomId,
    this.returnToHome = false, // Default to false for backward compatibility
  }) : super(key: key);

  @override
  State<RoomInvitationView> createState() => _RoomInvitationViewState();
}

class _RoomInvitationViewState extends State<RoomInvitationView> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _roomData;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load room data
      final roomDoc =
          await FirebaseFirestore.instance
              .collection('rooms')
              .doc(widget.roomId)
              .get();

      if (!roomDoc.exists) {
        setState(() {
          _error = 'Room not found';
          _isLoading = false;
        });
        return;
      }

      // Load user data
      final currentUserId = authService.value.currentUser?.uid;
      if (currentUserId != null) {
        final userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .get();

        if (userDoc.exists) {
          setState(() {
            _userData = userDoc.data();
            _roomData = roomDoc.data();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load data';
        _isLoading = false;
      });
    }
  }

  void _navigateToRoom(String currentUserId) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                widget.returnToHome
                    ? const HomeView()
                    : RoomView(
                      roomId: widget.roomId,
                      roomName: _roomData?['name'] ?? '',
                      roomDescription: _roomData?['description'] ?? '',
                      participants: List<Map<String, dynamic>>.from(
                        _roomData?['participants'] ?? [],
                      ),
                      currentUserId: currentUserId,
                    ),
      ),
      (route) => false, // Remove all previous routes
    );
  }

  Future<void> _joinRoom() async {
    setState(() => _isLoading = true);

    try {
      final currentUserId = authService.value.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is already in the room
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUserId)
              .get();

      if (userDoc.data()?['rooms']?.contains(widget.roomId) ?? false) {
        if (mounted) {
          _navigateToRoom(currentUserId);
        }
        return;
      }

      // Add room to user's rooms array
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
            'rooms': FieldValue.arrayUnion([widget.roomId]),
          });

      if (mounted) {
        _navigateToRoom(currentUserId);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to join room: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                  : Column(
                    children: [
                      // User info card at the top
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Colors.blue,
                              size: 36,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Joining as:',
                                    style: TextStyle(
                                      color: Colors.blue.shade200,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userData?['name'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _userData?['title'] ?? 'No title',
                                    style: TextStyle(
                                      color: Colors.blue.shade200,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Rest of the invitation content
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Join Room: ${_roomData?['name'] ?? 'Unknown'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _roomData?['description'] ?? 'No description',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                onPressed: _joinRoom,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('Join Room'),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}
