import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { userPath } from "discourse/lib/url";

export default class MessagingPreferencesUserLink extends Component {
  @service appEvents;

  get username() {
    return this.args.user?.username;
  }

  get href() {
    return this.username ? userPath(this.username.toLowerCase()) : null;
  }

  @action
  openUserCard(event) {
    if (!this.username || !event) {
      return;
    }

    if (
      (event.button && event.button !== 0) ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    ) {
      return;
    }

    const target = event.currentTarget;
    if (!target || !this.appEvents?.trigger) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    this.appEvents.trigger(
      "topic-header:trigger-user-card",
      this.username,
      target,
      event
    );
  }

  <template>
    {{#if this.username}}
      <a
        href={{this.href}}
        class="trigger-user-card mp-activity__user-link"
        data-user-card={{this.username}}
        {{on "click" this.openUserCard}}
      >
        {{yield}}
      </a>
    {{else}}
      <span class="mp-activity__unknown-user">{{yield}}</span>
    {{/if}}
  </template>
}
