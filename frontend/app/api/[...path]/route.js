export const dynamic = 'force-dynamic';

const BACKEND = process.env.BACKEND_URL || 'http://backend:8080';

async function proxy(request, { params }) {
  const search = new URL(request.url).search;
  const url = `${BACKEND}/api/${params.path.join('/')}${search}`;

  const init = {
    method: request.method,
    headers: { 'Content-Type': request.headers.get('content-type') || 'application/json' },
    cache: 'no-store',
  };
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    init.body = await request.text();
  }

  try {
    const res = await fetch(url, init);
    return new Response(await res.text(), {
      status: res.status,
      headers: { 'Content-Type': res.headers.get('content-type') || 'application/json' },
    });
  } catch {
    return Response.json({ error: 'backend unreachable' }, { status: 502 });
  }
}

export { proxy as GET, proxy as POST };
