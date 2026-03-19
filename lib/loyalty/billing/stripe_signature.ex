defmodule Loyalty.Billing.StripeSignature do
  @moduledoc "Verifies `Stripe-Signature` headers for webhook payloads."

  @max_age_seconds 300

  @doc """
  Verifies the raw JSON body against the signing secret (`whsec_...`).

  Returns `:ok` or `{:error, reason}`.
  """
  def verify(_, _, secret) when secret in [nil, ""], do: {:error, :webhook_secret_not_configured}

  def verify(raw_body, signature_header, secret)
      when is_binary(raw_body) and is_binary(signature_header) and is_binary(secret) do
    with {:ok, timestamp, v1_list} <- parse_header(signature_header),
         :ok <- verify_timestamp(timestamp),
         signing_key <- decode_signing_secret(secret) do
      signed_payload = "#{timestamp}.#{raw_body}"

      mac = :crypto.mac(:hmac, :sha256, signing_key, signed_payload)
      expected = Base.encode16(mac, case: :lower)

      if Enum.any?(v1_list, &secure_compare_hex?(&1, expected)) do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def verify(_, _, _), do: {:error, :invalid_arguments}

  defp parse_header(header) do
    parts =
      header
      |> String.split(",")
      |> Enum.map(&String.trim/1)

    t =
      parts
      |> Enum.find_value(fn part ->
        case String.split(part, "=", parts: 2) do
          ["t", ts] -> ts
          _ -> nil
        end
      end)

    v1s =
      parts
      |> Enum.filter(&String.starts_with?(&1, "v1="))
      |> Enum.map(fn "v1=" <> sig -> sig end)

    if is_binary(t) and t != "" and v1s != [] do
      {:ok, t, v1s}
    else
      {:error, :invalid_header}
    end
  end

  defp verify_timestamp(t_str) do
    case Integer.parse(t_str) do
      {t, ""} ->
        now = System.system_time(:second)

        if abs(now - t) <= @max_age_seconds do
          :ok
        else
          {:error, :timestamp_out_of_range}
        end

      _ ->
        {:error, :invalid_timestamp}
    end
  end

  defp decode_signing_secret("whsec_" <> encoded) do
    Base.decode64!(encoded)
  end

  defp decode_signing_secret(raw), do: raw

  defp secure_compare_hex?(a, b) when byte_size(a) == byte_size(b) do
    Plug.Crypto.secure_compare(a, b)
  end

  defp secure_compare_hex?(_, _), do: false
end
