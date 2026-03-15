# Diagramas do Projeto STOX

## 1. Diagrama de Arquitetura

Mobile App (Flutter)
├── [Câmera] → Google ML Kit OCR (local, sem internet)
├── [Câmera] → mobile_scanner — Leitura de Código de Barras
├── [SQLite local] → Armazenamento offline das contagens
├── [Bluetooth] → Impressora Térmica ESC/POS
│
└── [HTTPS] → SAP Service Layer (REST/OData v4)
                └── SAP Business One
                      └── SQL Server (SBODemoBR)

## 2. Diagrama de Caso de Uso

Ator: Operador Estoquista
- Realizar Login no SAP
- Configurar API (URL, CompanyDB, Depósito)
- Realizar Contagem Offline
  ├── Digitar código manualmente
  ├── Ler código de barras (Scanner)
  └── Ler código e quantidade via OCR (IA local)
- Sincronizar Contagens com SAP
- Consultar Item no SAP
- Exportar Relatório CSV
- Imprimir Etiqueta via Bluetooth

## 3. Diagrama de Componentes

[App Mobile Flutter]
    │
    ├── [SQLite / DatabaseHelper] ←→ contagens offline
    ├── [SapService]             ←→ SAP Service Layer (HTTPS)
    ├── [OcrService]             ←→ Google ML Kit (local)
    ├── [ExportService]          ←→ CSV via share_plus
    └── [EtiquetaPage]           ←→ Impressora Bluetooth ESC/POS

[SAP Service Layer]
    └── [SAP Business One / SQL Server SBODemoBR]