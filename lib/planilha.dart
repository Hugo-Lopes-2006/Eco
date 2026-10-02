// =====================================================================
// PLANILHA.DART -> importar e exportar CSV (abre no Excel / Google Planilhas).
// Dica: no Excel use "Salvar como > CSV". Aceita separador ',' ou ';'.
// Cada linha = uma obra (+ uma experiência, se tiver status/nota/data).
// Para registrar RELEITURAS, repita o título em outra linha.
// =====================================================================
import 'package:csv/csv.dart';
import 'models.dart';
import 'store.dart';

// Colunas do arquivo. Para criar um campo novo na planilha, comece por aqui.
const colunas = [
  'tipo', 'titulo', 'criador', 'ano', 'plataforma', 'minutos', 'possuo', 'fila',
  'emprestado_para', 'status', 'nota', 'inicio', 'fim', 'data', 'comentario'
];
// 'tipo' aceita: livro, album, filme, serie, jogo
// 'status' aceita: Não comecei, Consumindo, Terminei, Abandonei, Quero revisitar
// datas aceitas: 2024-03-15 ou 15/03/2024 | possuo/fila: sim ou nao

// Pega a plataforma/minutos de qualquer obra (só alguns tipos têm esses campos).
// 'Filme f =>' testa o tipo do objeto e já o chama de 'f'.
String _plat(Obra o) => switch (o) {
      Filme f => f.plataforma, Serie s => s.plataforma, Jogo j => j.plataforma, _ => ''
    };
Object _min(Obra o) => switch (o) { Album a => a.minutos ?? '', Filme f => f.minutos ?? '', _ => '' };

String _two(int n) => n.toString().padLeft(2, '0'); // 5 -> '05'
String _iso(DateTime? d) => d == null ? '' : '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// EXPORTAR: devolve o texto CSV de todo o acervo.
String exportarCsv(EcoStore s) {
  final linhas = <List<dynamic>>[colunas];
  for (final o in s.obras) {
    final exps = s.deObra(o.id);
    // Parte comum a todas as linhas desta obra.
    final base = [
      o.tipo.name, o.titulo, o.criador, o.ano ?? '', _plat(o), _min(o),
      o.possuo ? 'sim' : 'nao', o.naFila ? 'sim' : 'nao', o.emprestadoPara
    ];
    if (exps.isEmpty) linhas.add([...base, '', '', '', '', '', '']); // obra sem experiência
    // inicio/fim agora são POR EXPERIÊNCIA (cada leitura tem as suas datas).
    for (final e in exps) {
      linhas.add([...base, e.status, e.nota, _iso(e.inicio), _iso(e.fim), _iso(e.data), e.comentario]);
    }
  }
  return const ListToCsvConverter().convert(linhas);
}

DateTime? _data(String t) {
  if (t.isEmpty) return null;
  // Formato brasileiro dd/mm/aaaa
  final br = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(t);
  if (br != null) return DateTime(int.parse(br[3]!), int.parse(br[2]!), int.parse(br[1]!));
  return DateTime.tryParse(t); // formato 2024-03-15
}

bool _sim(String t) => ['sim', 's', '1', 'true', 'x'].contains(t.toLowerCase());

/// IMPORTAR: lê o texto CSV e adiciona ao acervo. Devolve quantas obras NOVAS entraram.
/// Obras que já existem (mesmo tipo + título) são ignoradas, então dá para importar de novo sem duplicar.
Future<int> importarCsv(EcoStore s, String texto) async {
  texto = texto.replaceAll('\r\n', '\n').replaceAll('\uFEFF', '');
  // O Excel brasileiro usa ';' como separador; detectamos pela primeira linha.
  final sep = texto.split('\n').first.contains(';') ? ';' : ',';
  final linhas = CsvToListConverter(fieldDelimiter: sep, eol: '\n', shouldParseNumbers: false).convert(texto);
  if (linhas.length < 2) return 0;

  final cab = linhas.first.map((c) => c.toString().trim().toLowerCase()).toList();
  final existentes = {for (final o in s.obras) '${o.tipo.name}|${o.titulo.toLowerCase()}'};
  final novas = <String, Obra>{}; // chave tipo|título -> obra (agrupa releituras)
  final exps = <Experiencia>[];
  var n = 0;
  String nid() => '${DateTime.now().microsecondsSinceEpoch}_${n++}'; // ids únicos

  for (final l in linhas.skip(1)) {
    // c('titulo') devolve o valor da coluna 'titulo' desta linha ('' se não existir).
    String c(String nome) {
      final i = cab.indexOf(nome);
      return (i < 0 || i >= l.length) ? '' : l[i].toString().trim();
    }

    final tipo = Tipo.values.where((t) => t.name == c('tipo').toLowerCase()).firstOrNull;
    final titulo = c('titulo');
    if (tipo == null || titulo.isEmpty) continue; // linha inválida: pula
    final chave = '${tipo.name}|${titulo.toLowerCase()}';
    if (existentes.contains(chave)) continue; // já existe: pula

    final obra = novas.putIfAbsent(
      chave,
      () => Obra.criar(tipo,
          id: nid(), titulo: titulo, criador: c('criador'), ano: int.tryParse(c('ano')),
          possuo: _sim(c('possuo')), naFila: _sim(c('fila')),
          minutos: int.tryParse(c('minutos')), plataforma: c('plataforma'),
          emprestadoPara: c('emprestado_para')),
    );

    // Se a linha tem dados de experiência, cria uma Experiencia.
    final status = c('status');
    final nota = double.tryParse(c('nota').replaceAll(',', '.'));
    final data = _data(c('data'));
    if (status.isNotEmpty || nota != null || data != null || c('fim').isNotEmpty) {
      exps.add(Experiencia(
        id: nid(), obraId: obra.id,
        inicio: _data(c('inicio')), fim: _data(c('fim')), // período desta leitura
        // Sem 'data' na linha: usa o fim da leitura ou hoje.
        data: data ?? _data(c('fim')) ?? DateTime.now(),
        nota: nota ?? 0,
        status: estados.contains(status) ? status : 'Terminei',
        comentario: c('comentario'),
      ));
    }
  }
  await s.addMuitos(novas.values.toList(), exps);
  return novas.length;
}
