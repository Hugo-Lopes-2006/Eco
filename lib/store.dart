// =====================================================================
// STORE.DART  ->  Modificado para salvar em arquivo .json acessível
// =====================================================================
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'package:permission_handler/permission_handler.dart';

class EcoStore extends ChangeNotifier {
  List<Obra> obras = [];
  List<Experiencia> experiencias = [];

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // Define onde o arquivo será salvo para o Syncthing enxergar
  Future<File> get _file async {
    Directory dir;
    if (Platform.isAndroid) {
      // Solicita permissão (no Android 11+ vai abrir a tela do sistema pedindo acesso)
      if (await Permission.manageExternalStorage.status != PermissionStatus.granted) {
        await Permission.manageExternalStorage.request();
      }
      if (await Permission.storage.status != PermissionStatus.granted) {
        await Permission.storage.request();
      }
      
      // Aponta direto para a pasta pública Documentos do celular
      dir = Directory('/storage/emulated/0/Documents');
    } else {
      // No Linux, usa a pasta Documentos nativa
      dir = await getApplicationDocumentsDirectory();
    }
    
    // Cria a pasta caso ela não exista por algum motivo
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return File('${dir.path}/eco_dados.json');
  }

  // Carrega os dados do arquivo físico
  Future<void> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return;

      final raw = await file.readAsString();
      final m = jsonDecode(raw);
      obras = (m['obras'] as List).map((e) => Obra.fromJson(e)).toList();
      experiencias = (m['experiencias'] as List).map((e) => Experiencia.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Erro ao carregar banco de dados: $e');
    }
  }

  // Salva tudo em um arquivo JSON físico
  Future<void> _save() async {
    try {
      final file = await _file;
      final jsonStr = jsonEncode({
        'obras': obras.map((e) => e.toJson()).toList(),
        'experiencias': experiencias.map((e) => e.toJson()).toList(),
      });
      await file.writeAsString(jsonStr);
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao salvar banco de dados: $e');
    }
  }

  Future<void> addObra(Obra o) { obras.add(o); return _save(); }

  Future<void> addExperiencia(Experiencia e) {
    experiencias.add(e);
    obra(e.obraId)?.naFila = false; 
    return _save();
  }

  Future<void> removeObra(String id) {
    obras.removeWhere((o) => o.id == id);
    experiencias.removeWhere((e) => e.obraId == id);
    return _save();
  }

  Obra? obra(String id) => obras.where((o) => o.id == id).firstOrNull;

  List<Obra> porTipo(Tipo t) => obras.where((o) => o.tipo == t).toList();

  List<Experiencia> deObra(String id) =>
      experiencias.where((e) => e.obraId == id).toList()..sort((a, b) => a.data.compareTo(b.data));

  double? notaDe(String obraId) {
    final l = deObra(obraId).where((e) => e.nota > 0);
    return l.isEmpty ? null : l.last.nota;
  }

  List<String> hoje() {
    final n = DateTime.now();
    return [
      for (final e in experiencias)
        if (e.data.day == n.day && e.data.month == n.month && e.data.year < n.year)
          'Você viveu ${obra(e.obraId)?.titulo ?? '?'} há ${n.year - e.data.year} ano(s).'
    ];
  }

  List<Obra> buscar(String q) {
    q = q.toLowerCase();
    return obras.where((o) =>
        o.titulo.toLowerCase().contains(q) ||
        o.criador.toLowerCase().contains(q) ||
        deObra(o.id).any((e) =>
            e.comentario.toLowerCase().contains(q) || e.contextoVida.toLowerCase().contains(q))).toList();
  }

  Map<Tipo, int> consumidosPorTipo() {
    final ids = experiencias.where((e) => e.status == 'Terminei').map((e) => e.obraId).toSet();
    final r = {for (final t in Tipo.values) t: 0}; 
    for (final id in ids) {
      final o = obra(id);
      if (o != null) r[o.tipo] = r[o.tipo]! + 1; 
    }
    return r;
  }

  Map<Tipo, int> filaPorTipo() => {
        for (final t in Tipo.values) t: obras.where((o) => o.tipo == t && o.naFila).length
      };

  Future<void> alternarFila(Obra o) {
    o.naFila = !o.naFila;
    return _save();
  }

  Future<void> addMuitos(List<Obra> os, List<Experiencia> es) {
    obras.addAll(os);
    experiencias.addAll(es);
    return _save();
  }

  List<Obra> emprestados() => obras.where((o) => o.emprestado).toList();

  Future<void> emprestar(Obra o, String pessoa) {
    o.emprestadoPara = pessoa;
    o.emprestadoEm = pessoa.isEmpty ? null : DateTime.now();
    return _save();
  }

  Future<void> substituirObra(Obra nova) {
    final i = obras.indexWhere((o) => o.id == nova.id); 
    if (i >= 0) obras[i] = nova;
    return _save();
  }
}