import axios from "axios";
import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
} from "react";

interface AuthContextValue {
  token: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [token, setToken] = useState<string | null>(
    () => localStorage.getItem("token")
  );

  const login = useCallback(async (email: string, password: string) => {
    const res = await axios.post<{ token: string }>("/api/auth/login", {
      email,
      password,
    });
    const jwt = res.data.token;
    localStorage.setItem("token", jwt);
    setToken(jwt);
  }, []);

  const logout = useCallback(() => {
    // Fire-and-forget — backend deletes Redis session
    axios
      .post("/api/auth/logout", null, {
        headers: { Authorization: `Bearer ${token}` },
      })
      .catch(() => {});
    localStorage.removeItem("token");
    setToken(null);
  }, [token]);

  const value = useMemo(() => ({ token, login, logout }), [token, login, logout]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside AuthProvider");
  return ctx;
}
