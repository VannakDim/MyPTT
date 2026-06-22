class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? avatar;
  final List<Group>? groups;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatar,
    this.groups,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    var groupsList = json['groups'] as List?;
    List<Group>? parsedGroups = groupsList != null
        ? groupsList.map((g) => Group.fromJson(g)).toList()
        : null;

    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'] ?? 'user',
      avatar: json['avatar'],
      groups: parsedGroups,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'avatar': avatar,
      'groups': groups?.map((g) => g.toJson()).toList(),
    };
  }
}

class Group {
  final int id;
  final String name;
  final String displayName;

  Group({
    required this.id,
    required this.name,
    required this.displayName,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      displayName: json['display_name'] ?? json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
    };
  }
}
