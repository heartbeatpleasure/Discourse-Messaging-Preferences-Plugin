import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class AdminPluginsMessagingPreferencesActivityRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.messaging_preferences.activity.title");
  }

  setupController(controller) {
    super.setupController(...arguments);
    controller.resetState?.();
    controller.loadActivity?.();
  }
}
