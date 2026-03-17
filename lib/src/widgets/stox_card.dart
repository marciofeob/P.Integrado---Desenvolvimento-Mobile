import 'package:flutter/material.dart';

/// Card com borda suave — usado em listas de itens, depósitos, contagens.
class StoxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const StoxCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? Colors.grey.shade200),
      ),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: padding != null
                  ? Padding(padding: padding!, child: child)
                  : child,
            )
          : padding != null
              ? Padding(padding: padding!, child: child)
              : child,
    );
  }
}

/// Card de cabeçalho colorido com código, nome e quantidade em estoque.
/// Usado na tela de consulta de item.
class StoxItemHeaderCard extends StatelessWidget {
  final String itemCode;
  final String itemName;
  final num quantidadeEmEstoque;
  final num estoqueMinimo;
  final num estoqueMaximo;
  final String unidadeMedida;

  const StoxItemHeaderCard({
    super.key,
    required this.itemCode,
    required this.itemName,
    required this.quantidadeEmEstoque,
    required this.estoqueMinimo,
    required this.estoqueMaximo,
    required this.unidadeMedida,
  });

  Color get _corQuantidade {
    if (quantidadeEmEstoque == 0) return Colors.white38;
    if (quantidadeEmEstoque < estoqueMinimo) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  String get _qtdFormatada => quantidadeEmEstoque % 1 == 0
      ? quantidadeEmEstoque.toInt().toString()
      : quantidadeEmEstoque.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(itemCode,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(itemName,
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_qtdFormatada,
                      style: TextStyle(
                          color: _corQuantidade,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.0)),
                  Text(unidadeMedida,
                      style: TextStyle(
                          color: _corQuantidade.withAlpha(200),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  const Text('em estoque',
                      style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ],
          ),
          if (estoqueMinimo > 0 || quantidadeEmEstoque > 0) ...[
            const SizedBox(height: 16),
            StoxEstoqueBarra(
              atual: quantidadeEmEstoque,
              minimo: estoqueMinimo,
              maximo: estoqueMaximo,
            ),
          ],
        ],
      ),
    );
  }
}

/// Barra de progresso de estoque (mínimo → máximo).
class StoxEstoqueBarra extends StatelessWidget {
  final num atual;
  final num minimo;
  final num maximo;

  const StoxEstoqueBarra({
    super.key,
    required this.atual,
    required this.minimo,
    required this.maximo,
  });

  @override
  Widget build(BuildContext context) {
    final ref = maximo > 0
        ? maximo
        : (minimo > 0 ? minimo * 3 : atual * 1.5);
    final pct =
        ref > 0 ? (atual / ref).clamp(0.0, 1.0).toDouble() : 0.0;
    final cor = atual == 0
        ? Colors.white24
        : atual < minimo
            ? Colors.orangeAccent
            : Colors.greenAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(cor),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (minimo > 0)
              Text('Mín: $minimo',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10)),
            if (maximo > 0)
              Text('Máx: $maximo',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

/// Card de seção com título e lista de linhas de detalhe.
/// Agrupa campos do item em blocos visuais.
class StoxSectionCard extends StatelessWidget {
  final String titulo;
  final List<StoxDetailRow> linhas;

  const StoxSectionCard({
    super.key,
    required this.titulo,
    required this.linhas,
  });

  @override
  Widget build(BuildContext context) {
    final visiveis = linhas.where((l) => l.value != null && l.value!.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
        ),
        if (visiveis.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Sem informações disponíveis.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          )
        else
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                for (int i = 0; i < visiveis.length; i++) ...[
                  visiveis[i],
                  if (i < visiveis.length - 1)
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Colors.grey.shade100),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Linha de detalhe label + valor dentro de um StoxSectionCard.
class StoxDetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool isAlert;
  final bool destaque;

  const StoxDetailRow(
    this.label,
    this.value, {
    super.key,
    this.isAlert = false,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      title: Text(label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      trailing: Text(
        value!,
        style: TextStyle(
          fontSize: destaque ? 16 : 13,
          fontWeight: destaque ? FontWeight.bold : FontWeight.w600,
          color: isAlert
              ? Colors.red
              : destaque
                  ? Theme.of(context).primaryColor
                  : Colors.black87,
        ),
      ),
    );
  }
}

/// Card de resumo do painel home — mostra contagem de itens pendentes.
class StoxSummaryCard extends StatelessWidget {
  final int totalItens;
  final bool carregando;
  final VoidCallback? onSincronizar;

  const StoxSummaryCard({
    super.key,
    required this.totalItens,
    this.carregando = false,
    this.onSincronizar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Theme.of(context).primaryColor.withAlpha(77),
              blurRadius: 12,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          const Text('Itens aguardando envio',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('$totalItens',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: carregando || totalItens == 0 ? null : onSincronizar,
              icon: carregando
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded),
              label: const Text('SINCRONIZAR AGORA',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}