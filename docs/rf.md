# STOX – Requisitos Funcionais (RF)

**RF01 – Autenticação**
- O sistema deve permitir autenticação via SAP Business One Service
  Layer, armazenando SessionID e ROUTEID para requisições subsequentes.
- O sistema deve exibir o nome do operador autenticado no painel
  principal após login bem-sucedido.

**RF02 – Modo Contador Offline**
- O sistema deve permitir registro de contagens sem conexão com a
  internet, armazenando os dados localmente no SQLite.
- Cada contagem deve registrar: código do item, quantidade, depósito,
  data/hora e status de sincronização.

**RF03 – Leitura de Código de Barras**
- O aplicativo deve permitir leitura de códigos EAN e QRCode
  utilizando a câmera do dispositivo via mobile_scanner.

**RF04 – Leitura via OCR com IA**
- O sistema deve permitir captura de código de item e quantidade
  por fotografia, utilizando Google ML Kit Text Recognition (OCR)
  com recorte assistido da imagem antes do processamento.

**RF05 – Consulta de Item**
- O sistema deve consultar informações do item no SAP B1 via endpoint
  GET /b1s/v1/Items, retornando código, nome, unidade de medida,
  status (ativo/bloqueado) e estoque por depósito.

**RF06 – Sincronização com SAP**
- O sistema deve enviar as contagens registradas ao SAP B1 via
  endpoint POST /b1s/v1/InventoryCountings, incluindo código do item,
  depósito e quantidade contada.
- Em caso de falha, o registro deve ser marcado como Erro (syncStatus=2)
  para reprocessamento posterior.

**RF07 – Exportação de Relatório CSV**
- O sistema deve gerar relatório CSV com: código do item, quantidade,
  depósito, data/hora e status de sincronização, em formato compatível
  com Excel (UTF-8 BOM, delimitador ponto e vírgula).

**RF08 – Impressão de Etiqueta**
- O sistema deve gerar e imprimir etiquetas com código de barras
  Code128 via impressora térmica Bluetooth (protocolo ESC/POS).

**RF09 – Configuração da API**
- O sistema deve permitir configuração da URL da Service Layer,
  CompanyDB, depósito padrão e política de SSL pelo administrador.

**RF10 – Histórico de Contagens (Pós-MVP — planejado)**
- Está previsto para versão futura: manutenção de histórico entre
  sessões, com filtro por período, item e operador.