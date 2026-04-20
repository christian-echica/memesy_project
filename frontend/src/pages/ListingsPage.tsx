import { useEffect, useState } from "react";
import api from "../api/client";
import { useAuth } from "../contexts/AuthContext";

interface Listing {
  id: number;
  title: string;
  price_cents: number;
  preview_url: string;
}

export default function ListingsPage() {
  const { logout } = useAuth();
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

  if (loading) return <p>Loading…</p>;
  if (error) return <p style={{ color: "red" }}>{error}</p>;

  return (
    <div style={{ maxWidth: 900, margin: "40px auto", fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", justifyContent: "space-between" }}>
        <h1>Browse Memes</h1>
        <button onClick={logout}>Log out</button>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 16 }}>
        {listings.map((l) => (
          <div key={l.id} style={{ border: "1px solid #ddd", borderRadius: 8, padding: 12 }}>
            <img
              src={l.preview_url}
              alt={l.title}
              style={{ width: "100%", aspectRatio: "1", objectFit: "cover" }}
            />
            <h3 style={{ margin: "8px 0 4px" }}>{l.title}</h3>
            <p style={{ margin: 0, color: "#555" }}>
              ${(l.price_cents / 100).toFixed(2)}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}
