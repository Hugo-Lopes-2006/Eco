// =====================================================================
// MAIN.DART  ->  TODAS AS TELAS e o ponto de entrada do app.
// Em Flutter, tudo na tela é um 'Widget' (bloco de interface) aninhado em outros.
//   StatelessWidget = tela que não muda sozinha
//   StatefulWidget  = tela que guarda estado (ex: aba selecionada)
// =====================================================================
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'dart:convert'; // utf8: transforma os bytes do arquivo em texto
import 'package:file_picker/file_picker.dart'; // janela de escolher arquivo
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard (área de transferência)
import 'models.dart';
import 'planilha.dart'; // importar/exportar CSV
import 'store.dart';

// Nome mostrado na saudação. Troque aqui.
const nomeUsuario = 'Aguinaldo';

// main() é onde o app COMEÇA. Primeiro criamos a store e carregamos os dados
// salvos; só depois abrimos a tela (por isso o 'await').
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = EcoStore();
  await store.load();
  // runApp inicia o app. MaterialApp define o tema (cores, modo escuro)
  // e qual é a primeira tela ('home'): o Shell.
  runApp(MaterialApp(
    title: 'ECO',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.lightGreenAccent, brightness: Brightness.dark),
        useMaterial3: true),
    home: Shell(store),
  ));
}

// SHELL = a "moldura" do app: guarda a barra inferior e troca a tela de dentro.
// Stateful porque precisa lembrar qual aba está ativa.
// O Shell em si recebe a store e a repassa para as telas.
class Shell extends StatefulWidget {
  final EcoStore store;
  const Shell(this.store, {super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  // idx = aba atual (0 Início, 1 Biblioteca, 2 Linha do tempo, 3 Busca).
  // tipoIdx = qual aba de tipo a Biblioteca abre (0 = Livros...).
  int idx = 0;
  int tipoIdx = 0;

  // Ícones da barra inferior, na MESMA ordem das telas em 'pages'.
  static const icons = [
    Icons.home_outlined,
    Icons.collections_bookmark_outlined,
    Icons.timeline,
    Icons.search,
  ];

  // Chamado pelo botão + do centro.
  Future<void> _novo() async {
    // Abre a folha de baixo para escolher o tipo; devolve o Tipo tocado
    // (ou null se fechar sem escolher).
    final t = await showModalBottomSheet<Tipo>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final t in Tipo.values)
            ListTile(
              leading: Text(t.emoji, style: const TextStyle(fontSize: 22)),
              title: Text('Nova obra: ${t.label}'),
              onTap: () => Navigator.pop(ctx, t),
            ),
        ]),
      ),
    );
    // Se escolheu algum tipo, abre o formulário de nova obra. 'mounted' garante que a tela ainda existe.
    if (t != null && mounted) novaObra(context, widget.store, t);
  }

  @override
  // build() DESENHA a tela. É chamado sempre que algo muda.
  // 'context' diz onde este widget está na árvore (usado p/ tema, navegação etc).
  Widget build(BuildContext context) {
    final s = widget.store;
    final cs = Theme.of(context).colorScheme;
    // Reconstrói tudo abaixo toda vez que a store avisar mudança (notifyListeners).
    return AnimatedBuilder(
      animation: s,
      builder: (_, __) {
        // As 4 telas, na ordem dos ícones. Só a do 'idx' atual aparece (pages[idx]).
        // 'setState' avisa o Flutter para redesenhar com o novo valor.
        final pages = [
          HomePage(s,
              onTipo: (t) => setState(() {
                    tipoIdx = t.index;
                    idx = 1;
                  })),
          BibliotecaPage(s, initial: tipoIdx, key: ValueKey(tipoIdx)),
          TimelinePage(s),
          BuscaPage(s),
        ];
        // Scaffold = estrutura padrão de tela: corpo, botão flutuante, barra inferior...
        return Scaffold(
          body: pages[idx],
          floatingActionButton: FloatingActionButton(
              onPressed: _novo, child: const Icon(Icons.add)),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          // A barra animada. Ajuste o visual aqui: raios dos cantos, suavidade do recorte...
          // 'onTap' recebe o índice tocado e troca a tela com setState.
          bottomNavigationBar: AnimatedBottomNavigationBar(
            icons: icons,
            activeIndex: idx,
            gapLocation: GapLocation.center,
            notchSmoothness: NotchSmoothness.verySmoothEdge,
            leftCornerRadius: 24,
            rightCornerRadius: 24,
            backgroundColor: cs.surfaceContainerHigh,
            activeColor: cs.primary,
            inactiveColor: cs.onSurfaceVariant,
            onTap: (i) => setState(() => idx = i),
          ),
        );
      },
    );
  }
}

// ---------------- INÍCIO ----------------
// TELA INÍCIO: saudação, métricas, fila, "continuar consumindo",
// "hoje na sua história" e os botões de planilha.
// 'onTipo' é uma função recebida de fora: chamada ao tocar num contador/fila.
class HomePage extends StatelessWidget {
  final EcoStore s;
  final void Function(Tipo) onTipo;
  const HomePage(this.s, {super.key, required this.onTipo});

  // Saudação conforme a hora do dia. (condição ? se_sim : se_não)
  String get saudacao {
    final h = DateTime.now().hour;
    return h < 12
        ? 'BOM DIA'
        : h < 18
            ? 'BOA TARDE'
            : 'BOA NOITE';
  }

  // Escolhe um .csv no aparelho, lê e importa. 'await' = espera terminar.
  Future<void> _importar(BuildContext context) async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    final bytes = r?.files.single.bytes; // null se cancelou
    if (bytes == null) return;
    final n = await importarCsv(s, utf8.decode(bytes, allowMalformed: true));
    // 'mounted': só mostra o aviso se a tela ainda existe.
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$n obras novas importadas')));
    }
  }

  // Copia todo o acervo em CSV para a área de transferência (cole no Excel/Planilhas).
  Future<void> _exportar(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: exportarCsv(s)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV copiado! Cole numa planilha.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoje = s.hoje();
    final consumindo =
        s.experiencias.where((e) => e.status == 'Consumindo').toList();
    final consumidos = s.consumidosPorTipo(); // métrica sem repetição, por tipo
    final fila = s.filaPorTipo(); // contador da fila, por tipo
    // fold soma todos os valores do Map (começa em 0).
    final totalConsumidos = consumidos.values.fold(0, (a, b) => a + b);
    final txt = Theme.of(context).textTheme;
    // ListView = lista com rolagem; 'children' são os itens, de cima para baixo.
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('$saudacao, ${nomeUsuario.toUpperCase()}.',
          style: txt.headlineMedium),
      const Text('O que você anda consumindo?'),
      const SizedBox(height: 16),
      // MÉTRICA: obras distintas já terminadas (reler/rever não soma de novo).
      Text('$totalConsumidos obras consumidas', style: txt.titleLarge),
      const Text('(cada obra conta uma vez, mesmo relida ou revista)'),
      const SizedBox(height: 12),
      // Wrap = coloca os cartões lado a lado e quebra a linha se faltar espaço.
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final t in Tipo.values)
          // InkWell deixa qualquer widget clicável.
          InkWell(
            onTap: () => onTipo(t),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('${t.emoji} ${t.label}'),
                  Text('${s.porTipo(t).length}',
                      style: txt.headlineSmall), // total cadastrado
                  Text('${consumidos[t]} consumidos', style: txt.bodySmall),
                ]),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 24),
      // FILA: "tenho que ler / ouvir / ver". Toque para abrir a lista do tipo.
      Text('Na fila', style: txt.titleMedium),
      Wrap(spacing: 8, children: [
        for (final t in Tipo.values)
          ActionChip(
              label: Text('🔖 ${fila[t]} para ${t.verbo}'),
              onPressed: () => onTipo(t)),
      ]),
      const SizedBox(height: 24),
      Text('Continuar consumindo', style: txt.titleMedium),
      if (consumindo.isEmpty) const Text('Nada em andamento.'),
      // 'for' dentro da lista de widgets: gera um ListTile para cada item em andamento.
      for (final e in consumindo)
        ListTile(
          title: Text(s.obra(e.obraId)?.titulo ?? '?'),
          subtitle: Text(e.comentario),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => ObraPage(s, e.obraId))),
        ),
      const SizedBox(height: 24),
      Text('Hoje na sua história', style: txt.titleMedium),
      if (hoje.isEmpty) const Text('Nenhuma lembrança para hoje ainda.'),
      for (final h in hoje)
        ListTile(leading: const Icon(Icons.auto_stories), title: Text(h)),
      const SizedBox(height: 24),
      // EMPRÉSTIMOS: quem está com as suas obras (marque na página da obra).
      Text('Emprestados', style: txt.titleMedium),
      if (s.emprestados().isEmpty) const Text('Nenhuma obra emprestada.'),
      for (final o in s.emprestados())
        ListTile(
          leading: Text(o.tipo.emoji, style: const TextStyle(fontSize: 22)),
          title: Text(o.titulo),
          subtitle: Text(
              'com ${o.emprestadoPara}${o.emprestadoEm != null ? ' desde ${fmtData(o.emprestadoEm!)}' : ''}'),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => ObraPage(s, o.id))),
        ),
      const SizedBox(height: 24),
      Text('Planilha (CSV)', style: txt.titleMedium),
      Wrap(spacing: 8, children: [
        FilledButton.icon(
            onPressed: () => _importar(context),
            icon: const Icon(Icons.upload_file),
            label: const Text('Importar CSV')),
        OutlinedButton.icon(
            onPressed: () => _exportar(context),
            icon: const Icon(Icons.copy),
            label: const Text('Copiar como CSV')),
      ]),
      const SizedBox(
          height: 80), // espaço para o botão + não cobrir o fim da lista
    ]);
  }
}

// ---------------- BIBLIOTECA (abas por tipo) ----------------
// TELA BIBLIOTECA: 5 abas (uma por tipo), cada uma mostrando a lista daquele tipo.
class BibliotecaPage extends StatelessWidget {
  final EcoStore s;
  final int initial;
  const BibliotecaPage(this.s, {super.key, this.initial = 0});

  @override
  Widget build(BuildContext context) {
    // Controla qual aba está ativa. TabBar = os títulos; TabBarView = o conteúdo de cada aba.
    return DefaultTabController(
      length: Tipo.values.length,
      initialIndex: initial,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Biblioteca'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final t in Tipo.values) Tab(text: '${t.emoji} ${t.label}')
            ],
          ),
        ),
        body: TabBarView(
            children: [for (final t in Tipo.values) ListaPage(s, t)]),
      ),
    );
  }
}

// LISTA de obras de um tipo, com campo de busca. Stateful porque guarda o texto digitado.
class ListaPage extends StatefulWidget {
  final EcoStore s;
  final Tipo tipo;
  const ListaPage(this.s, this.tipo, {super.key});
  @override
  State<ListaPage> createState() => _ListaPageState();
}

// Classe de estado (o '_' = privada). Aqui ficam os dados que mudam.
class _ListaPageState extends State<ListaPage> {
  // q = texto atual da busca.
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    // Sem busca mostra todas do tipo; com busca, filtra pelo texto.
    final lista = q.isEmpty
        ? s.porTipo(widget.tipo)
        : s.buscar(q).where((o) => o.tipo == widget.tipo).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar nesta lista...'),
          onChanged: (v) => setState(() => q = v),
        ),
      ),
      Expanded(
        child: ListView(children: [for (final o in lista) ObraTile(s, o)]),
      ),
    ]);
  }
}

// Linha de uma obra (emoji, título, autor, nota). Reaproveitada na lista e na busca.
// Ao tocar, abre a página de detalhe com Navigator.push.
class ObraTile extends StatelessWidget {
  final EcoStore s;
  final Obra o;
  const ObraTile(this.s, this.o, {super.key});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Text(o.tipo.emoji, style: const TextStyle(fontSize: 22)),
        title: Text(o.titulo),
        // 'o.detalhe' traz minutagem/plataforma/datas, conforme o tipo da obra.
        subtitle: Text([o.criador, if (o.ano != null) '${o.ano}', o.detalhe]
            .where((e) => e.isNotEmpty)
            .join(' • ')),
        // 🔖 aparece quando a obra está na fila.
        trailing: Text(
            '${o.emprestado ? '🤝 ' : ''}${o.naFila ? '🔖 ' : ''}${s.notaDe(o.id)?.toStringAsFixed(1) ?? '—'}'),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => ObraPage(s, o.id))),
      );
}

// ---------------- BUSCA GLOBAL ----------------
// TELA BUSCA: procura em todas as obras, inclusive nos comentários e no contexto de vida.
class BuscaPage extends StatefulWidget {
  final EcoStore s;
  const BuscaPage(this.s, {super.key});
  @override
  State<BuscaPage> createState() => _BuscaPageState();
}

class _BuscaPageState extends State<BuscaPage> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    // Sem texto digitado, não mostra nada.
    final res = q.isEmpty ? <Obra>[] : widget.s.buscar(q);
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            autofocus: false,
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Título, comentário, memória... (ex: solidão)'),
            onChanged: (v) => setState(() => q = v),
          ),
        ),
        Expanded(
            child: ListView(
                children: [for (final o in res) ObraTile(widget.s, o)])),
      ]),
    );
  }
}

// Formulário de OBRA (caixa de diálogo). Serve para CRIAR e para EDITAR:
// se você passar 'editar: obra', os campos já vêm preenchidos e, ao salvar,
// a obra é substituída (mesmo id), então as experiências continuam ligadas a ela.
// '{Obra? editar}' = parâmetro opcional nomeado (pode ser null = modo "criar").
Future<void> novaObra(BuildContext context, EcoStore s, Tipo tipo,
    {Obra? editar}) async {
  // Controllers guardam o que o usuário digita. 'text:' é o valor inicial;
  // 'editar?.titulo' = o título se estiver editando, senão null.
  final titulo = TextEditingController(text: editar?.titulo);
  final criador = TextEditingController(text: editar?.criador);
  final ano = TextEditingController(text: editar?.ano?.toString());
  final local = TextEditingController(text: editar?.localizacao);
  final minutos = TextEditingController(text: editar?.minutos?.toString());
  final plataforma = TextEditingController(text: editar?.plataforma);
  bool possuo = editar?.possuo ?? false, fila = editar?.naFila ?? false;
  // O formato salvo precisa existir na lista do menu; senão usa o primeiro.
  String formato =
      formatos.contains(editar?.formato) ? editar!.formato : formatos.first;

  final ok = await showDialog<bool>(
    context: context,
    // StatefulBuilder permite atualizar o diálogo com set(() => ...).
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title:
            Text(editar == null ? 'Nova obra (${tipo.label})' : 'Editar obra'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: titulo,
                decoration: const InputDecoration(labelText: 'Título')),
            TextField(
                controller: criador,
                decoration: const InputDecoration(
                    labelText: 'Autor / artista / estúdio')),
            TextField(
                controller: ano,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ano')),
            // ---- CAMPOS ESPECÍFICOS: o 'if' dentro da lista só mostra para o tipo certo ----
            // (datas de leitura do livro ficam na EXPERIÊNCIA, não aqui)
            if (tipo == Tipo.album || tipo == Tipo.filme)
              TextField(
                  controller: minutos,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Minutagem (minutos)')),
            if (tipo == Tipo.filme || tipo == Tipo.serie || tipo == Tipo.jogo)
              TextField(
                  controller: plataforma,
                  decoration: const InputDecoration(
                      labelText: 'Plataforma (Netflix, Steam...)')),
            // ---- fim dos campos específicos ----
            SwitchListTile(
                title: Text('Quero ${tipo.verbo} (na fila)'),
                value: fila,
                onChanged: (v) => set(() => fila = v)),
            SwitchListTile(
                title: const Text('Possuo'),
                value: possuo,
                onChanged: (v) => set(() => possuo = v)),
            DropdownButton<String>(
                value: formato,
                items: [
                  for (final f in formatos)
                    DropdownMenuItem(value: f, child: Text(f))
                ],
                onChanged: (v) => set(() => formato = v!)),
            TextField(
                controller: local,
                decoration: const InputDecoration(
                    labelText: 'Localização (estante/prateleira/posição)')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    ),
  );
  // Salvou com título preenchido: Obra.criar monta o objeto do tipo certo.
  if (ok == true && titulo.text.trim().isNotEmpty) {
    final obra = Obra.criar(tipo,
        id: editar?.id ?? s.newId(), // editando: mantém o id antigo
        titulo: titulo.text.trim(),
        criador: criador.text.trim(),
        ano: int.tryParse(ano.text),
        possuo: possuo,
        formato: formato,
        localizacao: local.text.trim(),
        naFila: fila,
        minutos: int.tryParse(minutos.text),
        plataforma: plataforma.text.trim(),
        // Preserva o empréstimo atual ao editar.
        emprestadoPara: editar?.emprestadoPara ?? '',
        emprestadoEm: editar?.emprestadoEm);
    if (editar == null) {
      await s.addObra(obra);
    } else {
      await s.substituirObra(obra);
    }
  }
}

// ---------------- DETALHE DA OBRA ----------------
// TELA DE DETALHE de uma obra: campos do tipo, fila, biblioteca física e experiências.
class ObraPage extends StatelessWidget {
  final EcoStore s;
  final String obraId;
  const ObraPage(this.s, this.obraId, {super.key});

  // Pergunta "para quem?" e registra o empréstimo na store.
  Future<void> _emprestar(BuildContext context, Obra o) async {
    final nome = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emprestar para quem?'),
        content: TextField(
            controller: nome,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome da pessoa')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true && nome.text.trim().isNotEmpty)
      await s.emprestar(o, nome.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    // Atualiza a página quando a store muda (ex: ao adicionar uma experiência).
    return AnimatedBuilder(
      animation: s,
      builder: (_, __) {
        final o = s.obra(obraId);
        if (o == null) return const Scaffold(); // obra apagada
        final exps = s.deObra(o.id);
        return Scaffold(
          appBar: AppBar(title: Text(o.titulo), actions: [
            // EDITAR: reabre o formulário com os dados atuais (para completar/aprofundar).
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => novaObra(context, s, o.tipo, editar: o),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                s.removeObra(o.id);
                Navigator.pop(context);
              },
            ),
          ]),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => novaExperiencia(context, s, o.id),
            icon: const Icon(Icons.add),
            label: const Text('Experiência'),
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text(o.criador, style: Theme.of(context).textTheme.titleMedium),
            Text('${o.tipo.label}${o.ano != null ? ' • ${o.ano}' : ''}'),
            // Campos especiais do tipo (datas do livro, minutagem, plataforma).
            if (o.detalhe.isNotEmpty) Text(o.detalhe),
            Text(
                'Nota atual: ${s.notaDe(o.id)?.toStringAsFixed(1) ?? '—'}   |   Experiências: ${exps.length}'),
            // Liga/desliga a fila; alternarFila salva e atualiza os contadores.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Quero ${o.tipo.verbo} (na fila)'),
              value: o.naFila,
              onChanged: (_) => s.alternarFila(o),
            ),
            const Divider(height: 32),
            Text('BIBLIOTECA FÍSICA',
                style: Theme.of(context).textTheme.labelLarge),
            Text(o.possuo
                ? 'Possuo (${o.formato}) — ${o.localizacao.isEmpty ? 'sem localização' : o.localizacao}'
                : 'Não possuo'),
            const Divider(height: 32),
            // EMPRÉSTIMO: só aparece para obra que possuo.
            if (o.possuo) ...[
              Text('EMPRÉSTIMO', style: Theme.of(context).textTheme.labelLarge),
              if (o.emprestado)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.handshake_outlined),
                  title: Text('Emprestado para ${o.emprestadoPara}'),
                  subtitle: Text(o.emprestadoEm == null
                      ? ''
                      : 'desde ${fmtData(o.emprestadoEm!)}'),
                  // Passar '' = devolvido.
                  trailing: FilledButton(
                      onPressed: () => s.emprestar(o, ''),
                      child: const Text('Devolvido')),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Emprestar'),
                    onPressed: () => _emprestar(context, o),
                  ),
                ),
              const Divider(height: 32),
            ],
            Text('MINHAS EXPERIÊNCIAS',
                style: Theme.of(context).textTheme.labelLarge),
            // Um cartão por experiência, numerado (#1, #2...).
            for (var i = 0; i < exps.length; i++)
              Card(
                child: ListTile(
                  title: Text(
                      '#${i + 1} • ${fmtData(exps[i].data)} • ${exps[i].status} • ★ ${exps[i].nota.toStringAsFixed(1)}'),
                  subtitle: Text([
                    // Período da leitura (quando preenchido).
                    if (exps[i].inicio != null || exps[i].fim != null)
                      'Período: ${exps[i].inicio == null ? '?' : fmtData(exps[i].inicio!)} → ${exps[i].fim == null ? '?' : fmtData(exps[i].fim!)}',
                    if (exps[i].comentario.isNotEmpty)
                      '“${exps[i].comentario}”',
                    if (exps[i].contextoVida.isNotEmpty)
                      'Na minha vida: ${exps[i].contextoVida}',
                  ].join('\n')),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// Formulário de NOVA EXPERIÊNCIA: data, estado, nota, o que pensei e vida na época.
// Se a obra for um LIVRO, também pede início e fim desta leitura.
Future<void> novaExperiencia(
    BuildContext context, EcoStore s, String obraId) async {
  final coment = TextEditingController(), vida = TextEditingController();
  final ehLivro = s.obra(obraId) is Livro; // 'is' testa o tipo do objeto
  // Valores iniciais do formulário: hoje, nota 8, estado 'Terminei'.
  DateTime data = DateTime.now();
  DateTime? inicio, fim; // período da leitura (opcionais)
  double nota = 8;
  String status = 'Terminei';

  // Abre o calendário e devolve a data escolhida (ou null se cancelar).
  Future<DateTime?> escolher(BuildContext ctx, DateTime? atual) =>
      showDatePicker(
          context: ctx,
          initialDate: atual ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime(2100));

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Nova experiência'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text('Data: ${fmtData(data)}'),
              onPressed: () async {
                final d = await escolher(ctx, data);
                if (d != null) set(() => data = d);
              },
            ),
            // Só livros: início e fim da leitura. Ao escolher o fim, a 'data' da experiência acompanha.
            if (ehLivro) ...[
              TextButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(inicio == null
                    ? 'Início da leitura'
                    : 'Início: ${fmtData(inicio!)}'),
                onPressed: () async {
                  final d = await escolher(ctx, inicio);
                  if (d != null) set(() => inicio = d);
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.flag),
                label: Text(
                    fim == null ? 'Fim da leitura' : 'Fim: ${fmtData(fim!)}'),
                onPressed: () async {
                  final d = await escolher(ctx, fim);
                  if (d != null)
                    set(() {
                      fim = d;
                      data = d;
                    });
                },
              ),
            ],
            DropdownButton<String>(
                value: status,
                items: [
                  for (final e in estados)
                    DropdownMenuItem(value: e, child: Text(e))
                ],
                onChanged: (v) => set(() => status = v!)),
            // Deslizante de 0 a 10 em passos de 0,5 (20 divisões).
            Slider(
                value: nota,
                min: 0,
                max: 10,
                divisions: 20,
                label: nota.toStringAsFixed(1),
                onChanged: (v) => set(() => nota = v)),
            TextField(
                controller: coment,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'O que pensei')),
            TextField(
                controller: vida,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'O que acontecia na minha vida')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    ),
  );
  // Apertou Salvar: cria a Experiencia e guarda na store.
  if (ok == true) {
    await s.addExperiencia(Experiencia(
        id: s.newId(),
        obraId: obraId,
        data: data,
        nota: nota,
        status: status,
        comentario: coment.text.trim(),
        contextoVida: vida.text.trim(),
        inicio: inicio,
        fim: fim));
  }
}

// ---------------- LINHA DO TEMPO ----------------
// TELA LINHA DO TEMPO: experiências agrupadas por ano.
class TimelinePage extends StatelessWidget {
  final EcoStore s;
  const TimelinePage(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final exps = [...s.experiencias]..sort((a, b) => a.data.compareTo(b.data));
    // Map ano -> lista de experiências. 'putIfAbsent' cria a lista do ano se ainda não existir.
    final porAno = <int, List<Experiencia>>{};
    for (final e in exps) {
      porAno.putIfAbsent(e.data.year, () => []).add(e);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Linha do tempo')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (porAno.isEmpty)
          const Text('Registre experiências para ver sua formação cultural.'),
        for (final ano in porAno.keys) ...[
          Text('$ano', style: Theme.of(context).textTheme.headlineSmall),
          for (final e in porAno[ano]!)
            ListTile(
              dense: true,
              leading: Text(s.obra(e.obraId)?.tipo.emoji ?? ''),
              title: Text(s.obra(e.obraId)?.titulo ?? '?'),
              subtitle: Text('${e.data.day}/${e.data.month} • ${e.status}'),
            ),
        ],
      ]),
    );
  }
}
