class Destination {
  final String destinationId;
  final String nodeId;
  final String name;
  final String category;
  final String? description;

  const Destination({
    required this.destinationId,
    required this.nodeId,
    required this.name,
    required this.category,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'destinationId': destinationId,
        'nodeId': nodeId,
        'name': name,
        'category': category,
        'description': description,
      };

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      destinationId: json['destinationId'] as String,
      nodeId: json['nodeId'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'General',
      description: json['description'] as String?,
    );
  }
}
