# Protótipo MyRewards — Mobile First

Protótipo estático das telas do app, **sempre mobile first** (base 375px; depois tablet/desktop).

## Como usar

1. Abra `index.html` no navegador (duplo clique ou `open index.html`).
2. Ou sirva a pasta com um servidor estático, ex.: `python3 -m http.server 8080` e acesse `http://localhost:8080`.

## Estrutura

- **index.html** — Índice com links para todas as telas (cliente e estabelecimento).
- **screens/** — Uma página por tela do fluxo.
- **css/prototype.css** — Estilos mobile-first e estilo “sketch”.

## Fluxos

### Cliente (público)

1. **Landing** — `screens/01-landing.html`
2. **Meus cartões (entrada)** — `screens/02-meus-cartoes-entry.html` — Digitar e-mail.
3. **Meus cartões (lista)** — `screens/03-meus-cartoes-list.html` — Lista de cartões após “entrar” com e-mail.
3b. **Meus cartões (vazio)** — `screens/03-meus-cartoes-empty.html` — Estado quando o e-mail não tem cartões.

### Estabelecimento (painel)

4. **Login** — `screens/04-establishment-login.html`
5. **Cadastro** — `screens/05-establishment-register.html`
6. **Dashboard** — `screens/06-establishment-dashboard.html`
7. **Programa** — `screens/07-establishment-program.html` — Regra (ex.: 10 carimbos = 1 grátis).
8. **Cartões** — `screens/08-establishment-cards.html` — Lista de cartões; busca por e-mail.
9. **Adicionar carimbo** — `screens/09-establishment-add-stamp.html` — Detalhe do cartão + botão +1.

## Desenvolvimento

Use este protótipo como referência visual ao implementar as LiveViews no Phoenix. Mantenha o mesmo fluxo e hierarquia (mobile first).

## Handoff para dev

- **Concept:** `docs/CONCEPT.md`
- **TDD:** `docs/TDD.md`
- **System Design:** `docs/SYSTEM_DESIGN.md`
- **Protótipo:** sempre mobile first; abra `index.html` e navegue pelas telas em `screens/`.
