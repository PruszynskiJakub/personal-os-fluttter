class Thread {
  final String uuid;
  final String title;
  final DateTime createdAt;

  Thread({required this.uuid, required this.title, required this.createdAt});

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      uuid: json['uuid'] as String,
      title: json['title'] as String? ?? 'New conversation',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
