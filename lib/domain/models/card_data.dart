import 'package:equatable/equatable.dart';

class CardData extends Equatable {
  final int id;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final bool isLiked;

  const CardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    this.isLiked = false,
  });

  CardData copyWith({
    int? id,
    String? title,
    String? subtitle,
    String? description,
    String? imageUrl,
    bool? isLiked,
  }) {
    return CardData(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  @override
  List<Object?> get props => [id, title, subtitle, description, imageUrl, isLiked];
}
