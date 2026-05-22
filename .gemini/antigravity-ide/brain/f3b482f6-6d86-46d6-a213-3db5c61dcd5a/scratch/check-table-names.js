const apikey = "sb_publishable_5GKds9_Su2yTbv9VkLr0UQ_uB60fzO9";
const base = "https://xmqvljirpdxeomxmwudr.supabase.co/rest/v1";

const tables = ["sistemaConfiguracao", "sistema_configuracao", "sistemaconfiguracao", "configuracao"];

async function check() {
  for (const table of tables) {
    const url = `${base}/${table}?select=*&limit=1`;
    try {
      const res = await fetch(url, {
        headers: {
          "apikey": apikey,
          "Authorization": `Bearer ${apikey}`
        }
      });
      console.log(`Table: ${table} -> Status: ${res.status}`);
      if (res.status === 200) {
        const data = await res.json();
        console.log(`Success! Data length: ${data.length}`);
      } else {
        const err = await res.json();
        console.log("Error details:", err);
      }
    } catch (e) {
      console.log(`Table: ${table} -> Failed: ${e.message}`);
    }
  }
}

check();
