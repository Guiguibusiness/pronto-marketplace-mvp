import { createContext, useContext, useEffect, useState, type ReactNode } from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import type { Profile, UserRole } from '@/types/database'
type AuthContextValue = { session: Session | null; user: User | null; profile: Profile | null; loading: boolean; signOut: () => Promise<void>; refreshProfile: () => Promise<void> }
const AuthContext = createContext<AuthContextValue | undefined>(undefined)
export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null); const [profile, setProfile] = useState<Profile | null>(null); const [loading, setLoading] = useState(true)
  const loadProfile = async (userId?: string) => { if (!userId) { setProfile(null); return }; const { data } = await supabase.from('profiles').select('*').eq('id', userId).maybeSingle(); setProfile(data as Profile | null) }
  useEffect(() => { supabase.auth.getSession().then(({ data: { session } }) => { setSession(session); loadProfile(session?.user.id).finally(() => setLoading(false)) }); const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, next) => { setSession(next); loadProfile(next?.user.id); setLoading(false) }); return () => subscription.unsubscribe() }, [])
  return <AuthContext.Provider value={{ session, user: session?.user ?? null, profile, loading, signOut: () => supabase.auth.signOut(), refreshProfile: () => loadProfile(session?.user.id) }}>{children}</AuthContext.Provider>
}
export function useAuth() { const value = useContext(AuthContext); if (!value) throw new Error('useAuth must be used within AuthProvider'); return value }
export function dashboardFor(role: UserRole) { return role === 'professional' ? '/professional' : role === 'admin' ? '/admin' : '/client' }
