# jnt_app_0120

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Apurv Branch Optimization Snapshot (Previous vs Current)

### Comparison Scope
- **Previous baseline:** `origin/apurv_branch` (`556da40`)
- **Current branch:** `copilot/apurv-branch` (`90ef49b`)
- **Range analyzed:** `origin/apurv_branch..HEAD`

### High-Level Delta (Measured)
| Metric | Previous | Current | Change |
|---|---:|---:|---:|
| Total text lines (tracked files) | 163,948 | 180,721 | **+10.23%** |
| Dart lines (`*.dart`) | 157,684 | 169,165 | **+7.28%** |
| Files changed in range | - | 122 | - |
| Diff insertions | - | 25,318 | - |
| Diff deletions | - | 8,545 | - |
| Net line delta | - | +16,773 | - |

### Where Most Changes Happened (by diff volume)
| Area | Insertions | Deletions | Total line churn | Share of total churn |
|---|---:|---:|---:|---:|
| `lib/pages` | 17,422 | 7,929 | 25,351 | **74.86%** |
| `supabase` | 4,105 | 0 | 4,105 | **12.12%** |
| `lib/widgets` | 1,544 | 329 | 1,873 | **5.53%** |
| `lib/services` | 685 | 184 | 869 | **2.57%** |
| Others combined | 1,562 | 103 | 1,665 | **4.92%** |

### Previous vs Current Size Growth by Module
| Module | Previous lines | Current lines | Growth |
|---|---:|---:|---:|
| `lib/pages` | 136,615 | 146,108 | **+6.95%** |
| `lib/services` | 8,804 | 9,305 | **+5.69%** |
| `lib/widgets` | 6,384 | 7,599 | **+19.03%** |
| `lib/utils` | 2,034 | 2,194 | **+7.87%** |
| `android` | 287 | 398 | **+38.68%** |
| `supabase` | 83 | 4,188 | **+4,945.78%** |

### Optimization-Oriented Changes Observed from Diff Content
- Added centralized runtime configuration through `lib/config/environment.dart`.
- Expanded repository/service layer updates (`lib/services/*`) that indicate stronger data-access structuring.
- Introduced schema/migration artifacts in `supabase/migrations/*`, including support additions and auth alias updates.
- Large UI workflow refactors across artist/client page sets (`lib/pages/*`) and shared widgets (`lib/widgets/*`).

> Note: This comparison is based on repository diff metrics (line/file/churn analysis), not runtime benchmark telemetry.
