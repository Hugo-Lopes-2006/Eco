// =====================================================================
// STORE.DART  ->  guarda os dados, salva/carrega e responde perguntas
// sobre eles (buscar, notas...). Nenhum código de tela aqui.
// =====================================================================
// 'import' traz código de outros pacotes/arquivos para usar aqui.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Persistência simples em JSON. Troque por sqflite/drift quando crescer.
// ChangeNotifier: permite avisar as telas "os dados mudaram, se redesenhem".
// Quando chamamos notifyListeners(), todo AnimatedBuilder ligado à store atualiza.
class EcoStore extends ChangeNotifier {
  // As duas listas que guardam TUDO enquanto o app está aberto.
  List<Obra> obras = [];
  List<Experiencia> experiencias = [];

  // Gera um id único usando o horário atual em microssegundos.
  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // Carrega os dados salvos no aparelho.
  // 'Future' + 'async/await' = operação que demora (ler disco); esperamos terminar.
  Future<void> load() async {
    final raw = (await SharedPreferences.getInstance()).getString('eco');
    if (raw == null) return;
    // Transforma o texto JSON em Map; depois cada item vira Obra/Experiencia.
    final m = jsonDecode(raw);
    obras = (m['obras'] as List).map((e) => Obra.fromJson(e)).toList();
    experiencias = (m['experiencias'] as List).map((e) => Experiencia.fromJson(e)).toList();
  }

  // Salva tudo como um único texto JSON. O '_' no início = método privado
  // (só usado dentro deste arquivo). No fim, avisa as telas para atualizarem.
  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('eco', jsonEncode({
      'obras': obras.map((e) => e.toJson()).toList(),
      'experiencias': experiencias.map((e) => e.toJson()).toList(),
    }));
    notifyListeners();
  }

  // Adiciona uma obra à lista e salva. Telas atualizam sozinhas.
  Future<void> addObra(Obra o) { obras.add(o); return _save(); }
  // Adiciona uma experiência e salva.
  Future<void> addExperiencia(Experiencia e) {
    experiencias.add(e);
    obra(e.obraId)?.naFila = false; // se viveu a obra, ela sai da fila ('?.' = só se existir)
    return _save();
  }
  // Remove a obra E todas as experiências dela ('removeWhere' = apaga os que combinam).
  Future<void> removeObra(String id) {
    obras.removeWhere((o) => o.id == id);
    experiencias.removeWhere((e) => e.obraId == id);
    return _save();
  }

  // Busca uma obra pelo id. Retorna null se não achar (por isso 'Obra?').
  Obra? obra(String id) => obras.where((o) => o.id == id).firstOrNull;
  // Filtra as obras de um tipo (ex: só livros). '=>' é a forma curta de 'return'.
  List<Obra> porTipo(Tipo t) => obras.where((o) => o.tipo == t).toList();
  // Experiências de uma obra, ordenadas da mais antiga para a mais nova.
  // '..sort' ordena a própria lista criada.
  List<Experiencia> deObra(String id) =>
      experiencias.where((e) => e.obraId == id).toList()..sort((a, b) => a.data.compareTo(b.data));

  // A nota atual da obra = a nota da experiência mais recente (ignora nota 0).
  // Sem nenhuma nota, retorna null.
  double? notaDe(String obraId) {
    final l = deObra(obraId).where((e) => e.nota > 0);
    return l.isEmpty ? null : l.last.nota;
  }

  // 'Hoje na sua história': acha experiências feitas no mesmo dia e mês,
  // mas em anos anteriores, e monta frases como 'há 3 ano(s)'.
  // O 'for' dentro dos colchetes cria a lista já filtrada.
  /// "Hoje na sua história": experiências no mesmo dia/mês de anos anteriores.
  List<String> hoje() {
    final n = DateTime.now();
    return [
      for (final e in experiencias)
        if (e.data.day == n.day && e.data.month == n.month && e.data.year < n.year)
          'Você viveu ${obra(e.obraId)?.titulo ?? '?'} há ${n.year - e.data.year} ano(s).'
    ];
  }

  // Busca simples: procura o texto no título, criador, comentário ou contexto de vida.
  // 'toLowerCase' ignora maiúsculas/minúsculas; 'any' = 'existe pelo menos um'.
  /// Busca em títulos, comentários e contexto de vida.
  List<Obra> buscar(String q) {
    q = q.toLowerCase();
    return obras.where((o) =>
        o.titulo.toLowerCase().contains(q) ||
        o.criador.toLowerCase().contains(q) ||
        deObra(o.id).any((e) =>
            e.comentario.toLowerCase().contains(q) || e.contextoVida.toLowerCase().contains(q))).toList();
  }

  // MÉTRICA "CONSUMIDOS SEM REPETIR": conta OBRAS distintas com ao menos uma
  // experiência 'Terminei'. Reler/rever o mesmo título NÃO soma de novo,
  // porque guardamos só os ids (um Set não aceita repetidos).
  Map<Tipo, int> consumidosPorTipo() {
    final ids = experiencias.where((e) => e.status == 'Terminei').map((e) => e.obraId).toSet();
    final r = {for (final t in Tipo.values) t: 0}; // começa tudo em zero
    for (final id in ids) {
      final o = obra(id);
      if (o != null) r[o.tipo] = r[o.tipo]! + 1; // '!' = "tenho certeza que não é null"
    }
    return r;
  }

  // CONTADOR DA FILA: quantas obras de cada tipo estão marcadas "quero ler/ouvir/ver".
  Map<Tipo, int> filaPorTipo() => {
        for (final t in Tipo.values) t: obras.where((o) => o.tipo == t && o.naFila).length
      };

  // Liga/desliga a marcação de fila de uma obra.
  Future<void> alternarFila(Obra o) {
    o.naFila = !o.naFila;
    return _save();
  }

  // Adiciona várias de uma vez (usado na importação da planilha) e salva uma só vez.
  Future<void> addMuitos(List<Obra> os, List<Experiencia> es) {
    obras.addAll(os);
    experiencias.addAll(es);
    return _save();
  }

  // EMPRÉSTIMOS: obras que estão com outras pessoas.
  List<Obra> emprestados() => obras.where((o) => o.emprestado).toList();

  // Registra o empréstimo. Passe pessoa = '' para marcar como DEVOLVIDO.
  Future<void> emprestar(Obra o, String pessoa) {
    o.emprestadoPara = pessoa;
    o.emprestadoEm = pessoa.isEmpty ? null : DateTime.now();
    return _save();
  }

  // EDITAR: troca a obra antiga pela nova (mesmo id), então as experiências continuam ligadas.
  Future<void> substituirObra(Obra nova) {
    final i = obras.indexWhere((o) => o.id == nova.id); // posição da antiga
    if (i >= 0) obras[i] = nova;
    return _save();
  }
}
