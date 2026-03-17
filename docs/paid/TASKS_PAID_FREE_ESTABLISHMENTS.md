# Quebra de tarefas: Estabelecimento pagante e não pagante

Lista de tarefas para implementar a feature descrita em [CONCEPT_PAID_FREE_ESTABLISHMENTS.md](./CONCEPT_PAID_FREE_ESTABLISHMENTS.md). Seguir **TDD**: escrever o teste (Red), implementar (Green), refatorar. Cada tarefa deve ser concluída com `mix precommit` passando.

**Referências:** [TDD_PAID_FREE_ESTABLISHMENTS.md](./TDD_PAID_FREE_ESTABLISHMENTS.md) | [TEST_PLAN_PAID_FREE_ESTABLISHMENTS.md](./TEST_PLAN_PAID_FREE_ESTABLISHMENTS.md) | [SYSTEM_DESIGN_PAID_FREE_ESTABLISHMENTS.md](./SYSTEM_DESIGN_PAID_FREE_ESTABLISHMENTS.md)

---

## Legenda

| Símbolo | Significado |
|---------|-------------|
| Depends on | Só pode começar após a tarefa indicada. |
| TDD §X | Seção do TDD com testes a escrever primeiro. |
| SP §Y | System Design seção Y. |

---

## Fase 1: Context Establishments (limites e helpers)

### T1 — Constantes e módulo Establishments

- [ ] **Tarefa:** Definir constantes de limite no módulo `Establishments` (ou module attributes): free = 20, paid = 1000. Documentar em `@moduledoc` ou em funções que as usem.
- **Critério de aceite:** Constantes ou atributos `@free_client_limit` e `@paid_client_limit` (ou funções `free_client_limit/0` e `paid_client_limit/0`) existem e são usados nos pontos de limite.
- **Depends on:** Nenhuma.
- **TDD:** §1 (Constants).

---

### T2 — count_loyalty_cards/1

- [ ] **Tarefa:** Implementar `Establishments.count_loyalty_cards(establishment_id)` que retorna a quantidade de loyalty_cards do estabelecimento. Incluir `@spec` e `@doc`.
- **Critério de aceite:** Testes TDD §1.1 passando; função retorna 0 para estabelecimento sem cartões; retorna N quando houver N cartões; contrato para nil/unknown id definido (0 ou raise).
- **Depends on:** T1 (opcional, para usar constante em testes).
- **TDD:** §1.1.

---

### T3 — active_for_billing?/1

- [ ] **Tarefa:** Implementar `Establishments.active_for_billing?(subscription_status)` que retorna `true` apenas quando status é `"active"`. Pode ser função pública ou privada conforme uso.
- **Critério de aceite:** Testes TDD §1.5 passando (active → true; past_due, nil, "free" → false).
- **Depends on:** Nenhuma.
- **TDD:** §1.5.

---

### T4 — can_add_client?/1

- [ ] **Tarefa:** Implementar `Establishments.can_add_client?(establishment)` usando `count_loyalty_cards`, limites free/paid e `active_for_billing?`. Free (subscription_status nil ou "free"): permitir se count < 20. Paid: permitir só se status active e count < 1000. past_due/unpaid/canceled → false.
- **Critério de aceite:** Todos os testes TDD §1.2 passando; estabelecimento cancelado tratado como free (limite 20).
- **Depends on:** T2, T3.
- **TDD:** §1.2.

---

### T5 — user_has_free_establishment?/1

- [ ] **Tarefa:** Implementar `Establishments.user_has_free_establishment?(user)` que retorna true se o usuário tem pelo menos um estabelecimento com subscription_status nil ou "free".
- **Critério de aceite:** Testes TDD §1.3 passando (0 establishments → false; 1 free → true; 1 paid → false; mixed → true; 2 paid → false).
- **Depends on:** Nenhuma.
- **TDD:** §1.3.

---

### T6 — create_establishment mantém subscription_status nil

- [ ] **Tarefa:** Garantir que `Establishments.create_establishment(user, attrs)` não altera subscription_status (permanece nil). Nenhuma chamada ao Stripe no context.
- **Critério de aceite:** Testes TDD §1.4 passando; novo estabelecimento sempre com subscription_status nil (ou "free" se explicitamente setado).
- **Depends on:** Nenhuma (pode já estar assim; só validar com testes).
- **TDD:** §1.4.

---

## Fase 2: Context Loyalty (limite e pagamento em create_loyalty_card)

### T7 — create_loyalty_card com checagem de limite e pagamento

- [ ] **Tarefa:** Em `Loyalty.create_loyalty_card(establishment, customer_email)`, antes de inserir: carregar estabelecimento (se for só id); chamar `Establishments.can_add_client?(establishment)`. Se false, retornar `{:error, :client_limit_reached}` quando no limite (20 ou 1000) ou `{:error, :payment_not_active}` quando subscription não está active. Manter idempotência (cliente já existente retorna {:ok, card}).
- **Critério de aceite:** Testes TDD §2.1 passando (free 19→20 ok; free 20→21 erro; paid active 999→1000 ok; paid active 1000→1001 erro; paid past_due/unpaid erro; mesmo email retorna existing card).
- **Depends on:** T4 (can_add_client?).
- **TDD:** §2.1.

---

## Fase 3: Webhook (persistir status completos)

### T8 — Webhook persiste subscription status (past_due, unpaid, canceled)

- [ ] **Tarefa:** No `StripeWebhookController`, em `customer.subscription.updated`, persistir o valor de `data.object.status` em `subscription_status` (active, past_due, unpaid, canceled, canceled_at_period_end). Em `customer.subscription.deleted`, garantir subscription_status = "canceled".
- **Critério de aceite:** Testes TDD §3 (webhook) passando; qualquer status enviado pelo Stripe é gravado no estabelecimento.
- **Depends on:** Nenhuma (webhook já existe; só estender).
- **TDD:** §3. **SP:** §4.4.

---

## Fase 4: LiveView New (primeiro free, segundo Stripe)

### T9 — EstablishmentLive.New: primeiro estabelecimento free (sem Stripe)

- [ ] **Tarefa:** Em `EstablishmentLive.New`, no handle_event "save": antes de criar, obter `existing_count = length(Establishments.list_establishments_by_user(user))`. Após create_establishment com sucesso: se `existing_count == 0`, fazer `push_navigate` para a página do estabelecimento (show); não chamar Stripe. Se existing_count >= 1, manter comportamento atual (create_checkout_session e redirect externo).
- **Critério de aceite:** Testes TDD §4 (LiveView New) passando: user com 0 establishments → cria e vai para show; user com 1 free ou 1 paid → cria e redireciona para Stripe.
- **Depends on:** T2 (opcional, para contar; list_establishments_by_user já existe).
- **TDD:** §4. **SP:** §4.5.

---

## Fase 5: LiveView Show (indicador de plano e banner)

### T10 — EstablishmentLive.Show: assigns e exibição de plano e limite

- [ ] **Tarefa:** No mount (ou no render) do Show: calcular e atribuir `plan_type` (:free ou :paid a partir de subscription_status), `client_count` (count_loyalty_cards), `client_limit` (20 ou 1000), `payment_pending` (true se subscription_status in ["past_due", "unpaid"]). Template: exibir indicador "Plano gratuito (X/20)" ou "Plano pago (X/1000)"; se free e client_count == 20, exibir CTA "Assinar por R$ 10/mês" (link/button que leva ao checkout com establishment_id); se payment_pending, exibir banner "Pagamento pendente" ou "Problema no pagamento".
- **Critério de aceite:** Testes TDD §7 passando; IDs/selectors estáveis (ex.: #establishment-plan-free, #establishment-subscribe-cta, #payment-pending-banner).
- **Depends on:** T2, T4 (can_add_client? não obrigatório para só exibir; count e limites sim).
- **TDD:** §7. **SP:** §4.6.

---

### T11 — CTA "Assinar" no Show (link para Checkout)

- [ ] **Tarefa:** O botão/link "Assinar por R$ 10/mês" no Show deve chamar `Stripe.create_checkout_session(establishment.id, success_url, cancel_url)` e redirecionar para a URL retornada (external). success_url = show do estabelecimento; cancel_url = show ou new, conforme definido. Tratar erro (Stripe não configurado) com flash e permanecer na página.
- **Critério de aceite:** Em estabelecimento free, ao clicar em "Assinar", usuário é redirecionado ao Stripe Checkout; após pagamento (webhook), estabelecimento fica com subscription_status active.
- **Depends on:** T10, fluxo Stripe já existente.

---

## Fase 6: LiveView Cards index (adicionar cliente e limites)

### T12 — EstablishmentLive.CardsIndex: can_add_client e erro ao submeter

- [ ] **Tarefa:** No mount do CardsIndex: carregar estabelecimento e atribuir `can_add_client = Establishments.can_add_client?(establishment)`. No handle_event de submit do formulário "adicionar cliente": chamar `Loyalty.create_loyalty_card(establishment, email)`. Em caso de `{:error, :client_limit_reached}`: put_flash de erro e exibir mensagem (ex.: "Limite de 20 clientes no plano gratuito. Assine por R$ 10/mês para cadastrar mais.") e CTA "Assinar". Em caso de `{:error, :payment_not_active}`: put_flash e mensagem "Pagamento pendente. Atualize sua forma de pagamento para continuar cadastrando novos clientes." (e opcionalmente desabilitar formulário ou mostrar banner). Exibir contador de clientes (ex.: "18/20" ou "50/1000").
- **Critério de aceite:** Testes TDD §5 passando; free com 20 cards → submit novo email mostra erro e CTA; paid active 1000 → idem; paid past_due → erro de pagamento; IDs estáveis (#cards-add-client-form, #cards-limit-reached ou equivalente).
- **Depends on:** T4, T7.
- **TDD:** §5. **SP:** §4.7.

---

### T13 — CardsIndex: banner de pagamento pendente

- [ ] **Tarefa:** Quando establishment tem subscription_status past_due ou unpaid, exibir banner persistente na página de cartões (mesmo texto ou referência ao Show). Opcional: link "Atualizar forma de pagamento" (Stripe Portal) se for implementado depois.
- **Critério de aceite:** Teste TDD §5 (given paid past_due, visit cards page then see banner) passando.
- **Depends on:** T12.

---

## Fase 7: LiveView Add stamp (comportamento com past_due)

### T14 — AddStampShow: permitir carimbo com past_due

- [ ] **Tarefa:** Garantir que o fluxo de "adicionar carimbo" a um cartão existente **não** bloqueia quando establishment está past_due ou unpaid (apenas "adicionar novo cliente" é bloqueado). Nenhuma alteração no AddStampShow se já permitir; caso contrário, não checar subscription_status para add_stamp.
- **Critério de aceite:** Testes TDD §6 passando (paid past_due + existing card → add stamp succeeds; free 20 cards + existing card → add stamp succeeds).
- **Depends on:** Nenhuma (só validar comportamento).
- **TDD:** §6.

---

## Fase 8: Fixtures e ajustes finais

### T15 — Fixtures para subscription_status e muitos cartões

- [ ] **Tarefa:** Em `EstablishmentsFixtures` (ou equivalente), permitir passar `subscription_status` no attrs (nil, "free", "active", "past_due", "unpaid", "canceled"). Em `LoyaltyFixtures`, ter helper para criar N loyalty_cards para um estabelecimento (ex.: `many_cards_fixture(establishment_id, count)`) para testes de limite 20 e 1000.
- **Critério de aceite:** Testes de limite e de webhook usam fixtures sem criar registros manualmente em loop onde possível.
- **Depends on:** Nenhuma (pode ser feita em paralelo com T2–T7).

---

### T16 — IDs e data-* nos templates

- [ ] **Tarefa:** Revisar templates (Show, CardsIndex, New) e garantir IDs estáveis para: formulário de novo estabelecimento, formulário de adicionar cliente, mensagem de limite atingido, CTA Assinar, banner de pagamento pendente, indicador de plano. Documentar em TEST_PLAN ou TDD os selectors usados nos testes.
- **Critério de aceite:** Testes LiveView usam has_element?(view, "#id", text) ou element(view, "#id") sem quebrar com mudança de copy.
- **Depends on:** T9, T10, T12.

---

### T17 — Precommit e cobertura

- [ ] **Tarefa:** Rodar `mix precommit`; corrigir format, Credo, Sobelow, Dialyzer, testes e cobertura. Garantir que nenhum código novo está em `.test_coverage_ignore.exs` sem justificativa.
- **Critério de aceite:** `mix precommit` passa; cobertura não cai abaixo do threshold.
- **Depends on:** Todas as tarefas anteriores.

---

## Resumo da ordem sugerida

| Ordem | Tarefa | Fase |
|-------|--------|------|
| 1 | T1 — Constantes | 1 |
| 2 | T2 — count_loyalty_cards | 1 |
| 3 | T3 — active_for_billing? | 1 |
| 4 | T4 — can_add_client? | 1 |
| 5 | T5 — user_has_free_establishment? | 1 |
| 6 | T6 — create_establishment (validar nil) | 1 |
| 7 | T7 — create_loyalty_card limites | 2 |
| 8 | T8 — Webhook status | 3 |
| 9 | T9 — New: primeiro free | 4 |
| 10 | T10 — Show: plano e limite | 5 |
| 11 | T11 — CTA Assinar no Show | 5 |
| 12 | T12 — CardsIndex: limite e erro | 6 |
| 13 | T13 — CardsIndex: banner pagamento | 6 |
| 14 | T14 — Add stamp past_due | 7 |
| 15 | T15 — Fixtures | 8 |
| 16 | T16 — IDs nos templates | 8 |
| 17 | T17 — Precommit | 8 |

T15 (fixtures) pode ser feita cedo (em paralelo a T2–T5) para facilitar os testes das demais.

---

## Checklist de conclusão da feature

- [ ] Todos os testes do TDD passando.
- [ ] Test plan executado (automated + checklist manual quando aplicável).
- [ ] System design respeitado (sem novos endpoints ou tabelas além do descrito).
- [ ] `mix precommit` passando.
- [ ] Documentação (@doc e @spec) em inglês em todas as funções públicas novas ou alteradas.
