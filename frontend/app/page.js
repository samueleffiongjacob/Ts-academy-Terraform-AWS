'use client';

import { useCallback, useEffect, useState } from 'react';

export default function Home() {
  const [health, setHealth] = useState(null);
  const [healthError, setHealthError] = useState(false);
  const [messages, setMessages] = useState([]);
  const [content, setContent] = useState('');

  const loadHealth = useCallback(async () => {
    try {
      const res = await fetch('/api/health', { cache: 'no-store' });
      if (!res.ok) throw new Error('bad status');
      setHealth(await res.json());
      setHealthError(false);
    } catch {
      setHealthError(true);
    }
  }, []);

  const loadMessages = useCallback(async () => {
    try {
      const res = await fetch('/api/messages', { cache: 'no-store' });
      if (res.ok) setMessages(await res.json());
    } catch {
      /* backend not ready yet */
    }
  }, []);

  useEffect(() => {
    loadHealth();
    loadMessages();
  }, [loadHealth, loadMessages]);

  async function submit(e) {
    e.preventDefault();
    await fetch('/api/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ content }),
    });
    setContent('');
    loadMessages();
  }

  return (
    <main>
      <h1>Ts Academy test app</h1>
      <p>Next.js frontend, Java backend, MySQL database, running on k3s.</p>

      <div className={`status ${healthError ? 'bad' : health ? 'ok' : ''}`}>
        {healthError && 'Backend unreachable'}
        {!healthError && !health && 'Checking backend...'}
        {health &&
          `Backend: ${health.status} | database: ${health.database} | served by pod: ${health.pod}`}
      </div>

      <form onSubmit={submit}>
        <input
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="Write a message"
          maxLength={255}
          required
        />
        <button type="submit">Save to database</button>
      </form>

      <h3>Messages (stored in RDS MySQL)</h3>
      <ul>
        {messages.map((m) => (
          <li key={m.id}>
            {m.content} <small>(#{m.id}, {m.created_at})</small>
          </li>
        ))}
      </ul>
    </main>
  );
}
