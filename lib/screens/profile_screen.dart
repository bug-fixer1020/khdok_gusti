import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _educationController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = true;
  bool _isEditing = false;
  String _userId = '';
  String? _userRole;
  String? _profilePhotoUrl;
  File? _profileImage;
  String? _nidPhotoUrl;
  File? _nidImage;
  String? _memberId;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login again')),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }
    
    _userId = user.id;
    
    try {
      // Load from users table
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('*')
          .eq('id', _userId)
          .single();
      
      _nameController.text = userResponse['name'] ?? '';
      _addressController.text = userResponse['address'] ?? '';
      _fatherNameController.text = userResponse['father_name'] ?? '';
      _motherNameController.text = userResponse['mother_name'] ?? '';
      _educationController.text = userResponse['education'] ?? '';
      _profilePhotoUrl = userResponse['profile_photo_url'];
      _nidPhotoUrl = userResponse['nid_photo_url'];
      _userRole = userResponse['role'];
      
      // Load from members table
      final memberResponse = await Supabase.instance.client
          .from('members')
          .select('*')
          .eq('user_id', _userId)
          .maybeSingle();
      
      if (memberResponse != null) {
        _memberId = memberResponse['id'];
        _phoneController.text = memberResponse['phone'] ?? '';
        if (_nameController.text.isEmpty) {
          _nameController.text = memberResponse['name'] ?? '';
        }
      }
      
      setState(() {});
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        if (_userId.isEmpty) {
          throw Exception('User ID is missing');
        }
        
        String? profilePhotoUrl = _profilePhotoUrl;
        String? nidPhotoUrl = _nidPhotoUrl;
        
        // Upload profile photo if selected
        if (_profileImage != null) {
          final fileExt = _profileImage!.path.split('.').last;
          final fileName = 'profile_${_userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          
          await Supabase.instance.client.storage
              .from('profile_photos')
              .upload(fileName, _profileImage!);
          
          profilePhotoUrl = Supabase.instance.client.storage
              .from('profile_photos')
              .getPublicUrl(fileName);
        }
        
        // Upload NID photo if selected
        if (_nidImage != null) {
          final fileExt = _nidImage!.path.split('.').last;
          final fileName = 'nid_${_userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          
          await Supabase.instance.client.storage
              .from('nid_photos')
              .upload(fileName, _nidImage!);
          
          nidPhotoUrl = Supabase.instance.client.storage
              .from('nid_photos')
              .getPublicUrl(fileName);
        }
        
        // Update users table
        await Supabase.instance.client
            .from('users')
            .update({
              'name': _nameController.text,
              'address': _addressController.text,
              'father_name': _fatherNameController.text,
              'mother_name': _motherNameController.text,
              'education': _educationController.text,
              'profile_photo_url': profilePhotoUrl ?? '',
              'nid_photo_url': nidPhotoUrl ?? '',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _userId);
        
        // Update or insert into members table
        if (_memberId != null) {
          // Update existing member
          await Supabase.instance.client
              .from('members')
              .update({
                'name': _nameController.text,
                'phone': _phoneController.text,
                'email': Supabase.instance.client.auth.currentUser?.email,
              })
              .eq('id', _memberId!);
        } else {
          // Insert new member
          final newMember = await Supabase.instance.client
              .from('members')
              .insert({
                'user_id': _userId,
                'name': _nameController.text,
                'phone': _phoneController.text,
                'email': Supabase.instance.client.auth.currentUser?.email,
                'join_date': DateTime.now().toIso8601String(),
                'is_active': true,
              })
              .select()
              .single();
          
          _memberId = newMember['id'];
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
        
        setState(() => _isEditing = false);
        await _loadUserProfile(); // Reload fresh data
      } catch (e) {
        print('Error updating profile: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating profile: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (pickedFile != null && mounted) {
        setState(() {
          if (type == 'profile') {
            _profileImage = File(pickedFile.path);
          } else {
            _nidImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _showImagePickerOptions(String type) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            const Text(
              'Choose Image Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.green),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, type);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'My Profile'),
        backgroundColor: Colors.green,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  _updateProfile();
                } else {
                  setState(() => _isEditing = true);
                }
              },
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() => _isEditing = false);
                _loadUserProfile();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Photo Card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // Profile Photo Section
                            Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.green, width: 3),
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.green[100],
                                    backgroundImage: _profileImage != null
                                        ? FileImage(_profileImage!)
                                        : (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                                            ? NetworkImage(_profilePhotoUrl!)
                                            : null),
                                    child: (_profileImage == null && (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty))
                                        ? Text(
                                            _nameController.text.isNotEmpty
                                                ? _nameController.text[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(fontSize: 50, color: Colors.green),
                                          )
                                        : null,
                                  ),
                                ),
                                if (_isEditing)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          const BoxShadow(color: Colors.black26, blurRadius: 5),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                        onPressed: () => _showImagePickerOptions('profile'),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Personal Information Section
                            const Text(
                              'Personal Information',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            const SizedBox(height: 15),
                            
                            // Full Name
                            TextFormField(
                              controller: _nameController,
                              enabled: _isEditing,
                              decoration: InputDecoration(
                                labelText: 'Full Name *',
                                hintText: 'Enter your full name',
                                prefixIcon: const Icon(Icons.person),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter your name';
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            
                            // Phone Number
                            TextFormField(
                              controller: _phoneController,
                              enabled: _isEditing,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                hintText: 'Enter your phone number',
                                prefixIcon: const Icon(Icons.phone),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            // Address
                            TextFormField(
                              controller: _addressController,
                              enabled: _isEditing,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Address',
                                hintText: 'Enter your address',
                                prefixIcon: const Icon(Icons.home),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            // Father's Name
                            TextFormField(
                              controller: _fatherNameController,
                              enabled: _isEditing,
                              decoration: InputDecoration(
                                labelText: "Father's Name",
                                hintText: "Enter your father's name",
                                prefixIcon: const Icon(Icons.people),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            // Mother's Name
                            TextFormField(
                              controller: _motherNameController,
                              enabled: _isEditing,
                              decoration: InputDecoration(
                                labelText: "Mother's Name",
                                hintText: "Enter your mother's name",
                                prefixIcon: const Icon(Icons.people),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            // Education
                            TextFormField(
                              controller: _educationController,
                              enabled: _isEditing,
                              decoration: InputDecoration(
                                labelText: 'Education',
                                hintText: 'Your educational qualification',
                                prefixIcon: const Icon(Icons.school),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            const Divider(),
                            const SizedBox(height: 10),
                            
                            // NID Photo Section
                            if (_isEditing)
                              Column(
                                children: [
                                  const Text(
                                    'NID /身份证 Photo',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () => _showImagePickerOptions('nid'),
                                    child: Container(
                                      height: 200,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: _nidImage != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: Image.file(
                                                _nidImage!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                              ),
                                            )
                                          : Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.upload_file, size: 50, color: Colors.grey[600]),
                                                const SizedBox(height: 10),
                                                Text(
                                                  'Tap to upload NID photo',
                                                  style: TextStyle(color: Colors.grey[600]),
                                                ),
                                                Text(
                                                  '(Camera or Gallery)',
                                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            
                            if (_nidPhotoUrl != null && _nidPhotoUrl!.isNotEmpty && !_isEditing)
                              Column(
                                children: [
                                  const Text(
                                    'NID Photo:',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _nidPhotoUrl!,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 200,
                                          color: Colors.grey[200],
                                          child: const Center(
                                            child: Text('Failed to load image'),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Account Information Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Information',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            const SizedBox(height: 10),
                            ListTile(
                              leading: const Icon(Icons.email, color: Colors.green),
                              title: const Text('Email Address'),
                              subtitle: Text(currentUserEmail),
                              dense: true,
                            ),
                            const Divider(),
                            ListTile(
                              leading: const Icon(Icons.admin_panel_settings, color: Colors.green),
                              title: const Text('Role'),
                              subtitle: Text(_userRole ?? 'Member'),
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (!_isEditing && _memberId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green[600]),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Your profile is complete! You can edit anytime.',
                                  style: TextStyle(color: Colors.green[800]),
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