defmodule Loyalty.Billing.Stripe do
  @moduledoc "Server-side Stripe Checkout Session creation (subscription mode) via Req."

  @sessions_url "https://api.stripe.com/v1/checkout/sessions"

  @doc """
  Creates a Checkout Session in `subscription` mode for the given establishment.

  Returns `{:ok, url}` to redirect the browser, or `{:error, reason}`.

  ## Options

    * `:req_opts` — extra options merged into `Req.post/2` (e.g. `plug:` for tests).
  """
  def create_subscription_checkout_session(
        %Loyalty.Establishments.Establishment{} = establishment,
        success_url,
        cancel_url,
        opts \\ []
      ) do
    cfg = Application.get_env(:loyalty, :stripe, [])
    secret = cfg[:secret_key]
    price_id = cfg[:price_id]

    if missing?(secret) or missing?(price_id) do
      {:error, :stripe_not_configured}
    else
      id = establishment.id |> to_string()

      form = [
        {"mode", "subscription"},
        {"success_url", success_url},
        {"cancel_url", cancel_url},
        {"client_reference_id", id},
        {"line_items[0][price]", price_id},
        {"line_items[0][quantity]", "1"},
        {"metadata[establishment_id]", id}
      ]

      base_req = [
        headers: [{"authorization", "Bearer #{secret}"}],
        form: form
      ]

      req_opts = Keyword.get(opts, :req_opts, [])

      case Req.post(@sessions_url, Keyword.merge(base_req, req_opts)) do
        {:ok, %{status: 200, body: body}} when is_map(body) ->
          checkout_url_from_body(body)

        {:ok, %{status: status, body: body}} ->
          {:error, {:stripe_http_error, status, body}}

        {:error, reason} ->
          {:error, {:stripe_request_failed, reason}}
      end
    end
  end

  defp missing?(v), do: is_nil(v) or v == ""

  defp checkout_url_from_body(body) do
    case body["url"] do
      url when is_binary(url) -> {:ok, url}
      _ -> {:error, :stripe_no_checkout_url}
    end
  end
end
