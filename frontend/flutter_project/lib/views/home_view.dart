import 'package:flutter/material.dart';
import 'package:project491/views/create_room_sheet.dart';
import 'package:project491/views/profile_edit_view.dart';
import 'package:project491/views/room_view.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'login_view.dart';
import '../managers/auth_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthViewModel>(context, listen: false).loadCurrentUser();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          bottomNavigationBar: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'Home'), Tab(text: 'Notifications')],
          ),
          body: Consumer<AuthViewModel>(
            builder: (context, authVM, child) {
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              authVM.currentUser?.name != null
                                  ? Text(
                                    authVM.currentUser!.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                              authVM.currentUser?.title != null
                                  ? Text(
                                    authVM.currentUser!.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  )
                                  : const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                              TextButton(
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder:
                                        (context) => ProfileEditView(
                                          user: authVM.currentUser!,
                                        ),
                                  );
                                },
                                child: const Text(
                                  'Edit Profile',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
                          onPressed: () async {
                            await authService.value.signOut();
                            authVM.clearUserData();
                            if (context.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginView(),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        RefreshIndicator(
                          onRefresh: () async {
                            await Provider.of<AuthViewModel>(
                              context,
                              listen: false,
                            ).loadCurrentUser();
                            setState(() {});
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: FutureBuilder<List<Widget>>(
                                  future: _buildRoomsList(
                                    authVM.currentUser?.rooms ?? [],
                                  ),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return const SizedBox(
                                        height: 200,
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }

                                    if (authVM.currentUser?.rooms.isEmpty ??
                                        true) {
                                      return const SizedBox(
                                        height: 200,
                                        child: Center(
                                          child: Text(
                                            'No room assigned',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: snapshot.data ?? [],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Center(
                          child: Text(
                            'Notifications Content',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 30,
          child: Container(
            alignment: Alignment.center,
            child: FloatingActionButton(
              mini: true,
              elevation: 4,
              onPressed: () async {
                final authVM = Provider.of<AuthViewModel>(
                  context,
                  listen: false,
                );
                if (authVM.currentUser != null) {
                  _showCreateRoomSheet(context);
                }
              },
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  Future<List<Widget>> _buildRoomsList(List<String> roomIds) async {
    List<Widget> roomWidgets = [];
    List<String> invalidRoomIds = [];

    for (String roomId in roomIds) {
      try {
        final roomDoc =
            await FirebaseFirestore.instance
                .collection('rooms')
                .doc(roomId)
                .get();

        if (roomDoc.exists) {
          final roomData = roomDoc.data()!;
          roomWidgets.add(
            Dismissible(
              key: Key(roomId),
              background: Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16.0),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              direction: DismissDirection.endToStart,
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Confirm Delete'),
                      content: const Text(
                        'Are you sure you want to delete this room?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    );
                  },
                );
              },
              onDismissed: (direction) async {
                // Host kontrolünü participants array'inden yap
                final participants = List<Map<String, dynamic>>.from(roomData['participants'] ?? []);
                final isHost = participants.any((p) => 
                  p['isHost'] == true && 
                  p['userId'] == authService.value.currentUser!.uid
                );

                if (isHost) {
                  // Host ise odayı tamamen sil
                  await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(roomId)
                      .delete();
                } else {
                  // Host değilse sadece kendini unassign et
                  final participants = List<Map<String, dynamic>>.from(
                    roomData['participants'] ?? [],
                  );
                  
                  // Kullanıcının atandığı participant'ı bul
                  final myParticipant = participants.firstWhere(
                    (p) => p['userId'] == authService.value.currentUser!.uid,
                    orElse: () => <String, dynamic>{},
                  );

                  // Participant'ı unassign et
                  myParticipant['userId'] = '';
                  myParticipant['assignedUserName'] = null;

                  // Firestore'da participant güncelle
                  await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(roomId)
                      .update({'participants': participants});

                  // Preferences'ları sil
                  await FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(roomId)
                      .collection('preferences')
                      .doc(myParticipant['name'])
                      .delete();
                
                  // Kullanıcının rooms listesinden odayı kaldır
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(authService.value.currentUser!.uid)
                      .update({
                        'rooms': FieldValue.arrayRemove([roomId]),
                      });
                }

                // Refresh the user data
                await Provider.of<AuthViewModel>(
                  context,
                  listen: false,
                ).loadCurrentUser();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => RoomView(
                              roomId: roomId,
                              roomName: roomData['name'] ?? 'Unnamed Room',
                              roomDescription:
                                  roomData['description'] ?? 'No description',
                              participants: List<Map<String, dynamic>>.from(
                                roomData['participants'] ?? [],
                              ),
                              currentUserId: authService.value.currentUser!.uid,
                            ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomData['name'] ?? 'Unnamed Room',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          roomData['description'] ?? 'No description',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          invalidRoomIds.add(roomId);
        }
      } catch (e) {
        invalidRoomIds.add(roomId);
      }
    }

    // Clean up invalid room IDs from user's rooms array
    if (invalidRoomIds.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authService.value.currentUser!.uid)
            .update({'rooms': FieldValue.arrayRemove(invalidRoomIds)});

        // Refresh the user data in AuthViewModel
        await Provider.of<AuthViewModel>(
          context,
          listen: false,
        ).loadCurrentUser();
      } catch (e) {
        debugPrint('Error cleaning up invalid room IDs: $e');
      }
    }

    return roomWidgets;
  }

  void _showCreateRoomSheet(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateRoomSheet(
        hostId: authService.value.currentUser!.uid,
        hostName: Provider.of<AuthViewModel>(context, listen: false).currentUser!.name,
      ),
    );

    if (result == true && mounted) {
      // Kullanıcı bilgilerini ve oda listesini yenile
      await Provider.of<AuthViewModel>(context, listen: false).loadCurrentUser();
      setState(() {}); // UI'ı yenile
    }
  }
}
