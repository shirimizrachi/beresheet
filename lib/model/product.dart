class Product {
  Product({
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.id,
    this.qty = 0, // Default quantity is 0
  });

  final String name;
  final String category;
  final int price;
  final String description;
  final String id;
  final String imageUrl;
  int qty; // Add qty field

  factory Product.fromFirestore(Map<String, dynamic> firestoreData) {
    return Product(
      name: firestoreData['name'],
      category: firestoreData['category'],
      id: firestoreData['id'],
      price: firestoreData['price'],
      imageUrl: firestoreData['image_url'],
      description: firestoreData['description'],
      qty: firestoreData['qty'] ?? 0, // Initialize qty from Firestore, default is 0
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'],
      category: json['category'],
      id: json['id'],
      price: json['price'],
      imageUrl: json['image_url'],
      description: json['description'],
      qty: json['qty'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'id': id,
      'price': price,
      'image_url': imageUrl,
      'description': description,
      'qty': qty,
    };
  }
}