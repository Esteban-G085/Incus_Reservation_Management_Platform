#!/bin/bash
# setup-frontend.sh - Instala Node.js y crea la app React + Vite en core

set -e

echo "=========================================="
echo "  SETUP FRONTEND - React + Vite (core)"
echo "=========================================="
echo ""

sudo incus exec core -- bash <<'FRONTEND'

set -e

# ─── 1. Node.js ───────────────────────────────────────────────────────────────
echo "[1/6] Instalando Node.js 22..."
apt install -y curl -qq > /dev/null 2>&1
curl -fsSL https://deb.nodesource.com/setup_22.x | bash - > /dev/null 2>&1
apt install -y nodejs -qq > /dev/null 2>&1
echo "  OK: $(node --version) / npm $(npm --version)"

# ─── 2. Estructura del proyecto ───────────────────────────────────────────────
echo "[2/6] Creando proyecto React + Vite..."
mkdir -p /app/frontend
cd /app/frontend

cat > package.json <<'PKG'
{
  "name": "reservas-frontend",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0 --port 5173",
    "build": "vite build",
    "preview": "vite preview --host 0.0.0.0 --port 5173"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "react-router-dom": "^6.28.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "vite": "^6.0.5"
  }
}
PKG

npm install --silent
echo "  OK: dependencias instaladas"

# ─── 3. Configuración Vite ────────────────────────────────────────────────────
echo "[3/6] Configurando Vite..."

cat > vite.config.js <<'VITE'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  preview: {
    host: '0.0.0.0',
    port: 5173,
    allowedHosts: 'all',
    proxy: {
      '/api': {
        target: 'http://api:8080',
        changeOrigin: true
      }
    }
  },
  server: {
    host: '0.0.0.0',
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://api:8080',
        changeOrigin: true
      }
    }
  }
})
VITE

mkdir -p src/components src/pages src/hooks src/context public

cat > index.html <<'HTML'
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Plataforma de Reservas</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
HTML

echo "  OK: Vite configurado"

# ─── 4. Código fuente React ───────────────────────────────────────────────────
echo "[4/6] Escribiendo código fuente..."

# Estilos globales
cat > src/index.css <<'CSS'
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg: #0f1117;
  --bg-card: #1a1d27;
  --bg-input: #252836;
  --border: #2e3347;
  --accent: #6366f1;
  --accent-hover: #818cf8;
  --accent-light: rgba(99,102,241,0.15);
  --success: #22c55e;
  --warning: #f59e0b;
  --danger: #ef4444;
  --text: #e2e8f0;
  --text-muted: #8892a4;
  --radius: 12px;
  --shadow: 0 4px 24px rgba(0,0,0,0.4);
}

body {
  font-family: 'Inter', system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  min-height: 100vh;
}

button {
  cursor: pointer;
  border: none;
  font-family: inherit;
  font-size: 0.875rem;
  font-weight: 500;
  border-radius: 8px;
  padding: 0.6rem 1.2rem;
  transition: all 0.2s;
}

.btn-primary {
  background: var(--accent);
  color: white;
}
.btn-primary:hover { background: var(--accent-hover); transform: translateY(-1px); }
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }

.btn-danger { background: var(--danger); color: white; }
.btn-danger:hover { opacity: 0.85; }

.btn-ghost {
  background: transparent;
  color: var(--text-muted);
  border: 1px solid var(--border);
}
.btn-ghost:hover { border-color: var(--accent); color: var(--accent); }

input, select {
  width: 100%;
  background: var(--bg-input);
  border: 1px solid var(--border);
  border-radius: 8px;
  color: var(--text);
  padding: 0.65rem 1rem;
  font-size: 0.875rem;
  font-family: inherit;
  outline: none;
  transition: border-color 0.2s;
}
input:focus, select:focus { border-color: var(--accent); }

.card {
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 1.5rem;
  box-shadow: var(--shadow);
}

.badge {
  display: inline-block;
  padding: 0.2rem 0.6rem;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 600;
}
.badge-green { background: rgba(34,197,94,0.15); color: var(--success); }
.badge-yellow { background: rgba(245,158,11,0.15); color: var(--warning); }
.badge-red { background: rgba(239,68,68,0.15); color: var(--danger); }
.badge-blue { background: var(--accent-light); color: var(--accent-hover); }

.error-msg {
  background: rgba(239,68,68,0.1);
  border: 1px solid rgba(239,68,68,0.3);
  color: #fca5a5;
  padding: 0.75rem 1rem;
  border-radius: 8px;
  font-size: 0.875rem;
  margin-top: 0.5rem;
}

.spinner {
  width: 20px; height: 20px;
  border: 2px solid var(--border);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
  margin: auto;
}
@keyframes spin { to { transform: rotate(360deg); } }
CSS

# Contexto de autenticación
cat > src/context/AuthContext.jsx <<'AUTH_CTX'
import { createContext, useContext, useState, useEffect } from 'react'

const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null)
  const [token, setToken] = useState(localStorage.getItem('token'))

  useEffect(() => {
    if (token) {
      const payload = JSON.parse(atob(token.split('.')[1]))
      setUser({ id: payload.sub, ...JSON.parse(localStorage.getItem('user') || '{}') })
    }
  }, [token])

  const login = (tokenStr, userData) => {
    localStorage.setItem('token', tokenStr)
    localStorage.setItem('user', JSON.stringify(userData))
    setToken(tokenStr)
    setUser(userData)
  }

  const logout = () => {
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    setToken(null)
    setUser(null)
  }

  return (
    <AuthContext.Provider value={{ user, token, login, logout, isAuth: !!token }}>
      {children}
    </AuthContext.Provider>
  )
}

export const useAuth = () => useContext(AuthContext)
AUTH_CTX

# Hook de API
cat > src/hooks/useApi.js <<'API_HOOK'
const BASE = '/api/v1'

export function useApi() {
  const token = localStorage.getItem('token')
  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {})
  }

  const get = (path) => fetch(`${BASE}${path}`, { headers }).then(r => r.json())
  const post = (path, body) => fetch(`${BASE}${path}`, { method: 'POST', headers, body: JSON.stringify(body) }).then(r => r.json())
  const put = (path, body) => fetch(`${BASE}${path}`, { method: 'PUT', headers, body: JSON.stringify(body) }).then(r => r.json())
  const del = (path) => fetch(`${BASE}${path}`, { method: 'DELETE', headers }).then(r => r.json())

  return { get, post, put, del }
}
API_HOOK

# Componente Navbar
cat > src/components/Navbar.jsx <<'NAVBAR'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export default function Navbar() {
  const { user, logout, isAuth } = useAuth()
  const location = useLocation()
  const navigate = useNavigate()

  const handleLogout = () => { logout(); navigate('/login') }

  const navStyle = {
    background: 'var(--bg-card)',
    borderBottom: '1px solid var(--border)',
    padding: '0 2rem',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'space-between',
    height: '60px',
    position: 'sticky',
    top: 0,
    zIndex: 100,
  }

  const logoStyle = {
    fontWeight: 700,
    fontSize: '1.1rem',
    color: 'var(--accent-hover)',
    textDecoration: 'none',
    letterSpacing: '-0.5px',
  }

  const linkStyle = (path) => ({
    textDecoration: 'none',
    color: location.pathname === path ? 'var(--accent-hover)' : 'var(--text-muted)',
    fontSize: '0.875rem',
    fontWeight: 500,
    padding: '0.4rem 0.75rem',
    borderRadius: '6px',
    background: location.pathname === path ? 'var(--accent-light)' : 'transparent',
    transition: 'all 0.2s',
  })

  return (
    <nav style={navStyle}>
      <Link to="/" style={logoStyle}>⬡ ReservasLab</Link>
      {isAuth && (
        <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
          <Link to="/dashboard" style={linkStyle('/dashboard')}>Dashboard</Link>
          <Link to="/recursos" style={linkStyle('/recursos')}>Recursos</Link>
          <Link to="/reservas" style={linkStyle('/reservas')}>Mis Reservas</Link>
        </div>
      )}
      <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
        {isAuth ? (
          <>
            <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
              {user?.nombre}
            </span>
            <button className="btn-ghost" onClick={handleLogout} style={{ padding: '0.4rem 0.9rem' }}>
              Salir
            </button>
          </>
        ) : (
          <Link to="/login">
            <button className="btn-primary" style={{ padding: '0.4rem 0.9rem' }}>Iniciar sesión</button>
          </Link>
        )}
      </div>
    </nav>
  )
}
NAVBAR

# Página Login
cat > src/pages/Login.jsx <<'LOGIN'
import { useState } from 'react'
import { useNavigate, Link } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'

export default function Login() {
  const [form, setForm] = useState({ email: '', password: '' })
  const [mode, setMode] = useState('login')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true); setError('')
    try {
      const endpoint = mode === 'login' ? '/api/v1/auth/login' : '/api/v1/auth/register'
      const body = mode === 'login' ? form : { ...form, nombre: form.nombre }
      const res = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body)
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Error de autenticación')
      if (mode === 'register') {
        setMode('login')
        setError('')
        setForm({ email: form.email, password: '' })
        return
      }
      login(data.token, data.usuario)
      navigate('/dashboard')
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '2rem' }}>
      <div className="card" style={{ width: '100%', maxWidth: '420px' }}>
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <div style={{ fontSize: '2.5rem', marginBottom: '0.5rem' }}>⬡</div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700, color: 'var(--accent-hover)' }}>ReservasLab</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>
            {mode === 'login' ? 'Ingresa a tu cuenta' : 'Crea una cuenta nueva'}
          </p>
        </div>

        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          {mode === 'register' && (
            <div>
              <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', display: 'block', marginBottom: '0.4rem' }}>Nombre</label>
              <input
                type="text" placeholder="Tu nombre" required
                value={form.nombre || ''}
                onChange={e => setForm({ ...form, nombre: e.target.value })}
              />
            </div>
          )}
          <div>
            <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', display: 'block', marginBottom: '0.4rem' }}>Email</label>
            <input
              type="email" placeholder="correo@ejemplo.com" required
              value={form.email}
              onChange={e => setForm({ ...form, email: e.target.value })}
            />
          </div>
          <div>
            <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', display: 'block', marginBottom: '0.4rem' }}>Contraseña</label>
            <input
              type="password" placeholder="••••••••" required
              value={form.password}
              onChange={e => setForm({ ...form, password: e.target.value })}
            />
          </div>
          {error && <div className="error-msg">{error}</div>}
          <button type="submit" className="btn-primary" disabled={loading} style={{ marginTop: '0.5rem', padding: '0.75rem' }}>
            {loading ? <div className="spinner" /> : mode === 'login' ? 'Iniciar sesión' : 'Registrarse'}
          </button>
        </form>

        <p style={{ textAlign: 'center', marginTop: '1.5rem', fontSize: '0.875rem', color: 'var(--text-muted)' }}>
          {mode === 'login' ? '¿No tienes cuenta?' : '¿Ya tienes cuenta?'}{' '}
          <span
            onClick={() => { setMode(mode === 'login' ? 'register' : 'login'); setError('') }}
            style={{ color: 'var(--accent-hover)', cursor: 'pointer', fontWeight: 600 }}
          >
            {mode === 'login' ? 'Regístrate' : 'Inicia sesión'}
          </span>
        </p>
      </div>
    </div>
  )
}
LOGIN

# Página Dashboard
cat > src/pages/Dashboard.jsx <<'DASHBOARD'
import { useState, useEffect } from 'react'
import { useAuth } from '../context/AuthContext'
import { useApi } from '../hooks/useApi'

function StatCard({ label, value, icon, color }) {
  return (
    <div className="card" style={{ textAlign: 'center' }}>
      <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>{icon}</div>
      <div style={{ fontSize: '2rem', fontWeight: 700, color }}>{value}</div>
      <div style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.25rem' }}>{label}</div>
    </div>
  )
}

export default function Dashboard() {
  const { user } = useAuth()
  const api = useApi()
  const [stats, setStats] = useState({ recursos: 0, disponibles: 0, reservas: 0 })
  const [loading, setLoading] = useState(true)
  const [health, setHealth] = useState(null)

  useEffect(() => {
    const load = async () => {
      try {
        const [recursos, reservas, healthData] = await Promise.all([
          api.get('/recursos'),
          api.get('/reservas'),
          fetch('/api/v1/health').then(r => r.json())
        ])
        setStats({
          recursos: recursos.data?.length || 0,
          disponibles: recursos.data?.filter(r => r.estado === 'disponible').length || 0,
          reservas: reservas.data?.length || 0
        })
        setHealth(healthData)
      } catch {}
      setLoading(false)
    }
    load()
  }, [])

  if (loading) return <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}><div className="spinner" style={{ width: 40, height: 40 }} /></div>

  return (
    <div style={{ padding: '2rem', maxWidth: '1100px', margin: '0 auto' }}>
      <div style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '1.5rem', fontWeight: 700 }}>Bienvenido, {user?.nombre} 👋</h1>
        <p style={{ color: 'var(--text-muted)', marginTop: '0.25rem', fontSize: '0.875rem' }}>
          Aquí tienes un resumen de la plataforma
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
        <StatCard label="Total Recursos" value={stats.recursos} icon="🗂️" color="var(--accent-hover)" />
        <StatCard label="Disponibles" value={stats.disponibles} icon="✅" color="var(--success)" />
        <StatCard label="Mis Reservas" value={stats.reservas} icon="📅" color="var(--warning)" />
        <StatCard
          label="API Status"
          value={health?.status === 'healthy' ? 'Online' : 'Error'}
          icon={health?.status === 'healthy' ? '🟢' : '🔴'}
          color={health?.status === 'healthy' ? 'var(--success)' : 'var(--danger)'}
        />
      </div>

      {health && (
        <div className="card">
          <h2 style={{ fontSize: '1rem', fontWeight: 600, marginBottom: '1rem' }}>Estado del Sistema</h2>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.75rem' }}>
            {[
              { label: 'API', value: health.status, ok: health.status === 'healthy' },
              { label: 'Base de datos', value: health.database, ok: health.database === 'ok' },
              { label: 'Servicio', value: health.service, ok: true },
            ].map(item => (
              <div key={item.label} style={{ padding: '0.75rem 1rem', background: 'var(--bg-input)', borderRadius: '8px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <span style={{ fontSize: '0.875rem', color: 'var(--text-muted)' }}>{item.label}</span>
                <span className={`badge ${item.ok ? 'badge-green' : 'badge-red'}`}>{item.value}</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
DASHBOARD

# Página Recursos
cat > src/pages/Recursos.jsx <<'RECURSOS'
import { useState, useEffect } from 'react'
import { useApi } from '../hooks/useApi'

const TIPOS = ['sala', 'equipo', 'laboratorio', 'auditorio', 'otro']
const ESTADOS = ['disponible', 'mantenimiento', 'ocupado']

function badgeClass(estado) {
  return estado === 'disponible' ? 'badge-green' : estado === 'mantenimiento' ? 'badge-yellow' : 'badge-red'
}

export default function Recursos() {
  const api = useApi()
  const [recursos, setRecursos] = useState([])
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ nombre: '', tipo: 'sala', estado: 'disponible' })
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)
  const [filtro, setFiltro] = useState('todos')

  const load = async () => {
    const data = await api.get('/recursos')
    setRecursos(data.data || [])
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const handleSubmit = async (e) => {
    e.preventDefault(); setSaving(true); setError('')
    const res = await api.post('/recursos', form)
    if (res.error) { setError(res.error); setSaving(false); return }
    setShowForm(false)
    setForm({ nombre: '', tipo: 'sala', estado: 'disponible' })
    load()
    setSaving(false)
  }

  const handleDelete = async (id) => {
    if (!confirm('¿Eliminar este recurso?')) return
    await api.del(`/recursos/${id}`)
    load()
  }

  const filtrados = filtro === 'todos' ? recursos : recursos.filter(r => r.estado === filtro)

  if (loading) return <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}><div className="spinner" style={{ width: 40, height: 40 }} /></div>

  return (
    <div style={{ padding: '2rem', maxWidth: '1100px', margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700 }}>Recursos</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.2rem' }}>{recursos.length} recursos registrados</p>
        </div>
        <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', alignItems: 'center' }}>
          <select value={filtro} onChange={e => setFiltro(e.target.value)} style={{ width: 'auto' }}>
            <option value="todos">Todos</option>
            {ESTADOS.map(e => <option key={e} value={e}>{e}</option>)}
          </select>
          <button className="btn-primary" onClick={() => setShowForm(!showForm)}>
            {showForm ? 'Cancelar' : '+ Nuevo recurso'}
          </button>
        </div>
      </div>

      {showForm && (
        <div className="card" style={{ marginBottom: '1.5rem' }}>
          <h3 style={{ fontWeight: 600, marginBottom: '1rem' }}>Nuevo Recurso</h3>
          <form onSubmit={handleSubmit} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem' }}>
            <div>
              <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', display: 'block', marginBottom: '0.4rem' }}>Nombre</label>
              <input type="text" placeholder="Sala A-101" required value={form.nombre} onChange={e => setForm({ ...form, nombre: e.target.value })} />
            </div>
            <div>
              <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', display: 'block', marginBottom: '0.4rem' }}>Tipo</label>
              <select value={form.tipo} onChange={e => setForm({ ...form, tipo: e.target.value })}>
                {TIPOS.map(t => <option key={t} value={t}>{t}</option>)}
              </select>
            </div>
            <div>
              <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', display: 'block', marginBottom: '0.4rem' }}>Estado</label>
              <select value={form.estado} onChange={e => setForm({ ...form, estado: e.target.value })}>
                {ESTADOS.map(s => <option key={s} value={s}>{s}</option>)}
              </select>
            </div>
            <div style={{ display: 'flex', alignItems: 'flex-end' }}>
              <button type="submit" className="btn-primary" disabled={saving} style={{ width: '100%' }}>
                {saving ? <div className="spinner" /> : 'Crear recurso'}
              </button>
            </div>
          </form>
          {error && <div className="error-msg" style={{ marginTop: '1rem' }}>{error}</div>}
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '1rem' }}>
        {filtrados.length === 0 && (
          <div style={{ gridColumn: '1/-1', textAlign: 'center', padding: '3rem', color: 'var(--text-muted)' }}>
            No hay recursos {filtro !== 'todos' ? `con estado "${filtro}"` : 'registrados'}
          </div>
        )}
        {filtrados.map(r => (
          <div key={r.id_recurso} className="card" style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <div style={{ fontWeight: 600 }}>{r.nombre}</div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)', marginTop: '0.2rem' }}>{r.tipo}</div>
              </div>
              <span className={`badge ${badgeClass(r.estado)}`}>{r.estado}</span>
            </div>
            <div style={{ display: 'flex', gap: '0.5rem', marginTop: 'auto' }}>
              <button className="btn-danger" style={{ flex: 1, padding: '0.5rem' }} onClick={() => handleDelete(r.id_recurso)}>
                Eliminar
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
RECURSOS

# Página Reservas
cat > src/pages/Reservas.jsx <<'RESERVAS'
import { useState, useEffect } from 'react'
import { useApi } from '../hooks/useApi'

function badgeClass(estado) {
  return estado === 'confirmada' ? 'badge-green' : estado === 'cancelada' ? 'badge-red' : 'badge-yellow'
}

export default function Reservas() {
  const api = useApi()
  const [reservas, setReservas] = useState([])
  const [recursos, setRecursos] = useState([])
  const [loading, setLoading] = useState(true)
  const [showForm, setShowForm] = useState(false)
  const [form, setForm] = useState({ id_recurso: '', fecha_inicio: '', fecha_fin: '' })
  const [error, setError] = useState('')
  const [saving, setSaving] = useState(false)

  const load = async () => {
    const [resData, recData] = await Promise.all([api.get('/reservas'), api.get('/recursos')])
    setReservas(resData.data || [])
    setRecursos((recData.data || []).filter(r => r.estado === 'disponible'))
    setLoading(false)
  }

  useEffect(() => { load() }, [])

  const handleSubmit = async (e) => {
    e.preventDefault(); setSaving(true); setError('')
    const body = {
      id_recurso: parseInt(form.id_recurso),
      fecha_inicio: new Date(form.fecha_inicio).toISOString(),
      fecha_fin: new Date(form.fecha_fin).toISOString()
    }
    const res = await api.post('/reservas', body)
    if (res.error) { setError(res.error); setSaving(false); return }
    setShowForm(false)
    setForm({ id_recurso: '', fecha_inicio: '', fecha_fin: '' })
    load(); setSaving(false)
  }

  const handleCancel = async (id) => {
    if (!confirm('¿Cancelar esta reserva?')) return
    await api.del(`/reservas/${id}`)
    load()
  }

  const fmt = (iso) => new Date(iso).toLocaleString('es-CO', { dateStyle: 'medium', timeStyle: 'short' })

  if (loading) return <div style={{ display: 'flex', justifyContent: 'center', padding: '4rem' }}><div className="spinner" style={{ width: 40, height: 40 }} /></div>

  return (
    <div style={{ padding: '2rem', maxWidth: '1100px', margin: '0 auto' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.5rem', flexWrap: 'wrap', gap: '1rem' }}>
        <div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 700 }}>Mis Reservas</h1>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.875rem', marginTop: '0.2rem' }}>{reservas.length} reservas en total</p>
        </div>
        <button className="btn-primary" onClick={() => setShowForm(!showForm)}>
          {showForm ? 'Cancelar' : '+ Nueva reserva'}
        </button>
      </div>

      {showForm && (
        <div className="card" style={{ marginBottom: '1.5rem' }}>
          <h3 style={{ fontWeight: 600, marginBottom: '1rem' }}>Nueva Reserva</h3>
          <form onSubmit={handleSubmit} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '1rem' }}>
            <div>
              <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', display: 'block', marginBottom: '0.4rem' }}>Recurso</label>
              <select required value={form.id_recurso} onChange={e => setForm({ ...form, id_recurso: e.target.value })}>
                <option value="">Selecciona un recurso</option>
                {recursos.map(r => <option key={r.id_recurso} value={r.id_recurso}>{r.nombre} ({r.tipo})</option>)}
              </select>
            </div>
            <div>
              <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', display: 'block', marginBottom: '0.4rem' }}>Fecha inicio</label>
              <input type="datetime-local" required value={form.fecha_inicio} onChange={e => setForm({ ...form, fecha_inicio: e.target.value })} />
            </div>
            <div>
              <label style={{ fontSize: '0.8rem', color: 'var(--text-muted)', display: 'block', marginBottom: '0.4rem' }}>Fecha fin</label>
              <input type="datetime-local" required value={form.fecha_fin} onChange={e => setForm({ ...form, fecha_fin: e.target.value })} />
            </div>
            <div style={{ display: 'flex', alignItems: 'flex-end' }}>
              <button type="submit" className="btn-primary" disabled={saving} style={{ width: '100%' }}>
                {saving ? <div className="spinner" /> : 'Reservar'}
              </button>
            </div>
          </form>
          {error && <div className="error-msg" style={{ marginTop: '1rem' }}>{error}</div>}
        </div>
      )}

      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
        {reservas.length === 0 && (
          <div className="card" style={{ textAlign: 'center', padding: '3rem', color: 'var(--text-muted)' }}>
            No tienes reservas aún
          </div>
        )}
        {reservas.map(r => (
          <div key={r.id_reserva} className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '1rem' }}>
            <div style={{ display: 'flex', gap: '2rem', flexWrap: 'wrap' }}>
              <div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Recurso</div>
                <div style={{ fontWeight: 600 }}>#{r.id_recurso}</div>
              </div>
              <div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Inicio</div>
                <div style={{ fontSize: '0.875rem' }}>{fmt(r.fecha_inicio)}</div>
              </div>
              <div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Fin</div>
                <div style={{ fontSize: '0.875rem' }}>{fmt(r.fecha_fin)}</div>
              </div>
              <div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>Estado</div>
                <span className={`badge ${badgeClass(r.estado_reserva)}`}>{r.estado_reserva}</span>
              </div>
            </div>
            {r.estado_reserva === 'confirmada' && (
              <button className="btn-danger" style={{ padding: '0.4rem 0.9rem' }} onClick={() => handleCancel(r.id_reserva)}>
                Cancelar
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
RESERVAS

# main.jsx y App.jsx
cat > src/main.jsx <<'MAIN_JSX'
import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </React.StrictMode>
)
MAIN_JSX

cat > src/App.jsx <<'APP_JSX'
import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './context/AuthContext'
import Navbar from './components/Navbar'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import Recursos from './pages/Recursos'
import Reservas from './pages/Reservas'

function PrivateRoute({ children }) {
  const { isAuth } = useAuth()
  return isAuth ? children : <Navigate to="/login" />
}

export default function App() {
  return (
    <>
      <Navbar />
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/dashboard" element={<PrivateRoute><Dashboard /></PrivateRoute>} />
        <Route path="/recursos" element={<PrivateRoute><Recursos /></PrivateRoute>} />
        <Route path="/reservas" element={<PrivateRoute><Reservas /></PrivateRoute>} />
        <Route path="/" element={<Navigate to="/dashboard" />} />
      </Routes>
    </>
  )
}
APP_JSX

echo "  OK: código fuente escrito"

# ─── 5. Build de producción ───────────────────────────────────────────────────
echo "[5/6] Compilando build de producción..."
npm run build
echo "  OK: build generado en /app/frontend/dist"

# ─── 6. Servicio con vite preview ─────────────────────────────────────────────
echo "[6/6] Creando servicio systemd..."
cat > /etc/systemd/system/reservas-frontend.service <<'SYSTEMD'
[Unit]
Description=Reservas Frontend - React + Vite
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/app/frontend
ExecStart=/usr/bin/npm run preview
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable reservas-frontend
systemctl start reservas-frontend
sleep 2
echo "  Status: $(systemctl is-active reservas-frontend)"

FRONTEND

echo ""
echo "=========================================="
echo "  ✅ FRONTEND CONFIGURADO"
echo "=========================================="
echo ""
echo "  Frontend: http://10.100.0.4:5173"
echo "  (core tiene IP 10.100.0.4)"
echo ""
echo "  Para verificar:"
echo "    sudo incus exec core -- curl -s -o /dev/null -w '%{http_code}' http://localhost:5173"
echo ""
