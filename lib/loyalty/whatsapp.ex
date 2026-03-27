defmodule Loyalty.WhatsApp do
  @moduledoc """
  Sends WhatsApp messages via Twilio's Messages API.
  """

  require Logger

  @doc """
  Sends a stamp progress update to a customer's WhatsApp number.

  ## Options

    * `:req_opts` — extra options merged into `Req.post/2` (e.g. `plug:` for tests).
  """
  @spec send_stamp_update(String.t(), integer(), integer(), String.t(), String.t(), keyword()) ::
          :ok | {:error, term()}
  def send_stamp_update(
        whatsapp_number,
        stamps_current,
        stamps_required,
        reward,
        establishment_name,
        opts \\ []
      ) do
    remaining = stamps_required - stamps_current

    body =
      if remaining > 0 do
        "🎟 #{establishment_name}: você tem #{stamps_current}/#{stamps_required} carimbos! " <>
          "Faltam #{remaining} para ganhar: #{reward}."
      else
        "🎉 Parabéns! Você completou o cartão em #{establishment_name} e ganhou: #{reward}. " <>
          "Mostre esta mensagem para resgatar!"
      end

    send_message(whatsapp_number, body, opts)
  end

  defp send_message(to_number, body, opts) do
    config = Application.get_env(:loyalty, __MODULE__, [])
    account_sid = Keyword.get(config, :account_sid)
    auth_token = Keyword.get(config, :auth_token)
    from_number = Keyword.get(config, :from_number)

    if is_nil(account_sid) or is_nil(auth_token) or is_nil(from_number) do
      Logger.warning("WhatsApp not configured — skipping message to #{to_number}")
      :ok
    else
      url = "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json"

      base_req = [
        auth: {account_sid, auth_token},
        form: [
          From: "whatsapp:#{from_number}",
          To: "whatsapp:#{to_number}",
          Body: body
        ]
      ]

      req_opts = Keyword.get(opts, :req_opts, [])

      result = Req.post(url, Keyword.merge(base_req, req_opts))

      case result do
        {:ok, %{status: status}} when status in 200..299 ->
          :ok

        {:ok, %{status: status, body: resp_body}} ->
          Logger.error("Twilio error #{status}: #{inspect(resp_body)}")
          {:error, :twilio_error}

        {:error, reason} ->
          Logger.error("WhatsApp HTTP error: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end
end
