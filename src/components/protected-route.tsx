import { Navigate, Outlet } from 'react-router-dom'
import type { UserRole } from '@/types/database'
import { useAuth, dashboardFor } from '@/contexts/auth-context'
export function ProtectedRoute({ roles }: { roles?: UserRole[] }) { const { user, profile, loading } = useAuth(); if (loading) return <div className="grid min-h-screen place-items-center text-sm text-muted-foreground">Carregando...</div>; if (!user) return <Navigate to="/login" replace />; if (!profile) return <Navigate to="/choose-role" replace />; if (roles && !roles.includes(profile.role)) return <Navigate to={dashboardFor(profile.role)} replace />; return <Outlet /> }
