export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("messagingPreferences", { path: "/messaging-preferences" });
  },
};
