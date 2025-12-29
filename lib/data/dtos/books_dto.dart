import 'package:json_annotation/json_annotation.dart';

part 'books_dto.g.dart';

@JsonSerializable(createToJson: false)
class BooksDto {
  @JsonKey(name: 'docs')
  final List<BookDataDto>? data;

  const BooksDto({this.data});

  factory BooksDto.fromJson(Map<String, dynamic> json) => _$BooksDtoFromJson(json);
}

@JsonSerializable(createToJson: false)
class BookDataDto {
  final String? title;

  @JsonKey(name: 'author_name')
  final List<String>? authorName;

  @JsonKey(name: 'first_publish_year')
  final int? firstPublishYear;

  @JsonKey(name: 'cover_i')
  final int? coverId;

  const BookDataDto({
    this.title,
    this.authorName,
    this.firstPublishYear,
    this.coverId,
  });

  factory BookDataDto.fromJson(Map<String, dynamic> json) => _$BookDataDtoFromJson(json);
}
