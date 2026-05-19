// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({super.key});

//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends State<ProfileScreen> {
//   Map<String, dynamic> _userData = {};
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//   }

//   Future<void> _loadUserData() async {
//     final response = await Supabase.instance.client
//         .from('users')
//         .select()
//         .limit(1);
    
//     if (response.isNotEmpty) {
//       setState(() {
//         _userData = response[0];
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _logout() async {
//     await Supabase.instance.client.auth.signOut();
//     if (mounted) {
//       Navigator.pushReplacementNamed(context, '/');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('My Profile'),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: _logout,
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               child: Column(
//                 children: [
//                   // Profile Header
//                   Container(
//                     width: double.infinity,
//                     padding: const EdgeInsets.all(32),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Colors.blue, Colors.purple],
//                       ),
//                     ),
//                     child: Column(
//                       children: [
//                         CircleAvatar(
//                           radius: 60,
//                           backgroundColor: Colors.white,
//                           backgroundImage: _userData['profile_image'] != null
//                               ? NetworkImage(_userData['profile_image'])
//                               : null,
//                           child: _userData['profile_image'] == null
//                               ? const Icon(Icons.person, size: 60, color: Colors.blue)
//                               : null,
//                         ),
//                         const SizedBox(height: 16),
//                         Text(
//                           _userData['name'] ?? 'User',
//                           style: const TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Container(
//                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//                           decoration: BoxDecoration(
//                             color: Colors.white24,
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                           child: Text(
//                             _userData['role']?.toUpperCase() ?? 'MEMBER',
//                             style: const TextStyle(color: Colors.white),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
                  
//                   // User Details
//                   Container(
//                     padding: const EdgeInsets.all(16),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Personal Information',
//                           style: TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         _buildInfoCard(Icons.email, 'Email', _userData['email'] ?? 'N/A'),
//                         _buildInfoCard(Icons.people, 'Father\'s Name', _userData['father_name'] ?? 'N/A'),
//                         _buildInfoCard(Icons.people, 'Mother\'s Name', _userData['mother_name'] ?? 'N/A'),
//                         _buildInfoCard(Icons.home, 'Address', _userData['address'] ?? 'N/A'),
//                         _buildInfoCard(Icons.school, 'Education', _userData['current_education'] ?? 'N/A'),
//                       ],
//                     ),
//                   ),
                  
//                   // NID Image
//                   if (_userData['nid_image'] != null)
//                     Container(
//                       padding: const EdgeInsets.all(16),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'NID Document',
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Container(
//                             height: 200,
//                             decoration: BoxDecoration(
//                               border: Border.all(color: Colors.grey),
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: ClipRRect(
//                               borderRadius: BorderRadius.circular(12),
//                               child: Image.network(
//                                 _userData['nid_image'],
//                                 fit: BoxFit.cover,
//                                 errorBuilder: (context, error, stackTrace) {
//                                   return const Center(child: Icon(Icons.error));
//                                 },
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
                  
//                   const SizedBox(height: 32),
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildInfoCard(IconData icon, String label, String value) {
//     return Card(
//       margin: const EdgeInsets.only(bottom: 12),
//       child: ListTile(
//         leading: Icon(icon, color: Colors.blue),
//         title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
//         subtitle: Text(value),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoggedInUser();
  }

  Future<void> _loadLoggedInUser() async {
    setState(() => _isLoading = true);
    
    try {
      // Get stored user email from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('loggedInUserEmail');
      
      if (userEmail != null && userEmail.isNotEmpty) {
        // Fetch user data by email
        final response = await Supabase.instance.client
            .from('users')
            .select()
            .eq('email', userEmail)
            .single();
        
        setState(() {
          _userData = response;
          _isLoading = false;
        });
      } else {
        // Fallback to first user (for demo)
        final response = await Supabase.instance.client
            .from('users')
            .select()
            .limit(1);
        
        if (response.isNotEmpty) {
          setState(() {
            _userData = response[0];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading user: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      // Clear stored user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('loggedInUserEmail');
      
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      print('Logout error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userData.isEmpty
              ? const Center(child: Text('No user data found'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Profile Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(32),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue, Colors.purple],
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.white,
                              backgroundImage: _userData['profile_image'] != null && 
                                              _userData['profile_image'].toString().isNotEmpty
                                  ? NetworkImage(_userData['profile_image'])
                                  : null,
                              child: _userData['profile_image'] == null || 
                                      _userData['profile_image'].toString().isEmpty
                                  ? const Icon(Icons.person, size: 60, color: Colors.blue)
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _userData['name'] ?? 'User',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _userData['role']?.toUpperCase() ?? 'MEMBER',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // User Details
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildInfoCard(Icons.email, 'Email', _userData['email'] ?? 'N/A'),
                            _buildInfoCard(Icons.people, 'Father\'s Name', _userData['father_name'] ?? 'N/A'),
                            _buildInfoCard(Icons.people, 'Mother\'s Name', _userData['mother_name'] ?? 'N/A'),
                            _buildInfoCard(Icons.home, 'Address', _userData['address'] ?? 'N/A'),
                            _buildInfoCard(Icons.school, 'Education', _userData['current_education'] ?? 'N/A'),
                          ],
                        ),
                      ),
                      
                      // NID Image
                      if (_userData['nid_image'] != null && 
                          _userData['nid_image'].toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'NID Document',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _userData['nid_image'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.error, size: 50),
                                            SizedBox(height: 8),
                                            Text('Failed to load NID image'),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(value),
      ),
    );
  }
}