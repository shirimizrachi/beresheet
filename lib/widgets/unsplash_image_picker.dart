import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:beresheet_app/theme/app_theme.dart';
import 'package:beresheet_app/config/app_config.dart';

class UnsplashImagePicker extends StatefulWidget {
  final String eventType;
  final Function(String) onImageSelected;
  final int? crossAxisCount;

  const UnsplashImagePicker({
    Key? key,
    required this.eventType,
    required this.onImageSelected,
    this.crossAxisCount,
  }) : super(key: key);

  @override
  State<UnsplashImagePicker> createState() => _UnsplashImagePickerState();
}

class _UnsplashImagePickerState extends State<UnsplashImagePicker> {
  String get unsplashAccessKey => AppConfig.unsplashKey;
  List<UnsplashImage> images = [];
  bool isLoading = true;
  String? selectedImageUrl;

  @override
  void initState() {
    super.initState();
    fetchImages();
  }

  Future<void> fetchImages() async {
    try {
      setState(() => isLoading = true);
      
      final query = widget.eventType.replaceAll('-', ' ');
      final url = Uri.parse(
        'https://api.unsplash.com/search/photos?query=$query&per_page=20&client_id=$unsplashAccessKey'
      );
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          images = (data['results'] as List).map((item) => UnsplashImage(
            id: item['id'],
            url: item['urls']['regular'],
            thumbUrl: item['urls']['thumb'],
            photographer: item['user']['name'],
          )).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load images');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading images: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (images.isEmpty) {
      return const Center(child: Text('No images found'));
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount ?? (kIsWeb ? 4 : 2),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              final isSelected = selectedImageUrl == image.url;
              
              return GestureDetector(
                onTap: () {
                  setState(() => selectedImageUrl = image.url);
                  widget.onImageSelected(image.url);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: image.thumbUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        color: Colors.black45,
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          alignment: Alignment.centerLeft,
          child: Text(
            'Photos provided by Unsplash',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class UnsplashImage {
  final String id;
  final String url;
  final String thumbUrl;
  final String photographer;

  UnsplashImage({
    required this.id,
    required this.url,
    required this.thumbUrl,
    required this.photographer,
  });
}