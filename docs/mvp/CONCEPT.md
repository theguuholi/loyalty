# Concept: Cartões de Fidelidade que Sempre Perco

## Resumo do problema

Muitos estabelecimentos (barbearias, cafés, lojas, atrações) oferecem **cartões de fidelidade** em papel: a cada compra ou visita você ganha um carimbo ou furo. Ao completar um número fixo de carimbos (por exemplo 5 ou 10), você ganha um benefício (corte grátis, café grátis, 10 minutos grátis etc.). O problema é que **os cartões físicos se perdem** — ficam na carteira, na bolsa, em outro casaco, ou são esquecidos no estabelecimento — e o usuário perde o progresso e a recompensa.

---

## Contexto de uso

- **Quem:** Pessoas que frequentam os mesmos lugares e querem aproveitar programas de fidelidade (desconto ou item/serviço grátis após N compras).
- **Onde:** Barbearias, cafeterias, lavanderias, restaurantes, atrações de shopping (carrinho, trenzinho etc.), lojas de bairro.
- **Quando:** Toda vez que há uma compra ou uso de serviço que poderia contar para o programa de fidelidade.

---

## Exemplos concretos

### Exemplo 1: Barbearia

- **Estabelecimento:** Barbearia do bairro.
- **Regra:** A cada corte você ganha 1 carimbo no cartão. Com **10 carimbos** você ganha **1 corte grátis**.
- **Problema:** O cartão de papel fica na carteira ou em outro lugar; em uma troca de bolsa ou limpeza, o cartão some. O cliente perde quantos carimbos já tinha e “reinicia” do zero, ou desiste do programa.

### Exemplo 2: Carrinho no shopping

- **Estabelecimento:** Atração de carrinho no shopping (ex.: R$ 30 por 10 minutos).
- **Regra:** A cada pagamento de R$ 30 (10 minutos) você ganha 1 carimbo. Com **10 carimbos** você ganha **1 sessão de 10 minutos grátis**.
- **Problema:** O cartão é pequeno, fica no bolso ou na bolsa da criança; após algumas idas ao shopping, o cartão some. O progresso (ex.: 7 de 10) se perde.

---

## Dor principal

| Aspecto | Descrição |
|--------|-----------|
| **Perda do cartão** | Cartões de papel são fáceis de perder, esquecer ou estragar. |
| **Perda do progresso** | Ao perder o cartão, perde-se a noção de quantos carimbos já foram conquistados. |
| **Frustração** | Estar perto de completar (ex.: 8 de 10) e perder o cartão gera frustração e desânimo. |
| **Desistência** | Muitos deixam de participar dos programas por saber que provavelmente vão perder o cartão. |
| **Falta de visibilidade** | Não há um lugar único para ver todos os programas em que estou participando e quanto falta para cada recompensa. |

---

## Necessidade (job to be done)

> “Quando eu faço uma compra ou uso um serviço que dá direito a carimbo, quero **registrar esse progresso em um lugar que não vou perder**, e **saber quanto falta** para ganhar a recompensa, para que eu não perca mais os benefícios por perder o cartão de papel.”

---

## Premissas para uma solução

1. **Digital:** O progresso deve ficar guardado de forma digital (app ou sistema web), não em papel.
2. **Conta primeiro, depois estabelecimentos:** Quem oferece o programa de fidelidade (dono do estabelecimento) é um **usuário** que deve **criar uma conta** (e-mail e senha) primeiro. Após fazer login, esse usuário pode **criar e gerenciar um ou mais estabelecimentos**. Cada estabelecimento tem seu próprio programa e seus próprios cartões de clientes.
3. **Por estabelecimento:** Cada “cartão” é um programa de fidelidade de um lugar (nome do lugar, regra tipo “10 compras = 1 grátis”, e contagem atual).
4. **Simples:** O usuário não precisa que o estabelecimento use sistema especial; ele pode **auto-registrar** a compra/visita (ex.: “estou na barbearia X, adicionar 1 carimbo”).
5. **Visível:** Uma lista de “meus cartões” com progresso (ex.: 7/10) e o que falta para a recompensa.

---

## Escopo deste documento

Este é um **concept doc**: descreve o problema e o contexto. Decisões de produto (funcionalidades exatas, fluxos, priorização) e de implementação (tecnologia, UX) virão em documentos e backlog derivados deste conceito.

---

## Próximos passos sugeridos

1. Validar o conceito com usuários (entrevistas rápidas sobre perda de cartões e interesse em alternativa digital).
2. Definir MVP: cadastro de “cartões” (estabelecimento + meta + progresso) e forma de incrementar carimbos manualmente.
3. Especificar fluxos e telas (lista de cartões, detalhe, “adicionar carimbo”).
4. Implementar e testar com usuários reais.
