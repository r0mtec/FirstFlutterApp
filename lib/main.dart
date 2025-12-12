import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CardsPage(),
    );
  }
}

class Place {
  final String title;
  final String description;
  final String imageUrl;
  final String details;

  const Place({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.details,
  });
}

class CardsPage extends StatefulWidget {
  const CardsPage({super.key});

  @override
  State<CardsPage> createState() => _CardsPageState();
}

class _CardsPageState extends State<CardsPage> {
  final List<Place> _places = const [
    Place(
      title: 'Горы',
      description: 'Красивые горные пейзажи и чистый воздух.',
      imageUrl:
      'https://images.unsplash.com/photo-1501785888041-af3ef285b470',
      details:
      'Детали:\n• Высота: 2500+ м\n• Лучшее время: лето/осень\n• Активности: трекинг, фото, пикники',
    ),
    Place(
      title: 'Море',
      description: 'Отдых у моря и шум волн.',
      imageUrl:
      'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
      details:
      'Детали:\n• Температура воды: 22–27°C\n• Лучшее время: июнь–сентябрь\n• Активности: плавание, серф, прогулки',
    ),
    Place(
      title: 'Лес',
      description: 'Тишина, природа и прогулки.',
      imageUrl:
      'https://images.unsplash.com/photo-1441974231531-c6227db76b6e',
      details:
      'Детали:\n• Атмосфера: спокойствие\n• Лучшее время: весна/лето\n• Активности: прогулки, грибы, отдых',
    ),
  ];

  final Set<int> _liked = <int>{};

  void _toggleLike(int index) {
    final isLikedNow = !_liked.contains(index);

    setState(() {
      if (isLikedNow) {
        _liked.add(index);
      } else {
        _liked.remove(index);
      }
    });

    final placeTitle = _places[index].title;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isLikedNow ? 'Вы поставили лайк: $placeTitle' : 'Лайк убран: $placeTitle',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openDetails(Place place, bool isLiked) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailsPage(place: place, isLiked: isLiked),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Лабораторная 4'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _places.length,
        itemBuilder: (context, index) {
          final place = _places[index];
          final isLiked = _liked.contains(index);

          return GestureDetector(
            onTap: () => _openDetails(place, isLiked),
            child: Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Image.network(
                      place.imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                place.description,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _toggleLike(index),
                          icon: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                          ),
                          tooltip: isLiked ? 'Убрать лайк' : 'Поставить лайк',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class DetailsPage extends StatelessWidget {
  final Place place;
  final bool isLiked;

  const DetailsPage({
    super.key,
    required this.place,
    required this.isLiked,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(place.title),
      ),
      body: ListView(
        children: [
          Image.network(
            place.imageUrl,
            height: 240,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.title,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  place.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Детальная информация:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  place.details,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Примечание:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Это демонстрационная страница для Лабы 4: '
                      'открытие деталей по нажатию на карточку.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
