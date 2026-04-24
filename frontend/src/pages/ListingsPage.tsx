import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import api from "../api/client";
import { useAuth } from "../contexts/AuthContext";

interface Listing {
  id: number;
  title: string;
  price_cents: number;
  preview_url: string;
}

export default function ListingsPage() {
  const { token, logout } = useAuth();
  const [listings, setListings] = useState<Listing[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    api
      .get<Listing[]>("/listings")
      .then((res) => setListings(res.data))
      .catch(() => setError("Failed to load listings"))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between shadow-sm">
        <div className="flex items-center gap-2">
          <span className="text-2xl">😂</span>
          <span className="text-xl font-bold text-gray-900">Memesy</span>
        </div>
        {token ? (
          <button
            onClick={logout}
            className="rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-100 transition"
          >
            Log out
          </button>
        ) : (
          <Link
            to="/login"
            className="rounded-lg bg-violet-600 px-4 py-2 text-sm font-semibold text-white hover:bg-violet-700 transition"
          >
            Log in
          </Link>
        )}
      </nav>

      <main className="max-w-6xl mx-auto px-6 py-8">
        <h2 className="text-2xl font-bold text-gray-900 mb-6">Browse Memes</h2>

        {loading && (
          <div className="flex justify-center items-center py-20">
            <div className="h-8 w-8 animate-spin rounded-full border-4 border-violet-600 border-t-transparent" />
          </div>
        )}

        {error && (
          <p className="rounded-lg bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-600">{error}</p>
        )}

        {!loading && !error && listings.length === 0 && (
          <p className="text-center text-gray-400 py-20">No listings yet.</p>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {listings.map((l) => (
            <div
              key={l.id}
              className="bg-white rounded-2xl border border-gray-200 shadow-sm hover:shadow-md transition overflow-hidden"
            >
              <img
                src={l.preview_url}
                alt={l.title}
                className="w-full aspect-square object-cover"
              />
              <div className="p-4">
                <h3 className="font-semibold text-gray-900 truncate">{l.title}</h3>
                <p className="mt-1 text-violet-600 font-bold">
                  ${(l.price_cents / 100).toFixed(2)}
                </p>
                {token ? (
                  <button className="mt-3 w-full rounded-lg bg-violet-600 px-4 py-2 text-sm font-semibold text-white hover:bg-violet-700 transition">
                    Buy
                  </button>
                ) : (
                  <Link
                    to="/login"
                    className="mt-3 block w-full rounded-lg border border-violet-300 px-4 py-2 text-sm font-semibold text-violet-600 text-center hover:bg-violet-50 transition"
                  >
                    Log in to buy
                  </Link>
                )}
              </div>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}
