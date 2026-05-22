const url = "https://xmqvljirpdxeomxmwudr.supabase.co/rest/v1/";
const apikey = "sb_publishable_5GKds9_Su2yTbv9VkLr0UQ_uB60fzO9";

fetch(url, {
  method: "GET",
  headers: {
    "apikey": apikey,
    "Authorization": `Bearer ${apikey}`
  }
})
.then(async res => {
  const text = await res.text();
  console.log("Status:", res.status);
  console.log("Response text sample:", text.substring(0, 1000));
})
.catch(err => {
  console.error(err);
});
