import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import userSearch from "discourse/lib/user-search";
import { i18n } from "discourse-i18n";

const SEARCH_LIMIT = 10;

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

function avatarUrl(user, size = 40) {
  return String(user?.avatar_template || "").replace("{size}", String(size));
}

function decorateSearchUser(user) {
  if (!user?.id || !user?.username) {
    return null;
  }

  return {
    id: user.id,
    username: user.username,
    name: user.name,
    avatarUrl: avatarUrl(user),
  };
}

export default class AdminPluginsMessagingPreferencesActivityController extends Controller {
  @tracked data;
  @tracked isLoading = false;
  @tracked error;
  @tracked query = "";
  @tracked searchResults = [];
  @tracked isSearching = false;
  @tracked searchActiveIndex = -1;

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
          "admin.messaging_preferences.activity.cards.preference_changes_detail"
        ),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.cards.got_it_confirmations"
        ),
        value: formatNumber(this.summary.tracked_acknowledgements),
        detail: i18n(
          "admin.messaging_preferences.activity.cards.got_it_confirmations_detail"
        ),
      },
    ];
  }

  get generatedAtLabel() {
    return formatDateTime(this.data?.generated_at);
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
          "admin.messaging_preferences.activity.user.cards.changes_detail"
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

  get searchExpanded() {
    return this.searchResults.length > 0;
  }

  get searchListboxId() {
    return "messaging-preferences-member-search-results";
  }

  get searchActiveDescendant() {
    return this.searchActiveIndex >= 0
      ? `messaging-preferences-member-search-option-${this.searchActiveIndex}`
      : undefined;
  }

  get showNoSearchResults() {
    return (
      this.query.trim().length >= 2 &&
      !this.isSearching &&
      this.searchResults.length === 0
    );
  }

  get searchStatusMessage() {
    if (this.isSearching) {
      return i18n("admin.messaging_preferences.activity.user.searching");
    }

    if (this.searchResults.length > 0) {
      return i18n(
        "admin.messaging_preferences.activity.user.results_available",
        { count: this.searchResults.length }
      );
    }

    if (this.showNoSearchResults) {
      return i18n("admin.messaging_preferences.activity.user.no_results");
    }

    return "";
  }

  decorateEvent(event) {
    return {
      ...event,
      actorDisplay:
        event.actor?.username ||
        i18n("admin.messaging_preferences.activity.unknown_user"),
      targetDisplay:
        event.target?.username ||
        i18n("admin.messaging_preferences.activity.unknown_user"),
      dateLabel: formatDateTime(event.occurred_at),
    };
  }

  resetState() {
    this.data = null;
    this.isLoading = false;
    this.error = null;
    this.query = "";
    this.searchResults = [];
    this.isSearching = false;
    this.searchActiveIndex = -1;
    this.searchSequence += 1;
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
    this.searchActiveIndex = -1;
    this.searchSequence += 1;

    const term = this.query.trim();
    if (term.length < 2) {
      this.isSearching = false;
      return;
    }

    this.performSearch(term);
  }

  async performSearch(term) {
    const sequence = ++this.searchSequence;
    this.isSearching = true;

    try {
      const result = await userSearch({
        term,
        includeGroups: false,
        includeStagedUsers: false,
        limit: SEARCH_LIMIT,
      });

      if (sequence !== this.searchSequence || this.query.trim() !== term) {
        return;
      }

      const users = Array.isArray(result?.users)
        ? result.users
        : Array.isArray(result)
          ? result.filter((item) => item?.isUser || item?.username)
          : [];

      this.searchResults = users.map(decorateSearchUser).filter(Boolean);
      this.searchActiveIndex = -1;
    } catch {
      if (sequence === this.searchSequence) {
        this.searchResults = [];
        this.searchActiveIndex = -1;
      }
    } finally {
      if (sequence === this.searchSequence) {
        this.isSearching = false;
      }
    }
  }

  setSearchActiveIndex(index) {
    const lastIndex = this.searchResults.length - 1;
    this.searchActiveIndex = Math.max(-1, Math.min(index, lastIndex));
  }

  @action
  handleSearchKeydown(event) {
    const lastIndex = this.searchResults.length - 1;

    if (event.key === "Escape") {
      if (this.searchResults.length > 0) {
        event.preventDefault();
      }
      this.searchSequence += 1;
      this.searchResults = [];
      this.searchActiveIndex = -1;
      this.isSearching = false;
      return;
    }

    if (lastIndex < 0) {
      return;
    }

    if (event.key === "ArrowDown") {
      event.preventDefault();
      this.setSearchActiveIndex(
        this.searchActiveIndex >= lastIndex ? 0 : this.searchActiveIndex + 1
      );
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      this.setSearchActiveIndex(
        this.searchActiveIndex <= 0 ? lastIndex : this.searchActiveIndex - 1
      );
    } else if (event.key === "Home") {
      event.preventDefault();
      this.setSearchActiveIndex(0);
    } else if (event.key === "End") {
      event.preventDefault();
      this.setSearchActiveIndex(lastIndex);
    } else if (event.key === "Enter") {
      const user =
        this.searchResults[
          this.searchActiveIndex >= 0 ? this.searchActiveIndex : 0
        ];
      if (user) {
        event.preventDefault();
        this.selectUser(user);
      }
    }
  }

  @action
  selectUser(user) {
    this.searchSequence += 1;
    this.query = user.username;
    this.searchResults = [];
    this.searchActiveIndex = -1;
    this.isSearching = false;
    return this.loadActivity(user.id);
  }

  @action
  clearSelectedUser() {
    this.searchSequence += 1;
    this.query = "";
    this.searchResults = [];
    this.searchActiveIndex = -1;
    this.isSearching = false;
    return this.loadActivity();
  }
}
