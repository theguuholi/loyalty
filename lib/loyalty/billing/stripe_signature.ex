defmodule Loyalty.Billing.StripeSignature do
  @moduledoc "Verifies `Stripe-Signature` headers for webhook payloads."

  @max_age_seconds 300

  @doc """
  Verifies the raw JSON body against the signing secret (`whsec_...`).

  Returns `:ok` or `{:error, reason}`.

  If verification fails on the exact bytes, tries a compact JSON re-encoding when
  the payload parses as JSON and differs from the raw string (whitespace-only
  differences vs what Stripe signed).
  """
  def verify(raw_body, signature_header, secret) do
    secret = String.trim(secret || "")

    cond do
      secret == "" ->
        {:error, :webhook_secret_not_configured}

      not (is_binary(raw_body) and is_binary(signature_header)) ->
        {:error, :invalid_arguments}

      true ->
        verify_signed_payload(raw_body, signature_header, secret)
    end
  end

  defp verify_signed_payload(raw_body, signature_header, secret) do
    with {:ok, timestamp, v1_list} <- parse_header(signature_header),
         :ok <- verify_timestamp(timestamp),
         {:ok, signing_key} <- decode_signing_secret(secret) do
      cond do
        hmac_matches?(timestamp, raw_body, v1_list, signing_key) ->
          :ok

        match_compact_json?(timestamp, raw_body, v1_list, signing_key) ->
          :ok

        true ->
          {:error, :invalid_signature}
      end
    end
  end

  defp match_compact_json?(timestamp, raw_body, v1_list, signing_key) do
    case Jason.decode(raw_body) do
      {:ok, data} ->
        compact = Jason.encode!(data)
        compact != raw_body and hmac_matches?(timestamp, compact, v1_list, signing_key)

      _ ->
        false
    end
  end

  defp hmac_matches?(timestamp, payload, v1_list, signing_key) do
    signed_payload = "#{timestamp}.#{payload}"
    mac = :crypto.mac(:hmac, :sha256, signing_key, signed_payload)
    expected = Base.encode16(mac, case: :lower)
    Enum.any?(v1_list, &secure_compare_hex?(&1, expected))
  end

  defp parse_header(header) when is_binary(header) do
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
      |> Enum.map(fn "v1=" <> sig -> sig |> String.trim() |> String.downcase() end)

    if is_binary(t) and t != "" and v1s != [] do
      {:ok, t, v1s}
    else
      {:error, :invalid_header}
    end
  end

  defp parse_header(_), do: {:error, :invalid_header}

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

  defp decode_signing_secret("whsec_" <> rest) do
    decode_whsec_payload(String.trim(rest))
  end

  defp decode_signing_secret(raw) when is_binary(raw), do: {:ok, raw}

  defp decode_whsec_payload("") do
    {:error, :invalid_webhook_secret}
  end

  defp decode_whsec_payload(encoded) do
    case Base.decode64(encoded, padding: false) do
      {:ok, bin} ->
        {:ok, bin}

      :error ->
        pad = rem(4 - rem(byte_size(encoded), 4), 4)
        padded = encoded <> :binary.copy("=", pad)

        case Base.decode64(padded, padding: false) do
          {:ok, bin} -> {:ok, bin}
          :error -> {:error, :invalid_webhook_secret}
        end
    end
  end

  defp secure_compare_hex?(a, b) when byte_size(a) == byte_size(b) do
    Plug.Crypto.secure_compare(a, b)
  end

  defp secure_compare_hex?(_, _), do: false
end
