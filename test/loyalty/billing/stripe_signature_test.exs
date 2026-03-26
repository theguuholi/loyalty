defmodule Loyalty.Billing.StripeSignatureTest do
  use ExUnit.Case, async: true

  alias Loyalty.Billing.StripeSignature

  @secret "whsec_c90c66e720722386a7c3ee4216cc5c24aaa8259bfc219c21f50f39428d96fb19"

  defp sign(raw_body, key \\ @secret) do
    t = System.system_time(:second)
    payload = "#{t}.#{raw_body}"
    mac = :crypto.mac(:hmac, :sha256, key, payload)
    sig = Base.encode16(mac, case: :lower)
    {t, "t=#{t},v1=#{sig}"}
  end

  describe "verify/3" do
    test "accepts valid signature" do
      body = ~s({"x":1})
      {_t, header} = sign(body)
      assert :ok == StripeSignature.verify(body, header, @secret)
    end

    test "accepts secret with surrounding whitespace" do
      body = ~s({"x":1})
      {_t, header} = sign(body)
      assert :ok == StripeSignature.verify(body, header, "  \n#{@secret}\t")
    end

    test "accepts pretty-printed JSON when signature was computed on compact JSON" do
      compact = ~s({"x":1})
      pretty = "{\n  \"x\": 1\n}"
      {_t, header} = sign(compact)
      assert :ok == StripeSignature.verify(pretty, header, @secret)
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
      mac = :crypto.mac(:hmac, :sha256, @secret, payload)
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

    test "rejects nil signature header" do
      assert {:error, :invalid_header} == StripeSignature.verify("{}", nil, @secret)
    end
  end
end
