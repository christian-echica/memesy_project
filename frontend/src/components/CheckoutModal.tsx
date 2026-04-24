import { useEffect, useState } from "react";
import { loadStripe } from "@stripe/stripe-js";
import {
  Elements,
  PaymentElement,
  useStripe,
  useElements,
} from "@stripe/react-stripe-js";
import api from "../api/client";

const stripePromise = loadStripe(
  "pk_test_51HP5CRA4nIz9JEy4B7Ng6Ak0XtZqkUd6kPw3HETc3cJFS6W2ZDTnbTs9ycBtjTcZ5t5XkBFJK5Jzfw4xpgydETaD00yn1SyXUI"
);

interface Props {
  listing: { id: number; title: string; price_cents: number };
  onClose: () => void;
}

function PaymentForm({
  totalCents,
  onClose,
}: {
  totalCents: number;
  onClose: () => void;
}) {
  const stripe = useStripe();
  const elements = useElements();
  const [paying, setPaying] = useState(false);
  const [err, setErr] = useState("");
  const [done, setDone] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements) return;
    setPaying(true);
    setErr("");
    const result = await stripe.confirmPayment({
      elements,
      confirmParams: { return_url: window.location.href },
      redirect: "if_required",
    });
    setPaying(false);
    if (result.error) {
      setErr(result.error.message ?? "Payment failed");
    } else {
      setDone(true);
    }
  };

  if (done) {
    return (
      <div className="text-center py-8">
        <div className="text-5xl mb-4">🎉</div>
        <h3 className="text-xl font-bold text-gray-900 mb-2">Payment successful!</h3>
        <p className="text-gray-500 text-sm mb-6">Check your email for the download link.</p>
        <button
          onClick={onClose}
          className="rounded-lg bg-violet-600 px-6 py-2 text-sm font-semibold text-white hover:bg-violet-700 transition"
        >
          Done
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit}>
      <p className="text-sm text-gray-500 mb-4">
        Total: <span className="font-bold text-gray-900">${(totalCents / 100).toFixed(2)}</span>
      </p>
      <PaymentElement />
      {err && (
        <p className="mt-3 text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
          {err}
        </p>
      )}
      <button
        type="submit"
        disabled={paying || !stripe}
        className="mt-4 w-full rounded-lg bg-violet-600 px-4 py-3 text-sm font-semibold text-white hover:bg-violet-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {paying ? "Processing…" : `Pay $${(totalCents / 100).toFixed(2)}`}
      </button>
    </form>
  );
}

export default function CheckoutModal({ listing, onClose }: Props) {
  const [clientSecret, setClientSecret] = useState("");
  const [totalCents, setTotalCents] = useState(0);
  const [loadErr, setLoadErr] = useState("");

  useEffect(() => {
    api
      .post<{ order_id: number; total_cents: number }>("/orders", {
        listing_ids: [listing.id],
      })
      .then((res) =>
        api.post<{ client_secret: string }>("/payment/intent", {
          order_id: res.data.order_id,
        }).then((r) => {
          setTotalCents(res.data.total_cents);
          setClientSecret(r.data.client_secret);
        })
      )
      .catch(() => setLoadErr("Could not start checkout. Please try again."));
  }, [listing.id]);

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 px-4"
      onClick={(e) => e.target === e.currentTarget && onClose()}
    >
      <div className="w-full max-w-md rounded-2xl bg-white shadow-2xl p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-gray-900 truncate pr-4">{listing.title}</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 text-2xl leading-none"
          >
            ×
          </button>
        </div>

        {loadErr && (
          <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
            {loadErr}
          </p>
        )}

        {!loadErr && !clientSecret && (
          <div className="flex justify-center py-10">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-violet-600 border-t-transparent" />
          </div>
        )}

        {clientSecret && (
          <Elements stripe={stripePromise} options={{ clientSecret }}>
            <PaymentForm
              totalCents={totalCents}
              onClose={onClose}
            />
          </Elements>
        )}
      </div>
    </div>
  );
}
