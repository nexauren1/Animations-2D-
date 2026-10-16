import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import '../services/app_locale.dart';

class LibraryAsset {
  const LibraryAsset({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.tint,
    required this.description,
  });
  final String id;
  final String name;
  final String category;
  final IconData icon;
  final Color tint;
  final String description;
}

/// Biblioteca visual de elementos vetoriais locais, sem internet nem conta.
class AssetsLibraryScreen extends StatefulWidget {
  const AssetsLibraryScreen({super.key});

  @override
  State<AssetsLibraryScreen> createState() => _AssetsLibraryScreenState();
}

class _AssetsLibraryScreenState extends State<AssetsLibraryScreen> {
  static const _categories = ['Todos', 'Personagens', 'Natureza', 'Objetos'];
  static const _assets = <LibraryAsset>[
    LibraryAsset(id: 'fox', name: 'Raposa simpática', category: 'Personagens', icon: Icons.pets_rounded, tint: Color(0xFFFFB15A), description: 'Personagem simples'),
    LibraryAsset(id: 'robot', name: 'Robot Buddy', category: 'Personagens', icon: Icons.smart_toy_rounded, tint: Color(0xFF8FC9F5), description: 'Robot de formas básicas'),
    LibraryAsset(id: 'face', name: 'Rosto expressivo', category: 'Personagens', icon: Icons.face_rounded, tint: Color(0xFFFFD0A6), description: 'Rosto com olhos e sorriso'),
    LibraryAsset(id: 'tree', name: 'Árvore', category: 'Natureza', icon: Icons.park_rounded, tint: Color(0xFF7DC99B), description: 'Árvore e tronco'),
    LibraryAsset(id: 'cloud', name: 'Nuvem', category: 'Natureza', icon: Icons.cloud_rounded, tint: Color(0xFFA7C9FF), description: 'Nuvem leve'),
    LibraryAsset(id: 'star', name: 'Estrela', category: 'Objetos', icon: Icons.star_rounded, tint: Color(0xFFFFD166), description: 'Estrela de cinco pontas'),
    LibraryAsset(id: 'heart', name: 'Coração', category: 'Objetos', icon: Icons.favorite_rounded, tint: Color(0xFFFF93B4), description: 'Coração desenhado'),
    LibraryAsset(id: 'house', name: 'Casa', category: 'Objetos', icon: Icons.cottage_rounded, tint: Color(0xFFD6B6FF), description: 'Casa com telhado'),
  ];

  String _category = 'Todos';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _assets.where((asset) {
      final byCategory = _category == 'Todos' || asset.category == _category;
      final term = _search.trim().toLowerCase();
      final bySearch = term.isEmpty ||
          asset.name.toLowerCase().contains(term) ||
          asset.description.toLowerCase().contains(term);
      return byCategory && bySearch;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de assets', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Ajuda',
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Assets vetoriais'),
                content: const Text('Escolhe um elemento para adicionar um desenho-base à camada selecionada. Depois podes editar os traços no canvas.'),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ),
            ),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: TextField(
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Procurar assets…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFF202332),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 45,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _category;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = category),
                  selectedColor: const Color(0xFF5445C6),
                  backgroundColor: const Color(0xFF242737),
                  labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
                  side: BorderSide(color: selected ? const Color(0xFF897CFF) : const Color(0xFF3B4054)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('Nenhum asset encontrado',
                        style: TextStyle(color: Colors.white.withOpacity(.6))),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 13,
                      mainAxisSpacing: 13,
                      childAspectRatio: .83,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final asset = filtered[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(asset.id),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF171A27),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: Center(
                                      child: Container(
                                        height: 76,
                                        width: 76,
                                        decoration: BoxDecoration(
                                          color: asset.tint.withOpacity(.17),
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        child: CustomPaint(
                                          painter: _AssetThumbnailPainter(asset.id, asset.tint),
                                          child: const SizedBox.expand(),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 11),
                                Text(asset.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(asset.category,
                                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(.52))),
                                const SizedBox(height: 9),
                                SizedBox(
                                  width: double.infinity,
                                  height: 36,
                                  child: FilledButton.icon(
                                    onPressed: () => Navigator.of(context).pop(asset.id),
                                    icon: const Icon(Icons.add, size: 17),
                                    label: const Text('Adicionar'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF5145B6),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


/// Hand-drawn miniature illustrations make each asset preview match its purpose.
class _AssetThumbnailPainter extends CustomPainter {
  const _AssetThumbnailPainter(this.id, this.tint);

  final String id;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final dark = const Color(0xFF25283A);
    final cream = const Color(0xFFFFE6C8);
    final white = const Color(0xFFFFFFFF);
    final ink = Paint()..color = dark;
    final fill = Paint()..color = tint;
    final soft = Paint()..color = tint.withOpacity(.2);
    final outline = Paint()
      ..color = dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void circle(double x, double y, double radius, Paint paint) =>
        canvas.drawCircle(Offset(x, y), radius, paint);
    void line(List<Offset> points, Paint paint) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }

    circle(50, 87, 25, soft);
    switch (id) {
      case 'fox':
        final ears = Path()
          ..moveTo(24, 39)..lineTo(29, 10)..lineTo(46, 29)
          ..lineTo(54, 29)..lineTo(72, 10)..lineTo(77, 39)
          ..close();
        canvas.drawPath(ears, fill);
        canvas.drawPath(ears, outline);
        final face = RRect.fromRectAndRadius(
          const Rect.fromLTWH(23, 24, 54, 53), const Radius.circular(23));
        canvas.drawRRect(face, fill);
        canvas.drawRRect(face, outline);
        final muzzle = Path()
          ..moveTo(30, 51)..quadraticBezierTo(50, 75, 70, 51)
          ..quadraticBezierTo(50, 42, 30, 51)..close();
        canvas.drawPath(muzzle, Paint()..color = cream);
        circle(39, 45, 3.2, ink);
        circle(61, 45, 3.2, ink);
        circle(50, 54, 3.3, ink);
        line([const Offset(47, 59), const Offset(50, 62), const Offset(53, 59)], outline);
        break;
      case 'robot':
        line([const Offset(50, 20), const Offset(50, 12)], outline);
        circle(50, 10, 4, Paint()..color = const Color(0xFF70D6E7));
        final head = RRect.fromRectAndRadius(
          const Rect.fromLTWH(24, 22, 52, 40), const Radius.circular(11));
        canvas.drawRRect(head, Paint()..color = const Color(0xFFB9DDF9));
        canvas.drawRRect(head, outline);
        circle(39, 39, 4.2, Paint()..color = const Color(0xFF6353C8));
        circle(61, 39, 4.2, Paint()..color = const Color(0xFF6353C8));
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(41, 48, 18, 5), const Radius.circular(3)),
          Paint()..color = dark);
        canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(32, 65, 36, 19), const Radius.circular(6)), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(32, 65, 36, 19), const Radius.circular(6)), outline);
        line([const Offset(32, 70), const Offset(22, 78)], outline);
        line([const Offset(68, 70), const Offset(78, 78)], outline);
        break;
      case 'face':
        circle(50, 49, 29, Paint()..color = const Color(0xFFFFD6AF));
        circle(50, 49, 29, outline);
        final hair = Path()
          ..moveTo(22, 42)..quadraticBezierTo(18, 12, 48, 16)
          ..quadraticBezierTo(76, 10, 79, 42)..lineTo(69, 34)
          ..lineTo(58, 28)..lineTo(42, 31)..lineTo(30, 38)..close();
        canvas.drawPath(hair, Paint()..color = const Color(0xFF65422E));
        circle(39, 48, 3, ink);
        circle(61, 48, 3, ink);
        final smile = Path()
          ..moveTo(39, 59)..quadraticBezierTo(50, 69, 61, 59);
        canvas.drawPath(smile, outline);
        break;
      case 'tree':
        canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(43, 54, 14, 33), const Radius.circular(3)),
          Paint()..color = const Color(0xFF9A623C));
        circle(34, 43, 19, Paint()..color = const Color(0xFF67C78D));
        circle(64, 40, 21, Paint()..color = const Color(0xFF4BB879));
        circle(49, 25, 22, Paint()..color = const Color(0xFF8FE0A8));
        circle(34, 43, 19, outline);
        circle(64, 40, 21, outline);
        circle(49, 25, 22, outline);
        break;
      case 'cloud':
        final cloud = Path()
          ..moveTo(20, 65)..quadraticBezierTo(9, 62, 12, 49)
          ..quadraticBezierTo(14, 36, 28, 38)
          ..quadraticBezierTo(33, 18, 51, 25)
          ..quadraticBezierTo(64, 28, 66, 39)
          ..quadraticBezierTo(85, 34, 88, 51)
          ..quadraticBezierTo(90, 65, 76, 67)..close();
        canvas.drawPath(cloud, Paint()..color = const Color(0xFFCAE5FF));
        canvas.drawPath(cloud, outline);
        line([const Offset(33, 76), const Offset(24, 80)], Paint()
          ..color = tint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
        line([const Offset(57, 78), const Offset(48, 82)], outline..color = tint);
        break;
      case 'star':
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? 34.0 : 15.0;
          final point = Offset(50 + math.cos(angle) * radius, 48 + math.sin(angle) * radius);
          if (i == 0) star.moveTo(point.dx, point.dy); else star.lineTo(point.dx, point.dy);
        }
        star.close();
        canvas.drawPath(star, Paint()..color = const Color(0xFFFFD166));
        canvas.drawPath(star, outline);
        circle(42, 42, 2.2, Paint()..color = white);
        break;
      case 'heart':
        final heart = Path()
          ..moveTo(50, 80)
          ..cubicTo(39, 70, 15, 54, 18, 36)
          ..cubicTo(21, 16, 42, 18, 50, 33)
          ..cubicTo(60, 15, 80, 18, 83, 36)
          ..cubicTo(86, 54, 61, 72, 50, 80)..close();
        canvas.drawPath(heart, Paint()..color = const Color(0xFFFF7FA8));
        canvas.drawPath(heart, outline);
        break;
      case 'house':
        canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(24, 42, 52, 42), const Radius.circular(3)),
          Paint()..color = const Color(0xFFE7D5FF));
        line([const Offset(18, 44), const Offset(50, 16), const Offset(82, 44)], outline..strokeWidth = 6);
        line([const Offset(18, 44), const Offset(50, 16), const Offset(82, 44)], Paint()
          ..color = const Color(0xFF9D82D8)..style = PaintingStyle.stroke..strokeWidth = 4);
        canvas.drawRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(43, 59, 14, 25), const Radius.circular(4)),
          Paint()..color = const Color(0xFF9D82D8));
        canvas.drawRect(const Rect.fromLTWH(29, 51, 9, 9), Paint()..color = const Color(0xFF9DCEEF));
        canvas.drawRect(const Rect.fromLTWH(62, 51, 9, 9), Paint()..color = const Color(0xFF9DCEEF));
        break;
      default:
        circle(50, 50, 27, fill);
        circle(50, 50, 27, outline);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AssetThumbnailPainter oldDelegate) =>
      oldDelegate.id != id || oldDelegate.tint != tint;
}
