import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import getURL from "discourse/lib/get-url";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import MessagingPreferencesUserLink from "../../components/messaging-preferences-user-link";

const settingsUrl = getURL("/admin/site_settings/category/all_results?filter=messaging_preferences");
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
        border: 1px solid var(--mp-border);
        border-radius: 18px;
        background: var(--mp-surface);
        box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
      }

      .mp-activity__hero,
      .mp-activity__panel {
        padding: 1.2rem 1.35rem;
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

      .mp-activity__actions {
        display: flex;
        flex-wrap: wrap;
        justify-content: flex-end;
        gap: 0.5rem;
      }

      .mp-activity__summary-grid,
      .mp-activity__user-grid {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 1rem;
      }

      .mp-activity__summary-card,
      .mp-activity__user-card {
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
        font-size: var(--font-up-2);
        font-weight: 700;
        overflow-wrap: anywhere;
      }

      .mp-activity__card-detail {
        margin-top: 0.35rem;
        color: var(--mp-muted);
        line-height: 1.35;
      }

      .mp-activity__notice,
      .mp-activity__error {
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

      .mp-activity__search-empty {
        margin-top: 0.5rem;
      }

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
        padding: 1rem;
        border: 1px solid var(--mp-border);
        border-radius: 16px;
        background: var(--mp-surface-alt);
      }

      .mp-activity__subpanel h3 {
        margin-bottom: 0.75rem;
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

      .mp-activity__event-copy {
        min-width: 0;
        line-height: 1.45;
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

      .mp-activity__event-time {
        color: var(--mp-muted);
        font-size: var(--font-down-1);
        white-space: nowrap;
      }

      .mp-activity__empty {
        margin-top: 0.75rem;
        color: var(--mp-muted);
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
        .mp-activity__user-grid {
          grid-template-columns: 1fr;
        }

        .mp-activity__event {
          grid-template-columns: 1fr;
        }

        .mp-activity__event-time {
          white-space: normal;
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
            <a
              class="btn"
              href={{settingsUrl}}
            >
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
                  <MessagingPreferencesUserLink
                    @user={{@controller.selectedUser.user}}
                  >
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

            <div class="mp-activity__columns">
              <section class="mp-activity__subpanel">
                <h3>
                  {{i18n
                    "admin.messaging_preferences.activity.user.received_title"
                  }}
                </h3>
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
                <h3>
                  {{i18n
                    "admin.messaging_preferences.activity.user.made_title"
                  }}
                </h3>
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
              {{#if @controller.selectedUserEvents.length}}
                <div class="mp-activity__events">
                  {{#each @controller.selectedUserEvents as |event|}}
                    <article class="mp-activity__event">
                      <div class="mp-activity__event-copy">
                        {{#if (eq event.event_type "acknowledged")}}
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
                            {{i18n
                              "admin.messaging_preferences.activity.events.preferences_created_action"
                            }}
                          {{else if (eq event.event_type "preferences_updated")}}
                            {{i18n
                              "admin.messaging_preferences.activity.events.preferences_updated_action"
                            }}
                          {{else if (eq event.event_type "preferences_cleared")}}
                            {{i18n
                              "admin.messaging_preferences.activity.events.preferences_cleared_action"
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
                        {{#if (eq event.event_type "acknowledged")}}
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
                            {{i18n
                              "admin.messaging_preferences.activity.events.preferences_created_action"
                            }}
                          {{else if (eq event.event_type "preferences_updated")}}
                            {{i18n
                              "admin.messaging_preferences.activity.events.preferences_updated_action"
                            }}
                          {{else if (eq event.event_type "preferences_cleared")}}
                            {{i18n
                              "admin.messaging_preferences.activity.events.preferences_cleared_action"
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
        </section>
      {{/if}}
    </div>
  </template>
);
