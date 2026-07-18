export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("messagingPreferencesActivity", {
      path: "/messaging-preferences-activity",
    });
  },
};
