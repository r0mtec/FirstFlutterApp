import 'package:flutter/material.dart';
import 'package:lab/domain/models/card.dart';
import 'package:lab/data/dtos/books_dto.dart';

extension BookDataDtoToModel on BookDataDto {
  CardData toDomain() {
    final author = (authorName != null && authorName!.isNotEmpty)
        ? authorName!.first
        : 'Unknown';

    final year = firstPublishYear?.toString() ?? '—';
    final coverUrl = coverId == null
        ? null
        : 'https://covers.openlibrary.org/b/id/$coverId-M.jpg';

    return CardData(
      title ?? 'Untitled',
      descriptionText: '$author • $year',
      icon: Icons.menu_book,
      imageUrl: coverUrl,
    );
  }
}
