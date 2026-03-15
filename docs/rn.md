# STOX – Regras de Negócio (RN)

**RN01 – Autorização**
- Somente usuários autenticados no SAP Business One poderão acessar as
  funcionalidades de consulta e sincronização de inventário.
- O modo contador offline dispensa autenticação, mas os dados só são
  enviados ao SAP após login válido.

**RN02 – Integridade de Dados**
- Nenhuma contagem poderá ser salva sem código de item e quantidade
  válida (maior que zero).
- Nenhuma contagem poderá ser salva sem código de depósito informado.
- Ao editar uma contagem já registrada, o syncStatus retorna para
  Pendente (0), garantindo reenvio com o valor atualizado.

**RN03 – Ambiente de Integração**
- A URL da Service Layer e o CompanyDB são configuráveis pelo
  administrador, permitindo uso em qualquer ambiente SAP B1
  (desenvolvimento, homologação ou produção).

**RN04 – Rastreabilidade das Contagens**
- Cada contagem registrada armazena: código do item, quantidade,
  depósito, data/hora e status de sincronização.
- O operador autenticado é identificado pelo nome de usuário SAP,
  exibido no painel principal durante a sessão ativa.

**RN05 – Tratamento de Erros de Sincronização**
- Em caso de falha no envio ao SAP, o registro recebe syncStatus = 2
  (Erro no Envio) e permanece disponível para reprocessamento.
- Erros de item duplicado (código SAP -1310) são identificados e
  exibidos com mensagem explicativa ao operador.

**RN06 – Divergências (Pós-MVP — planejado)**
- Está previsto para versão futura: comparação entre a quantidade
  contada e o estoque atual no SAP, com sinalização de divergências
  e registro de justificativa pelo operador.