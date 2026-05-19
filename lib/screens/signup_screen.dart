import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/image_helper.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _educationController = TextEditingController();
  
  String? _profileImagePath;
  String? _nidImagePath;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _pickImage(bool isProfile) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        if (isProfile) {
          _profileImagePath = pickedFile.path;
        } else {
          _nidImagePath = pickedFile.path;
        }
      });
    }
  }

  Future<String?> _uploadImage(File imageFile, String userId, String type) async {
    return await ImageHelper.uploadImage(
      imageFile: imageFile,
      userId: userId,
      type: type,
    );
  }

  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        // Check if email already exists
        final existingUser = await Supabase.instance.client
            .from('users')
            .select()
            .eq('email', _emailController.text.trim());
        
        if (existingUser.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email already exists!')),
          );
          setState(() => _isLoading = false);
          return;
        }
        
        Map<String, dynamic> userData = {
          'name': _nameController.text,
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'father_name': _fatherNameController.text,
          'mother_name': _motherNameController.text,
          'address': _addressController.text,
          'current_education': _educationController.text,
        };
        
        final response = await Supabase.instance.client
            .from('users')
            .insert(userData)
            .select()
            .single();
        
        final userId = response['id'];
        
        // Upload images if selected
        if (_profileImagePath != null) {
          final imageFile = File(_profileImagePath!);
          final imageUrl = await _uploadImage(imageFile, userId, 'profile');
          if (imageUrl != null) {
            await Supabase.instance.client
                .from('users')
                .update({'profile_image': imageUrl})
                .eq('id', userId);
          }
        }
        
        if (_nidImagePath != null) {
          final imageFile = File(_nidImagePath!);
          final imageUrl = await _uploadImage(imageFile, userId, 'nid');
          if (imageUrl != null) {
            await Supabase.instance.client
                .from('users')
                .update({'nid_image': imageUrl})
                .eq('id', userId);
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Signup successful! Please login.')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signup failed: ${e.toString()}')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildImagePreview(String? imagePath, bool isProfile) {
    if (imagePath == null) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        child: Icon(isProfile ? Icons.camera_alt : Icons.upload_file, 
                   size: 40, color: Colors.grey),
      );
    }
    
    if (kIsWeb) {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: NetworkImage(imagePath),
        onBackgroundImageError: (_, __) {},
      );
    } else {
      return CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey.shade200,
        backgroundImage: FileImage(File(imagePath)),
      );
    }
  }

  Widget _buildNIDPreview(String? imagePath) {
    if (imagePath == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, size: 40),
            Text('Upload NID Image'),
          ],
        ),
      );
    }
    
    if (kIsWeb) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.error));
        },
      );
    } else {
      return Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up - Khadk Gusti'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image
              GestureDetector(
                onTap: () => _pickImage(true),
                child: _buildImagePreview(_profileImagePath, true),
              ),
              const SizedBox(height: 8),
              const Text('Tap to add profile photo'),
              const SizedBox(height: 24),
              
              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) => value!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              
              // Email
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value!.isEmpty) return 'Enter email';
                  if (!value.contains('@')) return 'Enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value!.isEmpty) return 'Enter password';
                  if (value.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Confirm Password
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Father Name
              TextFormField(
                controller: _fatherNameController,
                decoration: InputDecoration(
                  labelText: 'Father\'s Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.family_restroom),
                ),
              ),
              const SizedBox(height: 16),
              
              // Mother Name
              TextFormField(
                controller: _motherNameController,
                decoration: InputDecoration(
                  labelText: 'Mother\'s Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.family_restroom),
                ),
              ),
              const SizedBox(height: 16),
              
              // Address
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.home),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Current Education
              TextFormField(
                controller: _educationController,
                decoration: InputDecoration(
                  labelText: 'Current Education',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.school),
                ),
              ),
              const SizedBox(height: 16),
              
              // NID Image
              GestureDetector(
                onTap: () => _pickImage(false),
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildNIDPreview(_nidImagePath),
                ),
              ),
              const SizedBox(height: 24),
              
              // Signup Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Sign Up', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _addressController.dispose();
    _educationController.dispose();
    super.dispose();
  }
}