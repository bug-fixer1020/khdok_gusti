import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageHelper {
  // Display image from file or network
  static Widget displayImage({
    required String? imageUrl,
    File? imageFile,
    double width = 100,
    double height = 100,
    BoxFit fit = BoxFit.cover,
    IconData? placeholderIcon,
  }) {
    // For web: always use NetworkImage if URL exists
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(width, height, placeholderIcon ?? Icons.person);
        },
      );
    }
    
    // For mobile: check if file exists
    if (!kIsWeb && imageFile != null) {
      return Image.file(
        imageFile,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(width, height, placeholderIcon ?? Icons.person);
        },
      );
    }
    
    // Default placeholder
    return _buildPlaceholder(width, height, placeholderIcon ?? Icons.person);
  }
  
  static Widget _buildPlaceholder(double width, double height, IconData icon) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: width * 0.5, color: Colors.grey.shade400),
    );
  }
  
  // Upload image to Supabase storage
  static Future<String?> uploadImage({
    required File imageFile,
    required String userId,
    required String type,
  }) async {
    try {
      String fileName;
      
      if (kIsWeb) {
        // For web: Handle differently
        final bytes = await imageFile.readAsBytes();
        fileName = '$userId/$type.jpg';
        
        await Supabase.instance.client.storage
            .from('user_images')
            .uploadBinary(fileName, bytes);
      } else {
        // For mobile
        final fileExt = imageFile.path.split('.').last;
        fileName = '$userId/$type.$fileExt';
        
        await Supabase.instance.client.storage
            .from('user_images')
            .upload(fileName, imageFile);
      }
      
      final imageUrl = Supabase.instance.client.storage
          .from('user_images')
          .getPublicUrl(fileName);
      
      return imageUrl;
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
}