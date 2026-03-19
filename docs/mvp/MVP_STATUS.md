# MVP status: o que está pronto e o que falta

Resumo do que já está implementado e do que falta para o MVP (incluindo cobrança) e para a landing page.

---

## Implementado

| Item | Status |
|------|--------|
| **Documentação** | CONCEPT, TDD, SYSTEM_DESIGN, SCREENS, TEST_PLAN, DEVELOPMENT |
| **Migrations** | users, establishments (user_id, stripe_*), loyalty_programs, customers, loyalty_cards |
| **Schemas** | User, Establishment, LoyaltyProgram, Customer, LoyaltyCard |
| **Context Accounts** | User auth (register, login, session) – phx.gen.auth |
| **Context Establishments** | list_establishments_by_user, create_establishment, get_establishment!, change_establishment, update_subscription_attrs, get_establishment_by_stripe_subscription_id |
| **Context Loyalty** | Loyalty.Customers (get_or_create_customer_by_email, get_customer_by_email), LoyaltyCards (create_loyalty_card, add_stamp, list_loyalty_cards_by_customer_email, list_loyalty_cards) |
| **Auth** | User (conta) com login/registro; rotas protegidas para `/establishments` |
| **Landing** | GET `/` com título/copy MyRewards, "Ver meus cartões" → `/cards`, "Sou estabelecimento" → `/users/log-in`; IDs para testes |
| **Meus cartões** | GET `/cards` (form e-mail + lista/empty); IDs conforme SCREENS.md |
| **Establishment LiveViews** | Index, New, Show (dashboard com IDs SCREENS), LoyaltyPrograms (Index/Form/Show), LoyaltyCards (Index/Form/Show com add-stamp e IDs SCREENS) |
| **Stripe** | Checkout após criar estabelecimento; webhook POST `/webhooks/stripe`; subscription_status no banco |
| **Rotas** | `/`, `/cards`, `/users/*`, `/establishments`, `/establishments/:id`, `/establishments/:id/loyalty_programs`, `/establishments/:id/loyalty_cards`, `/establishments/:id/loyalty_cards/:card_id` (add stamp), `/webhooks/stripe` |

---

## Landing page

- **Implementado:** A rota `GET /` usa `PageController` e renderiza a landing do MyRewards com título “MyRewards — Nunca mais perca seus cartões de fidelidade”, copy, botão “Ver meus cartões” → `/cards`, link “Sou estabelecimento” → `/users/log-in`, IDs `#landing-cta-cards` e `#landing-link-establishment`.

---

## Variáveis de ambiente Stripe

Para cobrança em produção ou ambiente de testes Stripe:

- **STRIPE_SECRET_KEY** – Chave secreta da API (ex.: `sk_test_...` ou `sk_live_...`).
- **STRIPE_PRICE_ID** – ID do preço recorrente no Stripe (ex.: `price_...`). Criar produto/preço no Dashboard em BRL, R$ 10/mês.
- **STRIPE_WEBHOOK_SECRET** – Segredo do webhook (ex.: `whsec_...`). Configurar endpoint `https://seu-dominio.com/webhooks/stripe` no Dashboard e usar o signing secret.

Sem essas variáveis, o fluxo de criar estabelecimento continua funcionando (redireciona direto para o show do estabelecimento, sem passar pelo Checkout).

---

## O que falta para o MVP completo (opcional)

1. ~~Landing page do produto~~ ✅  
2. ~~Rota e LiveView “Meus cartões”~~ ✅ (controller + view em GET /cards)  
3. ~~Context Loyalty~~ ✅  
4. ~~LiveViews de estabelecimento (program, cards, add stamp)~~ ✅  
5. ~~Stripe (Checkout + webhooks)~~ ✅  
6. **Opcional:** Bloquear uso do painel do estabelecimento se a assinatura não estiver ativa (subscription_status != "active").

---

## O que falta especificamente para cobrar o cliente

Para **cobrar o cliente** (estabelecimento pagando R$ 10/mês):

1. **Integração Stripe**
   - Criar produto e preço recorrente (BRL, R$ 10/mês) no Stripe Dashboard.
   - Após `Establishments.create_establishment`, criar **Stripe Checkout Session** (mode: subscription) e redirecionar o usuário para o Stripe.
   - Configurar `success_url` e `cancel_url` para voltar ao app.
   - Endpoint de **webhook** para receber `customer.subscription.created/updated`, `invoice.paid`, `invoice.payment_failed` e atualizar `establishments.subscription_status` e `stripe_subscription_id`.

2. **Variáveis de ambiente**
   - `STRIPE_SECRET_KEY`
   - `STRIPE_WEBHOOK_SECRET`
   - (Opcional) `STRIPE_PRICE_ID` ou criar preço via API.

3. **Fluxo no código**
   - Em `EstablishmentLive.New`, após `create_establishment` com sucesso, em vez de só `push_navigate` para `/establishments/:id`, chamar um módulo de integração Stripe que cria a Session e redireciona para a URL do Checkout.
   - Após o pagamento no Stripe, o usuário cai em `success_url`; o webhook já terá atualizado o establishment (ou você atualiza na success_url se preferir).

Sem essa parte, o cliente (estabelecimento) **não é cobrado**; o MVP de produto pode funcionar, mas não o de monetização.

---

## Respostas diretas

- **Tudo que o MVP precisa está implementado?**  
  **Sim.** Implementados: landing, rota/“Meus cartões” (GET /cards), context Loyalty, LiveViews (program, cards, add stamp), Stripe (Checkout + webhook) e testes cobrindo isso.

- **O que falta para cobrar o cliente?**  
  Configurar no Stripe Dashboard: produto e preço em BRL (R$ 10/mês); definir env vars `STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID`, `STRIPE_WEBHOOK_SECRET` e apontar o webhook para `POST /webhooks/stripe`.

- **A landing page está pronta?**  
  **Sim.** A `/` é a landing do MyRewards (texto + “Ver meus cartões” + “Sou estabelecimento”) conforme SCREENS.md.
