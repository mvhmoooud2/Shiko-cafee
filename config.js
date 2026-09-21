/* =====================================================================
   إعدادات الربط مع Supabase — ده الملف الوحيد اللي محتاج تعدّله
   =====================================================================
   1) افتح مشروعك على https://supabase.com/dashboard
   2) من Settings → API Keys انسخ:
        - Project URL        →  حطه في SUPABASE_URL
        - Publishable key    →  حطه في SUPABASE_KEY   (بيبدأ بـ sb_publishable_)
          (لو مشروعك قديم ومفيهوش Publishable key، مفتاح anon القديم شغال برضه)
   3) احفظ الملف وارفعه مع باقي الموقع.

   ⚠️ عمرك ما تحط هنا الـ secret key أو service_role — دول للسيرفر بس.
   ===================================================================== */
window.SHIKO_CONFIG = {
  SUPABASE_URL: "https://cbdzfawqxunpnyacdlcr.supabase.co",
  SUPABASE_KEY: "sb_publishable_vk7jLZh110IKOLdQ1DEcRg_WnbskktC",
};
