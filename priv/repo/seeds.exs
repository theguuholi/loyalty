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
    Customers,
    Establishments,
    LoyaltyCards,
    LoyaltyPrograms,
    Repo
  }

  def run do
    IO.puts("Seeding MyRewards demo data...")

    email = "owner@test.com"
    user = ensure_user("owner@test.com", email <> "M1@")
    scope = Scope.for_user(user)

    barbershop = ensure_establishment(scope, "Barbearia do João")
    coffee_shop = ensure_establishment(scope, "Café Central")

    barbershop_scope = Scope.put_establishment(scope, barbershop)
    coffee_scope = Scope.put_establishment(scope, coffee_shop)

    ensure_program(barbershop_scope, "Programa da Barbearia", 10, "1 corte grátis")
    ensure_program(coffee_scope, "Programa do Café", 6, "1 café grátis")

    customer_1 = ensure_customer("cliente@myrewards.local")
    customer_2 = ensure_customer("ana@example.com")
    customer_3 = ensure_customer("paulo@example.com")

    ensure_card(barbershop_scope, customer_1, 7, 10)
    ensure_card(coffee_scope, customer_1, 3, 6)
    ensure_card(barbershop_scope, customer_2, 10, 10)
    ensure_card(coffee_scope, customer_3, 1, 6)

    IO.puts("Seeded demo user: #{user.email} / #{@demo_password}")
    IO.puts("Seeded establishments: #{barbershop.name}, #{coffee_shop.name}")
    IO.puts("Seeded customers: #{customer_1.email}, #{customer_2.email}, #{customer_3.email}")
  end

  defp ensure_user(email, password) do
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
