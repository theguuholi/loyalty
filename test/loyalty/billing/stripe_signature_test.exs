defmodule Loyalty.Billing.StripeSignatureTest do
  use ExUnit.Case, async: true

  alias Loyalty.Billing.StripeSignature

  @secret "whsec_" <> Base.encode64("01234567890123456789012345678901")

  defp signing_key, do: "01234567890123456789012345678901"

  defp sign(raw_body) do
    t = System.system_time(:second)
    payload = "#{t}.#{raw_body}"
    mac = :crypto.mac(:hmac, :sha256, signing_key(), payload)
    sig = Base.encode16(mac, case: :lower)
    {t, "t=#{t},v1=#{sig}"}
  end

  describe "verify/3" do
    test "accepts valid signature" do
      body = ~s({"x":1})
      {_t, header} = sign(body)
      assert :ok == StripeSignature.verify(body, header, @secret)
    end

    test "rejects wrong body" do
      {_t, header} = sign(~s({"x":1}))
      assert {:error, :invalid_signature} == StripeSignature.verify(~s({"x":2}), header, @secret)
    end

    test "rejects malformed header" do
      assert {:error, :invalid_header} ==
               StripeSignature.verify("{}", "nope", @secret)
    end

    test "rejects bad timestamp" do
      assert {:error, :invalid_timestamp} ==
               StripeSignature.verify("{}", "t=notint,v1=abc", @secret)
    end

    test "rejects stale timestamp" do
      old = System.system_time(:second) - 9999
      body = "{}"
      payload = "#{old}.#{body}"
      mac = :crypto.mac(:hmac, :sha256, signing_key(), payload)
      sig = Base.encode16(mac, case: :lower)
      header = "t=#{old},v1=#{sig}"
      assert {:error, :timestamp_out_of_range} == StripeSignature.verify(body, header, @secret)
    end

    test "rejects missing or empty webhook secret" do
      assert {:error, :webhook_secret_not_configured} ==
               StripeSignature.verify("{}", "t=1,v1=a", nil)

      assert {:error, :webhook_secret_not_configured} ==
               StripeSignature.verify("{}", "t=1,v1=a", "")
    end

    test "rejects invalid argument types" do
      assert {:error, :invalid_arguments} == StripeSignature.verify(:not_bin, "t=1,v1=a", @secret)
    end
  end
end
