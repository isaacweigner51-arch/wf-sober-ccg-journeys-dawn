# WF Sober CCG — Google Play pack purchase setup

The project now uses these **consumable one-time product IDs**:

| Product ID | Packs | Suggested US price |
|---|---:|---:|
| `wf_sober_packs_5` | 5 | $2.99 |
| `wf_sober_packs_15` | 15 | $7.99 |
| `wf_sober_packs_40` | 40 | $19.99 |
| `wf_sober_packs_80` | 80 | $39.99 |

## Required before cash purchases work

1. Keep the Android package ID exactly `com.wfsober.ccg.journeysdawn`.
2. Install and enable the official **GodotGooglePlayBilling 3.2+** plugin under `addons/GodotGooglePlayBilling/`.
3. Keep **Gradle Build** enabled in the Android export preset.
4. Create the four one-time products above in Google Play Console and activate them.
5. Upload a signed AAB to an Internal Testing track.
6. Add tester Gmail accounts under License testing / Internal testing.
7. Install the app from the Play testing link. Billing does not complete from a sideloaded APK or desktop run.
8. For a public launch, verify purchase tokens on a secure backend before granting packs. The current RC includes local duplicate-token protection and automatic consumption for testing.

Do not change the package ID or signing key after testers begin installing updates, or Android will treat the app as a different application.
