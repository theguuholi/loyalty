# Technical Design Document (TDD): MyRewards

## Referência

Este documento deriva do **[Concept Doc (CONCEPT.md)](./CONCEPT.md)** e detalha o desenho técnico da solução.

Do concept doc são mantidos:

- **Problema:** Cartões de fidelidade em papel se perdem; o cliente perde progresso e recompensa.
- **Job to be done:** Registrar o progresso em um lugar que não se perde e saber quanto falta para a recompensa.
- **Premissas:** Solução digital; **conta primeiro, depois estabelecimentos** (usuário cria conta, faz login, depois cria um ou mais estabelecimentos); um “cartão” por estabelecimento; simples (registro de carimbos); visível (lista com progresso).

---

## 1. Visão do produto (a partir do concept)

### 1.1 Cliente (quem acumula carimbos)

- **Cadastro:** O cliente informa apenas o **e-mail** ao se cadastrar em um estabelecimento. Não precisa senha nem app próprio para começar.
- **Cartão por estabelecimento:** Cada estabelecimento tem seu programa de fidelidade (ex.: 10 compras = 1 grátis). O cliente ganha **um cartão digital** específico daquele estabelecimento ao se cadastrar com o e-mail.
- **Visualizar todos os cartões:** Em um único lugar (tela “Meus cartões”), o cliente **digita o e-mail** e passa a **visualizar todos os cartões** que possui (todos os estabelecimentos em que se cadastrou), com progresso (ex.: 7/10) e o que falta para a recompensa.

Assim atendemos à premissa do concept: *“uma lista de ‘meus cartões’ com progresso e quanto falta para a recompensa”*, sem depender de cartão físico.

### 1.2 Usuário (conta) e estabelecimentos (quem oferece o programa)

- **Conta primeiro:** O usuário (dono de estabelecimento) deve **criar uma conta** (e-mail e senha) e fazer **login** antes de poder criar estabelecimentos.
- **Um usuário, vários estabelecimentos:** Após logado, o usuário pode **criar um ou mais estabelecimentos**. Cada estabelecimento tem nome, programa de fidelidade e cartões de clientes próprios.
- **Monetização:** Cada estabelecimento paga **R$ 10,00 por mês** de forma **recorrente**, via **Stripe** (subscription).
- Enquanto a assinatura do estabelecimento estiver ativa, o usuário pode gerenciar o programa daquele estabelecimento e ter clientes cadastrados (cartões digitais).

---

## 2. Atores e capacidades

| Ator | Ações principais |
|------|------------------|
| **Cliente** | Informar e-mail no estabelecimento; depois, digitar o mesmo e-mail no sistema para ver todos os seus cartões (lista com progresso). |
| **Usuário (conta)** | Criar conta (e-mail, senha); fazer login; criar um ou mais estabelecimentos; para cada estabelecimento: assinar plano R$ 10/mês (Stripe), criar/editar programa (ex.: 10 carimbos = 1 grátis), cadastrar cliente por e-mail (cria cartão), registrar carimbo no cartão do cliente. |
| **Sistema** | Autenticar usuário (conta); permitir que o usuário crie e gerencie estabelecimentos; cobrar e gerenciar assinatura Stripe por estabelecimento; armazenar cartões e progresso; exibir “Meus cartões” por e-mail. |

---

## 3. Modelo de dados

### 3.1 Entidades

- **Account/User (Conta / Usuário)**  
  - Pessoa que gerencia estabelecimentos. Deve criar conta e fazer login antes de criar estabelecimentos.  
  - Campos relevantes: e-mail, senha (hash).  
  - Tem **muitos** estabelecimentos (`has_many :establishments`).

- **Establishment (Estabelecimento)**  
  - Pertence a uma conta (`belongs_to :account` ou `user_id`). Um estabelecimento é um “lugar” (barbearia, café, etc.) criado pelo usuário após o login.  
  - Campos relevantes: `account_id` (ou `user_id`), nome (do estabelecimento). Status da assinatura Stripe por estabelecimento: `stripe_subscription_id`, `subscription_status`.  
  - Só pode criar cartões e dar carimbos nesse estabelecimento se `subscription_status` for ativo.

- **LoyaltyProgram (Programa de fidelidade)**  
  - Um por estabelecimento (1:1).  
  - Define a regra: `stamps_required` (ex.: 10), `reward_description` (ex.: “1 corte grátis”).  
  - Opcional: nome do programa, descrição.

- **Customer (Cliente)**  
  - Identificado por **e-mail** (único globalmente ou por estabelecimento, conforme regra de negócio).  
  - Não tem senha no MVP: acesso aos cartões apenas digitando o e-mail na tela “Meus cartões”.

- **LoyaltyCard (Cartão de fidelidade)**  
  - Um cartão **por par (cliente, estabelecimento)**.  
  - Representa o “cartão específico do estabelecimento” que o concept doc menciona.  
  - Campos: `customer_id`, `establishment_id` (ou `loyalty_program_id`), `stamps_current` (carimbos atuais), `stamps_required` (cópia da regra ou FK para o programa).  
  - Quando `stamps_current >= stamps_required`, o cliente “completou” o cartão (pode zerar e dar a recompensa, ou marcar como usado conforme regra de negócio).

- **Stamp (Carimbo)**  
  - Opcional como entidade separada: cada carimbo é um registro (data, cartão_id).  
  - Alternativa mais simples: apenas `stamps_current` no LoyaltyCard, incrementado quando o estabelecimento registra “+1 carimbo”.

### 3.2 Relacionamentos

```
Account/User 1 ---- N Establishment   (usuário cria e possui vários estabelecimentos)
Establishment 1 ---- 1 LoyaltyProgram
Establishment 1 ---- N LoyaltyCard
Customer 1 ---- N LoyaltyCard (um cartão por estabelecimento)
LoyaltyCard N ---- 0..N Stamp (opcional; ou só contador no cartão)
```

- O usuário cria conta primeiro; após login, cria estabelecimentos. Cada estabelecimento tem seu programa e seus cartões.
- Cliente é identificado por e-mail; pode ser criado no momento em que o estabelecimento cadastra esse e-mail (primeiro cartão daquele cliente).

---

## 4. Fluxos principais

### 4.1 Usuário: criar conta, login e criar estabelecimentos

1. Usuário acessa área de cadastro (landing ou “Sou estabelecimento”).
2. Preenche **conta**: e-mail e senha. Ao confirmar, sistema cria a **conta** (Account/User) e redireciona para login (ou faz login automático).
3. Usuário faz **login** (e-mail e senha).
4. Após login, usuário acessa painel e pode **criar estabelecimentos**. Para cada estabelecimento: informa nome (e dados opcionais) e, ao criar, o sistema redireciona para **checkout Stripe** (assinatura recorrente R$ 10/mês **daquele estabelecimento**).
5. Stripe retorna (success/cancel). Webhook Stripe confirma pagamento e ativa `subscription_status` **do estabelecimento**.
6. Usuário, no painel (autenticado), escolhe o estabelecimento e cria/edita o **programa de fidelidade** (ex.: 10 carimbos = 1 corte grátis).

### 4.2 Cliente: “cadastro” no estabelecimento (ganhar cartão)

1. No estabelecimento (presencial ou link), o cliente informa o **e-mail**.
2. Estabelecimento (ou sistema) registra: busca ou cria `Customer` por e-mail e cria `LoyaltyCard` ligando esse cliente ao estabelecimento/programa.
3. O cliente passa a ter **um cartão específico daquele estabelecimento** (conforme concept: “cartão por estabelecimento”).

### 4.3 Cliente: ver todos os cartões (acesso por e-mail)

1. Cliente acessa a tela **“Meus cartões”** (pública ou sem login).
2. **Digita apenas o e-mail** e submete.
3. Sistema busca todos os `LoyaltyCard` cujo `Customer` tem esse e-mail e retorna a lista: estabelecimento, progresso (ex.: 7/10), descrição da recompensa.
4. Não exige senha no MVP; opcional: link mágico por e-mail ou código de acesso para aumentar segurança depois.

### 4.4 Usuário (estabelecimento): registrar carimbo

1. Usuário autenticado no painel escolhe o **estabelecimento**, depois o cliente (e-mail ou lista de cartões) e aciona “Adicionar carimbo”.
2. Sistema incrementa `stamps_current` do `LoyaltyCard` correspondente (e opcionalmente cria registro em `Stamp`).
3. Se `stamps_current >= stamps_required`, fluxo de “cartão completo” (ex.: avisar, zerar contador ou marcar recompensa usada).

---

## 5. Monetização: Stripe (R$ 10/mês recorrente)

- **Produto/Preço:** Um produto Stripe com preço recorrente mensal em BRL, valor R$ 10,00.
- **Checkout:** Após o usuário (logado) criar um estabelecimento, redirecionar para **Stripe Checkout** (Session) em modo subscription para aquele estabelecimento; `success_url` e `cancel_url` para o nosso app.
- **Webhooks:** Escutar `customer.subscription.created`, `customer.subscription.updated`, `invoice.paid`, `invoice.payment_failed` para manter `subscription_status` e `stripe_subscription_id` no `Establishment`.
- **Comportamento:** Se a assinatura for cancelada ou inadimplente, o estabelecimento não pode criar novos cartões ou (opcional) não pode adicionar carimbos até regularizar.

---

## 6. Segurança e privacidade

- **Acesso aos cartões por e-mail:** Qualquer um que souber o e-mail vê os cartões. No MVP isso é aceitável (baixa sensibilidade); depois pode-se adicionar confirmação por e-mail (link mágico) ou PIN.
- **Usuário (conta):** Autenticação com senha (hash com bcrypt/argon2); sessão após login; rotas de painel protegidas. O usuário só acessa estabelecimentos que pertencem à sua conta.
- **Dados pessoais:** E-mail é dado pessoal; tratar conforme LGPD (finalidade, mínimo necessário, possibilidade de exclusão).

---

## 7. Stack e implementação (Phoenix)

- **Backend:** Phoenix (já em uso no projeto); Ecto para Account/User, Establishment (com `account_id`), Customer, LoyaltyProgram, LoyaltyCard (e Stamp se houver).
- **Autenticação:** Usuário (conta) com `phx.gen.auth` ou similar; cliente (quem acumula carimbos) sem login no MVP.
- **Stripe:** Biblioteca oficial Stripe para Elixir ou HTTP (Req) para API REST; webhooks com verificação de assinatura.
- **Front-end:** LiveView; telas: cadastro e login de **usuário (conta)**, lista de estabelecimentos do usuário, criar estabelecimento, checkout Stripe por estabelecimento, painel por estabelecimento (programa, lista de cartões, adicionar carimbo), tela pública “Meus cartões” (input e-mail, lista de cartões).

---

## 8. Resumo de alinhamento com o concept doc

| Concept doc | Como o TDD atende |
|-------------|--------------------|
| Conta primeiro, depois estabelecimentos | Entidade Account/User; usuário cria conta e faz login; depois cria N Establishments (account_id). |
| Progresso em lugar que não se perde | Cartões e carimbos armazenados no banco; cliente acessa por e-mail. |
| Um “cartão” por estabelecimento | Entidade LoyaltyCard por (cliente, estabelecimento). |
| Saber quanto falta para a recompensa | Exibição tipo 7/10 e descrição da recompensa na lista “Meus cartões”. |
| Simples para o cliente | Cadastro só com e-mail no estabelecimento; visualização digitando o e-mail. |
| Visível: lista de todos os programas | Tela “Meus cartões” lista todos os LoyaltyCard do e-mail. |
| Estabelecimento paga R$ 10/mês | Assinatura recorrente Stripe por estabelecimento; webhooks atualizam status. |

---

*Documento técnico derivado do [CONCEPT.md](./CONCEPT.md). Alterações de regra de negócio devem ser refletidas neste TDD e, quando relevante, no concept doc.*
