export type UserRole = 'client' | 'professional' | 'admin'
export interface Profile { id: string; full_name: string; phone: string | null; role: UserRole; avatar_url: string | null; created_at: string }
export type PriceType = 'fixed' | 'quote'
export interface Category { id: string; name: string; slug: string; description: string | null; icon: string | null }
export interface Service { id: string; professional_id: string; category_id: string; title: string; description: string | null; base_price: number | null; price_type: PriceType; active: boolean }
export interface Professional { id: string; fullName: string; avatarUrl: string | null; bio: string | null; city: string | null; state: string | null; neighborhood: string | null; radiusKm: number | null; latitude: number | null; longitude: number | null; averageRating: number; reviewCount: number; completedServicesCount: number; specialties: string[]; services: Service[] }
export interface Review { id: string; rating: number; comment: string | null; created_at: string; client: { full_name: string } | null }
export interface Availability { id: string; weekday: number; start_time: string; end_time: string; active: boolean }
export interface ServiceRequest { id: string; client_id: string; category_id: string; title: string; description: string; status: 'open' | 'quoted' | 'booked' | 'completed' | 'cancelled'; created_at: string }
