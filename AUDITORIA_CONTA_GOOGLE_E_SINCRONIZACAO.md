# Auditoria de Conta Google e Sincronização — Xarleta Finanças

> **Documento de análise e planejamento.** Nenhuma implementação de login,
> autenticação ou sincronização foi realizada nesta rodada. O objetivo é
> registrar o estado atual, avaliar a prontidão da arquitetura e comparar
> alternativas para decisão futura.

---

## 1. Estado atual do armazenamento de dados

### 1.1 Banco de dados

- **Tecnologia:** SQLite via `sqflite` (mobile) e `sqflite_common_ffi`
  (Windows/Linux), configurado em
  [`database_platform.dart`](lib/core/database/database_platform.dart:1).
- **Schema:** versão **8**, definido em
  [`app_database.dart`](lib/core/database/app_database.dart:1).
- **Localização:** arquivo local no dispositivo (sandbox do app). Não há
  armazenamento remoto.

### 1.2 Tabelas

| Tabela | Finalidade | Possui `user_id`? |
| --- | --- | --- |
| `transactions` | Lançamentos (ganhos/gastos) | Não |
| `bills` | Contas e vencimentos (recorrência) | Não |
| `installments` | Parcelamentos | Não |
| `work_sessions` | Sessões de trabalho/entregas | Não |
| `goals` | Metas financeiras | Não |
| `goal_contributions` | Histórico de aportes em metas | Não |
| `reserves` | Reservas financeiras | Não |
| `reserve_movements` | Histórico de movimentações de reservas | Não |
| `categories` | Categorias (ganho/gasto) | Não |
| `app_settings` | Preferências (chave/valor) | Não |

### 1.3 Preferências

- `shared_preferences` para tema, PIN (hash PBKDF2), flag de biometria e
  preferências do dashboard.

### 1.4 Backup

- [`backup_service.dart`](lib/services/backup_service.dart:4) exporta as 10
  tabelas em JSON (versão 9) e restaura de forma transacional.

---

## 2. Prontidão para multiusuário

### 2.1 Ausência de identidade de usuário

- **Não existe** tabela `users`.
- **Nenhuma** tabela possui coluna `user_id`.
- Não há conceito de sessão de usuário, token ou identidade.

### 2.2 Implicações

Para suportar conta Google + sincronização, será necessário:

1. **Identidade:** obter um identificador estável do usuário (ex.: `sub` do
   Google ID token ou `uid` do Firebase Auth).
2. **Escopo de dados:** associar cada registro a um usuário.
3. **Migração:** os dados atuais são "locais e anônimos". É preciso decidir como
   vinculá-los ao primeiro usuário que fizer login (adoção automática dos dados
   locais).
4. **Conflitos:** definir estratégia de resolução (last-write-wins, versionamento
   por `updated_at`, ou merge por registro).

### 2.3 Colunas úteis já existentes

- `transactions` possui `created_at` e `updated_at` — úteis para sincronização
  incremental e resolução de conflitos.
- As demais tabelas **não** possuem `updated_at` de forma consistente, o que
  exigirá padronização para sync confiável.

---

## 3. Comparação de alternativas

### Opção A — Firebase Authentication (Google Sign-In) apenas

- **O que é:** autenticação gerenciada pelo Firebase; dados continuam locais.
- **Prós:** login simples e robusto; tokens gerenciados; base para sync futuro.
- **Contras:** não sincroniza dados por si só.
- **Esforço:** Baixo.
- **Indicado quando:** o objetivo imediato é apenas "entrar com Google".

### Opção B — Google Sign-In isolado (sem backend)

- **O que é:** `google_sign_in` puro, sem provedor de backend.
- **Prós:** sem dependência de BaaS; controle total.
- **Contras:** exige backend próprio para sync; gestão manual de tokens;
  complexidade de refresh/expiração.
- **Esforço:** Médio (login) / Alto (sync).
- **Indicado quando:** há backend próprio planejado.

### Opção C — Supabase (Auth + Postgres + Realtime)

- **O que é:** BaaS open-source com Postgres gerenciado.
- **Prós:** Auth com Google; banco relacional (próximo do SQLite atual);
  Row Level Security; realtime; exportável.
- **Contras:** dependência de serviço externo; curva de modelagem de RLS;
  migração de schema local → remoto.
- **Esforço:** Médio.
- **Indicado quando:** deseja-se SQL relacional e controle sobre os dados.

### Opção D — Firebase completo (Auth + Firestore)

- **O que é:** Auth + banco NoSQL com sync offline nativo.
- **Prós:** sync offline-first nativo; SDK maduro; escalável.
- **Contras:** modelo NoSQL difere do SQLite atual (requer remodelagem);
  custo pode crescer; menos portável.
- **Esforço:** Médio/Alto (remodelagem de dados).
- **Indicado quando:** prioriza-se sync offline-first com mínimo de backend.

### Opção E — Google Drive (App Data Folder)

- **O que é:** usar a pasta privada do app no Drive do usuário para guardar o
  backup JSON.
- **Prós:** sem backend próprio; aproveita o backup JSON já existente;
  privacidade (pasta oculta do app).
- **Contras:** não é sync em tempo real; resolução de conflitos manual;
  limites de API; sem consultas remotas.
- **Esforço:** Baixo/Médio.
- **Indicado quando:** o objetivo é "backup na nuvem do usuário", não
  colaboração/multiusuário.

### Opção F — Outra (backend próprio / REST)

- **O que é:** API própria com autenticação Google.
- **Prós:** controle total; sem lock-in.
- **Contras:** maior custo de desenvolvimento e operação.
- **Esforço:** Alto.
- **Indicado quando:** há requisitos específicos de negócio/privacidade.

---

## 4. Recomendação

Para o estágio atual (app pessoal, dados locais, sem backend):

1. **Curto prazo — Opção E (Google Drive App Data Folder):** menor esforço,
   reutiliza o backup JSON existente, entrega valor imediato ("meus dados na
   nuvem") sem remodelar o banco.
2. **Médio prazo — Opção A (Firebase Auth) + sync incremental:** se o objetivo
   evoluir para multiusuário real, adotar identidade estável e sincronização por
   `updated_at`.
3. **Longo prazo — Opção C (Supabase):** se houver necessidade de consultas
   remotas, RLS e modelo relacional.

**Não recomendado agora:** Opção D (Firebase completo), pois exigiria remodelar
todo o schema relacional atual em NoSQL, com alto risco e pouco ganho imediato.

---

## 5. Plano de migração (quando aprovado)

> **Não implementar sem aprovação explícita.**

### Fase 1 — Identidade

1. Adicionar dependência de autenticação (ex.: `google_sign_in` + Firebase Auth).
2. Criar tela de login opcional (o app deve continuar funcionando sem login).
3. Persistir o identificador do usuário em `shared_preferences`.

### Fase 2 — Escopo de dados

1. Adicionar coluna `user_id` (nullable) às tabelas sincronizáveis.
2. Migração de schema (versão 9) **não destrutiva**: registros existentes ficam
   com `user_id = NULL` até o primeiro login.
3. No primeiro login, associar os dados locais ao usuário (adoção).

### Fase 3 — Sincronização

1. Padronizar `updated_at` em todas as tabelas sincronizáveis.
2. Implementar sync incremental (enviar alterações desde o último timestamp).
3. Definir resolução de conflitos (recomendado: `updated_at` mais recente vence,
   com log de conflitos).

### Fase 4 — Backup remoto (alternativa leve)

1. Reutilizar [`backup_service.dart`](lib/services/backup_service.dart:4).
2. Enviar o JSON para a App Data Folder do Drive.
3. Restaurar a partir do Drive quando solicitado.

---

## 6. Riscos e cuidados

| Risco | Mitigação |
| --- | --- |
| Perda de dados locais na migração | Migração não destrutiva; backup automático antes |
| Conflitos de sincronização | `updated_at` + estratégia explícita de resolução |
| App deixar de funcionar offline | Login **opcional**; app local-first |
| Lock-in de provedor | Abstrair camada de sync atrás de interface |
| Exposição de dados | RLS (Supabase) ou regras de segurança (Firebase) |
| Complexidade prematura | Começar pela Opção E (Drive), evoluir conforme necessidade |

---

## 7. Conclusão

- A arquitetura atual é **local-first** e **não** está pronta para multiusuário:
  faltam identidade (`user_id`) e padronização de `updated_at`.
- A adoção de conta Google é **viável** e pode ser feita de forma incremental,
  sem quebrar o funcionamento offline.
- Recomenda-se iniciar pela **Opção E (Google Drive)** para entrega rápida de
  valor, evoluindo para **Firebase Auth** ou **Supabase** conforme a necessidade
  de multiusuário real.
- **Nenhuma alteração de código foi feita** nesta área nesta rodada.
