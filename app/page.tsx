import AppShell from "@/components/AppShell";
import { getDashboardData } from "@/lib/data";

export const dynamic = "force-dynamic";

export default async function Home() {
  const data = await getDashboardData();
  return <AppShell initialData={data} />;
}
