# Deploy do beta

## Front-end na Vercel

1. Importe este repositório na Vercel.
2. Use `npm run build` como comando e `dist` como diretório de saída.
3. Adicione `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` nas variáveis de ambiente.
4. Faça o deploy. O arquivo `vercel.json` mantém as rotas do React funcionando após recarregar a página.

## Supabase

1. Vincule o projeto pelo Supabase CLI.
2. Aplique migrations e publique as funções:

```sh
supabase db push
supabase functions deploy create-booking
supabase functions deploy admin-moderate
```

3. Em Authentication > URL Configuration, adicione as URLs da Vercel em Site URL e Redirect URLs.
4. Nunca use a Service Role Key no front-end; somente a chave anônima deve estar em `VITE_*`.
