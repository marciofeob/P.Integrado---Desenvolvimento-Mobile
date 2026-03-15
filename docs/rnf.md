# STOX – Requisitos Não Funcionais (RNF)

**RNF01 – Segurança**
- Comunicação exclusiva via HTTPS com suporte a certificados auto-assinados (configurável)
- Autenticação via SAP Service Layer com gerenciamento de SessionID e ROUTEID
- Controle de sessão com logout explícito e limpeza de credenciais locais

**RNF02 – Performance**
- Consulta de item no SAP ≤ 2 segundos (timeout de 15s configurado)
- Envio de contagem ao SAP ≤ 3 segundos (timeout de 30s configurado)
- Processamento de OCR local ≤ 3 segundos após captura da imagem
- Operações de leitura/escrita no SQLite executadas de forma assíncrona

**RNF03 – Disponibilidade**
- Funcionalidades de contagem disponíveis sem conexão com a internet (offline-first)
- Dados persistidos localmente no SQLite antes de qualquer tentativa de sincronização
- Infraestrutura do servidor SAP em ambiente virtualizado VMware com backup Veeam

**RNF04 – Escalabilidade**
- Arquitetura preparada para múltiplas filiais via configuração dinâmica de depósito (warehouseCode por contagem)
- URL da Service Layer e CompanyDB configuráveis por ambiente

**RNF05 – Usabilidade**
- Interface adaptada para ambiente industrial (botões mínimos de 54dp, alto contraste)
- Registro de contagem completo em no máximo 3 interações
- Feedback sensorial trimodal: visual (SnackBar), sonoro (audioplayers) e tátil (vibration)

**RNF06 – Manutenibilidade**
- Banco de dados com versionamento explícito e migração estruturada (onUpgrade)
- Arquitetura modular em camadas: features / services / db / core