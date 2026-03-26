# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Loyalty.Repo.insert!(%Loyalty.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

defmodule Seeds do
  alias Loyalty.{
    Accounts,
    Accounts.Scope,
    Billing,
    Customers,
    Establishments,
    LoyaltyCards,
    LoyaltyPrograms,
    Repo
  }

  def run do
    IO.puts("Seeding MyRewards demo data...")

    admin_email = Application.fetch_env!(:loyalty, :admin_email)
    ensure_user(admin_email)
    IO.puts("Admin account: #{admin_email} (password: #{admin_email}M1@)")
    IO.puts("")

    free_user = ensure_user("free.demo@test.com")
    free_scope = user_scope_with_establishment(free_user, "Demo — plano gratuito (uso baixo)")
    ensure_program(free_scope, "Programa fidelidade", 10, "1 recompensa grátis")

    limit_user = ensure_user("free_limit.demo@test.com")

    limit_scope =
      user_scope_with_establishment(limit_user, "Demo — plano gratuito (20/20, migrar)")

    ensure_program(limit_scope, "Programa cartão", 8, "Brinde ao completar")

    paid_user = ensure_user("paid.demo@test.com")
    paid_est = user_establishment(paid_user, "Demo — plano pago (assinatura ativa)")
    paid_est = apply_paid_subscription(paid_est)

    paid_scope =
      paid_user
      |> Scope.for_user()
      |> Scope.put_establishment(paid_est)

    ensure_program(paid_scope, "Programa VIP", 12, "Desconto especial")

    c1 = ensure_customer("cliente1@test.com")
    c2 = ensure_customer("cliente2@test.com")
    c3 = ensure_customer("cliente3@test.com")
    ensure_card(free_scope, c1, 3, 10)
    ensure_card(free_scope, c2, 5, 10)
    ensure_card(free_scope, c3, 10, 10)

    for i <- 1..Billing.free_client_limit() do
      c = ensure_customer("full_client_#{i}@test.com")
      ensure_card(limit_scope, c, 0, 8)
    end

    ensure_card(paid_scope, ensure_customer("vip@test.com"), 4, 12)

    IO.puts("")
    IO.puts("--- Demo accounts (password for each: <email>M1@) ---")
    IO.puts("1) Free - under limit:     #{free_user.email}")

    IO.puts(
      "2) Free - #{Billing.free_client_limit()}/#{Billing.free_client_limit()} (upgrade / migrate): #{limit_user.email}"
    )

    IO.puts(
      "   -> Dashboard shows subscribe CTA, near-limit hint, and client limit when adding clients."
    )

    IO.puts("3) Paid - active subscription: #{paid_user.email}")
    IO.puts("")
  end

  defp user_scope_with_establishment(user, establishment_name) do
    scope = Scope.for_user(user)
    est = ensure_establishment(scope, establishment_name)
    Scope.put_establishment(scope, est)
  end

  defp user_establishment(user, establishment_name) do
    scope = Scope.for_user(user)
    ensure_establishment(scope, establishment_name)
  end

  defp apply_paid_subscription(%Loyalty.Establishments.Establishment{} = establishment) do
    establishment
    |> Ecto.Changeset.change(%{
      subscription_status: "active",
      stripe_customer_id: "cus_seed_" <> String.slice(establishment.id, 0, 8),
      stripe_subscription_id: "sub_seed_" <> String.replace(establishment.id, "-", "")
    })
    |> Repo.update!()
  end

  defp ensure_user(email) do
    password = email <> "M1@"

    case Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Accounts.register_user(%{email: email})

        {:ok, {user, _expired_tokens}} =
          Accounts.update_user_password(user, %{password: password})

        user

      user ->
        {:ok, {user, _expired_tokens}} =
          Accounts.update_user_password(user, %{password: password})

        user
    end
  end

  defp ensure_establishment(scope, name) do
    case scope |> Establishments.list_establishments() |> Enum.find(&(&1.name == name)) do
      nil ->
        {:ok, establishment} = Establishments.create_establishment(scope, %{name: name})
        establishment

      establishment ->
        establishment
    end
  end

  defp ensure_program(scope, name, stamps_required, reward_description) do
    case LoyaltyPrograms.list_loyalty_programs(scope) do
      [program | _] ->
        {:ok, program} =
          LoyaltyPrograms.update_loyalty_program(scope, program, %{
            name: name,
            stamps_required: stamps_required,
            reward_description: reward_description
          })

        program

      [] ->
        {:ok, program} =
          LoyaltyPrograms.create_loyalty_program(scope, %{
            name: name,
            stamps_required: stamps_required,
            reward_description: reward_description
          })

        program
    end
  end

  defp ensure_customer(email) do
    {:ok, customer} = Customers.get_or_create_customer_by_email(email)
    customer
  end

  defp ensure_card(scope, customer, stamps_current, stamps_required) do
    attrs = %{
      customer_id: customer.id,
      stamps_current: stamps_current,
      stamps_required: stamps_required,
      loyalty_program_id: program_for_scope(scope).id
    }

    case Repo.get_by(LoyaltyCards.LoyaltyCard,
           customer_id: customer.id,
           establishment_id: scope.establishment.id
         ) do
      nil ->
        {:ok, card} = LoyaltyCards.create_loyalty_card(scope, attrs)
        card

      card ->
        {:ok, card} = LoyaltyCards.update_loyalty_card(scope, card, attrs)
        card
    end
  end

  defp program_for_scope(scope) do
    case LoyaltyPrograms.list_loyalty_programs(scope) do
      [program | _] -> program
      [] -> raise "missing loyalty program for establishment #{scope.establishment.id}"
    end
  end
end

Seeds.run()
