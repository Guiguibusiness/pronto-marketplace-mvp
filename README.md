# Pronto — Marketplace de serviços presenciais

Base do MVP para conectar clientes e profissionais locais. A interface foi construída com React, TypeScript, Tailwind CSS e componentes compatíveis com shadcn/ui; a camada de dados usa Supabase (PostgreSQL, Auth, Storage e Edge Functions).

## Começar

1. Crie um projeto no Supabase.
2. Execute a migration em `supabase/migrations/20260919000000_initial_schema.sql` pelo SQL Editor ou Supabase CLI.
3. Copie `.env.example` para `.env.local` e preencha a URL e a chave anônima do projeto.
4. Instale dependências com `npm install` e rode `npm run dev`.

Para preparar o beta, consulte [o checklist de lançamento](docs/BETA_LAUNCH_CHECKLIST.md) e o [guia de deploy](docs/DEPLOY.md). O arquivo `supabase/seed.sql` inclui categorias iniciais e exemplos comentados de profissionais e serviços de demonstração.

Para tornar uma conta administradora, faça isso apenas pelo SQL Editor com privilégio administrativo:

```sql
update public.profiles set role = 'admin' where id = '<auth-user-id>';
```

## Estrutura

- `src/pages`: landing, autenticação e painéis iniciais por papel.
- `src/components/ui`: primitives no padrão shadcn/ui.
- `src/contexts/auth-context.tsx`: sessão, perfil e acesso por papel.
- `supabase/migrations`: schema, gatilhos, índices, RLS e políticas de Storage.
- `supabase/functions/create-booking`: exemplo de Edge Function com autenticação e validação de participante.

## Descoberta de serviços

As rotas públicas `/categories`, `/search` e `/professionals/:id` compõem o núcleo de descoberta. A pesquisa consulta serviços ativos por texto, categoria, cidade, preço e avaliação, com paginação. O mapa usa tiles do OpenStreetMap via Leaflet; para posicionar profissionais, preencha `latitude` e `longitude` no `professional_profiles`.

Execute também a migration `20260919000001_discovery.sql`, que adiciona tipo de preço (`fixed` ou `quote`), localização por bairro, coordenadas, quantidade de serviços concluídos e a galeria de fotos profissional.

## Fluxo de contratação

Execute a migration `20260919000002_hiring_flow.sql`. Ela adiciona fotos de solicitações e os estados `pending`, `quoting`, `accepted`, `scheduled`, `in_progress`, `completed` e `cancelled`, além das funções transacionais para enviar/aceitar propostas, responder solicitações de preço fixo e alterar o andamento de agendamentos. Os controles de status não ficam expostos como updates diretos do navegador.

## Administração e Fase 2

Execute `20260919000003_admin_and_phase2.sql` por último. Ela adiciona bloqueio de usuários, moderação, métricas de GMV/ticket médio e permissões administrativas específicas. Os campos reservados para comissão, pagamento, reembolso e verificação são apenas preparação de schema: nenhum desses recursos está ativo no MVP.

## Segurança

O banco usa `auth.users` como origem de identidade e cria `profiles` automaticamente após o cadastro. As políticas RLS limitam criação e gestão de dados ao titular/participante, com exceção de administradores. O papel `admin` não é aceito dos metadados de cadastro; ele deve ser promovido de forma privilegiada.
