# System Design: MyRewards

## Referências

- **[Concept Doc](CONCEPT.md)** — Problema, dores, job to be done.
- **[TDD (Technical Design Document)](TDD.md)** — Regras de negócio, modelo de dados, fluxos, Stripe.

Este documento descreve a **arquitetura do sistema**, **componentes**, **fluxo de dados** e **entrega mobile-first**, pronta para desenvolvimento.

---

## 1. Visão geral da arquitetura

```mermaid
flowchart TB
  subgraph Clientes["👤 Clientes (mobile-first)"]
    direction TB
    A["Tela Meus cartões\n(digitar e-mail → ver cartões)"]
    B["Sem login\nAcesso público"]
  end

  subgraph Phoenix["MyRewards Web App (Phoenix)"]
    direction TB
    LV["LiveView\n(telas cliente + painel estabelecimento)"]
    Auth["Auth usuário (conta)\nSessão · Rotas protegidas"]
    StripePlug["Stripe Checkout redirect\n+ Webhooks"]
  end

  subgraph External["Serviços externos"]
    PG[("PostgreSQL\n(Ecto)")]
    Stripe["Stripe API\nSubscription · Webhooks"]
  end

  Clientes -->|HTTP| Phoenix
  Phoenix -->|Ecto| PG
  Phoenix -->|Checkout · Webhooks| Stripe
  Stripe -->|eventos| Phoenix
```

- **Uma única aplicação Phoenix** serve tanto a experiência do **cliente** (telas públicas, mobile-first) quanto o **painel do usuário** (autenticado), que cria e gerencia **estabelecimentos**.
- **PostgreSQL** persiste **contas (users)**, estabelecimentos (por conta), clientes, programas de fidelidade e cartões.
- **Stripe** cuida da assinatura recorrente (R$ 10/mês por estabelecimento) e notifica o app via webhooks.

---

## 2. Componentes do sistema

### 2.1 Phoenix Application (MyRewards)

```mermaid
flowchart LR
  subgraph Web["Web"]
    LV[LiveView]
    Ctrl[Controllers]
    Layout[Layouts]
  end

  subgraph Contextos["Contextos"]
    Accounts[Accounts\nEstablishment · Auth]
    Loyalty[Loyalty\nCustomer · Program · Card]
  end

  subgraph Integrações["Integrações"]
    StripeInt[Stripe\nCheckout · Webhooks]
  end

  subgraph Persistência["Persistência"]
    Repo[Ecto Repo]
  end

  Web --> Contextos
  Contextos --> Repo
  Contextos --> StripeInt
```

| Camada | Responsabilidade |
|--------|-------------------|
| **Web** | LiveView, controllers, layouts, componentes UI. **Todo layout e CSS mobile-first** (base em viewport pequeno; breakpoints para tablet/desktop). |
| **Contextos** | `Accounts` (User/Account, auth; user has many establishments), `Establishments` ou `Loyalty` (Establishment, LoyaltyProgram, LoyaltyCard, Customer, Stamp se houver). Establishment belongs to account. |
| **Integrações** | `Stripe` (checkout session por estabelecimento, webhooks para subscription/invoice). |
| **Repo** | Ecto; migrations para todas as tabelas do TDD (users/accounts, establishments com account_id, etc.). |

### 2.2 Banco de dados (PostgreSQL)

```mermaid
erDiagram
  users ||--o{ establishments : "possui"
  establishments ||--o| loyalty_programs : "tem um"
  establishments ||--o{ loyalty_cards : "possui"
  customers ||--o{ loyalty_cards : "possui"
  loyalty_cards ||--o{ stamps : "tem (opcional)"

  users {
    bigint id PK
    string email UK
    string hashed_password
    timestamp inserted_at
    timestamp updated_at
  }

  establishments {
    bigint id PK
    bigint user_id FK
    string name
    string stripe_customer_id
    string stripe_subscription_id
    string subscription_status
    timestamp inserted_at
    timestamp updated_at
  }

  loyalty_programs {
    bigint id PK
    bigint establishment_id FK
    string name
    int stamps_required
    string reward_description
    timestamp inserted_at
    timestamp updated_at
  }

  customers {
    bigint id PK
    string email UK
    timestamp inserted_at
    timestamp updated_at
  }

  loyalty_cards {
    bigint id PK
    bigint customer_id FK
    bigint establishment_id FK
    int stamps_current
    int stamps_required
    timestamp inserted_at
    timestamp updated_at
  }

  stamps {
    bigint id PK
    bigint loyalty_card_id FK
    timestamp inserted_at
  }
```

- **users** — conta do usuário (e-mail, senha). Um usuário possui vários estabelecimentos.
- **establishments** — pertence a um usuário (user_id); nome do estabelecimento e status da assinatura Stripe **desse estabelecimento**.
- **loyalty_programs** — 1:1 com establishment; regra (stamps_required, reward_description).
- **customers** — identificado por e-mail (unique).
- **loyalty_cards** — um por par (customer, establishment); progresso stamps_current / stamps_required.
- **stamps** (opcional) — histórico de carimbos por cartão.

Índices: `customers(email)`, `loyalty_cards(customer_id, establishment_id)` único, `loyalty_cards(customer_id)` para listar por cliente.

### 2.3 Stripe

```mermaid
flowchart LR
  subgraph Checkout["Checkout"]
    A[Phoenix cria\nCheckout Session] --> B[Redirect usuário\npara Stripe]
    B --> C[Usuário paga]
    C --> D[Redirect success\nou cancel]
  end

  subgraph Webhooks["Webhooks"]
    E[Stripe envia evento] --> F[POST /webhooks/stripe]
    F --> G{Verificar\nassinatura}
    G --> H[subscription.*\ninvoice.paid\ninvoice.payment_failed]
    H --> I[Atualizar\nestablishment]
  end
```

- **Produto/Preço:** 1 produto, preço recorrente mensal BRL R$ 10,00.
- **Checkout:** Criar Session (mode: subscription) após cadastro do estabelecimento; redirect success/cancel.
- **Webhooks (POST /webhooks/stripe):** Verificar assinatura; processar `customer.subscription.created/updated`, `invoice.paid`, `invoice.payment_failed`; atualizar `establishments.subscription_status` e `stripe_subscription_id`.

### 2.4 Front-end e experiência

- **Mobile-first:** Todas as telas são desenhadas primeiro para **viewport pequeno** (ex.: 375px). Depois, media queries `min-width` (ex.: 640px, 1024px) para tablet e desktop.
- **Protótipo:** Em `design/prototype/` há um protótipo estático HTML/CSS das telas principais, em ordem mobile-first, para servir de referência visual (estilo sketch) antes e durante o desenvolvimento.

---

## 3. Mapa de telas e rotas (mobile-first)

```mermaid
flowchart TB
  subgraph Cliente["Fluxo Cliente (público)"]
    L["/ · Landing"]
    E["/cards · Meus cartões\n(entrada e-mail)"]
    R["/cards?email=... · Meus cartões\n(lista ou vazio)"]
    L --> E --> R
  end

  subgraph Usuário["Fluxo Usuário / Estabelecimentos (autenticado)"]
    Reg["/users/register\n(criar conta)"]
    Login["/users/log-in"]
    ListEst["/establishments\n(lista estabelecimentos)"]
    NewEst["/establishments/new\n(criar estabelecimento)"]
    ShowEst["/establishments/:id"]
    Prog["/establishments/:id/program"]
    Cards["/establishments/:id/cards"]
    Stamp["/establishments/:id/cards/:id\n(adicionar carimbo)"]
    Reg --> Login
    Login --> ListEst
    ListEst --> NewEst
    ListEst --> ShowEst
    ShowEst --> Prog
    ShowEst --> Cards
    Cards --> Stamp
  end

  L -.->|"Sou estabelecimento"| Reg
```

### 3.1 Público (Cliente)

| Rota | Tela | Descrição |
|------|------|-----------|
| `GET /` | Landing | Logo, valor proposto, CTA "Ver meus cartões". |
| `GET /cards` ou `GET /meus-cartoes` | Meus cartões (entrada) | Campo e-mail + botão "Entrar" / "Ver cartões". |
| `GET /cards?email=...` ou POST + redirect | Meus cartões (resultado) | Lista de cartões do cliente: estabelecimento, progresso (ex.: 7/10), recompensa. Empty state se não houver cartões. |

### 3.2 Usuário e estabelecimentos (autenticado)

| Rota | Tela | Descrição |
|------|------|-----------|
| `GET /users/register` | Cadastro de conta | E-mail + senha → criar **conta** (User). |
| `GET /users/log-in` | Login | E-mail + senha → sessão do usuário. |
| `GET /establishments` | Lista de estabelecimentos | Lista estabelecimentos do usuário logado; link "Criar estabelecimento". |
| `GET /establishments/new` | Criar estabelecimento | Nome (e dados opcionais) → criar Establishment → redirect Stripe Checkout (assinatura desse estabelecimento). |
| `GET /establishments/:id` | Detalhe do estabelecimento | Resumo (programa ativo, nº de cartões); links para Programa, Cartões/Clientes. |
| `GET /establishments/:id/program` ou `.../program/edit` | Programa | Editar stamps_required, reward_description (e nome do programa). |
| `GET /establishments/:id/cards` | Cartões / Clientes | Lista de loyalty_cards do estabelecimento; busca por e-mail. |
| `GET /establishments/:id/cards/:card_id` ou modal | Adicionar carimbo | Detalhe do cartão; botão "+1 carimbo"; exibir progresso. |

Rotas atrás de `require_authenticated_user`; o usuário só acessa estabelecimentos da própria conta.

---

## 4. Fluxo de dados resumido

### 4.1 Cliente vê cartões

```mermaid
sequenceDiagram
  participant U as Navegador
  participant P as Phoenix
  participant R as Repo / DB

  U->>P: GET/POST com e-mail
  P->>R: busca Customer por email
  R-->>P: customer ou nil
  P->>R: list LoyaltyCards (customer_id)
  R-->>P: cartões
  P-->>U: HTML (lista ou empty state)
```

### 4.2 Estabelecimento cadastra cliente

```mermaid
sequenceDiagram
  participant E as Painel (estabelecimento)
  participant P as Phoenix
  participant R as Repo / DB

  E->>P: Cadastrar cliente (e-mail)
  P->>R: get_or_create Customer por email
  R-->>P: customer
  P->>R: create LoyaltyCard(customer_id, establishment_id)
  R-->>P: loyalty_card
  P-->>E: resposta (sucesso)
```

### 4.3 Estabelecimento adiciona carimbo

```mermaid
sequenceDiagram
  participant E as Painel
  participant P as Phoenix
  participant R as Repo / DB

  E->>P: +1 carimbo (loyalty_card_id)
  P->>R: fetch LoyaltyCard
  P->>R: update stamps_current += 1
  opt histórico
    P->>R: insert Stamp
  end
  P-->>E: resposta (novo progresso)
```

### 4.4 Conta, estabelecimento e assinatura Stripe

```mermaid
sequenceDiagram
  participant U as Usuário
  participant P as Phoenix
  participant S as Stripe

  U->>P: Cadastro de conta (email, senha)
  P->>P: create User (Account)
  P-->>U: redirect login
  U->>P: Login (email, senha)
  P-->>U: sessão
  U->>P: Criar estabelecimento (nome)
  P->>P: create Establishment (user_id)
  P->>S: create Checkout Session (subscription, establishment)
  S-->>P: session URL
  P-->>U: redirect Stripe Checkout
  U->>S: paga (cartão)
  S-->>U: redirect success_url
  S->>P: Webhook (subscription.created / invoice.paid)
  P->>P: update Establishment (subscription_status)
```

---

## 5. Segurança e limites

```mermaid
flowchart TB
  subgraph Public["Rotas públicas"]
    Landing["/"]
    Cards["/cards"]
  end

  subgraph Protected["Rotas autenticadas (usuário)"]
    ListEst["/establishments"]
    ShowEst["/establishments/:id"]
    Prog["/establishments/:id/program"]
    CardsList["/establishments/:id/cards"]
  end

  subgraph Auth["Controle de acesso"]
    Session["Sessão (user_id)"]
    Plug["require_authenticated_user"]
  end

  Public --> Cards
  Session --> Plug --> Protected
  Webhook["POST /webhooks/stripe"] --> VerifySig["Verificar assinatura Stripe"]
```

- **Usuário (conta):** Sessão após login; o usuário só acessa estabelecimentos que pertencem à sua conta (user_id); apenas esses loyalty_cards e programas.
- **Cliente:** Acesso aos cartões apenas por e-mail (sem senha no MVP); considerar rate limit no endpoint "Meus cartões" por IP/e-mail.
- **Webhooks Stripe:** Sempre validar assinatura; processar de forma idempotente quando possível.

---

## 6. Deployment (sugestão para “pronto para desenvolver”)

```mermaid
flowchart LR
  subgraph Dev["Desenvolvimento"]
    Local["Phoenix local\n+ Postgres"]
    Ngrok["ngrok / similar\n(webhooks Stripe)"]
    Local --> Ngrok
  end

  subgraph Prod["Produção (futuro)"]
    App["Fly.io / Render\n/ Elixir Cloud"]
    DB[("Postgres\ngerenciado")]
    App --> DB
  end

  Dev -.->|deploy| Prod
```

- **Ambiente:** Desenvolvimento local (Phoenix, Postgres, ngrok ou similar para Stripe webhooks).
- **Produção (futuro):** App em Fly.io/Render/Elixir Cloud; Postgres gerenciado; Stripe em modo live; variáveis de ambiente para `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `DATABASE_URL`.

---

## 7. Protótipo mobile-first (design/prototype)

- **Objetivo:** Referência visual estática de todas as telas, **sempre mobile-first**, em estilo sketch, para alinhar produto e desenvolvimento.
- **Local:** `design/prototype/`. 
- **Conteúdo:** 
  - `index.html` — Índice com links para cada tela (cliente e estabelecimento).
  - Telas em HTML com CSS mobile-first (base 320–375px; depois 640px+).
  - Frame opcional de “celular” para reforçar mobile-first.
- **Uso:** Abrir `design/prototype/index.html` no navegador (ou servir a pasta com um servidor estático). Desenvolver as LiveViews seguindo o layout e a hierarquia do protótipo.

---

## 8. Checklist “pronto para desenvolver”

- [x] Concept doc (CONCEPT.md)
- [x] TDD (TDD.md) com modelo de dados, fluxos e Stripe
- [x] System Design (este doc) com arquitetura, componentes e rotas
- [x] Design (DESIGN.md) com cores e layout
- [x] Screens (SCREENS.md) com copy, campos e IDs para testes
- [x] MVP Backlog (MVP_BACKLOG.md) com ordem de implementação e decisão de auth
- [x] Protótipo mobile-first em `docs/design/prototype/` (sketch das telas)
- [ ] Migrations Ecto (users, establishments com user_id, loyalty_programs, customers, loyalty_cards)
- [ ] Contextos Accounts (User), Establishments/Loyalty (Establishment, programa, cartões)
- [ ] Auth usuário (conta); usuário tem muitos estabelecimentos
- [ ] LiveViews públicas (landing, meus cartões)
- [ ] LiveViews: lista de estabelecimentos, criar estabelecimento, painel por estabelecimento (programa, cartões, +1 carimbo)
- [ ] Integração Stripe (checkout + webhooks)
- [ ] Testes (contextos e LiveView críticos)

---

*Documento de sistema derivado do [TDD](TDD.md) e do [Concept](CONCEPT.md). O desenvolvimento deve seguir o protótipo em `design/prototype/` e este system design.*
