// =====================================================================
// MODELS.DART  ->  descreve COMO OS DADOS SÃO (só "formas", sem tela).
// =====================================================================
// Um 'enum' é uma lista fixa de opções. Aqui: os tipos de mídia.
// Cada opção carrega um texto (label) e um emoji, usados nas telas.
// Uso: Tipo.livro.label  ->  'Livros'
enum Tipo {
  // Terceiro valor = verbo usado na fila ("3 para ler", "2 para ouvir"...).
  livro('Livros', '📚', 'ler'),
  album('Álbuns', '🎵', 'ouvir'),
  filme('Filmes', '🎬', 'ver'),
  serie('Séries', '📺', 'ver'),
  jogo('Jogos', '🎮', 'jogar');

  final String label;
  final String emoji;
  final String verbo;
  const Tipo(this.label, this.emoji, this.verbo);
}

// Listas fixas usadas em menus de escolha (dropdowns).
// 'const' = valor que nunca muda.
const estados = ['Não comecei', 'Consumindo', 'Terminei', 'Abandonei', 'Quero revisitar'];
const formatos = ['Física', 'Kindle', 'PDF', 'Spotify', 'Steam', 'Blu-ray', 'Streaming', 'Outro'];

// Funções auxiliares (o '_' no início = só usadas neste arquivo).
DateTime? _data(dynamic v) => v == null ? null : DateTime.tryParse(v); // texto -> data (ou null)
String fmtData(DateTime d) => '${d.day}/${d.month}/${d.year}'; // 15/3/2024

// OBRA = molde COMUM a todos os tipos (título, autor, ano, se possuo, fila...).
// Livro, Album, Filme, Serie e Jogo "herdam" (extends) tudo isto e ganham
// campos próprios. Para um campo que TODOS têm, edite aqui.
class Obra {
  final String id;
  final Tipo tipo;
  String titulo, criador, formato, localizacao;
  int? ano;
  bool possuo;
  bool naFila; // true = "quero ler/ouvir/ver" (ainda não consumi)
  String emprestadoPara; // nome de quem está com a obra ('' = está comigo)
  DateTime? emprestadoEm; // desde quando está emprestada

  Obra({required this.id, required this.tipo, required this.titulo, this.criador = '',
      this.ano, this.possuo = false, this.formato = 'Física', this.localizacao = '',
      this.naFila = false, this.emprestadoPara = '', this.emprestadoEm});

  // Lê os campos comuns de um Map. As subclasses chamam isto via 'super.fromMap(j)'.
  Obra.fromMap(Map<String, dynamic> j)
      : id = j['id'],
        tipo = Tipo.values.byName(j['tipo']),
        titulo = j['titulo'],
        criador = j['criador'] ?? '',
        ano = j['ano'],
        possuo = j['possuo'] ?? false,
        formato = j['formato'] ?? 'Física',
        localizacao = j['localizacao'] ?? '',
        naFila = j['naFila'] ?? false, // dados antigos não tinham: assume false
        emprestadoPara = j['emprestadoPara'] ?? '',
        emprestadoEm = _data(j['emprestadoEm']);

  // Ao CARREGAR do JSON: olha o 'tipo' salvo e cria o objeto certo (Livro, Filme...).
  factory Obra.fromJson(Map<String, dynamic> j) => switch (Tipo.values.byName(j['tipo'])) {
        Tipo.livro => Livro.fromJson(j),
        Tipo.album => Album.fromJson(j),
        Tipo.filme => Filme.fromJson(j),
        Tipo.serie => Serie.fromJson(j),
        Tipo.jogo => Jogo.fromJson(j),
      };

  // Para CRIAR por tipo (formulário e importação de planilha usam esta).
  // Cada tipo usa só os campos que importam para ele; o resto é ignorado.
  factory Obra.criar(Tipo t, {required String id, required String titulo, String criador = '',
      int? ano, bool possuo = false, String formato = 'Física', String localizacao = '',
      bool naFila = false, int? minutos, String plataforma = '',
      String emprestadoPara = '', DateTime? emprestadoEm}) {
    final o = switch (t) {
      Tipo.livro => Livro(id: id, titulo: titulo, criador: criador, ano: ano, possuo: possuo,
          formato: formato, localizacao: localizacao, naFila: naFila),
      Tipo.album => Album(id: id, titulo: titulo, criador: criador, ano: ano, possuo: possuo,
          formato: formato, localizacao: localizacao, naFila: naFila, minutos: minutos),
      Tipo.filme => Filme(id: id, titulo: titulo, criador: criador, ano: ano, possuo: possuo,
          formato: formato, localizacao: localizacao, naFila: naFila, minutos: minutos, plataforma: plataforma),
      Tipo.serie => Serie(id: id, titulo: titulo, criador: criador, ano: ano, possuo: possuo,
          formato: formato, localizacao: localizacao, naFila: naFila, plataforma: plataforma),
      Tipo.jogo => Jogo(id: id, titulo: titulo, criador: criador, ano: ano, possuo: possuo,
          formato: formato, localizacao: localizacao, naFila: naFila, plataforma: plataforma),
    };
    // Empréstimo é comum a todos os tipos: aplicado depois de criar.
    o.emprestadoPara = emprestadoPara;
    o.emprestadoEm = emprestadoEm;
    return o;
  }


  // Obra -> Map para salvar. As subclasses acrescentam seus campos com '...super.toJson()'.
  Map<String, dynamic> toJson() => {
        'id': id, 'titulo': titulo, 'criador': criador, 'tipo': tipo.name, 'ano': ano,
        'possuo': possuo, 'formato': formato, 'localizacao': localizacao, 'naFila': naFila,
        'emprestadoPara': emprestadoPara, 'emprestadoEm': emprestadoEm?.toIso8601String(),
      };

  // Texto curto com os campos especiais, mostrado nas listas e no detalhe.
  // Cada subclasse sobrescreve (@override) com o que lhe interessa.
  String get detalhe => '';

  // true quando a obra está emprestada para alguém.
  bool get emprestado => emprestadoPara.isNotEmpty;

  // Valores padrão que Album/Filme/Serie/Jogo "sobrescrevem" com seus campos reais.
  // Assim qualquer tela pode ler obra.minutos ou obra.plataforma sem checar o tipo.
  int? get minutos => null;
  String get plataforma => '';
}

// LIVRO: sem campos próprios por enquanto. As datas de início/fim da leitura
// ficam em cada EXPERIÊNCIA (assim cada releitura tem as suas datas).
class Livro extends Obra {
  Livro({required super.id, required super.titulo, super.criador, super.ano, super.possuo,
      super.formato, super.localizacao, super.naFila})
      : super(tipo: Tipo.livro);
  Livro.fromJson(Map<String, dynamic> j) : super.fromMap(j);
}


// ÁLBUM: ganha minutagem (duração total em minutos).
class Album extends Obra {
  int? minutos;
  Album({required super.id, required super.titulo, super.criador, super.ano, super.possuo,
      super.formato, super.localizacao, super.naFila, this.minutos})
      : super(tipo: Tipo.album);
  Album.fromJson(Map<String, dynamic> j) : minutos = j['minutos'], super.fromMap(j);
  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'minutos': minutos};
  @override
  String get detalhe => minutos == null ? '' : '$minutos min';
}

// FILME: minutagem + plataforma (Netflix, cinema, Blu-ray...).
class Filme extends Obra {
  int? minutos;
  String plataforma;
  Filme({required super.id, required super.titulo, super.criador, super.ano, super.possuo,
      super.formato, super.localizacao, super.naFila, this.minutos, this.plataforma = ''})
      : super(tipo: Tipo.filme);
  Filme.fromJson(Map<String, dynamic> j)
      : minutos = j['minutos'], plataforma = j['plataforma'] ?? '', super.fromMap(j);
  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'minutos': minutos, 'plataforma': plataforma};
  @override
  String get detalhe => [if (minutos != null) '$minutos min', if (plataforma.isNotEmpty) plataforma].join(' • ');
}

// SÉRIE: plataforma.
class Serie extends Obra {
  String plataforma;
  Serie({required super.id, required super.titulo, super.criador, super.ano, super.possuo,
      super.formato, super.localizacao, super.naFila, this.plataforma = ''})
      : super(tipo: Tipo.serie);
  Serie.fromJson(Map<String, dynamic> j) : plataforma = j['plataforma'] ?? '', super.fromMap(j);
  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'plataforma': plataforma};
  @override
  String get detalhe => plataforma;
}

// JOGO: plataforma (Steam, PlayStation...).
class Jogo extends Obra {
  String plataforma;
  Jogo({required super.id, required super.titulo, super.criador, super.ano, super.possuo,
      super.formato, super.localizacao, super.naFila, this.plataforma = ''})
      : super(tipo: Tipo.jogo);
  Jogo.fromJson(Map<String, dynamic> j) : plataforma = j['plataforma'] ?? '', super.fromMap(j);
  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'plataforma': plataforma};
  @override
  String get detalhe => plataforma;
}


/// Cada vez que você viveu a obra (leitura, audição, partida...).
// EXPERIÊNCIA: cada vez que você viveu uma obra (leu, ouviu, jogou...).
// Uma Obra pode ter várias Experiências. A ligação é o 'obraId'.
class Experiencia {
  // id = identificador desta experiência; obraId = a qual obra ela pertence.
  final String id, obraId;
  DateTime data;
  DateTime? inicio, fim; // período (livros: início e fim desta leitura)
  double nota;
  String status, comentario, contextoVida;

  // Construtor da Experiência (mesma ideia do construtor da Obra).
  Experiencia({required this.id, required this.obraId, required this.data, this.nota = 0,
      this.status = 'Terminei', this.comentario = '', this.contextoVida = '', this.inicio, this.fim});

  // Experiência -> Map/JSON. DateTime é salvo como texto no formato ISO.
  Map<String, dynamic> toJson() => {
        'id': id, 'obraId': obraId, 'data': data.toIso8601String(), 'nota': nota,
        'status': status, 'comentario': comentario, 'contextoVida': contextoVida,
        'inicio': inicio?.toIso8601String(), 'fim': fim?.toIso8601String(),
      };

  // Map/JSON -> Experiência. 'DateTime.parse' lê o texto da data de volta.
  factory Experiencia.fromJson(Map<String, dynamic> j) => Experiencia(
        id: j['id'], obraId: j['obraId'], data: DateTime.parse(j['data']),
        nota: (j['nota'] ?? 0).toDouble(), status: j['status'] ?? 'Terminei',
        comentario: j['comentario'] ?? '', contextoVida: j['contextoVida'] ?? '',
        inicio: _data(j['inicio']), fim: _data(j['fim']),
      );
}
