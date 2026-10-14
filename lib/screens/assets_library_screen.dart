import 'package:flutter/material.dart';

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
                                        child: Icon(asset.icon, color: asset.tint, size: 46),
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
