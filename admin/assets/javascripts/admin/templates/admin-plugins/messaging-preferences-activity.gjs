import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import DSelect from "discourse/ui-kit/d-select";
import { i18n } from "discourse-i18n";
import MessagingPreferencesUserLink from "../../components/messaging-preferences-user-link";

const settingsUrl = getURL(
  "/admin/site_settings/category/all_results?filter=messaging_preferences"
);
const overviewUrl = getURL("/admin/plugins/messaging-preferences");

export default RouteTemplate(
  <template>
    <style>
      .mp-activity {
        --mp-surface: var(--secondary);
        --mp-surface-alt: var(--primary-very-low);
        --mp-border: var(--primary-low);
        --mp-muted: var(--primary-medium);
        display: flex;
        flex-direction: column;
        gap: 1rem;
      }

      .mp-activity h1,
      .mp-activity h2,
      .mp-activity h3,
      .mp-activity p {
        margin: 0;
      }

      .mp-activity__hero,
      .mp-activity__panel {
        padding: 1.2rem 1.35rem;
        border: 1px solid var(--mp-border);
        border-radius: 18px;
        background: var(--mp-surface);
        box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
      }

      .mp-activity__panel--danger {
        border: 2px solid var(--danger-low-mid);
        box-shadow: 0 1px 2px rgb(0 0 0 / 3%), 0 0 0 3px rgb(220 38 38 / 4%);
      }

      .mp-activity__header,
      .mp-activity__panel-header,
      .mp-activity__user-header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 1rem;
      }

      .mp-activity__copy,
      .mp-activity__panel-copy,
      .mp-activity__user-copy {
        display: flex;
        min-width: 0;
        flex-direction: column;
        gap: 0.35rem;
      }

      .mp-activity__muted {
        color: var(--mp-muted);
      }

      .mp-activity__actions,
      .mp-activity__pagination,
      .mp-activity__maintenance-actions {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        gap: 0.5rem;
      }

      .mp-activity__actions {
        justify-content: flex-end;
      }

      .mp-activity__summary-grid,
      .mp-activity__user-grid {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 1rem;
      }

      .mp-activity__trend-grid {
        display: grid;
        grid-template-columns: repeat(4, minmax(0, 1fr));
        gap: 1rem;
        margin-top: 1rem;
      }

      .mp-activity__summary-card,
      .mp-activity__user-card,
      .mp-activity__trend-card {
        min-width: 0;
        padding: 0.9rem 1rem;
        border: 1px solid var(--mp-border);
        border-radius: 16px;
        background: var(--mp-surface-alt);
      }

      .mp-activity__card-label {
        color: var(--mp-muted);
        font-size: var(--font-down-1);
        font-weight: 700;
      }

      .mp-activity__card-value {
        margin-top: 0.25rem;
        overflow-wrap: anywhere;
        font-size: var(--font-up-2);
        font-weight: 700;
      }

      .mp-activity__card-detail {
        margin-top: 0.35rem;
        color: var(--mp-muted);
        line-height: 1.35;
      }

      .mp-activity__notice,
      .mp-activity__error,
      .mp-activity__scope-warning {
        padding: 0.8rem 0.9rem;
        border-radius: 12px;
      }

      .mp-activity__notice {
        border: 1px solid var(--highlight-medium);
        background: var(--highlight-low);
        color: var(--primary-high);
      }

      .mp-activity__error {
        border: 1px solid var(--danger-low-mid);
        background: var(--danger-low);
        color: var(--danger);
      }

      .mp-activity__filters {
        display: grid;
        grid-template-columns: repeat(2, minmax(12rem, 18rem));
        gap: 0.9rem;
        margin-top: 1rem;
      }

      .mp-activity__filter {
        display: grid;
        gap: 0.35rem;
      }

      .mp-activity__filter label {
        font-size: var(--font-down-1);
        font-weight: 700;
      }

      .mp-activity__filter select {
        width: 100%;
      }

      .mp-activity__history-filter {
        display: flex;
        align-items: flex-end;
        justify-content: space-between;
        gap: 1rem;
        margin-top: 1.1rem;
        padding-top: 1rem;
        border-top: 1px solid var(--mp-border);
      }

      .mp-activity__history-filter-copy {
        display: grid;
        min-width: 0;
        gap: 0.25rem;
      }

      .mp-activity__history-filter .mp-activity__filter {
        flex: 0 0 min(18rem, 100%);
      }

      .mp-activity__search {
        position: relative;
        width: min(34rem, 100%);
        margin-top: 1rem;
      }

      .mp-activity__search input {
        width: 100%;
        box-sizing: border-box;
      }

      .mp-activity__search-results {
        position: absolute;
        z-index: 20;
        top: calc(100% + 0.25rem);
        right: 0;
        left: 0;
        max-height: 18rem;
        margin: 0;
        padding: 0.35rem;
        overflow-y: auto;
        border: 1px solid var(--mp-border);
        border-radius: 12px;
        background: var(--secondary);
        box-shadow: 0 10px 30px rgb(0 0 0 / 14%);
        list-style: none;
      }

      .mp-activity__search-result {
        display: flex;
        width: 100%;
        align-items: center;
        gap: 0.7rem;
        padding: 0.65rem 0.75rem;
        border: 0;
        border-radius: var(--d-button-border-radius);
        background: transparent;
        color: var(--primary);
        text-align: left;
        cursor: pointer;
      }

      .mp-activity__search-result:hover,
      .mp-activity__search-result:focus-visible,
      .mp-activity__search-result.is-active {
        background: var(--primary-very-low);
        outline: 2px solid var(--tertiary);
        outline-offset: -2px;
      }

      .mp-activity__search-avatar {
        flex: 0 0 auto;
        width: 40px;
        height: 40px;
        border-radius: 50%;
        object-fit: cover;
      }

      .mp-activity__search-identity {
        display: flex;
        min-width: 0;
        flex-direction: column;
        gap: 0.1rem;
      }

      .mp-activity__search-identity strong,
      .mp-activity__search-name {
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
      }

      .mp-activity__search-name,
      .mp-activity__search-status,
      .mp-activity__search-empty {
        color: var(--mp-muted);
        font-size: var(--font-down-1);
      }

      .mp-activity__search-status {
        position: absolute !important;
        width: 1px !important;
        height: 1px !important;
        padding: 0 !important;
        margin: -1px !important;
        overflow: hidden !important;
        clip: rect(0, 0, 0, 0) !important;
        white-space: nowrap !important;
        border: 0 !important;
      }

      .mp-activity__search-empty,
      .mp-activity__empty {
        margin-top: 0.75rem;
        color: var(--mp-muted);
      }

      .mp-activity__user-header,
      .mp-activity__user-grid {
        margin-top: 1rem;
      }

      .mp-activity__columns {
        display: grid;
        grid-template-columns: repeat(2, minmax(0, 1fr));
        gap: 1rem;
        margin-top: 1rem;
      }

      .mp-activity__subpanel {
        min-width: 0;
        margin-top: 1rem;
        padding: 1rem;
        border: 1px solid var(--mp-border);
        border-radius: 16px;
        background: var(--mp-surface-alt);
      }

      .mp-activity__columns .mp-activity__subpanel {
        margin-top: 0;
      }

      .mp-activity__subpanel h3 {
        margin-bottom: 0.75rem;
      }

      .mp-activity__maintenance-grid {
        display: grid;
        grid-template-columns: 1fr;
        gap: 1rem;
        margin-top: 1rem;
      }

      .mp-activity__maintenance-card {
        display: grid;
        grid-template-columns: minmax(0, 1fr) auto;
        grid-template-areas:
          "heading actions"
          "description actions"
          "copy actions";
        align-items: start;
        column-gap: 1rem;
        row-gap: 0.65rem;
        min-width: 0;
        padding: 1rem 1.1rem;
        border: 1px solid var(--mp-border);
        border-radius: 16px;
        background: var(--mp-surface-alt);
      }

      .mp-activity__maintenance-card.is-sitewide {
        border-color: var(--danger-low-mid);
        background: var(--secondary);
      }

      .mp-activity__maintenance-heading {
        display: flex;
        grid-area: heading;
        align-items: center;
        justify-content: flex-start;
        gap: 0.55rem;
        margin-bottom: 0;
      }

      .mp-activity__maintenance-heading h3 {
        margin: 0;
      }

      .mp-activity__scope-badge {
        display: inline-flex;
        flex: 0 0 auto;
        align-items: center;
        padding: 0.2rem 0.5rem;
        border: 1px solid var(--danger-low-mid);
        border-radius: 999px;
        background: var(--secondary);
        color: var(--danger);
        font-size: var(--font-down-2);
        font-weight: 700;
      }

      .mp-activity__scope-badge.is-member {
        border-color: var(--primary-low-mid);
        background: var(--primary-very-low);
        color: var(--primary-medium);
      }

      .mp-activity__scope-warning {
        display: grid;
        gap: 0.3rem;
        margin-top: 1rem;
        padding: 0.95rem 1rem;
        border: 1px solid var(--danger-low-mid);
        border-radius: 14px;
        background: var(--secondary);
        color: var(--primary-high);
      }

      .mp-activity__scope-warning strong {
        color: var(--danger);
      }

      .mp-activity__maintenance-card > .mp-activity__muted {
        grid-area: description;
      }

      .mp-activity__maintenance-copy {
        grid-area: copy;
        display: grid;
        gap: 0.35rem;
        color: var(--mp-muted);
      }

      .mp-activity__maintenance-actions {
        grid-area: actions;
        align-self: center;
        justify-content: flex-end;
        margin-top: 0;
      }

      .mp-activity__table-wrap {
        width: 100%;
        overflow-x: auto;
      }

      .mp-activity__table {
        width: 100%;
        border-collapse: collapse;
      }

      .mp-activity__table th,
      .mp-activity__table td {
        padding: 0.65rem 0.5rem;
        border-bottom: 1px solid var(--mp-border);
        text-align: left;
        vertical-align: top;
      }

      .mp-activity__table th {
        color: var(--mp-muted);
        font-size: var(--font-down-1);
      }

      .mp-activity__user-link {
        color: var(--tertiary);
        font-weight: 600;
        text-decoration: none;
      }

      .mp-activity__user-link:hover,
      .mp-activity__user-link:focus-visible {
        text-decoration: underline;
      }

      .mp-activity__status {
        display: inline-flex;
        padding: 0.2rem 0.45rem;
        border: 1px solid var(--mp-border);
        border-radius: 999px;
        font-size: var(--font-down-2);
        font-weight: 700;
      }

      .mp-activity__status.is-current {
        border-color: var(--success-low-mid);
        background: var(--success-low);
        color: var(--success);
      }

      .mp-activity__status.is-outdated {
        border-color: var(--highlight-medium);
        background: var(--highlight-low);
        color: var(--primary-high);
      }

      .mp-activity__events {
        display: grid;
        gap: 0.65rem;
        margin-top: 1rem;
      }

      .mp-activity__event {
        display: grid;
        grid-template-columns: minmax(0, 1fr) auto;
        gap: 0.75rem;
        padding: 0.75rem 0.85rem;
        border: 1px solid var(--mp-border);
        border-radius: 12px;
        background: var(--mp-surface-alt);
      }

      .mp-activity__event-copy {
        min-width: 0;
        line-height: 1.45;
      }

      .mp-activity__event-time {
        color: var(--mp-muted);
        font-size: var(--font-down-1);
        white-space: nowrap;
      }

      .mp-activity__pagination {
        justify-content: space-between;
        margin-top: 1rem;
        padding-top: 0.8rem;
        border-top: 1px solid var(--mp-border);
      }

      .mp-activity__pagination-status {
        color: var(--mp-muted);
        font-size: var(--font-down-1);
      }

      .dialog-container.messaging-preferences-sitewide-confirm .dialog-content {
        border: 2px solid var(--danger-medium);
        border-radius: 16px;
      }

      .dialog-container.messaging-preferences-sitewide-confirm .dialog-header {
        background: var(--danger-low);
      }

      .dialog-container.messaging-preferences-sitewide-confirm .dialog-header h3 {
        color: var(--danger);
      }

      .dialog-container.messaging-preferences-sitewide-confirm .dialog-body p {
        margin: 0;
      }

      .mp-sitewide-warning {
        display: grid;
        gap: 0.65rem;
        line-height: 1.45;
      }

      .mp-sitewide-warning__scope {
        display: block;
        padding: 0.65rem 0.75rem;
        border: 1px solid var(--danger-low-mid);
        border-radius: 10px;
        background: var(--danger-low);
        color: var(--danger);
        font-weight: 700;
      }

      @media (max-width: 900px) {
        .mp-activity__trend-grid {
          grid-template-columns: repeat(2, minmax(0, 1fr));
        }
      }

      @media (max-width: 900px) {
        .mp-activity__maintenance-card {
          grid-template-columns: 1fr;
          grid-template-areas:
            "heading"
            "description"
            "copy"
            "actions";
        }

        .mp-activity__maintenance-actions {
          justify-content: flex-start;
        }
      }

      @media (max-width: 800px) {
        .mp-activity__header,
        .mp-activity__panel-header,
        .mp-activity__user-header {
          flex-direction: column;
        }

        .mp-activity__actions {
          justify-content: flex-start;
        }

        .mp-activity__history-filter {
          align-items: stretch;
          flex-direction: column;
        }

        .mp-activity__history-filter .mp-activity__filter {
          flex-basis: auto;
          width: 100%;
        }

        .mp-activity__summary-grid,
        .mp-activity__user-grid {
          grid-template-columns: repeat(2, minmax(0, 1fr));
        }

        .mp-activity__columns {
          grid-template-columns: 1fr;
        }
      }

      @media (max-width: 520px) {
        .mp-activity__hero,
        .mp-activity__panel {
          padding: 1rem;
          border-radius: 14px;
        }

        .mp-activity__summary-grid,
        .mp-activity__user-grid,
        .mp-activity__trend-grid,
        .mp-activity__filters {
          grid-template-columns: 1fr;
        }

        .mp-activity__event {
          grid-template-columns: 1fr;
        }

        .mp-activity__event-time {
          white-space: normal;
        }

        .mp-activity__pagination {
          align-items: stretch;
          flex-direction: column;
        }

        .mp-activity__pagination .btn {
          width: 100%;
        }
      }
    </style>

    <div class="mp-activity">
      <section class="mp-activity__hero">
        <div class="mp-activity__header">
          <div class="mp-activity__copy">
            <h1>{{i18n "admin.messaging_preferences.activity.title"}}</h1>
            <p class="mp-activity__muted">
              {{i18n "admin.messaging_preferences.activity.description"}}
            </p>
            <p class="mp-activity__muted">
              {{i18n
                "admin.messaging_preferences.activity.last_checked"
                time=@controller.generatedAtLabel
              }}
            </p>
          </div>

          <div class="mp-activity__actions">
            <button
              type="button"
              class="btn"
              disabled={{@controller.isLoading}}
              {{on "click" @controller.refresh}}
            >
              {{if
                @controller.isLoading
                (i18n "admin.messaging_preferences.activity.refreshing")
                (i18n "admin.messaging_preferences.activity.refresh")
              }}
            </button>
            <a class="btn" href={{settingsUrl}}>
              {{i18n "admin.messaging_preferences.open_settings"}}
            </a>
            <a class="btn" href={{overviewUrl}}>
              {{i18n "admin.messaging_preferences.activity.back_to_overview"}}
            </a>
          </div>
        </div>
      </section>

      {{#if @controller.error}}
        <div class="mp-activity__error">{{@controller.error}}</div>
      {{/if}}

      {{#unless @controller.hasData}}
        <div class="mp-activity__notice">
          {{i18n "admin.messaging_preferences.activity.loading"}}
        </div>
      {{/unless}}

      {{#if @controller.hasData}}
        <section class="mp-activity__summary-grid">
          {{#each @controller.summaryCards as |card|}}
            <article class="mp-activity__summary-card">
              <div class="mp-activity__card-label">{{card.label}}</div>
              <div class="mp-activity__card-value">{{card.value}}</div>
              <div class="mp-activity__card-detail">{{card.detail}}</div>
            </article>
          {{/each}}
        </section>

        <section class="mp-activity__panel">
          <div class="mp-activity__panel-copy">
            <h2>{{i18n "admin.messaging_preferences.activity.trends.title"}}</h2>
            <p class="mp-activity__muted">
              {{i18n "admin.messaging_preferences.activity.trends.description"}}
            </p>
          </div>

          <div class="mp-activity__filters">
            <div class="mp-activity__filter">
              <label for="mp-activity-period">
                {{i18n "admin.messaging_preferences.activity.filters.period_label"}}
              </label>
              <DSelect
                id="mp-activity-period"
                @value={{@controller.period}}
                @includeNone={{false}}
                @onChange={{@controller.changePeriod}}
                disabled={{@controller.isLoading}}
                as |select|
              >
                {{#each @controller.periodOptions as |option|}}
                  <select.Option @value={{option.value}}>
                    {{option.label}}
                  </select.Option>
                {{/each}}
              </DSelect>
            </div>
          </div>

          <div class="mp-activity__trend-grid">
            {{#each @controller.trendCards as |card|}}
              <article class="mp-activity__trend-card">
                <div class="mp-activity__card-label">{{card.label}}</div>
                <div class="mp-activity__card-value">{{card.value}}</div>
                <div class="mp-activity__card-detail">{{card.detail}}</div>
              </article>
            {{/each}}
          </div>

          <div class="mp-activity__history-filter">
            <div class="mp-activity__history-filter-copy">
              <h3>{{i18n "admin.messaging_preferences.activity.filters.history_title"}}</h3>
              <p class="mp-activity__muted">
                {{i18n "admin.messaging_preferences.activity.filters.history_description"}}
              </p>
            </div>

            <div class="mp-activity__filter">
              <label for="mp-activity-event-filter">
                {{i18n "admin.messaging_preferences.activity.filters.type_label"}}
              </label>
              <DSelect
                id="mp-activity-event-filter"
                @value={{@controller.eventFilter}}
                @includeNone={{false}}
                @onChange={{@controller.changeEventFilter}}
                disabled={{@controller.isLoading}}
                as |select|
              >
                {{#each @controller.eventFilterOptions as |option|}}
                  <select.Option @value={{option.value}}>
                    {{option.label}}
                  </select.Option>
                {{/each}}
              </DSelect>
            </div>
          </div>
        </section>

        <section class="mp-activity__panel">
          <div class="mp-activity__panel-header">
            <div class="mp-activity__panel-copy">
              <h2>{{i18n "admin.messaging_preferences.activity.user.title"}}</h2>
              <p class="mp-activity__muted">
                {{i18n "admin.messaging_preferences.activity.user.description"}}
              </p>
            </div>

            {{#if @controller.selectedUser}}
              <button
                type="button"
                class="btn"
                {{on "click" @controller.clearSelectedUser}}
              >
                {{i18n "admin.messaging_preferences.activity.user.clear"}}
              </button>
            {{/if}}
          </div>

          <div class="mp-activity__search">
            <input
              type="search"
              class="input-large"
              value={{@controller.query}}
              placeholder={{i18n
                "admin.messaging_preferences.activity.user.search_placeholder"
              }}
              autocomplete="off"
              autocapitalize="none"
              spellcheck="false"
              role="combobox"
              aria-label={{i18n
                "admin.messaging_preferences.activity.user.search_label"
              }}
              aria-autocomplete="list"
              aria-expanded={{@controller.searchExpanded}}
              aria-controls={{@controller.searchListboxId}}
              aria-activedescendant={{@controller.searchActiveDescendant}}
              {{on "input" @controller.updateQuery}}
              {{on "keydown" @controller.handleSearchKeydown}}
            />

            <span
              class="mp-activity__search-status"
              role="status"
              aria-live="polite"
              aria-atomic="true"
            >
              {{@controller.searchStatusMessage}}
            </span>

            {{#if @controller.searchResults.length}}
              <ul
                id={{@controller.searchListboxId}}
                class="mp-activity__search-results"
                role="listbox"
                aria-label={{i18n
                  "admin.messaging_preferences.activity.user.results_label"
                }}
              >
                {{#each @controller.searchResults as |user index|}}
                  <li role="presentation">
                    <button
                      id="messaging-preferences-member-search-option-{{index}}"
                      type="button"
                      class={{if
                        (eq index @controller.searchActiveIndex)
                        "mp-activity__search-result is-active"
                        "mp-activity__search-result"
                      }}
                      role="option"
                      aria-selected={{eq index @controller.searchActiveIndex}}
                      {{on "click" (fn @controller.selectUser user)}}
                    >
                      {{#if user.avatarUrl}}
                        <img
                          class="mp-activity__search-avatar"
                          src={{user.avatarUrl}}
                          alt=""
                        />
                      {{/if}}
                      <span class="mp-activity__search-identity">
                        <strong>{{user.username}}</strong>
                        {{#if user.name}}
                          <span class="mp-activity__search-name">{{user.name}}</span>
                        {{/if}}
                      </span>
                    </button>
                  </li>
                {{/each}}
              </ul>
            {{else if @controller.showNoSearchResults}}
              <p class="mp-activity__search-empty">
                {{i18n "admin.messaging_preferences.activity.user.no_results"}}
              </p>
            {{/if}}
          </div>

          {{#if @controller.selectedUser}}
            <div class="mp-activity__user-header">
              <div class="mp-activity__user-copy">
                <h2>
                  <MessagingPreferencesUserLink @user={{@controller.selectedUser.user}}>
                    {{@controller.selectedUser.user.username}}
                  </MessagingPreferencesUserLink>
                </h2>
                {{#if @controller.selectedUser.user.name}}
                  <p class="mp-activity__muted">
                    {{@controller.selectedUser.user.name}}
                  </p>
                {{/if}}
              </div>
            </div>

            <div class="mp-activity__user-grid">
              {{#each @controller.selectedUserCards as |card|}}
                <article class="mp-activity__user-card">
                  <div class="mp-activity__card-label">{{card.label}}</div>
                  <div class="mp-activity__card-value">{{card.value}}</div>
                  <div class="mp-activity__card-detail">{{card.detail}}</div>
                </article>
              {{/each}}
            </div>

            <section class="mp-activity__subpanel">
              <div class="mp-activity__maintenance-heading">
                <h3>{{i18n "admin.messaging_preferences.activity.maintenance.member_title"}}</h3>
                <span class="mp-activity__scope-badge is-member">
                  {{i18n "admin.messaging_preferences.activity.maintenance.member_scope"}}
                </span>
              </div>
              <p class="mp-activity__muted">
                {{i18n
                  "admin.messaging_preferences.activity.maintenance.member_description"
                  username=@controller.selectedUser.user.username
                }}
              </p>
              <div class="mp-activity__maintenance-copy">
                <span>{{@controller.selectedMemberPreferencesLabel}}</span>
                <span>{{@controller.selectedMemberAcknowledgementsLabel}}</span>
              </div>
              <div class="mp-activity__maintenance-actions">
                <button
                  type="button"
                  class="btn btn-danger"
                  disabled={{@controller.isMaintaining}}
                  {{on "click" @controller.resetSelectedMemberAcknowledgements}}
                >
                  {{i18n
                    "admin.messaging_preferences.activity.maintenance.reset_member_acknowledgements"
                  }}
                </button>
                <button
                  type="button"
                  class="btn btn-danger"
                  disabled={{@controller.isMaintaining}}
                  {{on "click" @controller.clearSelectedMemberPreferences}}
                >
                  {{i18n
                    "admin.messaging_preferences.activity.maintenance.clear_member_preferences"
                  }}
                </button>
              </div>
            </section>

            <div class="mp-activity__columns">
              <section class="mp-activity__subpanel">
                <h3>{{i18n "admin.messaging_preferences.activity.user.received_title"}}</h3>
                {{#if @controller.acknowledgementsReceived.length}}
                  <div class="mp-activity__table-wrap">
                    <table class="mp-activity__table">
                      <thead>
                        <tr>
                          <th>{{i18n "admin.messaging_preferences.activity.columns.member"}}</th>
                          <th>{{i18n "admin.messaging_preferences.activity.columns.time"}}</th>
                          <th>{{i18n "admin.messaging_preferences.activity.columns.status"}}</th>
                        </tr>
                      </thead>
                      <tbody>
                        {{#each @controller.acknowledgementsReceived as |item|}}
                          <tr>
                            <td>
                              <MessagingPreferencesUserLink @user={{item.user}}>
                                {{item.user.username}}
                              </MessagingPreferencesUserLink>
                            </td>
                            <td>{{item.dateLabel}}</td>
                            <td>
                              <span class="mp-activity__status {{item.statusClass}}">
                                {{item.statusLabel}}
                              </span>
                            </td>
                          </tr>
                        {{/each}}
                      </tbody>
                    </table>
                  </div>
                {{else}}
                  <p class="mp-activity__empty">
                    {{i18n "admin.messaging_preferences.activity.user.no_received"}}
                  </p>
                {{/if}}
              </section>

              <section class="mp-activity__subpanel">
                <h3>{{i18n "admin.messaging_preferences.activity.user.made_title"}}</h3>
                {{#if @controller.acknowledgementsMade.length}}
                  <div class="mp-activity__table-wrap">
                    <table class="mp-activity__table">
                      <thead>
                        <tr>
                          <th>{{i18n "admin.messaging_preferences.activity.columns.member"}}</th>
                          <th>{{i18n "admin.messaging_preferences.activity.columns.time"}}</th>
                          <th>{{i18n "admin.messaging_preferences.activity.columns.status"}}</th>
                        </tr>
                      </thead>
                      <tbody>
                        {{#each @controller.acknowledgementsMade as |item|}}
                          <tr>
                            <td>
                              <MessagingPreferencesUserLink @user={{item.user}}>
                                {{item.user.username}}
                              </MessagingPreferencesUserLink>
                            </td>
                            <td>{{item.dateLabel}}</td>
                            <td>
                              <span class="mp-activity__status {{item.statusClass}}">
                                {{item.statusLabel}}
                              </span>
                            </td>
                          </tr>
                        {{/each}}
                      </tbody>
                    </table>
                  </div>
                {{else}}
                  <p class="mp-activity__empty">
                    {{i18n "admin.messaging_preferences.activity.user.no_made"}}
                  </p>
                {{/if}}
              </section>
            </div>

            <section class="mp-activity__subpanel">
              <h3>{{i18n "admin.messaging_preferences.activity.user.history_title"}}</h3>
              <p class="mp-activity__muted">
                {{i18n "admin.messaging_preferences.activity.user.history_filtered"}}
              </p>
              {{#if @controller.selectedUserEvents.length}}
                <div class="mp-activity__events">
                  {{#each @controller.selectedUserEvents as |event|}}
                    <article class="mp-activity__event">
                      <div class="mp-activity__event-copy">
                        {{#if (eq event.event_type "admin_site_cleanup")}}
                          <MessagingPreferencesUserLink @user={{event.actor}}>
                            {{event.actorDisplay}}
                          </MessagingPreferencesUserLink>
                          {{i18n "admin.messaging_preferences.activity.events.admin_site_cleanup_action"}}
                        {{else if (eq event.event_type "admin_reset_all_acks")}}
                          <MessagingPreferencesUserLink @user={{event.actor}}>
                            {{event.actorDisplay}}
                          </MessagingPreferencesUserLink>
                          {{i18n "admin.messaging_preferences.activity.events.admin_reset_all_acknowledgements_action"}}
                        {{else if (eq event.event_type "admin_reset_member_acks")}}
                          <MessagingPreferencesUserLink @user={{event.actor}}>
                            {{event.actorDisplay}}
                          </MessagingPreferencesUserLink>
                          {{i18n "admin.messaging_preferences.activity.events.admin_reset_member_acknowledgements_action"}}
                          <MessagingPreferencesUserLink @user={{event.target}}>
                            {{event.targetDisplay}}
                          </MessagingPreferencesUserLink>{{i18n
                            "admin.messaging_preferences.activity.events.admin_reset_member_acknowledgements_suffix"
                          }}
                        {{else if (eq event.event_type "acknowledged")}}
                          <MessagingPreferencesUserLink @user={{event.actor}}>
                            {{event.actorDisplay}}
                          </MessagingPreferencesUserLink>
                          {{i18n "admin.messaging_preferences.activity.events.acknowledged_action"}}
                          <MessagingPreferencesUserLink @user={{event.target}}>
                            {{event.targetDisplay}}
                          </MessagingPreferencesUserLink>{{i18n
                            "admin.messaging_preferences.activity.events.acknowledged_suffix"
                          }}
                        {{else}}
                          <MessagingPreferencesUserLink @user={{event.actor}}>
                            {{event.actorDisplay}}
                          </MessagingPreferencesUserLink>
                          {{#if (eq event.event_type "preferences_created")}}
                            {{i18n "admin.messaging_preferences.activity.events.preferences_created_action"}}
                          {{else if (eq event.event_type "preferences_updated")}}
                            {{i18n "admin.messaging_preferences.activity.events.preferences_updated_action"}}
                          {{else if (eq event.event_type "preferences_cleared")}}
                            {{i18n "admin.messaging_preferences.activity.events.preferences_cleared_action"}}
                          {{else if (eq event.event_type "preferences_admin_cleared")}}
                            {{i18n "admin.messaging_preferences.activity.events.preferences_admin_cleared_action"}}
                            <MessagingPreferencesUserLink @user={{event.target}}>
                              {{event.targetDisplay}}
                            </MessagingPreferencesUserLink>{{i18n
                              "admin.messaging_preferences.activity.events.preferences_admin_cleared_suffix"
                            }}
                          {{/if}}
                        {{/if}}
                      </div>
                      <time class="mp-activity__event-time">{{event.dateLabel}}</time>
                    </article>
                  {{/each}}
                </div>
              {{else}}
                <p class="mp-activity__empty">
                  {{i18n "admin.messaging_preferences.activity.no_tracked_events"}}
                </p>
              {{/if}}

              <div class="mp-activity__pagination">
                <button
                  type="button"
                  class="btn"
                  disabled={{@controller.selectedUserPreviousDisabled}}
                  {{on "click" @controller.previousUserEventPage}}
                >
                  {{i18n "admin.messaging_preferences.activity.pagination.previous"}}
                </button>
                <span class="mp-activity__pagination-status">
                  {{@controller.selectedUserPaginationLabel}}
                </span>
                <button
                  type="button"
                  class="btn"
                  disabled={{@controller.selectedUserNextDisabled}}
                  {{on "click" @controller.nextUserEventPage}}
                >
                  {{i18n "admin.messaging_preferences.activity.pagination.next"}}
                </button>
              </div>
            </section>
          {{/if}}
        </section>

        <section class="mp-activity__panel">
          <div class="mp-activity__panel-copy">
            <h2>{{i18n "admin.messaging_preferences.activity.recent_title"}}</h2>
            <p class="mp-activity__muted">
              {{i18n "admin.messaging_preferences.activity.recent_description"}}
            </p>
          </div>

          {{#if @controller.recentEvents.length}}
            <div class="mp-activity__events">
              {{#each @controller.recentEvents as |event|}}
                <article class="mp-activity__event">
                  <div class="mp-activity__event-copy">
                    {{#if (eq event.event_type "admin_site_cleanup")}}
                      <MessagingPreferencesUserLink @user={{event.actor}}>
                        {{event.actorDisplay}}
                      </MessagingPreferencesUserLink>
                      {{i18n "admin.messaging_preferences.activity.events.admin_site_cleanup_action"}}
                    {{else if (eq event.event_type "admin_reset_all_acks")}}
                      <MessagingPreferencesUserLink @user={{event.actor}}>
                        {{event.actorDisplay}}
                      </MessagingPreferencesUserLink>
                      {{i18n "admin.messaging_preferences.activity.events.admin_reset_all_acknowledgements_action"}}
                    {{else if (eq event.event_type "admin_reset_member_acks")}}
                      <MessagingPreferencesUserLink @user={{event.actor}}>
                        {{event.actorDisplay}}
                      </MessagingPreferencesUserLink>
                      {{i18n "admin.messaging_preferences.activity.events.admin_reset_member_acknowledgements_action"}}
                      <MessagingPreferencesUserLink @user={{event.target}}>
                        {{event.targetDisplay}}
                      </MessagingPreferencesUserLink>{{i18n
                        "admin.messaging_preferences.activity.events.admin_reset_member_acknowledgements_suffix"
                      }}
                    {{else if (eq event.event_type "acknowledged")}}
                      <MessagingPreferencesUserLink @user={{event.actor}}>
                        {{event.actorDisplay}}
                      </MessagingPreferencesUserLink>
                      {{i18n "admin.messaging_preferences.activity.events.acknowledged_action"}}
                      <MessagingPreferencesUserLink @user={{event.target}}>
                        {{event.targetDisplay}}
                      </MessagingPreferencesUserLink>{{i18n
                        "admin.messaging_preferences.activity.events.acknowledged_suffix"
                      }}
                    {{else}}
                      <MessagingPreferencesUserLink @user={{event.actor}}>
                        {{event.actorDisplay}}
                      </MessagingPreferencesUserLink>
                      {{#if (eq event.event_type "preferences_created")}}
                        {{i18n "admin.messaging_preferences.activity.events.preferences_created_action"}}
                      {{else if (eq event.event_type "preferences_updated")}}
                        {{i18n "admin.messaging_preferences.activity.events.preferences_updated_action"}}
                      {{else if (eq event.event_type "preferences_cleared")}}
                        {{i18n "admin.messaging_preferences.activity.events.preferences_cleared_action"}}
                      {{else if (eq event.event_type "preferences_admin_cleared")}}
                        {{i18n "admin.messaging_preferences.activity.events.preferences_admin_cleared_action"}}
                        <MessagingPreferencesUserLink @user={{event.target}}>
                          {{event.targetDisplay}}
                        </MessagingPreferencesUserLink>{{i18n
                          "admin.messaging_preferences.activity.events.preferences_admin_cleared_suffix"
                        }}
                      {{/if}}
                    {{/if}}
                  </div>
                  <time class="mp-activity__event-time">{{event.dateLabel}}</time>
                </article>
              {{/each}}
            </div>
          {{else}}
            <p class="mp-activity__empty">
              {{i18n "admin.messaging_preferences.activity.no_tracked_events"}}
            </p>
          {{/if}}

          <div class="mp-activity__pagination">
            <button
              type="button"
              class="btn"
              disabled={{@controller.recentPreviousDisabled}}
              {{on "click" @controller.previousEventPage}}
            >
              {{i18n "admin.messaging_preferences.activity.pagination.previous"}}
            </button>
            <span class="mp-activity__pagination-status">
              {{@controller.recentPaginationLabel}}
            </span>
            <button
              type="button"
              class="btn"
              disabled={{@controller.recentNextDisabled}}
              {{on "click" @controller.nextEventPage}}
            >
              {{i18n "admin.messaging_preferences.activity.pagination.next"}}
            </button>
          </div>
        </section>

        <section class="mp-activity__panel mp-activity__panel--danger">
          <div class="mp-activity__panel-copy">
            <h2>{{i18n "admin.messaging_preferences.activity.maintenance.title"}}</h2>
            <p class="mp-activity__muted">
              {{i18n "admin.messaging_preferences.activity.maintenance.description"}}
            </p>
          </div>

          <div class="mp-activity__scope-warning">
            <strong>{{i18n "admin.messaging_preferences.activity.maintenance.sitewide_warning_title"}}</strong>
            <span>{{i18n "admin.messaging_preferences.activity.maintenance.sitewide_warning"}}</span>
          </div>

          <div class="mp-activity__maintenance-grid">
            <article class="mp-activity__maintenance-card is-sitewide">
              <div class="mp-activity__maintenance-heading">
                <h3>{{i18n "admin.messaging_preferences.activity.maintenance.integrity_title"}}</h3>
                <span class="mp-activity__scope-badge">
                  {{i18n "admin.messaging_preferences.activity.maintenance.all_members_scope"}}
                </span>
              </div>
              <p class="mp-activity__muted">
                {{i18n "admin.messaging_preferences.activity.maintenance.integrity_scope_detail"}}
              </p>
              <div class="mp-activity__maintenance-copy">
                <span>{{@controller.retentionLabel}}</span>
                <span>{{@controller.retainedEventsLabel}}</span>
                <span>{{@controller.expiredEventsLabel}}</span>
                <span>{{@controller.integrityLabel}}</span>
              </div>
              <div class="mp-activity__maintenance-actions">
                <button
                  type="button"
                  class="btn"
                  disabled={{@controller.isMaintaining}}
                  {{on "click" @controller.runCleanup}}
                >
                  {{i18n "admin.messaging_preferences.activity.maintenance.run_cleanup"}}
                </button>
              </div>
            </article>

            <article class="mp-activity__maintenance-card is-sitewide">
              <div class="mp-activity__maintenance-heading">
                <h3>{{i18n "admin.messaging_preferences.activity.maintenance.acknowledgements_title"}}</h3>
                <span class="mp-activity__scope-badge">
                  {{i18n "admin.messaging_preferences.activity.maintenance.all_members_scope"}}
                </span>
              </div>
              <p class="mp-activity__muted">
                {{@controller.allAcknowledgementsLabel}}
              </p>
              <div class="mp-activity__maintenance-actions">
                <button
                  type="button"
                  class="btn btn-danger"
                  disabled={{@controller.isMaintaining}}
                  {{on "click" @controller.resetAllAcknowledgements}}
                >
                  {{i18n "admin.messaging_preferences.activity.maintenance.reset_all_acknowledgements"}}
                </button>
              </div>
            </article>

            <article class="mp-activity__maintenance-card is-sitewide">
              <div class="mp-activity__maintenance-heading">
                <h3>{{i18n "admin.messaging_preferences.activity.maintenance.history_title"}}</h3>
                <span class="mp-activity__scope-badge">
                  {{i18n "admin.messaging_preferences.activity.maintenance.all_members_scope"}}
                </span>
              </div>
              <p class="mp-activity__muted">
                {{@controller.allHistoryLabel}}
              </p>
              <div class="mp-activity__maintenance-actions">
                <button
                  type="button"
                  class="btn btn-danger"
                  disabled={{@controller.isMaintaining}}
                  {{on "click" @controller.clearActivityHistory}}
                >
                  {{i18n "admin.messaging_preferences.activity.maintenance.clear_history"}}
                </button>
              </div>
            </article>
          </div>
        </section>

      {{/if}}
    </div>
  </template>
);
