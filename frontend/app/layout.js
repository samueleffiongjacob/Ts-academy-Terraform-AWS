import './globals.css';

export const metadata = {
  title: 'Ts Academy test app',
  description: 'Next.js + Java + MySQL on k3s',
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
