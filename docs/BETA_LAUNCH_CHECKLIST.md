# Checklist de lançamento beta

## Configuração técnica

- [ ] Instalar Node.js 20 LTS ou superior.
- [ ] Executar `npm install` e `npm run build` sem erros.
- [ ] Criar `.env.local` a partir de `.env.example`.
- [ ] Criar o projeto Supabase e aplicar as migrations em ordem (`00000` a `00003`).
- [ ] Executar `supabase/seed.sql` e cadastrar pelo menos um profissional real de teste.
- [ ] Criar bucket/políticas via migrations e validar upload de avatar, galeria e fotos de pedido.
- [ ] Publicar `create-booking` e `admin-moderate` pelo Supabase CLI.
- [ ] Configurar no Supabase Auth as URLs do ambiente beta para login, confirmação e recuperação de senha.

## Testes por papel

- [ ] Cliente cria conta, recupera senha e edita o próprio perfil.
- [ ] Cliente busca por "eletricista", filtra e abre um perfil profissional.
- [ ] Cliente solicita serviço por orçamento, anexa foto e escolhe uma proposta.
- [ ] Cliente agenda serviço de preço fixo e recebe confirmação.
- [ ] Profissional configura perfil, serviço, preço e disponibilidade.
- [ ] Profissional envia orçamento, aceita/recusa preço fixo e conclui o agendamento.
- [ ] Cliente avalia somente um serviço concluído.
- [ ] Administrador visualiza métricas, bloqueia/desbloqueia usuário e modera conteúdo.
- [ ] Contas diferentes não leem ou alteram pedidos, propostas, agendamentos e arquivos privados de terceiros.

## Operação do beta

- [ ] Definir grupo fechado de clientes e profissionais, cidade e categorias iniciais.
- [ ] Definir canal de suporte e responsável por moderar perfis/serviços.
- [ ] Implantar em Vercel ou Netlify usando as variáveis `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY`.
- [ ] Acompanhar logs do Supabase, limites de Storage e erros do navegador diariamente.
- [ ] Fazer backup lógico do banco antes de qualquer alteração estrutural.
- [ ] Registrar feedback dos usuários-piloto e priorizar correções antes de abrir o cadastro.
