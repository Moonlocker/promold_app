import 'package:flutter/material.dart';

import '../tabs/capacidade_tab.dart';
import '../tabs/empresa_tab.dart';
import '../tabs/permissoes_tab.dart';
import '../tabs/usuarios_tab.dart';

/// Configurações do sistema: Empresa, Capacidade, Usuários e Permissões.
class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configurações'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Empresa'),
              Tab(text: 'Capacidade'),
              Tab(text: 'Usuários'),
              Tab(text: 'Permissões'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EmpresaTab(),
            CapacidadeFabricaTab(),
            UsuariosTab(),
            PermissoesTab(),
          ],
        ),
      ),
    );
  }
}
