import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_controller.dart';
import '../../domain/models/simulation_models.dart';
import '../../domain/rules/backup_validator.dart';
import '../../infrastructure/exports/backup_service.dart';
import '../navigation/app_route.dart';
import '../theme/meta_feita_theme.dart';
import '../widgets/cards.dart';
import '../widgets/meta_feita_buttons.dart';
import '../widgets/meta_feita_icon.dart';

enum _HistoricoFilter { todas, juros, dividendos, metas, outras }

class HistoricoScreen extends StatefulWidget {
  final AppController controller;
  final void Function(AppRoute route, {SavedSimulation? openSimulation})
      onNavigate;
  final VoidCallback? onBack;

  const HistoricoScreen({
    super.key,
    required this.controller,
    required this.onNavigate,
    this.onBack,
  });

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  final _searchCtrl = TextEditingController();
  _HistoricoFilter _filter = _HistoricoFilter.todas;
  bool _busyBackup = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SavedSimulation> _filteredSimulations() {
    final query = _searchCtrl.text.trim().toLowerCase();
    return widget.controller.simulations.where((sim) {
      final matchesFilter = switch (_filter) {
        _HistoricoFilter.todas => true,
        _HistoricoFilter.juros => sim.type == SimulationType.compoundInterest,
        _HistoricoFilter.dividendos => sim.type == SimulationType.dividends,
        _HistoricoFilter.metas => sim.type == SimulationType.goal,
        _HistoricoFilter.outras =>
          sim.type != SimulationType.compoundInterest &&
              sim.type != SimulationType.dividends &&
              sim.type != SimulationType.goal,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return sim.title.toLowerCase().contains(query) ||
          sim.summaryLabel.toLowerCase().contains(query) ||
          sim.type.labelPt.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSimulations();
    final totalSaved = widget.controller.simulations.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            if (widget.onBack != null)
              IconButton(
                tooltip: 'Voltar',
                onPressed: widget.onBack,
                icon: const MetaFeitaIcon(MfIcon.voltar, size: 22),
              ),
            Expanded(child: Text('Histórico', style: MfText.titulo)),
            if (totalSaved > 0)
              Text(
                '$totalSaved ${totalSaved == 1 ? 'salva' : 'salvas'}',
                style: MfText.pequeno,
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchCtrl,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar simulação',
            prefixIcon: const Padding(
              padding: EdgeInsets.all(12),
              child: MetaFeitaIcon(MfIcon.buscar, size: 20),
            ),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                    },
                    icon: const MetaFeitaIcon(MfIcon.fechar, size: 18),
                  )
                : null,
            filled: true,
            fillColor: MfColors.areiaCard,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: MfColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: MfColors.border),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChip('Todas', _HistoricoFilter.todas),
              const SizedBox(width: 8),
              _buildChip('Juros', _HistoricoFilter.juros),
              const SizedBox(width: 8),
              _buildChip('Dividendos', _HistoricoFilter.dividendos),
              const SizedBox(width: 8),
              _buildChip('Metas', _HistoricoFilter.metas),
              const SizedBox(width: 8),
              _buildChip('Outras', _HistoricoFilter.outras),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_filter == _HistoricoFilter.metas &&
            filtered.isEmpty &&
            widget.controller.goals.isNotEmpty) ...[
          LightCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const MetaFeitaIcon(MfIcon.metas, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.controller.goals.length} meta(s) ativa(s) na aba Metas',
                        style: MfText.rotulo,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Acompanhe o foco e o aporte ideal na tela dedicada de Metas.',
                        style: MfText.pequeno,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate(AppRoute.metas),
                  child: const Text('Abrir'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (filtered.isEmpty)
          EmptyStateCard(
            icon: MfIcon.historico,
            title: totalSaved == 0
                ? 'Nenhuma simulação salva ainda'
                : 'Nenhum resultado para o filtro',
            description: totalSaved == 0
                ? 'Salve cálculos de juros compostos, dividendos, metas ou outras calculadoras para comparar e revisar depois.'
                : 'Tente outro termo na busca ou selecione o filtro Todas.',
            action: totalSaved == 0
                ? ContornoButton(
                    label: 'Ir para Juros compostos',
                    fullWidth: false,
                    compact: true,
                    onPressed: () =>
                        widget.onNavigate(AppRoute.jurosCompostos),
                  )
                : null,
          )
        else
          for (final sim in filtered) ...[
            _HistoricoCard(
              simulation: sim,
              onOpen: () => widget.onNavigate(
                _routeForType(sim.type),
                openSimulation: sim,
              ),
              onRename: () => _promptRenameOrEdit(sim),
              onDelete: () => _confirmDelete(sim),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        DarkHighlightCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SÓ NESTE APARELHO',
                style: MfText.legenda.copyWith(color: MfColors.azulRioClaro),
              ),
              const SizedBox(height: 8),
              Text(
                'Leve seu histórico se trocar de celular',
                style: MfText.tituloCartao.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Seus cálculos nunca sobem para a nuvem. Exporte um arquivo JSON de backup ou restaure uma cópia anterior.',
                style: MfText.pequeno.copyWith(
                  color: MfColors.nevoaClaro,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ContornoButton(
                      label: 'Exportar backup',
                      compact: true,
                      lightOnDark: true,
                      leadingIcon: const MetaFeitaIcon(
                        MfIcon.exportar,
                        size: 16,
                        color: MfColors.areia,
                      ),
                      onPressed: _busyBackup ? null : _exportBackup,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ContornoButton(
                      label: 'Restaurar',
                      compact: true,
                      lightOnDark: true,
                      leadingIcon: const MetaFeitaIcon(
                        MfIcon.restaurar,
                        size: 16,
                        color: MfColors.areia,
                      ),
                      onPressed: _busyBackup ? null : _restoreBackup,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, _HistoricoFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: MfText.rotulo.copyWith(
          fontSize: 13.5,
          color: selected ? MfColors.areia : MfColors.petroleo,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      backgroundColor: MfColors.areiaCard,
      selectedColor: MfColors.petroleo,
      side: BorderSide(
        color: selected ? MfColors.petroleo : MfColors.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Future<void> _promptRenameOrEdit(SavedSimulation sim) async {
    final ctrl = TextEditingController(text: sim.title);
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar simulação', style: MfText.tituloCartao),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nome da simulação',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('open'),
            child: const Text('Abrir na calculadora'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('rename'),
            child: const Text('Salvar nome'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (action == 'open') {
      widget.onNavigate(_routeForType(sim.type), openSimulation: sim);
    } else if (action == 'rename') {
      final title = ctrl.text.trim();
      if (title.isNotEmpty) {
        widget.controller.renameSimulation(sim.id, title);
      }
    }
  }

  Future<void> _confirmDelete(SavedSimulation sim) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir simulação?', style: MfText.tituloCartao),
        content: Text(
          'A simulação "${sim.title}" será removida apenas deste aparelho.',
          style: MfText.corpo,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.controller.deleteSimulation(sim.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Simulação removida do histórico local.')),
      );
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _busyBackup = true);
    final json = BackupService.buildBackupJson(
      simulations: widget.controller.simulations,
      goals: widget.controller.goals,
      preferences: widget.controller.preferences,
    );
    try {
      await BackupService.exportAndShare(
        simulations: widget.controller.simulations,
        goals: widget.controller.goals,
        preferences: widget.controller.preferences,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arquivo JSON de backup pronto para salvar ou enviar.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      await _showManualJsonBackupDialog(json);
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<void> _showManualJsonBackupDialog(String json) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Exportar backup (JSON)', style: MfText.tituloCartao),
        content: SizedBox(
          width: 500,
          height: 280,
          child: SingleChildScrollView(
            child: SelectableText(json, style: MfText.pequeno),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('JSON copiado para a área de transferência.')),
              );
            },
            child: const Text('Copiar JSON'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup() async {
    setState(() => _busyBackup = true);
    try {
      final payload = await BackupService.pickAndValidateBackupFile();
      if (payload == null || !mounted) return;
      await _confirmAndApplyBackup(payload);
    } on BackupValidationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      final pasted = await _promptPasteJsonFallback();
      if (pasted != null && mounted) {
        await _confirmAndApplyBackup(pasted);
      }
    } finally {
      if (mounted) setState(() => _busyBackup = false);
    }
  }

  Future<BackupPayload?> _promptPasteJsonFallback() async {
    final ctrl = TextEditingController();
    String? errorMsg;
    return showDialog<BackupPayload>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Colar JSON de backup', style: MfText.tituloCartao),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: 'Cole aqui o conteúdo do arquivo meta-feita-backup.json',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: MfText.pequeno.copyWith(color: MfColors.erro),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                try {
                  final payload =
                      BackupValidator.parseAndValidate(ctrl.text.trim());
                  Navigator.of(ctx).pop(payload);
                } catch (err) {
                  setDialogState(() => errorMsg = err.toString());
                }
              },
              child: const Text('Validar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndApplyBackup(BackupPayload payload) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirmar restauração', style: MfText.tituloCartao),
        content: Text(
          'Arquivo validado (versão ${payload.schemaVersion}):\n'
          '• ${payload.simulations.length} simulação(ões)\n'
          '• ${payload.goals.length} meta(s)\n\n'
          'Créditos não são incluídos no backup. Deseja mesclar com o histórico atual ou substituir tudo neste aparelho?',
          style: MfText.corpo,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('merge'),
            child: const Text('Mesclar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('replace'),
            child: const Text('Substituir tudo'),
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;
    widget.controller.applyBackup(
      payload,
      replaceAll: choice == 'replace',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restaurado com sucesso.')),
    );
  }

  AppRoute _routeForType(SimulationType type) => switch (type) {
        SimulationType.compoundInterest => AppRoute.jurosCompostos,
        SimulationType.dividends => AppRoute.dividendos,
        SimulationType.reinvestment => AppRoute.reinvestimento,
        SimulationType.goal => AppRoute.metas,
        SimulationType.comparator => AppRoute.comparador,
        SimulationType.inflation => AppRoute.inflacao,
        SimulationType.withdrawal => AppRoute.retirada,
        SimulationType.retirement => AppRoute.aposentadoria,
      };
}

class _HistoricoCard extends StatelessWidget {
  final SavedSimulation simulation;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _HistoricoCard({
    required this.simulation,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dt = simulation.updatedAt;
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    return LightCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      onTap: onOpen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  simulation.type.eyebrowPt,
                  style: MfText.legenda.copyWith(
                    color: MfColors.inkMuted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  simulation.title,
                  style: MfText.tituloCartao.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 3),
                Text(
                  '${simulation.summaryLabel} · $dateStr',
                  style: MfText.pequeno.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar ou renomear',
            onPressed: onRename,
            icon: const MetaFeitaIcon(MfIcon.editar, size: 19),
          ),
          IconButton(
            tooltip: 'Excluir simulação',
            onPressed: onDelete,
            icon: const MetaFeitaIcon(MfIcon.excluir, size: 19),
          ),
        ],
      ),
    );
  }
}

