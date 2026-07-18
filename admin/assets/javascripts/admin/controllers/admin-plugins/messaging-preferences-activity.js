import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

function formatNumber(value) {
  const number = Number(value || 0);
  return Number.isFinite(number) ? new Intl.NumberFormat().format(number) : "0";
}

function formatDateTime(value) {
  if (!value) {
    return i18n("admin.messaging_preferences.activity.not_available");
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return i18n("admin.messaging_preferences.activity.not_available");
  }

  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function statusLabel(current) {
  return current
    ? i18n("admin.messaging_preferences.activity.current")
    : i18n("admin.messaging_preferences.activity.outdated");
}

function statusClass(current) {
  return current ? "is-current" : "is-outdated";
}

export default class AdminPluginsMessagingPreferencesActivityController extends Controller {
  @tracked data;
  @tracked isLoading = false;
  @tracked error;
  @tracked query = "";
  @tracked searchResults = [];
  @tracked isSearching = false;

  searchTimer = null;
  searchSequence = 0;

  get hasData() {
    return Boolean(this.data?.summary);
  }

  get summary() {
    return this.data?.summary || {};
  }

  get summaryCards() {
    return [
      {
        label: i18n(
          "admin.messaging_preferences.activity.cards.members_with_preferences"
        ),
        value: formatNumber(this.summary.members_with_preferences),
        detail: i18n(
          "admin.messaging_preferences.activity.cards.members_with_preferences_detail",
          {
            both: formatNumber(this.summary.members_with_both_fields),
            worksWell: formatNumber(
              this.summary.members_with_works_well_only
            ),
            pleaseAvoid: formatNumber(
              this.summary.members_with_please_avoid_only
            ),
          }
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.cards.updated_recently"
        ),
        value: formatNumber(this.summary.members_updated_last_30_days),
        detail: i18n(
          "admin.messaging_preferences.activity.cards.updated_recently_detail"
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.cards.current_acknowledgements"
        ),
        value: formatNumber(this.summary.current_acknowledgements),
        detail: i18n(
          "admin.messaging_preferences.activity.cards.current_acknowledgements_detail",
          {
            total: formatNumber(this.summary.acknowledgement_records),
            outdated: formatNumber(this.summary.outdated_acknowledgements),
          }
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.cards.acknowledging_members"
        ),
        value: formatNumber(this.summary.distinct_acknowledging_members),
        detail: i18n(
          "admin.messaging_preferences.activity.cards.acknowledging_members_detail",
          {
            owners: formatNumber(
              this.summary.distinct_preference_owners_acknowledged
            ),
          }
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.cards.preference_changes"
        ),
        value: formatNumber(this.summary.tracked_preference_changes),
        detail: i18n(
          "admin.messaging_preferences.activity.cards.tracked_since_update"
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.cards.got_it_confirmations"
        ),
        value: formatNumber(this.summary.tracked_acknowledgements),
        detail: i18n(
          "admin.messaging_preferences.activity.cards.tracked_since_update"
        ),
      },
    ];
  }

  get generatedAtLabel() {
    return formatDateTime(this.data?.generated_at);
  }

  get trackingStartedLabel() {
    return this.data?.tracking_started_at
      ? formatDateTime(this.data.tracking_started_at)
      : i18n("admin.messaging_preferences.activity.tracking_not_started");
  }

  get recentEvents() {
    return (this.data?.recent_events || []).map((event) =>
      this.decorateEvent(event)
    );
  }

  get selectedUser() {
    return this.data?.selected_user;
  }

  get selectedUserEvents() {
    return (this.selectedUser?.events || []).map((event) =>
      this.decorateEvent(event)
    );
  }

  get selectedUserCards() {
    const selected = this.selectedUser;
    if (!selected) {
      return [];
    }

    return [
      {
        label: i18n(
          "admin.messaging_preferences.activity.user.cards.preference_status"
        ),
        value: selected.current_preferences?.has_preferences
          ? i18n("admin.messaging_preferences.activity.set")
          : i18n("admin.messaging_preferences.activity.not_set"),
        detail: i18n(
          "admin.messaging_preferences.activity.user.cards.preference_status_detail",
          {
            worksWell: selected.current_preferences?.works_well_set
              ? i18n("admin.messaging_preferences.activity.set")
              : i18n("admin.messaging_preferences.activity.not_set"),
            pleaseAvoid: selected.current_preferences?.please_avoid_set
              ? i18n("admin.messaging_preferences.activity.set")
              : i18n("admin.messaging_preferences.activity.not_set"),
          }
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.user.cards.last_modified"
        ),
        value: formatDateTime(selected.current_preferences?.updated_at),
        detail: i18n(
          "admin.messaging_preferences.activity.user.cards.last_modified_detail"
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.user.cards.changes"
        ),
        value: formatNumber(selected.counts?.tracked_preference_changes),
        detail: i18n(
          "admin.messaging_preferences.activity.cards.tracked_since_update"
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.user.cards.current_received"
        ),
        value: formatNumber(
          selected.counts?.current_acknowledgements_received
        ),
        detail: i18n(
          "admin.messaging_preferences.activity.user.cards.current_received_detail",
          {
            tracked: formatNumber(
              selected.counts?.tracked_acknowledgements_received
            ),
          }
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.user.cards.current_made"
        ),
        value: formatNumber(
          selected.counts?.current_acknowledgements_made
        ),
        detail: i18n(
          "admin.messaging_preferences.activity.user.cards.current_made_detail",
          {
            tracked: formatNumber(
              selected.counts?.tracked_acknowledgements_made
            ),
          }
        ),
      },
    ];
  }

  get acknowledgementsReceived() {
    return (this.selectedUser?.acknowledgements_received || []).map((item) => ({
      ...item,
      dateLabel: formatDateTime(item.acknowledged_at),
      statusLabel: statusLabel(item.current),
      statusClass: statusClass(item.current),
    }));
  }

  get acknowledgementsMade() {
    return (this.selectedUser?.acknowledgements_made || []).map((item) => ({
      ...item,
      dateLabel: formatDateTime(item.acknowledged_at),
      statusLabel: statusLabel(item.current),
      statusClass: statusClass(item.current),
    }));
  }

  decorateEvent(event) {
    const actor = event.actor?.username || i18n("admin.messaging_preferences.activity.unknown_user");
    const target = event.target?.username || i18n("admin.messaging_preferences.activity.unknown_user");

    return {
      ...event,
      dateLabel: formatDateTime(event.occurred_at),
      label: i18n(
        `admin.messaging_preferences.activity.events.${event.event_type}`,
        { actor, target }
      ),
    };
  }

  resetState() {
    this.data = null;
    this.isLoading = false;
    this.error = null;
    this.query = "";
    this.searchResults = [];
    this.isSearching = false;
    this.searchSequence += 1;

    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
      this.searchTimer = null;
    }
  }

  @action
  async loadActivity(userId = null) {
    this.isLoading = true;
    this.error = null;

    try {
      this.data = await ajax(
        getURL("/admin/plugins/messaging-preferences/activity"),
        {
          cache: false,
          data: userId ? { user_id: userId } : {},
        }
      );
    } catch {
      this.error = i18n(
        "admin.messaging_preferences.activity.load_error"
      );
    } finally {
      this.isLoading = false;
    }
  }

  @action
  refresh() {
    return this.loadActivity(this.selectedUser?.user?.id);
  }

  @action
  updateQuery(event) {
    this.query = event.target.value;
    this.searchResults = [];

    if (this.searchTimer) {
      clearTimeout(this.searchTimer);
    }

    const term = this.query.trim();
    if (term.length < 2) {
      this.isSearching = false;
      return;
    }

    this.searchTimer = setTimeout(() => this.performSearch(term), 250);
  }

  async performSearch(term) {
    const sequence = ++this.searchSequence;
    this.isSearching = true;

    try {
      const response = await ajax(
        getURL("/admin/plugins/messaging-preferences/user-search"),
        { cache: false, data: { term } }
      );

      if (sequence === this.searchSequence) {
        this.searchResults = response?.users || [];
      }
    } catch {
      if (sequence === this.searchSequence) {
        this.searchResults = [];
      }
    } finally {
      if (sequence === this.searchSequence) {
        this.isSearching = false;
      }
    }
  }

  @action
  selectUser(user) {
    this.searchSequence += 1;
    this.query = user.username;
    this.searchResults = [];
    return this.loadActivity(user.id);
  }

  @action
  clearSelectedUser() {
    this.searchSequence += 1;
    this.query = "";
    this.searchResults = [];
    return this.loadActivity();
  }
}
