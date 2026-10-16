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
    LibraryAsset(id: 'bird', name: 'Pássaro', category: 'Personagens', icon: Icons.flutter_dash, tint: Color(0xFF68C7F1), description: 'Pássaro com asas, bico e patas'),
    LibraryAsset(id: 'butterfly', name: 'Borboleta', category: 'Natureza', icon: Icons.filter_vintage_rounded, tint: Color(0xFFDB8BFF), description: 'Asas simétricas e antenas'),
    LibraryAsset(id: 'flower', name: 'Flor', category: 'Natureza', icon: Icons.local_florist_rounded, tint: Color(0xFFFF8DB4), description: 'Pétalas, centro e caule'),
    LibraryAsset(id: 'sun', name: 'Sol', category: 'Natureza', icon: Icons.wb_sunny_rounded, tint: Color(0xFFFFCD58), description: 'Sol com raios'),
    LibraryAsset(id: 'moon', name: 'Lua', category: 'Natureza', icon: Icons.nightlight_round, tint: Color(0xFF9DB8FF), description: 'Lua crescente'),
    LibraryAsset(id: 'balloon', name: 'Balão', category: 'Objetos', icon: Icons.celebration_rounded, tint: Color(0xFFFF8C87), description: 'Balão com fio e laço'),
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
                          onTap: () => Navigator.of(context).pop(asset),
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
                                    child: CustomPaint(
                                      painter: _AssetPreviewPainter(asset),
                                      child: const SizedBox.expand(),
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
                                    onPressed: () => Navigator.of(context).pop(asset),
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


class _AssetPreviewPainter extends CustomPainter {
  _AssetPreviewPainter(this.asset);
  final LibraryAsset asset;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 150, size.height / 120);
    canvas.save(); canvas.translate((size.width - 150 * scale) / 2, (size.height - 120 * scale) / 2); canvas.scale(scale);
    final c = asset.tint;
    final line = Paint()..color = c..strokeWidth = 3..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    final fill = Paint()..color = c.withOpacity(.22);
    final detail = Paint()..color = c.withOpacity(.75);
    void oval(Rect r) { canvas.drawOval(r, fill); canvas.drawOval(r, line); }
    void drawLine(Offset a, Offset b) => canvas.drawLine(a, b, line);
    switch (asset.id) {
      case 'face':
      case 'fox':
        final p = Path()..moveTo(42, 37)..quadraticBezierTo(75, 12, 108, 37)..quadraticBezierTo(122, 73, 75, 96)..quadraticBezierTo(28, 73, 42, 37)..close();
        canvas.drawPath(p, fill); canvas.drawPath(p, line);
        if (asset.id == 'fox') { final ears = Path()..moveTo(43, 42)..lineTo(30, 12)..lineTo(57, 29)..close()..moveTo(93, 29)..lineTo(120, 12)..lineTo(107, 42)..close(); canvas.drawPath(ears, fill); canvas.drawPath(ears, line); }
        canvas.drawCircle(const Offset(59, 55), 4, detail); canvas.drawCircle(const Offset(91, 55), 4, detail);
        final smile = Path()..moveTo(63, 71)..quadraticBezierTo(75, 83, 87, 71); canvas.drawPath(smile, line);
        break;
      case 'robot':
        final head = RRect.fromRectAndRadius(const Rect.fromLTWH(42, 20, 66, 52), const Radius.circular(12)); canvas.drawRRect(head, fill); canvas.drawRRect(head, line);
        final body = RRect.fromRectAndRadius(const Rect.fromLTWH(49, 81, 52, 27), const Radius.circular(7)); canvas.drawRRect(body, fill); canvas.drawRRect(body, line);
        drawLine(const Offset(75, 10), const Offset(75, 20)); canvas.drawCircle(const Offset(75, 8), 4, detail);
        canvas.drawCircle(const Offset(61, 43), 4, detail); canvas.drawCircle(const Offset(89, 43), 4, detail); drawLine(const Offset(63, 59), const Offset(87, 59));
        break;
      case 'tree':
        final trunk = RRect.fromRectAndRadius(const Rect.fromLTWH(66, 69, 18, 39), const Radius.circular(3)); canvas.drawRRect(trunk, fill); canvas.drawRRect(trunk, line);
        oval(const Rect.fromLTWH(38, 33, 48, 46)); oval(const Rect.fromLTWH(68, 20, 45, 51)); oval(const Rect.fromLTWH(80, 42, 37, 36));
        break;
      case 'cloud':
        final p = Path()..moveTo(35, 79)..cubicTo(18, 78, 20, 54, 39, 52)..cubicTo(40, 29, 67, 25, 77, 42)..cubicTo(94, 25, 117, 38, 115, 56)..cubicTo(135, 57, 133, 80, 114, 81)..close();
        canvas.drawPath(p, fill); canvas.drawPath(p, line); break;
      case 'star':
        final pts = List<Offset>.generate(11, (i) { final a = -math.pi / 2 + i * math.pi / 5; final r = i.isEven ? 44.0 : 19.0; return Offset(75 + math.cos(a) * r, 60 + math.sin(a) * r); });
        final p = Path()..moveTo(pts.first.dx, pts.first.dy); for (final q in pts.skip(1)) { p.lineTo(q.dx, q.dy); } p.close(); canvas.drawPath(p, fill); canvas.drawPath(p, line); break;
      case 'heart':
        final p = Path()..moveTo(75, 98)..cubicTo(60, 80, 29, 64, 35, 42)..cubicTo(41, 20, 63, 27, 75, 44)..cubicTo(88, 26, 111, 20, 117, 42)..cubicTo(123, 64, 91, 84, 75, 98)..close(); canvas.drawPath(p, fill); canvas.drawPath(p, line); break;
      case 'house':
        final roof = Path()..moveTo(27, 56)..lineTo(75, 18)..lineTo(123, 56)..close(); canvas.drawPath(roof, fill); canvas.drawPath(roof, line);
        final body = RRect.fromRectAndRadius(const Rect.fromLTWH(37, 52, 76, 55), const Radius.circular(4)); canvas.drawRRect(body, fill); canvas.drawRRect(body, line);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(67, 78, 18, 29), const Radius.circular(2)), line); canvas.drawRect(const Rect.fromLTWH(47, 63, 13, 13), detail); canvas.drawRect(const Rect.fromLTWH(92, 63, 13, 13), detail); break;
      case 'bird':
        oval(const Rect.fromLTWH(38, 42, 62, 38)); canvas.drawCircle(const Offset(97, 39), 18, fill); canvas.drawCircle(const Offset(97, 39), 18, line);
        final beak = Path()..moveTo(112, 38)..lineTo(133, 43)..lineTo(112, 48)..close(); canvas.drawPath(beak, detail); canvas.drawPath(beak, line);
        final wing = Path()..moveTo(57, 60)..quadraticBezierTo(67, 42, 83, 60)..quadraticBezierTo(70, 73, 57, 60); canvas.drawPath(wing, detail); canvas.drawPath(wing, line);
        drawLine(const Offset(60, 80), const Offset(57, 91)); drawLine(const Offset(76, 80), const Offset(79, 91)); break;
      case 'butterfly':
        oval(const Rect.fromLTWH(28, 28, 42, 39)); oval(const Rect.fromLTWH(32, 63, 38, 29)); oval(const Rect.fromLTWH(80, 28, 42, 39)); oval(const Rect.fromLTWH(80, 63, 38, 29));
        drawLine(const Offset(75, 38), const Offset(75, 85)); drawLine(const Offset(75, 38), const Offset(64, 24)); drawLine(const Offset(75, 38), const Offset(86, 24)); break;
      case 'flower':
        drawLine(const Offset(75, 68), const Offset(75, 109)); oval(const Rect.fromLTWH(51, 83, 27, 13)); oval(const Rect.fromLTWH(74, 91, 27, 13));
        for (var i = 0; i < 6; i++) { final a = i * math.pi / 3; oval(Rect.fromCenter(center: Offset(75 + math.cos(a) * 19, 45 + math.sin(a) * 19), width: 22, height: 18)); }
        canvas.drawCircle(const Offset(75, 45), 10, detail); canvas.drawCircle(const Offset(75, 45), 10, line); break;
      case 'sun':
        for (var i = 0; i < 12; i++) { final a = i * math.pi / 6; drawLine(Offset(75 + math.cos(a) * 32, 59 + math.sin(a) * 32), Offset(75 + math.cos(a) * 44, 59 + math.sin(a) * 44)); }
        canvas.drawCircle(const Offset(75, 59), 26, fill); canvas.drawCircle(const Offset(75, 59), 26, line); break;
      case 'moon':
        final p = Path()..moveTo(91, 17)..cubicTo(54, 26, 48, 69, 78, 91)..cubicTo(99, 106, 120, 83, 118, 62)..cubicTo(91, 76, 75, 48, 91, 17)..close(); canvas.drawPath(p, fill); canvas.drawPath(p, line); break;
      case 'balloon':
        final p = Path()..moveTo(75, 93)..cubicTo(51, 77, 42, 51, 50, 32)..cubicTo(63, 10, 92, 15, 101, 33)..cubicTo(109, 54, 94, 78, 75, 93)..close(); canvas.drawPath(p, fill); canvas.drawPath(p, line); drawLine(const Offset(75, 98), const Offset(70, 115)); break;
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant _AssetPreviewPainter oldDelegate) => asset.id != oldDelegate.asset.id || asset.tint != oldDelegate.asset.tint;
}
