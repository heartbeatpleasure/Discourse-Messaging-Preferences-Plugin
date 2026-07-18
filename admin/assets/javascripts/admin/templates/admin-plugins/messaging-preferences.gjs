import RouteTemplate from "ember-route-template";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const settingsUrl = getURL("/admin/site_settings/category/all_results?filter=messaging_preferences");
const activityUrl = getURL("/admin/plugins/messaging-preferences-activity");

export default RouteTemplate(
  <template>
    <style>
      .mp-admin-landing {
        --mp-surface: var(--secondary);
        --mp-border: var(--primary-low);
        --mp-muted: var(--primary-medium);
        display: flex;
        flex-direction: column;
        gap: 1rem;
      }

      .mp-admin-landing h1,
      .mp-admin-landing h2,
      .mp-admin-landing h3,
      .mp-admin-landing p {
        margin: 0;
      }

      .mp-admin-landing__hero,
      .mp-admin-landing__card {
        border: 1px solid var(--mp-border);
        border-radius: 18px;
        background: var(--mp-surface);
        box-shadow: 0 1px 2px rgb(0 0 0 / 3%);
      }

      .mp-admin-landing__hero {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 1rem;
        padding: 1.25rem 1.35rem;
      }

      .mp-admin-landing__hero-copy,
      .mp-admin-landing__section-copy,
      .mp-admin-landing__card-title {
        display: flex;
        flex-direction: column;
      }

      .mp-admin-landing__hero-copy {
        gap: 0.45rem;
        max-width: 760px;
      }

      .mp-admin-landing__hero-copy p,
      .mp-admin-landing__section-copy p,
      .mp-admin-landing__card-description {
        color: var(--mp-muted);
      }

      .mp-admin-landing__section-copy {
        gap: 0.2rem;
        padding: 0 0.25rem;
      }

      .mp-admin-landing__grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        gap: 1rem;
      }

      .mp-admin-landing__card {
        display: flex;
        min-height: 170px;
        flex-direction: column;
        gap: 0.85rem;
        padding: 1rem 1.1rem;
        color: var(--primary);
        text-decoration: none;
        transition:
          border-color 0.12s ease,
          box-shadow 0.12s ease,
          transform 0.12s ease;
      }

      .mp-admin-landing__card:hover,
      .mp-admin-landing__card:focus {
        border-color: var(--tertiary-medium);
        box-shadow: 0 6px 18px rgb(0 0 0 / 6%);
        color: var(--primary);
        text-decoration: none;
        transform: translateY(-1px);
      }

      .mp-admin-landing__card.is-primary {
        border-color: var(--tertiary-low);
        background: linear-gradient(
          180deg,
          var(--secondary) 0%,
          var(--tertiary-very-low) 100%
        );
      }

      .mp-admin-landing__card-title {
        gap: 0.3rem;
      }

      .mp-admin-landing__card-title h3 {
        font-size: var(--font-up-1);
        line-height: 1.15;
      }

      .mp-admin-landing__badge {
        display: inline-flex;
        width: max-content;
        padding: 0.35rem 0.55rem;
        border: 1px solid var(--primary-low);
        border-radius: 999px;
        background: var(--primary-very-low);
        color: var(--primary-medium);
        font-size: var(--font-down-1);
        line-height: 1;
      }

      .mp-admin-landing__badge.is-primary {
        border-color: var(--tertiary-low);
        background: var(--tertiary-low);
        color: var(--tertiary);
      }

      .mp-admin-landing__card-action {
        display: inline-flex;
        margin-top: auto;
        color: var(--tertiary);
        font-weight: 600;
      }

      @media (max-width: 700px) {
        .mp-admin-landing__hero {
          flex-direction: column;
        }

        .mp-admin-landing__grid {
          grid-template-columns: 1fr;
        }
      }
    </style>

    <div class="mp-admin-landing">
      <section class="mp-admin-landing__hero">
        <div class="mp-admin-landing__hero-copy">
          <h1>{{i18n "admin.messaging_preferences.title"}}</h1>
          <p>{{i18n "admin.messaging_preferences.description"}}</p>
        </div>

        <a
          class="btn btn-primary"
          href={{settingsUrl}}
        >
          {{i18n "admin.messaging_preferences.open_settings"}}
        </a>
      </section>

      <div class="mp-admin-landing__section-copy">
        <h2>{{i18n "admin.messaging_preferences.overview_title"}}</h2>
        <p>{{i18n "admin.messaging_preferences.overview_description"}}</p>
      </div>

      <section class="mp-admin-landing__grid">
        <a
          class="mp-admin-landing__card is-primary"
          href={{settingsUrl}}
        >
          <div class="mp-admin-landing__card-title">
            <span class="mp-admin-landing__badge is-primary">
              {{i18n "admin.messaging_preferences.category_configuration"}}
            </span>
            <h3>{{i18n "admin.messaging_preferences.open_settings"}}</h3>
          </div>
          <p class="mp-admin-landing__card-description">
            {{i18n "admin.messaging_preferences.settings_description"}}
          </p>
          <span class="mp-admin-landing__card-action">
            {{i18n "admin.messaging_preferences.open_settings"}}
          </span>
        </a>

        <a
          class="mp-admin-landing__card"
          href={{activityUrl}}
        >
          <div class="mp-admin-landing__card-title">
            <span class="mp-admin-landing__badge">
              {{i18n "admin.messaging_preferences.category_activity"}}
            </span>
            <h3>{{i18n "admin.messaging_preferences.activity.short_title"}}</h3>
          </div>
          <p class="mp-admin-landing__card-description">
            {{i18n "admin.messaging_preferences.activity.description"}}
          </p>
          <span class="mp-admin-landing__card-action">
            {{i18n "admin.messaging_preferences.open_tool"}}
          </span>
        </a>
      </section>
    </div>
  </template>
);
