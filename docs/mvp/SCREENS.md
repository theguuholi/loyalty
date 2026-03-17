# Screen-by-Screen Spec (MVP)

This document specifies each screen: **route**, **title**, **copy**, **form fields**, and **suggested DOM IDs** for tests. Implementation should follow the prototype in `docs/design/prototype/` and the layout in [DESIGN](DESIGN.md). All copy below can be used as-is or adapted (e.g. i18n later).

---

## Public (Client)

### 1. Landing

| Item | Value |
|------|--------|
| Route | `GET /` |
| Title | MyRewards (or "MyRewards — Nunca mais perca seus cartões") |
| Copy | Short line: e.g. "Nunca mais perca seus cartões de fidelidade. Guarde no celular." |
| Actions | Primary button: "Ver meus cartões" → `/cards`. Secondary link: "Sou estabelecimento" → `/establishment/login`. |
| IDs | `landing-cta-cards`, `landing-link-establishment` |

---

### 2. Meus cartões — Entry

| Item | Value |
|------|--------|
| Route | `GET /cards` (or `/meus-cartoes`) |
| Title | Meus cartões |
| Copy | "Digite seu e-mail para ver todos os cartões de fidelidade." |
| Form | Single field: **E-mail** (type email, placeholder e.g. "seu@email.com"). Submit button: "Entrar" or "Ver cartões". |
| Behaviour | On submit: validate email; redirect to same path with `?email=...` (or POST + redirect) and show list or empty state. |
| IDs | `cards-entry-form`, `cards-entry-email`, `cards-entry-submit` |

---

### 3. Meus cartões — List

| Item | Value |
|------|--------|
| Route | `GET /cards?email=...` (or same with query after submit) |
| Title | Meus cartões |
| Copy | Subtitle: show the email used (e.g. "seu@email.com"). Optional link: "Trocar e-mail" back to entry. |
| Content | One **card** per loyalty card: establishment name, progress bar (current/required), text like "X de Y carimbos", reward description. If completed: e.g. "pronto para usar!" or "✓". |
| Empty state | If no cards: message like "Nenhum cartão encontrado para este e-mail." and optional "Trocar e-mail". |
| IDs | `cards-list`, `card-item-{id}` or `card-establishment`, `card-progress`, `card-reward`. Empty: `cards-empty-message`, `cards-change-email-link`. |

---

## Establishment (authenticated)

All under `/establishment`. Layout: header with establishment name and "Sair"; back links where needed.

### 4. Establishment — Login

| Item | Value |
|------|--------|
| Route | `GET /establishment/login` |
| Title | Entrar |
| Copy | "Painel do estabelecimento." |
| Form | **E-mail**, **Senha**. Submit: "Entrar". Link: "Criar conta" → `/establishment/register`. Back: "← Voltar" → `/` (landing). |
| IDs | `establishment-login-form`, `establishment-login-email`, `establishment-login-password`, `establishment-login-submit`, `establishment-register-link` |

---

### 5. Establishment — Register

| Item | Value |
|------|--------|
| Route | `GET /establishment/register` |
| Title | Criar conta |
| Copy | "R$ 10/mês. Após cadastro, você será redirecionado ao pagamento." |
| Form | **Nome do estabelecimento**, **E-mail**, **Senha**. Submit: "Criar conta e pagar R$ 10/mês". Link: "Já tenho conta" → login. Back → login. |
| Behaviour | On submit: create Establishment, then redirect to Stripe Checkout (subscription). After payment, redirect to dashboard. |
| IDs | `establishment-register-form`, `establishment-register-name`, `establishment-register-email`, `establishment-register-password`, `establishment-register-submit` |

---

### 6. Establishment — Dashboard

| Item | Value |
|------|--------|
| Route | `GET /establishment/dashboard` |
| Title | Establishment name (e.g. "Barbearia do João") |
| Copy | "Assinatura ativa" (or status). Header: "Sair" → logout. |
| Content | Card summarizing program: "Programa ativo", rule (e.g. "10 carimbos = 1 corte grátis"), link "Editar programa →" → `/establishment/program`. Section "Ações rápidas": button "Ver cartões / Clientes" → `/establishment/cards`, button "Adicionar carimbo" → e.g. `/establishment/cards` (or a flow to choose card then add stamp). |
| IDs | `dashboard-program-card`, `dashboard-edit-program-link`, `dashboard-cards-link`, `dashboard-add-stamp-link`, `dashboard-logout-link` |

---

### 7. Establishment — Program

| Item | Value |
|------|--------|
| Route | `GET /establishment/program` |
| Title | Programa de fidelidade |
| Copy | "Defina quantos carimbos o cliente precisa para ganhar a recompensa." |
| Form | **Nome do programa**, **Carimbos necessários** (number, min 1), **Descrição da recompensa**. Submit: "Salvar". Back → dashboard. |
| IDs | `program-form`, `program-name`, `program-stamps-required`, `program-reward-description`, `program-submit` |

---

### 8. Establishment — Cards / Clients

| Item | Value |
|------|--------|
| Route | `GET /establishment/cards` |
| Title | Cartões / Clientes |
| Copy | "Busque por e-mail ou veja a lista." |
| Form | Search input (email), placeholder "Buscar por e-mail...". Optional: "Cadastrar cliente (e-mail)" → modal or inline form to add new customer and create loyalty_card. |
| Content | List of loyalty cards: for each, show customer email, progress (e.g. "7/10 — 1 corte grátis"), link "+ Carimbo" → add-stamp for that card. |
| Empty state | "Nenhum cartão ainda." and CTA to register first client. |
| IDs | `establishment-cards-search`, `establishment-cards-list`, `establishment-card-item-{id}`, `establishment-add-stamp-link-{id}`, `establishment-register-client-btn` |

---

### 9. Establishment — Add stamp

| Item | Value |
|------|--------|
| Route | `GET /establishment/cards/:id` (card detail + add stamp) |
| Title | Adicionar carimbo |
| Copy | Customer email (e.g. "cliente@email.com"). |
| Content | Same card block as "Meus cartões": establishment name, progress bar, "X de Y carimbos", reward. Button "+ 1 carimbo". Hint: "Ao completar Y, o cliente ganha a recompensa." Back → list of cards. |
| Behaviour | On "+ 1 carimbo": increment stamps_current; re-render progress; optional flash "Carimbo adicionado." If stamps_current >= stamps_required, optional message "Cartão completo! Cliente pode usar a recompensa." |
| IDs | `add-stamp-card`, `add-stamp-progress`, `add-stamp-button`, `add-stamp-back-link` |

---

## Copy and IDs summary

- Use the IDs above in LiveView templates (e.g. `id="cards-entry-form"`) so tests can use `has_element?(view, "#cards-entry-form")`, `render_submit(view, "#cards-entry-form", %{...})`, etc.
- Copy is in Portuguese to match the prototype; you can move it to Gettext or a content module later.
- For flash messages: e.g. "Cartão não encontrado", "E-mail inválido", "Carimbo adicionado.", "Programa atualizado."

---

*Reference: [SYSTEM_DESIGN](SYSTEM_DESIGN.md) (routes), [design/prototype/](design/prototype/) (HTML), [DESIGN](DESIGN.md) (colors and layout).*
