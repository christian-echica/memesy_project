import { Navigate, Route, Routes } from "react-router-dom";
import { useAuth } from "./contexts/AuthContext";
import ListingsPage from "./pages/ListingsPage";
import LoginPage from "./pages/LoginPage";

function PrivateRoute({ children }: { children: React.ReactNode }) {
  const { token } = useAuth();
  return token ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <PrivateRoute>
            <ListingsPage />
          </PrivateRoute>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
