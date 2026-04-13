#  STOX

<p align="center">🌐 <a href="https://marciofeob.github.io/P.Integrado---Desenvolvimento-Mobile/">Site de apresentação no GitHub Pages</a></p>

### Plataforma Inteligente de Gestão de Inventário

*Solução Mobile Corporativa Integrada ao SAP Business One*

---

##  Screenshots

<p align="center">
  <img src="https://github.com/calebe-moraes/P.Integrado---Desenvolvimento-Mobile/raw/main/assets/screenshot/mockup02.gif" width="720">
</p>

<p align="center">
  <img src="https://github.com/calebe-moraes/P.Integrado---Desenvolvimento-Mobile/raw/main/assets/screenshot/image1.png" width="720">
</p>

---

##  Resumo Executivo

O **STOX** é uma plataforma móvel desenvolvida em Flutter para modernizar e automatizar o processo de inventário físico do **Grupo JCN** (São João da Boa Vista/SP). A solução substitui coletores físicos e processos manuais por um aplicativo ágil, integrado diretamente ao **SAP Business One via Service Layer API**, operando em modo **offline-first** com banco de dados local SQLite.

O diferencial do projeto é a combinação de **Inteligência Artificial** (OCR via Google ML Kit), **scanner universal** de códigos de barras, **contagem em equipe** com cruzamento automático de dados no SAP, **importação de contagens** de coletores industriais e **impressão de etiquetas térmicas** via Bluetooth.

---

##  Contexto de Negócio

### Empresa Parceira

**Grupo JCN** — São João da Boa Vista/SP

### Problemas Resolvidos

* **Custo Elevado:** Eliminação do aluguel de coletores de dados de alto custo.
* **Retrabalho:** Fim da digitação manual de planilhas Excel para o SAP.
* **Agilidade:** Consulta de estoque e contagem em tempo real diretamente na gôndola/depósito.
* **Confiabilidade:** Redução de erros humanos através da leitura automática de códigos e textos.
* **Rastreabilidade:** Impressão de etiquetas com código de barras diretamente do inventário.

---

##  Funcionalidades Principais

### Modos de Contagem

* **Contagem Simples** — operador conta offline e sincroniza via POST (novo documento no SAP)
* **Contagem em Equipe** — gerente cria documento no SAP, operadores selecionam no app, contam offline e sincronizam via PATCH. O SAP cruza os dados automaticamente
* **Importação CSV** — importa contagens de outro dispositivo STOX ou coletor industrial (Zebra, Honeywell)

### Entrada de Dados

* **Digitação manual** com seletor de quantidade (+/-)
* **Scanner universal** — Code 128, Code 39, EAN-13, EAN-8, UPC-A, QR Code, Data Matrix e outros
* **OCR por IA** — leitura de códigos e quantidades via câmera (Google ML Kit)
* **Importação CSV** — parser inteligente com detecção automática de delimitador e colunas

### Integração SAP Business One

* Autenticação via Service Layer com SessionID/ROUTEID
* Consulta de itens e estoque por depósito em tempo real
* Sincronização dual: POST (contagem simples) e PATCH (contagem em equipe)
* Tratamento de erros SAP com mensagens orientativas em português

### Impressão de Etiquetas Térmicas

* Impressão via Bluetooth com suporte a dois protocolos: **TSPL** (PT-260 e compatíveis) e **ESC/POS** (GoldenSky e compatíveis)
* Preview visual da etiqueta antes da impressão
* Configuração de dimensões, campos visíveis e quantidade de cópias
* Impressão em lote de múltiplos itens
* Geração de PDF para impressão via rede/WiFi

### Outros

* **Exportação CSV** compatível com Excel PT-BR (UTF-8 BOM, delimitador `;`)
* **Feedback sensorial** — sons, vibração e animações para cada operação
* **Modo offline completo** — funciona sem internet, sincroniza quando disponível
* **Design system próprio** — componentes visuais padronizados (StoxButton, StoxCard, etc.)

---

##  Infraestrutura e Ambiente

O projeto foi construído sobre uma infraestrutura **on-premises** robusta, simulando fielmente um ambiente de produção corporativo:

* **SAP Business One:** Servidor configurado com Service Layer e banco de dados SQL Server
* **Virtualização:** Ambiente rodando em **VMware** com políticas de backup via **Veeam**
* **Segurança:** Comunicação criptografada via **HTTPS**, com suporte a certificados auto-assinados e autenticação via SessionID do SAP

---

##  Integração com Inteligência Artificial

O STOX utiliza **Visão Computacional** através do **Google ML Kit**:

1. **Reconhecimento de Texto (OCR):** O app processa imagens em tempo real para extrair strings de texto da câmera
2. **Processamento de Linguagem:** A lógica separa automaticamente o "Código do Item" da "Quantidade", preenchendo o formulário de inventário automaticamente
3. **Assistência de desenvolvimento:** Arquitetura, revisão de código e resolução de problemas complexos de integração com suporte do **Claude (Anthropic)**

---

##  Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| **Framework Mobile** | Flutter 3.32+ / Dart 3.8+ |
| **ERP** | SAP Business One |
| **Integração** | SAP Service Layer — OData REST API (HTTPS) |
| **Inteligência Artificial** | Google ML Kit Text Recognition (OCR) |
| **Banco de Dados Local** | SQLite via sqflite — offline-first, v3 com migrations |
| **Scanner** | mobile_scanner (ZXing/MLKit) — protocolos 1D e 2D |
| **Impressão Bluetooth** | blue_thermal_printer — TSPL e ESC/POS |
| **Geração de PDF** | pdf + printing — impressão via rede/WiFi |
| **Infraestrutura** | VMware on-premises + Veeam Backup |
| **Plataforma** | Android (API 21+) |

---

##  Arquitetura do Sistema

```
┌─────────────────────────────────────────────┐
│               Flutter App (Android)         │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  Pages   │  │ Services │  │  Models  │   │
│  │  (UI)    │  │ (Lógica) │  │ (Dados)  │   │
│  └────┬─────┘  └────┬─────┘  └──────────┘   │
│       │             │                       │
│  ┌────▼─────────────▼─────────────────-─┐   │
│  │           SQLite (Offline)           │   │
│  └──────────────────────────────────────┘   │
└─────────────────────┬───────────────────────┘
                      │ HTTPS
                      ▼
         ┌────────────────────────┐
         │  SAP Service Layer API │
         └────────────┬───────────┘
                      │
                      ▼
         ┌────────────────────────┐
         │   SAP Business One     │
         │   + SQL Server         │
         └────────────────────────┘
```

1. **Frontend:** Flutter gerencia estado e interface de usuário com design system próprio
2. **IA Layer:** OCR processa imagens antes do envio; Claude auxilia no desenvolvimento
3. **Middleware:** Service Layer do SAP valida sessão e permissões
4. **Backend:** SAP B1 processa transações e atualiza registros de estoque
5. **Offline Layer:** SQLite armazena contagens localmente até a sincronização

---

##  Estrutura do Projeto

```
lib/
├── main.dart                          # Inicialização + SecureHttpOverrides
├── app_stox.dart                      # MaterialApp + StoxTheme + SplashPage
└── src/
    ├── models/
    │   ├── label_config.dart          # Config de etiqueta térmica + ProtocoloBluetooth
    │   └── counting_config.dart       # CountingMode + CounterInfo + persistência
    ├── pages/
    │   ├── login_page.dart            # Autenticação SAP
    │   ├── home_page.dart             # Painel + Drawer + Sincronização dual
    │   ├── contador_offline_page.dart # Contagem simples e múltipla
    │   ├── import_page.dart           # Importação CSV
    │   ├── item_search_page.dart      # Consulta de itens SAP
    │   ├── etiqueta_page.dart         # Impressão TSPL/ESC-POS + Preview PDF
    │   ├── stox_scanner_page.dart     # Scanner universal com viewfinder
    │   └── api_config_page.dart       # Configuração Service Layer
    ├── services/
    │   ├── sap_service.dart           # Comunicação SAP (POST + PATCH)
    │   ├── database_helper.dart       # SQLite singleton v3
    │   ├── export_service.dart        # CSV UTF-8 BOM
    │   ├── ocr_service.dart           # ML Kit + recorte de imagem
    │   └── stox_audio.dart            # Sons + vibração
    └── widgets/                       # Design system (StoxButton, StoxCard, etc.)
```

---

##  Banco de Dados

**Arquivo:** `stox_offline.db` | **Versão:** 3

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | INTEGER PK | Auto-incremento |
| `itemCode` | TEXT | Código do item SAP |
| `quantidade` | REAL | Quantidade contada |
| `dataHora` | TEXT | ISO 8601 |
| `syncStatus` | INTEGER | 0=Pendente, 1=Sincronizado, 2=Erro |
| `warehouseCode` | TEXT | Código do depósito |
| `countingMode` | TEXT | `single`, `single_doc` ou `multiple` |
| `counterID` | INTEGER | InternalKey do SAP (nullable) |
| `counterName` | TEXT | Nome do contador (nullable) |

---

##  Fluxo de Uso

### Contagem Simples
```
Login → Contagem Offline (drawer) → Escanear/digitar itens → Sincronizar
```

### Contagem em Equipe
```
Gerente: cria documento no SAP com contadores designados
Operador: Login → Seleciona documento → Conta offline → Sincroniza
Gerente: revisa e aprova no SAP
```

### Impressão de Etiquetas
```
Consultar Item → Adicionar à fila → Impressão de Etiqueta → Bluetooth → Imprimir
```

### Importação de Contagem
```
Exportar CSV (outro STOX/coletor) → Importar Contagem → Preview → Importa → Sincroniza
```

---

##  Idealização do Projeto

O STOX nasceu de uma necessidade real identificada por **Rafael Valentim**, Gerente de Tecnologia da Informação do **Grupo JCN** (São João da Boa Vista/SP), que concebeu a solução para modernizar o processo de inventário físico da empresa, substituindo coletores de alto custo e eliminando o retrabalho de digitação manual no SAP.

---

##  Equipe de Desenvolvimento

| Nome | RA |
|---|---|
| Calebe Matheus Moreira Moraes | 24000974 |
| Gustavo de Moraes Donadello | 24000419 |
| Márcio Augusto Garcia Soares | 24000138 |
| Lucas Vigo Calió | 24000092 |
| Mateus Oliveira Milane | 24000308 |
| Leandro José de Carvalho Coelho | 24001964 |

---

##  Corpo Docente e Orientadores

| Disciplina | Professor |
|---|---|
| Inteligência Artificial | Rodrigo Marudi de Oliveira |
| Qualidade e Testes de Software | Marcelo Ciacco de Almeida |
| Desenvolvimento Mobile | Nivaldo de Andrade |
| Engenharia de Software | Max Streicher Vallim |
| Coordenadora PI | Mariangela Martimbianco Santos |

---

> **Nota:** Este é um projeto acadêmico desenvolvido para o curso de **Análise e Desenvolvimento de Sistemas** da **UNIFEOB** — Centro Universitário da Fundação de Ensino Octávio Bastos, São João da Boa Vista/SP.
