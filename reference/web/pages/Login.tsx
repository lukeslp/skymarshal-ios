import { LoginForm } from '../components/auth/LoginForm';
import { useLocation } from 'react-router-dom';
import { AlertCircle } from 'lucide-react';
import { useDocumentTitle } from '../hooks/useDocumentTitle';

export function Login() {
  useDocumentTitle('Login');
  const location = useLocation();
  const message = (location.state as { message?: string })?.message;

  return (
    <div>
      {message && (
        <div className="max-w-md mx-auto mt-8 px-4">
          <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
            <p className="text-sm text-amber-800">{message}</p>
          </div>
        </div>
      )}
      <LoginForm />
    </div>
  );
}
