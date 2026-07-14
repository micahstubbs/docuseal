# White-labeling the product name

The displayed product name is configurable. It resolves in this order:

1. **`PRODUCT_NAME` environment variable** (deploy-time). Highest priority.
   ```bash
   PRODUCT_NAME="Acme Sign"
   ```
2. **Account config value** (runtime, settable by the user) — stored under the
   `product_name` account-config key (`AccountConfig::PRODUCT_NAME_KEY`). Applies
   only when `PRODUCT_NAME` is not set in the environment.
3. **Default:** `DocuSeal`.

All UI surfaces (page titles, meta tags, PWA manifest, MCP server info, audit
trail, sign reason, webhook User-Agent, generated certificate name, emails) read
the resolved value via `Docuseal.product_name` (or the `Docuseal::PRODUCT_NAME`
constant for load-time contexts, which reflects the env var / default).

The AGPL §7(b) "Powered by DocuSeal" attribution in interactive UIs is a separate,
required surface and is intentionally **not** affected by the product name.

To set the account-config value at runtime:

```ruby
AccountConfig.find_or_create_by(account:, key: AccountConfig::PRODUCT_NAME_KEY).update!(value: 'Acme Sign')
Docuseal.refresh_product_name!
```
