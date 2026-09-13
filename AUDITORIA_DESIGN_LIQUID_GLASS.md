# Auditoria de Design — Liquid Glass — Xarleta Finanças

> **Documento de análise e planejamento.** Nenhuma alteração visual foi
> implementada nesta rodada. O objetivo é registrar o estado atual do design,
> avaliar a aplicabilidade do estilo "Liquid Glass" e propor um plano seguro.

---

## 1. Estado atual do design system

### 1.1 Tema central

- **Arquivo:** [`app_theme.dart`](lib/core/theme/app_theme.dart:3)
- **Conteúdo atual:**
  - Cores: `primary` (`#2563EB`), `positive` (`#16A34A`), `negative`
    (`#DC2626`), `warning` (`#D97706`).
  - `ThemeData` claro e escuro com `useMaterial3: true`.
  - `ColorScheme.fromSeed(seedColor: primary)`.
  - `scaffoldBackgroundColor`: claro `#F8FAFC`, escuro `#0F172A`.
  - `cardTheme`: raio 16, `elevation: 0`, borda `#E2E8F0` (claro) / sem borda
    (escuro).
  - `inputDecorationTheme`: preenchido, raio 12.

### 1.2 O que **não** existe

- Não há **design tokens** centralizados (espaçamento, tipografia, elevação,
  raios) além das cores.
- Não há **componentes de vidro** (glassmorphism): nenhum uso de `BackdropFilter`,
  `ImageFilter.blur`, gradientes translúcidos ou camadas de profundidade.
- Não há **biblioteca de componentes** própria (botões, cards, chips
  padronizados).
- Não há **guia de estilo** documentado.

### 1.3 Conclusão do estado atual

O design é **Material 3 padrão** com uma paleta mínima. É consistente e
funcional, mas **não** possui a linguagem visual "Liquid Glass".

---

## 2. O que é "Liquid Glass"

Estilo visual caracterizado por:

- **Superfícies translúcidas** com desfoque de fundo (`BackdropFilter` +
  `ImageFilter.blur`).
- **Camadas de profundidade** (conteúdo de fundo visível através do vidro).
- **Bordas sutis e realces** (gradientes de luz, brilho nas arestas).
- **Sombras suaves e difusas**.
- **Movimento fluido** (transições e microinterações suaves).
- **Contraste controlado** para manter legibilidade.

---

## 3. Onde o Liquid Glass faz sentido

| Tela / elemento | Aplicar vidro? | Justificativa |
| --- | --- | --- |
| Barra de navegação inferior | **Sim** | Elemento flutuante sobre conteúdo; ganho visual alto |
| AppBar (topo) | **Sim (sutil)** | Sobreposição ao rolar; reforça profundidade |
| Cards de destaque (saldo no Dashboard) | **Sim** | Foco visual; poucos por tela |
| Botões flutuantes (FAB) | **Sim** | Elemento flutuante natural |
| Diálogos / bottom sheets | **Sim (moderado)** | Sobreposição clara sobre o fundo |
| Cards de listas longas | **Não** | Muitos elementos; desfoque degrada performance |
| Formulários (inputs) | **Não** | Legibilidade e foco são prioritários |
| Tabelas / listas densas | **Não** | Ruído visual e custo de renderização |
| Textos longos | **Não** | Contraste e leitura |

**Princípio:** vidro é para **poucos elementos de destaque**, não para a
interface inteira.

---

## 4. Análise por tela

### 4.1 Dashboard

- **Arquivo:** [`dashboard_page.dart`](lib/features/dashboard/dashboard_page.dart:8)
- **Estado:** cards Material 3 simples; saudação "Olá, Xarleta!".
- **Oportunidade:** card de **saldo** como peça central em vidro; demais cards
  mantêm estilo sólido para hierarquia.
- **Risco:** o Dashboard é a tela mais acessada — qualquer desfoque afeta
  performance percebida.

### 4.2 Transações

- **Arquivo:** [`transactions_page.dart`](lib/features/transactions/transactions_page.dart:1)
- **Estado:** lista com `ListTile` e ícones direcionais (verde/vermelho).
- **Oportunidade:** manter sólido; vidro apenas no cabeçalho de resumo, se
  houver.

### 4.3 Contas / Parcelamentos

- **Arquivos:** [`bills_page.dart`](lib/features/bills/bills_page.dart:1),
  [`installments_page.dart`](lib/features/installments/installments_page.dart:1)
- **Estado:** cards com progresso e botões de ação.
- **Oportunidade:** manter sólido; vidro não agrega em listas densas.

### 4.4 Análises

- **Arquivo:** [`analytics_page_v5.dart`](lib/features/analytics/analytics_page_v5.dart:10)
- **Estado:** gráficos `fl_chart` + métricas.
- **Oportunidade:** card de "saldo do período" (`_HeroBalance`) em vidro;
  gráficos permanecem sólidos (legibilidade).

### 4.5 Configurações / Formulários

- **Estado:** listas e formulários padrão.
- **Oportunidade:** nenhuma — priorizar clareza.

---

## 5. Design system proposto

### 5.1 Tokens (a criar em `app_theme.dart` ou arquivo dedicado)

- **Espaçamento:** `xs=4`, `sm=8`, `md=16`, `lg=24`, `xl=32`.
- **Raios:** `sm=12`, `md=16`, `lg=24`, `pill=999`.
- **Elevação:** `flat=0`, `soft=2`, `raised=6`.
- **Tipografia:** escala definida (título, corpo, legenda) com pesos.
- **Cores semânticas:** manter `primary/positive/negative/warning` e adicionar
  `surfaceGlass`, `borderGlass`, `shadowGlass`.

### 5.2 Componente de vidro (a criar)

Um widget reutilizável, ex.: `GlassCard`, encapsulando:

- `BackdropFilter` com `ImageFilter.blur`.
- Fundo translúcido (`Colors.white.withOpacity(...)` / escuro equivalente).
- Borda sutil com gradiente.
- Sombra suave.
- **Fallback** para plataformas/contextos sem suporte a desfoque.

> **Importante:** o desfoque deve ser **opcional e configurável**, com um
> parâmetro de intensidade, para permitir desligar em dispositivos fracos.

---

## 6. Cores

- **Paleta atual:** azul (`#2563EB`) como primária; verde/vermelho para
  ganho/gasto; âmbar para alerta.
- **Avaliação:** adequada e com bom contraste. Não há necessidade de mudança.
- **Para vidro:** definir variantes translúcidas da superfície, garantindo
  contraste mínimo (WCAG AA) sobre o conteúdo de fundo.

---

## 7. Dark mode

- **Estado:** implementado e funcional
  ([`app_theme.dart`](lib/core/theme/app_theme.dart:34)).
- **Atenção com vidro:** no escuro, o desfoque tende a "lavar" o conteúdo;
  usar fundos mais opacos e bordas mais visíveis.
- **Contraste:** validar textos sobre superfícies translúcidas em ambos os temas.

---

## 8. Navegação

- **Estado:** `NavigationBar` (Material 3) na parte inferior
  ([`app_shell.dart`](lib/features/shell/app_shell.dart:1)).
- **Oportunidade:** aplicar vidro na barra inferior é o ganho visual mais
  evidente e de menor risco (elemento único, sempre visível).

---

## 9. Microinterações

- **Estado:** transições padrão do Material; sem animações customizadas.
- **Oportunidades (baixo risco):**
  - Feedback tátil/visual em botões de pagamento.
  - Animação de progresso em metas/parcelas.
  - Transição suave ao abrir diálogos.
- **Cuidado:** animações não devem atrasar ações financeiras.

---

## 10. Performance

| Risco | Impacto | Mitigação |
| --- | --- | --- |
| `BackdropFilter` em listas longas | Alto (GPU) | Aplicar só em elementos fixos/poucos |
| Múltiplas camadas de desfoque | Alto | Limitar a 1–2 por tela |
| Dispositivos fracos | Médio | Flag para desligar vidro |
| Animações contínuas | Médio | Usar apenas em transições pontuais |

**Regra:** vidro **nunca** em `ListView.builder` com muitos itens.

---

## 11. Acessibilidade

- **Contraste:** garantir WCAG AA sobre superfícies translúcidas.
- **Escala de texto:** não fixar tamanhos; respeitar `textScaler`.
- **Semântica:** manter `Semantics`/`tooltip` em ícones.
- **Movimento reduzido:** respeitar `MediaQuery.disableAnimations`.
- **Foco:** manter indicadores visíveis em navegação por teclado.

---

## 12. Plano de implementação sugerido (quando aprovado)

> **Não implementar sem aprovação explícita.**

1. **Fase 1 — Tokens:** criar tokens de espaçamento, raios, tipografia e cores
   de vidro, sem alterar telas.
2. **Fase 2 — Componente `GlassCard`:** criar widget reutilizável com fallback e
   intensidade configurável.
3. **Fase 3 — Piloto:** aplicar em **um** elemento (barra de navegação inferior
   ou card de saldo do Dashboard) e medir performance.
4. **Fase 4 — Expansão controlada:** aplicar em AppBar e diálogos, se o piloto
   for satisfatório.
5. **Fase 5 — Microinterações:** adicionar transições pontuais.

**Critério de sucesso:** ganho visual perceptível **sem** regressão de
performance ou legibilidade.

---

## 13. Conclusão

- O app **não** possui hoje linguagem "Liquid Glass"; usa Material 3 padrão.
- A adoção é **viável e incremental**, começando por tokens e um componente de
  vidro reutilizável.
- O maior risco é **performance**; por isso, vidro deve ser restrito a poucos
  elementos de destaque.
- **Nenhuma alteração visual foi feita** nesta rodada.
