import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import userSearch from "discourse/lib/user-search";
import { i18n } from "discourse-i18n";

const SEARCH_LIMIT = 10;
const DEFAULT_PERIOD = "30";
const DEFAULT_EVENT_FILTER = "all";

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
  @service dialog;
  @service toasts;

  @tracked data;
  @tracked isLoading = false;
  @tracked error;
  @tracked query = "";
  @tracked searchResults = [];
  @tracked isSearching = false;
  @tracked isMaintaining = false;
  @tracked searchActiveIndex = -1;
  @tracked period = DEFAULT_PERIOD;
  @tracked eventFilter = DEFAULT_EVENT_FILTER;
  @tracked eventPage = 1;
  @tracked userEventPage = 1;

  searchSequence = 0;
  loadSequence = 0;

  get hasData() {
    return Boolean(this.data?.summary);
  }

  get summary() {
    return this.data?.summary || {};
  }

  get trend() {
    return this.data?.trend || {};
  }

  get maintenance() {
    return this.data?.maintenance || {};
  }

  get selectedMaintenance() {
    return this.maintenance.selected_user || {};
  }

  get periodOptions() {
    return [
      {
        value: "7",
        label: i18n("admin.messaging_preferences.activity.filters.period_7"),
      },
      {
        value: "30",
        label: i18n("admin.messaging_preferences.activity.filters.period_30"),
      },
      {
        value: "90",
        label: i18n("admin.messaging_preferences.activity.filters.period_90"),
      },
      {
        value: "all",
        label: i18n("admin.messaging_preferences.activity.filters.period_all"),
      },
    ];
  }

  get eventFilterOptions() {
    return [
      {
        value: "all",
        label: i18n("admin.messaging_preferences.activity.filters.type_all"),
      },
      {
        value: "preference_changes",
        label: i18n(
          "admin.messaging_preferences.activity.filters.type_preference_changes"
        ),
      },
      {
        value: "acknowledgements",
        label: i18n(
          "admin.messaging_preferences.activity.filters.type_acknowledgements"
        ),
      },
    ];
  }

  get retentionLabel() {
    if (this.maintenance.retention_unlimited) {
      return i18n(
        "admin.messaging_preferences.activity.maintenance.retention_unlimited"
      );
    }

    return i18n(
      "admin.messaging_preferences.activity.maintenance.retention_days",
      { days: formatNumber(this.maintenance.retention_days) }
    );
  }

  get retainedEventsLabel() {
    return i18n(
      "admin.messaging_preferences.activity.maintenance.retained_events",
      { count: formatNumber(this.maintenance.event_records) }
    );
  }

  get expiredEventsLabel() {
    return i18n(
      "admin.messaging_preferences.activity.maintenance.expired_events",
      { count: formatNumber(this.maintenance.expired_event_records) }
    );
  }

  get integrityLabel() {
    const orphanCount =
      Number(this.maintenance.orphaned_acknowledgement_records || 0) +
      Number(this.maintenance.orphaned_event_records || 0);

    return i18n(
      "admin.messaging_preferences.activity.maintenance.integrity_detail",
      {
        duplicates: formatNumber(
          this.maintenance.duplicate_custom_field_records
        ),
        blank: formatNumber(this.maintenance.blank_custom_field_records),
        invalidAcks: formatNumber(
          this.maintenance.invalid_acknowledgement_records
        ),
        orphans: formatNumber(orphanCount),
      }
    );
  }

  get allAcknowledgementsLabel() {
    return i18n(
      "admin.messaging_preferences.activity.maintenance.acknowledgements_detail",
      { count: formatNumber(this.maintenance.acknowledgement_records) }
    );
  }

  get allHistoryLabel() {
    return i18n(
      "admin.messaging_preferences.activity.maintenance.history_detail",
      { count: formatNumber(this.maintenance.event_records) }
    );
  }

  get selectedMemberAcknowledgementsLabel() {
    return i18n(
      "admin.messaging_preferences.activity.maintenance.member_acknowledgements",
      {
        count: formatNumber(
          this.selectedMaintenance.acknowledgement_records
        ),
      }
    );
  }

  get selectedMemberPreferencesLabel() {
    return i18n(
      "admin.messaging_preferences.activity.maintenance.member_preferences",
      { count: formatNumber(this.selectedMaintenance.preference_fields) }
    );
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

  trendDetail(metric) {
    if (!this.trend.comparison_available) {
      return i18n(
        "admin.messaging_preferences.activity.trends.no_comparison"
      );
    }

    if (metric?.change_percent == null) {
      return i18n(
        "admin.messaging_preferences.activity.trends.new_activity",
        { previous: formatNumber(metric?.previous) }
      );
    }

    if (metric.direction === "flat") {
      return i18n("admin.messaging_preferences.activity.trends.unchanged", {
        previous: formatNumber(metric.previous),
      });
    }

    return i18n(
      metric.direction === "up"
        ? "admin.messaging_preferences.activity.trends.increased"
        : "admin.messaging_preferences.activity.trends.decreased",
      {
        previous: formatNumber(metric.previous),
        percent: formatNumber(Math.abs(metric.change_percent)),
      }
    );
  }

  get trendCards() {
    const metrics = this.trend.metrics || {};
    return [
      {
        label: i18n(
          "admin.messaging_preferences.activity.trends.preference_changes"
        ),
        value: formatNumber(metrics.preference_changes?.current),
        detail: this.trendDetail(metrics.preference_changes),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.trends.acknowledgements"
        ),
        value: formatNumber(metrics.acknowledgements?.current),
        detail: this.trendDetail(metrics.acknowledgements),
      },
      {
        label: i18n(
          "admin.messaging_preferences.activity.trends.active_members"
        ),
        value: formatNumber(metrics.active_members?.current),
        detail: this.trendDetail(metrics.active_members),
      },
      {
        label: i18n("admin.messaging_preferences.activity.trends.total_events"),
        value: formatNumber(metrics.total_events?.current),
        detail: this.trendDetail(metrics.total_events),
      },
    ];
  }

  get generatedAtLabel() {
    return formatDateTime(this.data?.generated_at);
  }

  get recentEventsPayload() {
    return this.data?.recent_events || {};
  }

  get recentEvents() {
    return (this.recentEventsPayload.items || []).map((event) =>
      this.decorateEvent(event)
    );
  }

  get recentPagination() {
    return this.recentEventsPayload.pagination || {};
  }

  get recentPaginationLabel() {
    return i18n("admin.messaging_preferences.activity.pagination.status", {
      page: formatNumber(this.recentPagination.page || 1),
      pages: formatNumber(this.recentPagination.total_pages || 1),
      total: formatNumber(this.recentPagination.total || 0),
    });
  }

  get recentPreviousDisabled() {
    return this.isLoading || !this.recentPagination.has_previous;
  }

  get recentNextDisabled() {
    return this.isLoading || !this.recentPagination.has_next;
  }

  get selectedUser() {
    return this.data?.selected_user;
  }

  get selectedUserEventsPayload() {
    return this.selectedUser?.events || {};
  }

  get selectedUserEvents() {
    return (this.selectedUserEventsPayload.items || []).map((event) =>
      this.decorateEvent(event)
    );
  }

  get selectedUserPagination() {
    return this.selectedUserEventsPayload.pagination || {};
  }

  get selectedUserPaginationLabel() {
    return i18n("admin.messaging_preferences.activity.pagination.status", {
      page: formatNumber(this.selectedUserPagination.page || 1),
      pages: formatNumber(this.selectedUserPagination.total_pages || 1),
      total: formatNumber(this.selectedUserPagination.total || 0),
    });
  }

  get selectedUserPreviousDisabled() {
    return this.isLoading || !this.selectedUserPagination.has_previous;
  }

  get selectedUserNextDisabled() {
    return this.isLoading || !this.selectedUserPagination.has_next;
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
    this.isMaintaining = false;
    this.searchActiveIndex = -1;
    this.period = DEFAULT_PERIOD;
    this.eventFilter = DEFAULT_EVENT_FILTER;
    this.eventPage = 1;
    this.userEventPage = 1;
    this.searchSequence += 1;
    this.loadSequence += 1;
  }

  @action
  async loadActivity(userId = null) {
    const sequence = ++this.loadSequence;
    this.isLoading = true;
    this.error = null;

    try {
      const data = await ajax(
        getURL("/admin/plugins/messaging-preferences/activity"),
        {
          cache: false,
          data: {
            ...(userId ? { user_id: userId } : {}),
            period: this.period,
            event_filter: this.eventFilter,
            page: this.eventPage,
            user_page: this.userEventPage,
          },
        }
      );

      if (sequence !== this.loadSequence) {
        return;
      }

      this.data = data;
      this.period = this.data?.filters?.period || this.period;
      this.eventFilter =
        this.data?.filters?.event_filter || this.eventFilter;
      this.eventPage = this.recentPagination.page || 1;
      this.userEventPage = this.selectedUserPagination.page || 1;
    } catch {
      if (sequence === this.loadSequence) {
        this.error = i18n(
          "admin.messaging_preferences.activity.load_error"
        );
      }
    } finally {
      if (sequence === this.loadSequence) {
        this.isLoading = false;
      }
    }
  }

  @action
  refresh() {
    return this.loadActivity(this.selectedUser?.user?.id);
  }

  @action
  changePeriod(value) {
    this.period = value;
    this.eventPage = 1;
    this.userEventPage = 1;
    return this.loadActivity(this.selectedUser?.user?.id);
  }

  @action
  changeEventFilter(value) {
    this.eventFilter = value;
    this.eventPage = 1;
    this.userEventPage = 1;
    return this.loadActivity(this.selectedUser?.user?.id);
  }

  @action
  previousEventPage() {
    if (!this.recentPagination.has_previous) {
      return;
    }
    this.eventPage = Math.max(1, Number(this.recentPagination.page || 1) - 1);
    return this.loadActivity(this.selectedUser?.user?.id);
  }

  @action
  nextEventPage() {
    if (!this.recentPagination.has_next) {
      return;
    }
    this.eventPage = Number(this.recentPagination.page || 1) + 1;
    return this.loadActivity(this.selectedUser?.user?.id);
  }

  @action
  previousUserEventPage() {
    if (!this.selectedUserPagination.has_previous) {
      return;
    }
    this.userEventPage = Math.max(
      1,
      Number(this.selectedUserPagination.page || 1) - 1
    );
    return this.loadActivity(this.selectedUser?.user?.id);
  }

  @action
  nextUserEventPage() {
    if (!this.selectedUserPagination.has_next) {
      return;
    }
    this.userEventPage = Number(this.selectedUserPagination.page || 1) + 1;
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
    this.userEventPage = 1;
    return this.loadActivity(user.id);
  }

  @action
  clearSelectedUser() {
    this.searchSequence += 1;
    this.query = "";
    this.searchResults = [];
    this.searchActiveIndex = -1;
    this.isSearching = false;
    this.userEventPage = 1;
    return this.loadActivity();
  }

  async performAdminAction(path, type, successMessage) {
    this.isMaintaining = true;

    try {
      const result = await ajax(getURL(path), { type });
      const message =
        typeof successMessage === "function"
          ? successMessage(result)
          : successMessage;

      if (message) {
        this.toasts.success({ data: { message } });
      }

      await this.loadActivity(this.selectedUser?.user?.id);
      return result;
    } catch (error) {
      popupAjaxError(error);
      this.error = i18n(
        "admin.messaging_preferences.activity.action_failed"
      );
      return null;
    } finally {
      this.isMaintaining = false;
    }
  }

  sitewideDialog({ title, message, confirmButtonLabel, didConfirm }) {
    this.dialog.confirm({
      title,
      message,
      class: "messaging-preferences-sitewide-confirm",
      confirmButtonLabel,
      confirmButtonClass: "btn-danger",
      cancelButtonLabel:
        "admin.messaging_preferences.activity.maintenance.cancel_sitewide_action",
      didConfirm,
    });
  }

  @action
  runCleanup() {
    this.sitewideDialog({
      title: i18n(
        "admin.messaging_preferences.activity.maintenance.run_cleanup_title"
      ),
      message: i18n(
        "admin.messaging_preferences.activity.maintenance.run_cleanup_confirm",
        {
          events: formatNumber(this.maintenance.expired_event_records),
          duplicates: formatNumber(
            this.maintenance.duplicate_custom_field_records
          ),
          blank: formatNumber(this.maintenance.blank_custom_field_records),
          invalidAcks: formatNumber(
            this.maintenance.invalid_acknowledgement_records
          ),
          orphans: formatNumber(
            Number(this.maintenance.orphaned_acknowledgement_records || 0) +
              Number(this.maintenance.orphaned_event_records || 0)
          ),
        }
      ),
      confirmButtonLabel:
        "admin.messaging_preferences.activity.maintenance.run_cleanup",
      didConfirm: () =>
        this.performAdminAction(
          "/admin/plugins/messaging-preferences/activity/maintenance",
          "POST",
          (result) => {
            const removed = Object.values(result?.removed || {}).reduce(
              (total, value) => total + Number(value || 0),
              0
            );
            return i18n(
              "admin.messaging_preferences.activity.maintenance.cleanup_complete",
              { count: formatNumber(removed) }
            );
          }
        ),
    });
  }

  @action
  resetAllAcknowledgements() {
    const count = Number(this.maintenance.acknowledgement_records || 0);

    this.sitewideDialog({
      title: i18n(
        "admin.messaging_preferences.activity.maintenance.reset_all_acknowledgements_title"
      ),
      message: i18n(
        "admin.messaging_preferences.activity.maintenance.reset_all_acknowledgements_confirm",
        { count: formatNumber(count) }
      ),
      confirmButtonLabel:
        "admin.messaging_preferences.activity.maintenance.reset_all_acknowledgements",
      didConfirm: () =>
        this.performAdminAction(
          "/admin/plugins/messaging-preferences/activity/acknowledgements",
          "DELETE",
          (result) =>
            i18n(
              "admin.messaging_preferences.activity.maintenance.reset_all_acknowledgements_complete",
              {
                count: formatNumber(result?.removed_acknowledgements),
              }
            )
        ),
    });
  }

  @action
  clearActivityHistory() {
    const count = Number(this.maintenance.event_records || 0);

    this.sitewideDialog({
      title: i18n(
        "admin.messaging_preferences.activity.maintenance.clear_history_title"
      ),
      message: i18n(
        "admin.messaging_preferences.activity.maintenance.clear_history_confirm",
        { count: formatNumber(count) }
      ),
      confirmButtonLabel:
        "admin.messaging_preferences.activity.maintenance.clear_history",
      didConfirm: () =>
        this.performAdminAction(
          "/admin/plugins/messaging-preferences/activity/history",
          "DELETE",
          (result) =>
            i18n(
              "admin.messaging_preferences.activity.maintenance.clear_history_complete",
              { count: formatNumber(result?.removed_events) }
            )
        ),
    });
  }

  @action
  resetSelectedMemberAcknowledgements() {
    const user = this.selectedUser?.user;
    if (!user) {
      return;
    }

    const count = Number(this.selectedMaintenance.acknowledgement_records || 0);

    this.dialog.confirm({
      title: i18n(
        "admin.messaging_preferences.activity.maintenance.member_action_title",
        { username: user.username }
      ),
      message: i18n(
        "admin.messaging_preferences.activity.maintenance.reset_member_acknowledgements_confirm",
        { username: user.username, count: formatNumber(count) }
      ),
      confirmButtonLabel:
        "admin.messaging_preferences.activity.maintenance.reset_member_acknowledgements",
      confirmButtonClass: "btn-danger",
      didConfirm: () =>
        this.performAdminAction(
          `/admin/plugins/messaging-preferences/activity/users/${user.id}/acknowledgements`,
          "DELETE",
          (result) =>
            i18n(
              "admin.messaging_preferences.activity.maintenance.reset_member_acknowledgements_complete",
              {
                username: user.username,
                count: formatNumber(result?.removed_acknowledgements),
              }
            )
        ),
    });
  }

  @action
  clearSelectedMemberPreferences() {
    const user = this.selectedUser?.user;
    if (!user) {
      return;
    }

    this.dialog.confirm({
      title: i18n(
        "admin.messaging_preferences.activity.maintenance.member_action_title",
        { username: user.username }
      ),
      message: i18n(
        "admin.messaging_preferences.activity.maintenance.clear_member_preferences_confirm",
        {
          username: user.username,
          acknowledgements: formatNumber(
            this.selectedMaintenance.received_acknowledgement_records
          ),
        }
      ),
      confirmButtonLabel:
        "admin.messaging_preferences.activity.maintenance.clear_member_preferences",
      confirmButtonClass: "btn-danger",
      didConfirm: () =>
        this.performAdminAction(
          `/admin/plugins/messaging-preferences/activity/users/${user.id}/preferences`,
          "DELETE",
          () =>
            i18n(
              "admin.messaging_preferences.activity.maintenance.clear_member_preferences_complete",
              { username: user.username }
            )
        ),
    });
  }
}
