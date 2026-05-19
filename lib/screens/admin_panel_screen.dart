import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/image_helper.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String _currentUserRole = 'member';
  bool _isAdmin = false;
  
  // Add member controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _educationController = TextEditingController();
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('loggedInUserRole') ?? 'member';
    
    setState(() {
      _currentUserRole = userRole;
      _isAdmin = userRole == 'admin';
    });
    
    if (_isAdmin) {
      _loadMembers();
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access denied. Admin only!')),
        );
      }
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    
    final response = await Supabase.instance.client
        .from('users')
        .select()
        .order('created_at', ascending: false);
    
    setState(() {
      _members = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });
  }

  Future<void> _addMember() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can add members')),
      );
      return;
    }
    
    if (_formKey.currentState!.validate()) {
      try {
        final response = await Supabase.instance.client
            .from('users')
            .insert({
              'name': _nameController.text,
              'email': _emailController.text.trim(),
              'password': _passwordController.text,
              'father_name': _fatherNameController.text,
              'mother_name': _motherNameController.text,
              'address': _addressController.text,
              'current_education': _educationController.text,
              'role': 'member',
            })
            .select()
            .single();
        
        if (_profileImagePath != null) {
          final userId = response['id'];
          final imageFile = File(_profileImagePath!);
          final imageUrl = await ImageHelper.uploadImage(
            imageFile: imageFile,
            userId: userId,
            type: 'profile',
          );
          
          if (imageUrl != null) {
            await Supabase.instance.client
                .from('users')
                .update({'profile_image': imageUrl})
                .eq('id', userId);
          }
        }
        
        _clearForm();
        _loadMembers();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member added successfully')),
        );
        
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _updateMember(Map<String, dynamic> member) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can update members')),
      );
      return;
    }
    
    final nameController = TextEditingController(text: member['name']);
    final emailController = TextEditingController(text: member['email']);
    final fatherController = TextEditingController(text: member['father_name'] ?? '');
    final motherController = TextEditingController(text: member['mother_name'] ?? '');
    final addressController = TextEditingController(text: member['address'] ?? '');
    final educationController = TextEditingController(text: member['current_education'] ?? '');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Member'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextFormField(
                controller: fatherController,
                decoration: const InputDecoration(labelText: 'Father\'s Name'),
              ),
              TextFormField(
                controller: motherController,
                decoration: const InputDecoration(labelText: 'Mother\'s Name'),
              ),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextFormField(
                controller: educationController,
                decoration: const InputDecoration(labelText: 'Education'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client
                  .from('users')
                  .update({
                    'name': nameController.text,
                    'email': emailController.text,
                    'father_name': fatherController.text,
                    'mother_name': motherController.text,
                    'address': addressController.text,
                    'current_education': educationController.text,
                  })
                  .eq('id', member['id']);
              
              _loadMembers();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Member updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMember(String userId, String userName) async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can delete members')),
      );
      return;
    }
    
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member'),
        content: Text('Are you sure you want to delete $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('users')
            .delete()
            .eq('id', userId);
        
        _loadMembers();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$userName deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showAddMemberDialog() {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admin can add members')),
      );
      return;
    }
    
    _clearForm();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Member'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _pickImage(),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade200,
                    child: _profileImagePath != null
                        ? (kIsWeb
                            ? ClipOval(
                                child: Image.network(
                                  _profileImagePath!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : ClipOval(
                                child: Image.file(
                                  File(_profileImagePath!),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ))
                        : const Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => v!.isEmpty ? 'Enter name' : null,
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'Enter email' : null,
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                ),
                TextFormField(
                  controller: _fatherNameController,
                  decoration: const InputDecoration(labelText: 'Father\'s Name'),
                ),
                TextFormField(
                  controller: _motherNameController,
                  decoration: const InputDecoration(labelText: 'Mother\'s Name'),
                ),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextFormField(
                  controller: _educationController,
                  decoration: const InputDecoration(labelText: 'Education'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addMember,
            child: const Text('Add Member'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImagePath = pickedFile.path);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _fatherNameController.clear();
    _motherNameController.clear();
    _addressController.clear();
    _educationController.clear();
    _profileImagePath = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin && !_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('This area is only accessible by administrators'),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Members', icon: Icon(Icons.people)),
            Tab(text: 'Reports', icon: Icon(Icons.assessment)),
            Tab(text: 'Settings', icon: Icon(Icons.settings)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Members Tab
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: _showAddMemberDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Member'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                child: member['profile_image'] != null && member['profile_image'].toString().isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          member['profile_image'],
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Icon(Icons.person);
                                          },
                                        ),
                                      )
                                    : const Icon(Icons.person),
                              ),
                              title: Text(member['name']),
                              subtitle: Text(member['email']),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _updateMember(member),
                                  ),
                                  if (member['role'] != 'admin')
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteMember(member['id'], member['name']),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          
          // Reports Tab
          const Center(child: Text('Reports coming soon...')),
          
          // Settings Tab
          const Center(child: Text('Settings coming soon...')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _addressController.dispose();
    _educationController.dispose();
    super.dispose();
  }
}