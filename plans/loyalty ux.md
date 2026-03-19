Loyalty UX, Navigation, and Internationalization Plan

This plan consolidates the previous discussions into one build: simpler create-card flow, better list UX, fewer pages, and i18n (EN + PT-BR) with automatic locale.



1. Navigation: simpler path to create a loyalty card

Current: User must go Establishments → [establishment] → "Ver cartões / Clientes" → "New Loyalty card" (4 steps).

Changes:





Establishment Show:





Add a primary CTA: "Cadastrar cliente" (or "Novo cartão") that navigates directly to ~p"/establishments/#{@establishment}/loyalty_cards/new".



Merge the two quick actions into one: keep a single link "Cartões e clientes" (or "Ver cartões") to ~p"/establishments/#{@establishment}/loyalty_cards" and remove the duplicate "Adicionar carimbo" link (both currently go to the same list; add-stamp is done on the list).



LoyaltyCard Index: Make "New Loyalty card" / "Cadastrar cliente" the clear primary action (e.g. top-right); keep "back" to establishment show. Optionally add an empty-state CTA (see below).

Result: Create card in 2 steps: Dashboard → "Cadastrar cliente".



2. Remove unnecessary pages and links

LoyaltyCard Show:





The router defines live "/loyalty_cards/:id", LoyaltyCardLive.Show, :show but there is no LoyaltyCardLive.Show module (only index.ex and form.ex exist). Add-stamp is already on the Index.



Remove the Show route from router.ex (the line live "/loyalty_cards/:id", LoyaltyCardLive.Show, :show).



LoyaltyCard Index: Remove the sr-only "Show" link and any other link to loyalty_cards/:id (show).



LoyaltyCard Form: Always return to the list after save. Remove the "show" return path: delete return_to("show") and return_path(scope, "show", loyalty_card); after create/edit always push_navigate to the index path. Remove return_to from query params handling if it is only used for show.

Quick actions (already covered in section 1): One link from dashboard to cards list instead of two.



3. List visualization and UX

Stream container (required for LiveView streams):





In LoyaltyCardLive.Index, the list uses @streams.loyalty_cards but the parent element must have phx-update="stream" and a stable DOM id. Per Phoenix docs and AGENTS.md:





Wrap the streamed list in a single parent: <div id="loyalty_cards" phx-update="stream">.



Each streamed child must have id={id} (the stream id). Currently the inner div uses id={"add-stamp-card-#{id}"}; either use id={id} for the stream child and keep the same id for the card block, or use the stream id on the outermost element and ensure it is the direct child of the stream container.

Empty state:





When there are no cards, show a short message (e.g. "Nenhum cartão ainda." / "No cards yet.") and a single CTA button: "Cadastrar primeiro cliente" → navigate to loyalty_cards/new. Use an assign (e.g. cards_empty?) derived from the list length or stream count so the template can conditionally render the empty state vs the stream (streams do not support counting; use a separate assign).

Card block and actions:





Keep one card per row with progress bar, "X de Y carimbos", reward text, and "+ 1 carimbo" button.



Keep "Edit" and "Delete" links; remove the "Show" link (see section 2).



Use consistent DOM ids for tests (e.g. id={"add-stamp-card-#{id}"} or id={id} as required by streams).



4. Internationalization (EN + PT-BR, automatic)

4.1 Locales and Gettext





Keep en as default. Add pt_BR as second locale.



Run: mix gettext.merge priv/gettext --locale pt_BR to create priv/gettext/pt_BR/LC_MESSAGES/*.po from existing .pot files.



Ensure a default Gettext domain exists for app copy (not only errors). If only errors.pot exists, run mix gettext.extract and add a default domain so that gettext("...") strings are extracted into e.g. default.po. Fill EN (and PT-BR) as needed.

4.2 Automatic locale detection (Plug)





Add a Plug that runs after fetch_session in the browser pipeline (e.g. in router.ex or a new module):





If the user has a stored preference (e.g. conn.session["locale"] or a cookie), use it; normalize to "en" or "pt_BR" (e.g. "pt-BR" → "pt_BR").



Else, parse the Accept-Language header and choose the first supported locale (en, pt_BR).



Default to "en".



Then: Gettext.put_locale(LoyaltyWeb.Gettext, locale) and assign(conn, :locale, locale) so controllers and the initial LiveView mount see the same locale.

4.3 LiveView and locale





In the same live_session that uses this pipeline, ensure the locale assign is available. Add an on_mount hook (e.g. in UserAuth or a new module) that runs for the relevant live_sessions: read locale from socket assigns (set from conn at mount) and call Gettext.put_locale(LoyaltyWeb.Gettext, locale) so all gettext() calls in that LiveView use the chosen locale.

4.4 Wrap user-facing strings





Replace hardcoded copy with gettext("...") (and ngettext for plurals) in:





Layouts: nav links, "Establishments", "Settings", "Log out", "Register", "Log in".



Establishment Show: all Portuguese and English labels (e.g. "Assinatura ativa", "Criar programa", "Ver cartões / Clientes", "Editar estabelecimento").



LoyaltyCard Index: "Listing Loyalty cards", "back", "New Loyalty card", "de … carimbos", "+ 1 carimbo", "Edit", "Delete", empty state text.



LoyaltyCard Form: page title, subtitle, "Customer email", "Stamps current", "Stamps required", "Save Loyalty card", "Cancel", "Saving...".



Flash messages (e.g. "Loyalty card created successfully", "Customer email is required.", "Carimbo adicionado.") wherever they are set (Form, Index, etc.).



Use English as the default msgid; add Portuguese translations in priv/gettext/pt_BR/LC_MESSAGES/default.po (and errors.po for Ecto/validation messages).



Run mix gettext.extract --merge and fill in the PT-BR .po files.

4.5 Language switcher (optional)





In the layout, add a small switcher (e.g. "EN | PT") that sets the user preference (e.g. patch to a route that sets conn.session["locale"] and redirects back, or a form that does the same). The locale Plug then uses this on the next request.



5. Implementation order





Navigation and quick actions: Update Establishment Show (add "Cadastrar cliente", single "Cartões e clientes" link). Update LoyaltyCard Index header/actions if needed.



Remove Show: Remove Show route from router; remove Show link and return-to-show logic from Index and Form.



List UX: Fix stream container (id="loyalty_cards", phx-update="stream", correct child id); add empty-state assign and template; remove Show link from card row.



i18n – infrastructure: Add locale Plug (session → Accept-Language → default), add on_mount to set Gettext locale for LiveView; add pt_BR locale and default domain.



i18n – copy: Replace strings with gettext() in Layouts, Establishment Show, LoyaltyCard Index, LoyaltyCard Form, and flash messages; run extract/merge; add PT-BR translations.



Optional: Language switcher in layout.



6. Files to touch (summary)







Area



Files





Router



lib/loyalty_web/router.ex (remove Show route; add locale Plug in pipeline if not in separate module).





Locale



New Plug module (e.g. lib/loyalty_web/plugs/locale.ex); optionally UserAuth or new on_mount for put_locale.





Establishment Show



lib/loyalty_web/live/establishment_live/show.ex.





LoyaltyCard Index



lib/loyalty_web/live/loyalty_card_live/index.ex.





LoyaltyCard Form



lib/loyalty_web/live/loyalty_card_live/form.ex.





Layouts



lib/loyalty_web/components/layouts.ex.





Gettext



priv/gettext/ (merge pt_BR, default domain, translations).

No new pages are required; one route (Show) is removed. Form and Index remain the main entry points for create/edit and list+add-stamp.