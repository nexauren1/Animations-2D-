# AnimPro PayPal Worker — environment switching

The app calls the Worker endpoint; it does not contain PayPal credentials or choose Sandbox/Live. After this code is deployed once, switching the Worker environment does **not** require an APK update.

Set the Worker variable `PAYPAL_ENVIRONMENT` to `sandbox` or `live`. This is the preferred switch; the Worker maps it to the official PayPal API host. The legacy `PAYPAL_API_BASE` remains supported when `PAYPAL_ENVIRONMENT` is unset.

For a switch, update these values together in Cloudflare Workers settings/secrets, using credentials and IDs from the same PayPal environment:

- `PAYPAL_CLIENT_ID`
- `PAYPAL_CLIENT_SECRET`
- `PAYPAL_ENVIRONMENT` (`sandbox` or `live`)
- `PAYPAL_WEBHOOK_ID` (the webhook ID for that environment)
- `PAYPAL_MONTHLY_PLAN_ID` (the monthly billing plan ID for that environment)

Keep `FIREBASE_API_KEY`, `FIREBASE_PROJECT_ID` and the Firestore service account configured as before. With the existing Worker deployment, changing the variable and secrets in the Cloudflare dashboard should take effect without rebuilding the APK. If you change Worker code or wrangler configuration, deploy the Worker; the app can still remain installed.

**Important:** changing only the API URL is not enough. Sandbox client credentials, webhook IDs and billing-plan IDs do not work against Live, and Live transactions can charge real money. Test with Sandbox first, then switch all PayPal values together. Never place PayPal secrets in Flutter code, Git commits, or public Pages files.
