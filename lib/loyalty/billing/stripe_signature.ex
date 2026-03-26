defmodule Loyalty.Billing.StripeSignature do
  @moduledoc "Verifies `Stripe-Signature` headers for webhook payloads."

  @tolerance_seconds 300

  @doc """
  Verifies the raw JSON body against the signing secret (`whsec_...`).

  Returns `:ok` or `{:error, reason}`.

  If verification fails on the exact bytes, tries a compact JSON re-encoding when
  the payload parses as JSON and differs from the raw string (whitespace-only
  differences vs what Stripe signed).
  """
  def verify(payload, signature_header, webhook_secret) do
    with :ok <- validate_arguments(payload, signature_header),
         :ok <- check_secret_configured(webhook_secret),
         {:ok, %{"t" => timestamp, "v1" => signature}} <-
           parse_signature_header(signature_header),
         :ok <- verify_timestamp(timestamp) do
      key = String.trim(webhook_secret)
      verify_signature(payload, timestamp, signature, key)
    end
  end

  defp validate_arguments(payload, _header) when not is_binary(payload),
    do: {:error, :invalid_arguments}

  defp validate_arguments(_payload, _header), do: :ok

  defp check_secret_configured(nil), do: {:error, :webhook_secret_not_configured}
  defp check_secret_configured(""), do: {:error, :webhook_secret_not_configured}
  defp check_secret_configured(_), do: :ok

  defp parse_signature_header(nil), do: {:error, :invalid_header}

  defp parse_signature_header(header) when is_binary(header) do
    parts =
      header
      |> String.split(",")
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Enum.filter(&(length(&1) == 2))
      |> Map.new(fn [k, v] -> {k, v} end)

    if Map.has_key?(parts, "t") and Map.has_key?(parts, "v1") do
      {:ok, parts}
    else
      {:error, :invalid_header}
    end
  end

  defp verify_timestamp(timestamp) do
    case Integer.parse(timestamp) do
      {timestamp_int, ""} ->
        current_time = System.system_time(:second)

        if abs(current_time - timestamp_int) <= @tolerance_seconds do
          :ok
        else
          {:error, :timestamp_out_of_range}
        end

      _ ->
        {:error, :invalid_timestamp}
    end
  end

  defp verify_signature(payload, timestamp, signature, key) do
    if compute_signature(payload, timestamp, key) == signature do
      :ok
    else
      try_compact_json(payload, timestamp, signature, key)
    end
  end

  defp try_compact_json(payload, timestamp, signature, key) do
    with {:ok, decoded} <- Jason.decode(payload),
         compact = Jason.encode!(decoded),
         true <- compact != payload do
      if compute_signature(compact, timestamp, key) == signature do
        :ok
      else
        {:error, :invalid_signature}
      end
    else
      _ -> {:error, :invalid_signature}
    end
  end

  defp compute_signature(payload, timestamp, key) do
    signed_payload = "#{timestamp}.#{payload}"

    signed_payload
    |> then(&:crypto.mac(:hmac, :sha256, key, &1))
    |> Base.encode16(case: :lower)
  end
end
