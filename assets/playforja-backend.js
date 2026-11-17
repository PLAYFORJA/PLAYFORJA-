/* PLAYFORJA — conexión segura con Supabase.
   Solo usa la publishable key del proyecto; nunca incluir service_role aquí. */
(() => {
  "use strict";
  const CONFIG = {
    url: "https://gfxlzvhwidzmpiitkvdg.supabase.co",
    key: "sb_publishable_SUMUY3ZDNDeOL9dPdiahGg_ZbHQk-QD"
  };

  if (!window.supabase?.createClient) {
    console.error("[PLAYFORJA] No se pudo cargar Supabase JS.");
    return;
  }
  if (window.PLAYFORJA?.client) return;

  const client = window.supabase.createClient(CONFIG.url, CONFIG.key, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      flowType: "pkce"
    }
  });

  const result = async (promise) => {
    const { data, error } = await promise;
    if (error) throw error;
    return data;
  };

  const currentUser = async () => {
    const { data, error } = await client.auth.getUser();
    if (error) throw error;
    if (!data.user) throw new Error("Iniciá sesión para continuar.");
    return data.user;
  };

  const api = {
    client,

    async register({ email, password, username, country_code = null }) {
      if (!email || !password || !username) throw new Error("Completá email, contraseña y nombre de usuario.");
      if (String(password).length < 8) throw new Error("La contraseña debe tener al menos 8 caracteres.");
      if (String(username).trim().length < 3 || String(username).trim().length > 24) {
        throw new Error("El nombre de usuario debe tener entre 3 y 24 caracteres.");
      }
      return result(client.auth.signUp({
        email: String(email).trim().toLowerCase(),
        password,
        options: {
          emailRedirectTo: new URL("./", location.href).href,
          data: { username: String(username).trim(), country_code }
        }
      }));
    },

    async login({ email, password }) {
      if (!email || !password) throw new Error("Ingresá tu email y contraseña.");
      return result(client.auth.signInWithPassword({
        email: String(email).trim().toLowerCase(),
        password
      }));
    },

    async logout() {
      return result(client.auth.signOut());
    },

    async getMyData() {
      const user = await currentUser();
      const [profile, wallet] = await Promise.all([
        result(client.from("profiles").select("id,username,country_code,bio,avatar_preset,avatar_path,created_at").eq("id", user.id).single()),
        result(client.from("wallets").select("pf_coins,xp,updated_at").eq("user_id", user.id).single())
      ]);
      return { user, profile, wallet };
    },

    async updateProfile(changes) {
      const user = await currentUser();
      const allowed = ["username", "country_code", "bio", "avatar_preset", "avatar_path"];
      const safe = Object.fromEntries(Object.entries(changes || {}).filter(([key]) => allowed.includes(key)));
      if (!Object.keys(safe).length) throw new Error("No hay cambios válidos para guardar.");
      return result(client.from("profiles").update(safe).eq("id", user.id).select().single());
    },

    async getTournaments(platform = null) {
      let query = client.from("tournaments")
        .select("id,code,title,game,platform,mode,starts_at,capacity,enrolled,xp_reward,status")
        .order("starts_at", { ascending: true, nullsFirst: false });
      if (platform && platform !== "Todos") query = query.eq("platform", platform);
      return result(query);
    },

    async joinTournament(code) {
      await currentUser();
      if (!code) throw new Error("No se indicó el torneo.");
      return result(client.rpc("join_tournament", { p_tournament_code: code }));
    },

    async getMyRegistrations() {
      const user = await currentUser();
      return result(client.from("tournament_registrations")
        .select("id,tournament_id,registered_at")
        .eq("user_id", user.id)
        .order("registered_at", { ascending: false }));
    },

    async getRooms() {
      return result(client.from("game_rooms")
        .select("id,code,title,game,platform,mode,max_players,member_count,status,created_at")
        .in("status", ["open", "full"])
        .order("created_at", { ascending: false })
        .limit(30));
    },

    async createRoom({ title, game, platform, mode, max_players }) {
      await currentUser();
      return result(client.rpc("create_game_room", {
        p_title: title, p_game: game, p_platform: platform,
        p_mode: mode, p_max_players: Number(max_players)
      }));
    },

    async joinRoom(code) {
      await currentUser();
      return result(client.rpc("join_game_room", { p_room_code: code }));
    },

    async getFrames() {
      return result(client.from("frame_catalog")
        .select("code,title,price_pf,active")
        .eq("active", true)
        .order("price_pf", { ascending: true }));
    },

    async redeemFrame(code) {
      await currentUser();
      if (!code) throw new Error("No se indicó el marco.");
      return result(client.rpc("redeem_frame", { p_frame_code: code }));
    },

    async getLeaderboard() {
      return result(client.rpc("get_leaderboard"));
    },

    async getSession() {
      return result(client.auth.getSession());
    },

    onAuthChange(callback) {
      const { data } = client.auth.onAuthStateChange((event, session) => {
        window.dispatchEvent(new CustomEvent("playforja:auth", { detail: { event, session } }));
        if (typeof callback === "function") callback(event, session);
      });
      return () => data.subscription.unsubscribe();
    }
  };

  window.PLAYFORJA = Object.freeze(api);
  window.dispatchEvent(new CustomEvent("playforja:ready", { detail: { version: "1.0.0" } }));
  client.auth.getSession().then(({ data }) => {
    window.dispatchEvent(new CustomEvent("playforja:auth", {
      detail: { event: "INITIAL_SESSION", session: data.session }
    }));
  }).catch(error => console.error("[PLAYFORJA] No se pudo leer la sesión:", error));
})();
