// Example Cloudflare Pages Function.
//
// File-based routing: this file lives at functions/api/hello.ts, so it handles
//   GET /api/hello
// Rename/move the file to change the route. Export onRequest (all methods) or a
// method-specific handler like onRequestGet / onRequestPost.
//
// Docs: https://developers.cloudflare.com/pages/functions/

interface Env {
  // Bindings declared in wrangler.toml surface here, e.g.:
  // DB: D1Database;
  // CACHE: KVNamespace;
}

export const onRequestGet: PagesFunction<Env> = async (context) => {
  const { request } = context;
  const url = new URL(request.url);

  return Response.json({
    ok: true,
    product: '__PRODUCT__',
    message: 'Hello from the edge',
    path: url.pathname,
    now: new Date().toISOString(),
  });
};
