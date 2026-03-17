# Concept: Estabelecimento pagante e não pagante (free tier)

## Resumo

Introduzir dois tipos de estabelecimento no MyRewards:

- **Pagante:** R$ 10/mês por estabelecimento, **pagamento recorrente** (assinatura mensal); direito a até **1000 clientes** (cartões de fidelidade) naquele estabelecimento.
- **Não pagante (free):** **Apenas 1 estabelecimento** por usuário; até **20 clientes** nesse estabelecimento. Após 20 clientes, não permitir cadastrar mais e oferecer **somente a opção de migrar para pagante**.

---

## Objetivos

- Permitir que o usuário **experimente** o produto com um estabelecimento e poucos clientes antes de pagar.
- Limitar uso gratuito de forma clara (1 estabelecimento, 20 clientes) para incentivar conversão.
- Manter regra simples para o plano pago (preço fixo, limite alto de clientes).

---

## Definições

| Termo | Significado neste doc |
|-------|------------------------|
| **Cliente** | Um cartão de fidelidade (loyalty card) vinculado ao estabelecimento. Um mesmo e-mail pode ser “cliente” de vários estabelecimentos; para cada estabelecimento conta como 1 cliente. |
| **Estabelecimento pagante** | Estabelecimento com assinatura Stripe ativa (`subscription_status` = active); limite de 1000 clientes. |
| **Estabelecimento não pagante** | Estabelecimento sem assinatura ativa (criado sem passar pelo checkout ou assinatura cancelada); limite de 20 clientes e sujeito à regra “só 1 free por usuário”. |

---

## Regras de negócio

### Não pagante (free)

1. **Um estabelecimento free por usuário**  
   O usuário pode ter **no máximo 1** estabelecimento não pagante. Se já tiver um e tentar criar outro sem pagar, bloquear e oferecer “Assinar para criar mais estabelecimentos” (ou criar o segundo já indo para o checkout).

2. **Limite de 20 clientes**  
   No único estabelecimento free, só é permitido ter **até 20** loyalty cards (clientes). Ao tentar cadastrar o 21º cliente (ex.: ao dar o primeiro carimbo para um e-mail novo ou na tela de “adicionar cliente”), **não** criar o cartão e mostrar mensagem + CTA para migrar para pagante.

3. **Após 20 clientes: só migrar**  
   Não permitir novo cadastro de cliente; a única ação oferecida é “Assinar por R$ 10/mês” (ir para o Stripe Checkout desse estabelecimento). Quem já é cliente (já tem cartão) continua podendo receber carimbos normalmente.

4. **Criação do primeiro estabelecimento**  
   O primeiro estabelecimento criado pelo usuário pode ser **free por padrão**: não redirecionar para o Stripe na criação; o estabelecimento fica com `subscription_status` nil ou "free". O usuário pode migrar para pagante a qualquer momento (e aí passa a contar no limite “1 free por usuário” como “não free”).

### Pagante

1. **R$ 10/mês por estabelecimento — pagamento recorrente**  
   Cobrança via Stripe em modo **subscription (recorrente)**: a cada mês o Stripe cobra automaticamente o valor configurado (ex.: R$ 10). O usuário não precisa pagar manualmente todo mês. Um usuário pode ter vários estabelecimentos pagantes (cada um com sua assinatura).

2. **Limite de 1000 clientes**  
   Por estabelecimento pagante, no máximo **1000** loyalty cards. Ao atingir 1000, não permitir cadastrar novo cliente e mostrar mensagem (ex.: “Limite de 1000 clientes atingido. Entre em contato se precisar de mais.”).

3. **Migração free → pagante**  
   Para o estabelecimento free que já existe: botão/ação “Assinar por R$ 10/mês” abre o mesmo fluxo de Checkout (Stripe), associando a assinatura ao `establishment_id` (ex.: `client_reference_id`). No webhook `checkout.session.completed`, atualizar esse estabelecimento com `stripe_subscription_id` e `subscription_status` = active. A partir daí ele passa a ser “pagante” (limite 1000, não conta mais como “o único free”).

---

## Pagamento recorrente e quando o pagamento não é efetuado

### Recorrência

- A assinatura no Stripe é **mensal e recorrente**: o Stripe tenta cobrar todo mês (no aniversário da assinatura ou na data configurada). Não é cobrança única.
- O Stripe pode enviar **re tentativas** em caso de falha (cartão recusado, saldo insuficiente etc.), conforme configuração do Stripe e do produto.

### Status da assinatura (Stripe) e comportamento no sistema

| Status Stripe (ex.) | Significado | Validação / comportamento sugerido no MyRewards |
|--------------------|-------------|--------------------------------------------------|
| **active** | Assinatura em dia. | Estabelecimento considerado **pagante**: limite 1000 clientes; permitir cadastrar cliente e dar carimbo normalmente. |
| **past_due** | Cobrança falhou; Stripe está re tentando. | Tratar como **não ativo** até regularização: **não permitir cadastrar novo cliente**; opcionalmente permitir apenas dar carimbo em clientes já existentes. Exibir aviso: “Pagamento pendente. Atualize sua forma de pagamento para continuar cadastrando novos clientes.” |
| **unpaid** | Cobrança falhou e não foi paga (após retentativas). | Mesmo que past_due: não permitir novo cliente; exibir mensagem para atualizar pagamento ou reativar assinatura. |
| **canceled** / **canceled_at_period_end** | Assinatura cancelada (imediatamente ou no fim do período). | Estabelecimento volta a ser tratado como **não pagante** (limite 20 clientes). Aplicar mesma regra de “estabelecimento que cancelou” (ver lacuna 3). |

### Validações quando o pagamento não foi efetuado

1. **Ao cadastrar novo cliente (criar loyalty_card):**  
   Verificar se o estabelecimento está **ativo para cobrança** (ex.: `subscription_status` = "active"). Se estiver `past_due`, `unpaid` ou `canceled`, **não permitir** criar novo cartão e retornar erro com mensagem orientando a regularizar o pagamento (ou migrar para free com limite 20, conforme regra de cancelamento).

2. **Ao dar carimbo:**  
   Decisão de produto: permitir dar carimbo mesmo com `past_due`/`unpaid` (só bloquear novos clientes) ou bloquear qualquer ação até regularizar. Sugestão: permitir carimbo para clientes já existentes; bloquear só “adicionar novo cliente”.

3. **Webhook:**  
   Garantir que os eventos `customer.subscription.updated` e `customer.subscription.deleted` atualizam `subscription_status` no estabelecimento com os valores enviados pelo Stripe (active, past_due, unpaid, canceled, etc.). O `invoice.payment_failed` pode ser usado para notificar o usuário (e-mail) ou exibir aviso na UI; não precisa mudar o status sozinho (o subscription.updated já reflete o estado).

4. **UI:**  
   Para estabelecimentos com `subscription_status` em `past_due` ou `unpaid`: exibir banner ou alerta persistente (“Problema no pagamento. Atualize seu cartão para evitar interrupção.”) e link para o Stripe Customer Portal ou página de atualização de método de pagamento, se houver.

---

## Fluxos principais

### Criar primeiro estabelecimento (free)

1. Usuário clica em “Novo estabelecimento”, preenche nome, salva.
2. Sistema cria o estabelecimento **sem** redirecionar ao Stripe. Estabelecimento fica com `subscription_status` nil ou "free".
3. Usuário é levado à página do estabelecimento e pode configurar programa e começar a cadastrar clientes (até 20).

### Cadastrar cliente em estabelecimento free (até 20)

1. Na tela de cartões do estabelecimento, usuário informa e-mail (ou dá carimbo para e-mail novo).
2. Sistema verifica: quantidade de loyalty_cards desse estabelecimento < 20? Se sim, cria ou reutiliza cartão. Se não, **não** cria e exibe: “Você atingiu o limite de 20 clientes no plano gratuito. Assine por R$ 10/mês para cadastrar mais.” + botão “Assinar”.

### Migrar estabelecimento free para pagante

1. Usuário (na página do estabelecimento free ou em banner de “limite atingido”) clica em “Assinar por R$ 10/mês”.
2. Sistema chama `Stripe.create_checkout_session(establishment_id, success_url, cancel_url)` (mesmo fluxo de “criar estabelecimento pagante”) e redireciona para o Stripe.
3. Após pagamento, Stripe redireciona para success_url e envia webhook; sistema atualiza o estabelecimento com `stripe_subscription_id` e `subscription_status` = "active". Estabelecimento passa a ter limite de 1000 clientes.

### Criar segundo estabelecimento (usuário que já tem 1 free)

1. Usuário já tem um estabelecimento free. Clica em “Novo estabelecimento”.
2. Sistema detecta: já existe 1 estabelecimento free. **Não** criar outro free. Opções:
   - **A)** Bloquear e mostrar: “No plano gratuito você pode ter apenas 1 estabelecimento. Assine para criar mais.” + CTA para Stripe (checkout sem `client_reference_id` de estabelecimento? ou criar “estabelecimento placeholder” e passar o id?).  
   - **B)** Criar o estabelecimento e **na hora** redirecionar para o Stripe (como hoje para “novo estabelecimento”), ou seja, segundo estabelecimento já nasce pagante.  
   Decisão de produto: escolher A ou B e documentar.

### Estabelecimento pagante com 1000 clientes

1. Ao tentar cadastrar o 1001º cliente, não criar e mostrar mensagem clara (“Limite de 1000 clientes atingido”) e, se aplicável, “Entre em contato” ou link para upgrade (se no futuro houver plano maior).

---

## Lacunas e decisões em aberto

### Contagem e escopo

| # | Lacuna | Sugestão |
|---|--------|----------|
| 1 | **O que conta como “cliente”?** | Contar **loyalty_cards** por estabelecimento (um cartão = um cliente naquele estabelecimento). Já alinhado com o modelo atual. |
| 2 | **Usuário com 1 free e 1 pagante: pode criar outro free?** | Não. Regra: “no máximo 1 estabelecimento free por usuário”. Se já tem um free, o próximo estabelecimento tem de ser criado já como pagante (ou bloquear até assinar). |
| 3 | **Estabelecimento que era pagante e cancelou a assinatura** | Tratar como “não pagante” para limites: passa a ter limite de 20 clientes? Ou continua com os que já tem e só não pode **adicionar** novos até ter de novo 20? Decisão: ex.: “Após cancelamento, manter todos os clientes existentes, mas não permitir **novos** clientes além de 20.” Ou: “Após cancelamento, limite volta a 20; se tiver > 20, bloquear novos até que caia para 20 (churn natural).” |

### Migração e Stripe

| # | Lacuna | Sugestão |
|---|--------|----------|
| 4 | **Migração free → pagante usa o mesmo Checkout?** | Sim. Reutilizar `create_checkout_session(establishment_id, success_url, cancel_url)` com o id do estabelecimento free. Webhook já atualiza por `client_reference_id`. |
| 5 | **Criar segundo estabelecimento (usuário com 1 free): criar registro antes do checkout?** | Se optar por “segundo estabelecimento já vai para o Stripe”: criar o estabelecimento no banco (como hoje) e redirecionar para o Stripe com esse id; se o usuário cancelar no Stripe, fica um estabelecimento “órfão” (sem subscription). Definir se deleta ou mantém com status “incomplete” ou “canceled”. |
| 6 | **Preço e plano no Stripe** | Garantir que `STRIPE_PRICE_ID` é um preço recorrente mensal (ex.: R$ 10/mês). Documentar no config. |

### UX e mensagens

| # | Lacuna | Sugestão |
|---|--------|----------|
| 7 | **Onde mostrar “você está no plano free” / “limite de 20”?** | Ex.: banner na página do estabelecimento free; ou badge “Plano gratuito” no nome do estabelecimento; contador “15/20 clientes”. |
| 8 | **Onde colocar o CTA “Assinar” para o free?** | Na página do estabelecimento (sempre visível para free); e na mensagem de bloqueio ao atingir 20 clientes. |
| 9 | **Primeiro estabelecimento: sempre free ou perguntar?** | Decisão de produto: ex.: “primeiro estabelecimento sempre free; ao criar, não ir ao Stripe”. Ou: “ao criar, perguntar: Começar grátis (1 est., 20 clientes) ou Já assinar (R$ 10/mês)?”. |

### Dados e consistência

| # | Lacuna | Sugestão |
|---|--------|----------|
| 10 | **Como marcar “free” no banco?** | Usar `subscription_status`: nil ou "free" = não pagante; "active" = pagante. Ou campo booleano `is_paid` derivado de subscription_status. Evitar duplicar lógica. |
| 11 | **Estabelecimentos já existentes (antes da feature)** | Definir política: todos sem `stripe_subscription_id` ou com `subscription_status` != active são considerados free (1 por usuário, 20 clientes). Se um usuário já tiver 2+ estabelecimentos sem assinatura, definir: considerar o mais antigo como “o” free e os demais como “precisam assinar ou serão desativados”? Ou dar período de migração. |
| 12 | **Limite de 1000: validar em todo lugar que cria loyalty_card** | Garantir que `create_loyalty_card` (e qualquer outro ponto que insira cartão) verifica o limite antes de inserir. Retornar `{:error, :client_limit_reached}` ou similar para a UI exibir a mensagem e o CTA. |

### Pagamento recorrente e falha de pagamento

| # | Lacuna | Sugestão |
|---|--------|----------|
| 13 | **Quais status Stripe mapear para `subscription_status`?** | Persistir no mínimo: active, past_due, unpaid, canceled (e opcionalmente canceled_at_period_end). No webhook `customer.subscription.updated`, gravar `sub["status"]` no estabelecimento. Definir quais status são “pode cadastrar novo cliente” (só active). |
| 14 | **Grace period (período de tolerância)?** | Stripe pode enviar past_due enquanto re tenta. Definir se há um “período de graça” em dias (ex.: 7 dias em past_due ainda permite novo cliente) ou se qualquer não-active já bloqueia. Sugestão: bloquear novo cliente em qualquer status != active. |
| 15 | **Dar carimbo com past_due/unpaid: permitir ou bloquear?** | Decisão: (A) permitir apenas carimbo para clientes já existentes e bloquear só “adicionar cliente”; (B) bloquear toda ação até regularizar. Documentar escolha. |
| 16 | **Link para o usuário atualizar cartão** | Stripe Customer Portal ou Billing Portal permite o assinante atualizar método de pagamento. Definir se o app expõe um link (ex.: “Atualizar forma de pagamento”) que abre o portal; pode exigir criar/guardar `stripe_customer_id` no estabelecimento e gerar link de sessão. |
| 17 | **Notificação quando pagamento falha** | Enviar e-mail ao usuário em `invoice.payment_failed`? Ou confiar só no banner na UI? Decidir canal e texto. |
| 18 | **Retentativas do Stripe** | Comportamento de retentativas é configurável no Stripe. Documentar que a lógica “quando considerar unpaid” depende da configuração da subscription no Stripe (número de retentativas, intervalo). |

---

## Escopo técnico sugerido (para implementação)

1. **Context / Establishments**
   - Função para “contar loyalty_cards por establishment”.
   - Função “pode add client?” (free: count < 20; paid: count < 1000).
   - Função “usuário já tem estabelecimento free?” (para bloquear segundo free).

2. **Context / Loyalty**
   - Em `create_loyalty_card`: antes de inserir, checar limite do estabelecimento; se exceder, retornar erro específico.

3. **Stripe / Checkout**
   - Manter `create_checkout_session(establishment_id, ...)` para “novo estabelecimento pagante” e para “migrar free → pagante”.
   - Decidir fluxo de “criar estabelecimento”: se é sempre free no primeiro, remover redirect ao Stripe na criação do primeiro; se é segundo, ir ao Stripe na criação.

4. **LiveViews / UI**
   - Na criação de estabelecimento: lógica “é o primeiro e free?” vs “já tem free, vai para Stripe”.
   - Na tela de cartões / “adicionar cliente”: tratar erro de limite e mostrar CTA “Assinar”.
   - Banner ou indicador “Plano gratuito (X/20 clientes)” / “Plano pago (X/1000 clientes)”.

5. **Webhook**
   - Já atualiza establishment por `client_reference_id`; serve tanto para novo pagante quanto para migração.
   - Garantir que `customer.subscription.updated` persiste todos os status relevantes (active, past_due, unpaid, canceled) em `subscription_status`.

6. **Validações de pagamento**
   - Antes de criar loyalty_card: checar se estabelecimento está “ativo para cobrança” (subscription_status = active para pagante; para free, checar limite 20). Se past_due/unpaid/canceled, retornar erro com mensagem de regularizar pagamento.
   - UI: banner ou alerta para past_due/unpaid com link para atualizar método de pagamento (Stripe Portal), se implementado.

---

## Resumo

- **Free:** 1 estabelecimento por usuário, 20 clientes; ao atingir 20, bloquear novos clientes e oferecer só “Assinar”.
- **Pagante:** R$ 10/mês por estabelecimento, **pagamento recorrente** (assinatura mensal Stripe), 1000 clientes.
- **Quando o pagamento não é efetuado:** tratar past_due/unpaid como “não ativo” — não permitir cadastrar novo cliente; exibir aviso e opção de atualizar pagamento. canceled → estabelecimento volta a ser tratado como free (limite 20).
- **Migração:** mesmo fluxo Stripe Checkout; webhook atualiza o estabelecimento.
- **Lacunas (ver seção Lacunas e decisões em aberto):** segundo estabelecimento; comportamento pós-cancelamento; estabelecimentos existentes; onde exibir limite e CTA; **pagamento recorrente e falha** — status a mapear, grace period, dar carimbo em past_due, link Stripe Portal, notificação de falha, retentativas.

Este doc é um **concept**: as decisões de produto (ex.: A vs B no segundo estabelecimento, texto exato das mensagens) e de implementação devem ser fechadas antes ou durante o desenvolvimento.
