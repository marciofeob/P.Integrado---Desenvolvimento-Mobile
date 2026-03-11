#  STOX

### Plataforma Inteligente de Gestão de Inventário

*Solução Mobile Corporativa Integrada ao SAP Business One*

---

##  Resumo Executivo

O **Stox** é uma plataforma móvel desenvolvida para modernizar e automatizar o processo de inventário do Grupo JCN. A solução substitui coletores físicos e processos manuais por um aplicativo ágil, integrado diretamente ao **SAP Business One (Service Layer API)**.

O diferencial do projeto é a utilização de **Inteligência Artificial (OCR - Optical Character Recognition)** para a leitura de códigos e anotações, permitindo que o usuário capture dados de itens e quantidades diretamente da câmera, eliminando erros de digitação.

---

##  Contexto de Negócio

### Empresa Parceira

Grupo JCN – São João da Boa Vista/SP

### Problemas Resolvidos

* **Custo Elevado:** Eliminação do aluguel de coletores de dados de alto custo.
* **Retrabalho:** Fim da digitação manual de planilhas Excel para o SAP.
* **Agilidade:** Consulta de estoque e contagem em tempo real diretamente na gôndola/depósito.
* **Confiabilidade:** Redução de erros humanos através da leitura automática de códigos e textos.

---

##  Funcionalidades Principais (Core Features)

* **Busca Inteligente com IA:** Leitura de códigos de itens e nomes através de OCR, permitindo identificar produtos mesmo sem código de barras (usando etiquetas impressas ou anotações).
* **Scanner de Código de Barras:** Integração com a câmera para leitura rápida de etiquetas EAN/QRCode.
* **Contador Offline com OCR:** Captura automatizada de códigos de itens e quantidades escritas, agilizando o processo de inventário físico.
* **Consulta em Tempo Real:** Visualização de estoque por depósito, unidade de medida e status do item (bloqueado/ativo) via Service Layer.
* **Feedback Sensorial:** Respostas visuais, sonoras e táteis (vibração) para confirmação de leituras e erros.

---

##  Infraestrutura & Ambiente de Desenvolvimento

O projeto foi construído sobre uma infraestrutura **on-premises** robusta, simulando fielmente um ambiente de produção corporativo:

* **SAP Business One:** Servidor configurado com Service Layer e banco de dados SQL Server (SBODemoBR).
* **Virtualização:** Ambiente rodando em **VMware** com políticas de backup via **Veeam**.
* **Segurança:** Comunicação criptografada via **HTTPS**, túneis de rede seguros para a API e autenticação via SessionID do SAP.

---

##  Integração com Inteligência Artificial

Em vez de métodos tradicionais, o Stox utiliza **Visão Computacional** através do **Google ML Kit**:

1. **Reconhecimento de Texto (OCR):** O app processa imagens em tempo real para extrair strings de texto.
2. **Processamento de Linguagem:** A lógica implementada separa automaticamente o que é o "Código do Item" e o que é a "Quantidade", preenchendo o formulário de inventário automaticamente.

---

##  Stack Tecnológica

| Camada | Tecnologia |
| --- | --- |
| **Mobile** | Flutter (Dart) |
| **ERP** | SAP Business One |
| **Integração** | SAP Service Layer (REST API) |
| **Inteligência Artificial** | Google ML Kit (Text Recognition) |
| **Banco de Dados** | SQL Server |
| **Scanner** | Mobile Scanner & Image Picker |
| **Infraestrutura** | VMware & Veeam Backup |

---

##  Arquitetura do Sistema

1. **Frontend:** Flutter gerencia o estado e a interface de usuário.
2. **IA Layer:** O serviço de OCR processa a imagem antes do envio.
3. **Middleware:** Service Layer do SAP valida a sessão e as permissões.
4. **Backend:** O SAP B1 processa a transação e atualiza os registros de estoque.

---

##  Equipe de Desenvolvimento

| Nome | RA |
| --- | --- |
| Calebe Matheus Moreira Moraes | 24000974 |
| Gustavo de Moraes Donadello | 24000419 |
| Márcio Augusto Garcia Soares | 24000138 |
| Lucas Vigo Calió | 24000092 |
| Mateus Oliveira Milane | 24000308 |
| Leandro José de Carvalho Coelho | 24001964 |

---

##  Corpo Docente e Orientadores

| Disciplina | Professor |
| --- | --- |
| Inteligência Artificial | Rodrigo Marudi de Oliveira |
| Qualidade e Testes de Software | Marcelo Ciacco de Almeida |
| Desenvolvimento Mobile | Nivaldo de Andrade |
| Engenharia de Software | Max Streicher Vallim |
| Coordenadora PI | Mariangela Martimbianco Santos |

---

**Nota:** Este é um projeto acadêmico desenvolvido para o curso de Análise e Desenvolvimento de Sistemas da **UNIFEOB**.

---
