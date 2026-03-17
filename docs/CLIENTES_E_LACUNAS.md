# Como conseguir clientes e o que falta no sistema

Resumo prático: **o que fazer para vender** e **o que costuma faltar no produto** para converter e reter estabelecimentos.

---

## Parte 1: O que fazer para conseguir clientes

### Prioridade máxima (fase 0 → 10)

1. **Saia do código e fale com gente.**  
   O que mais traz os primeiros clientes é contato direto: WhatsApp, e-mail, visita. Não espere “o sistema pronto” para começar.

2. **Lista + mensagem + demos.**  
   - Liste 20–30 estabelecimentos (café, padaria, sorveteria, loja).  
   - Envie uma mensagem curta: o que é, para quem é, quanto custa, oferta de 5 min para mostrar.  
   - Marque 2–3 demos por semana, mesmo que “só para mostrar”.

3. **Anote tudo.**  
   Depois de cada conversa: objeção principal, o que gostaram/não gostaram, uma melhoria no pitch. Isso refina seu ICP e sua oferta.

4. **Oferta de lançamento (se fizer sentido).**  
   Ex.: “Primeiros 5: primeiro mês R$ 5” ou “1 mês grátis para testar”. Use para quebrar “não quero gastar agora”.

5. **Onde achar contatos.**  
   Network pessoal, grupos de donos de negócio (Facebook/WhatsApp), LinkedIn, cold email em sites de estabelecimentos.

Detalhes e tabela de primeiros passos estão em [MODELO_DE_VENDAS.md](./MODELO_DE_VENDAS.md).

### Depois que tiver 10+ clientes

- **Não abandone o que está funcionando.** Se WhatsApp ou visita está trazendo cliente, continue.  
- **Conteúdo em médio prazo:** building in public, posts sobre o produto e primeiros clientes.  
- **SEO + blog:** artigos como “programa de fidelidade para padaria”, “cartão de fidelidade digital para café”.  
- **Ferramenta gratuita como ímã:** ex. calculadora “quantos clientes fidelizados valem a pena?” → captura e-mail → nutre com conteúdo + oferta.

---

## Parte 2: O que costuma faltar no sistema

Checklist do que atrapalha **conversão** (visitante vira cliente) e **retenção** (cliente fica e paga).

### Para converter (visitante → estabelecimento pagante)

| O que | Por que importa |
|-------|------------------|
| **Landing clara** | Quem entra na home precisa entender em 10 segundos: o que é, para quem é, quanto custa. |
| **Preço visível** | Ex.: “R$ 10/mês” na landing ou em página de preços. Reduz “vou precisar falar com vendas?”. |
| **CTA óbvio** | Botão tipo “Criar minha conta” ou “Começar grátis” levando para cadastro/login. |
| **Fluxo pós-cadastro** | Após criar conta: criar estabelecimento → configurar programa (ex.: 10 carimbos = 1 café) → ver painel. Se isso não existir ou for confuso, o usuário desiste. |
| **Pagamento (Stripe)** | Cobrança após criar estabelecimento (ex.: trial curto ou cobrança na hora). Sem isso não há receita recorrente. |
| **Página “Meus cartões” (cliente final)** | O cliente do estabelecimento precisa ver seus cartões por e-mail. Se não tiver, o valor do produto fica abstrato. |

### Para reter (estabelecimento usa e continua pagando)

| O que | Por que importa |
|-------|------------------|
| **Forma do cliente achar seus cartões** | Link fixo (ex.: `/cards`) ou página por e-mail onde o cliente digita o e-mail e vê os cartões. Sem isso, o programa “não existe” na prática. |
| **Adicionar carimbo rápido** | Estabelecimento precisa dar carimbo no dia a dia (por e-mail do cliente ou por busca). Se for difícil, não usam. |
| **Ver que está funcionando** | Mínimo: quantos carimbos foram dados, quantos clientes ativos. Dashboard simples já ajuda. |
| **Cancelamento e billing claros** | Onde ver a cobrança, como cancelar. Evita chargeback e sensação de “me prenderam”. |

### Diferenciais que ajudam (não obrigatórios no início)

- **Link/QR para o estabelecimento:** “Seus clientes acessam aqui” (ex.: meuapp.com/cards ou link único por estabelecimento).  
- **Trial:** 7 ou 14 dias grátis antes de cobrar.  
- **E-mail de boas-vindas:** “Você criou o estabelecimento X; próximo passo: configurar o programa”.  
- **Um número simples:** “Você já deu X carimbos este mês” no painel.

---

## Resumo em uma frase

**Para conseguir clientes:** liste estabelecimentos, envie mensagem curta, marque demos e anote objeções; use o [modelo de vendas](./MODELO_DE_VENDAS.md) como guia.  
**Para o sistema não atrapalhar:** tenha landing + preço + CTA, fluxo completo (cadastro → estabelecimento → programa → cobrança) e uma forma real do cliente final ver e usar os cartões (ex.: `/cards` por e-mail).

Quando você tiver 5–10 conversas reais, vale revisar este doc e o MODELO_DE_VENDAS com “o que mais apareceu como objeção” e “o que mais faltou no produto” — aí você prioriza o próximo passo no código e na venda.
