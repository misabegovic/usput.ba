---
title: roundhouse check on usput main, 2026-09-30
date: 2026-09-30
via: roundhouse 2026.9.18 (25609ca3) built from source, run as roundhouse check --continue . on usput.ba main 019e6fe
---
# roundhouse check on usput, 2026-09-30

## Summary

roundhouse 2026.9.18 (25609ca3), `roundhouse check --continue .` on usput.ba main 019e6fe, 2026-09-30, 3.9 s wall.
Totals: 0 parse errors, 243 errors, 2263 warnings, 90 gap-attributed notes, 55 survey gaps (7 kinds).
Errors: 183 send_dispatch_failed, 37 incompatible_binop, 23 ivar_unresolved. Many are analyzer model gaps, not app bugs (e.g. "no known method `average` on Review", "no known method `location_category_ids` on Location", ActiveStorage variant `download`). Hottest files: new_design/explore.html.erb 29, new_design_controller.rb 16, curator/experiences/_experience_item 15, content_change.rb 14, location.rb 12.
Warnings: 1197 gradual_untyped, 1062 unresolved_type, 4 missing_preload (real N+1: curator/admin/photo_suggestions index x2, experiences/show.html.erb:152 and :225 read location photos without with_attached_photos).
Survey gaps: 32 GlobalVariableWriteNode (platform CLI/MCP tests), 12+4 `defined?` on constants (travel_profiles, user_plans, ai/audio_tour_generator, ai error_reporting, platform infrastructure executor), 4 backtick shell strings (platform infrastructure executor), browses.searchable virtual column dropped, protect_from_forgery macro in UserPlansController, routes `resources :moments only:` not a literal list.
Gems: 46 = 10 framework, 3 modeled, 20 infrastructure, 13 unknown: better_html, erb_lint, faraday, faraday-follow_redirects, flipper, flipper-active_record, geocoder, neighbor, parslet, rollbar, ruby_llm, rubyzip, undercover.

## Full output

```text
./app/controllers/application_controller.rb:23:5: note[send_dispatch_failed]: no known method `error` on Rollbar — likely roundhouse coverage, not an app error (the `rollbar` gem is in the Gemfile and roundhouse does not model it)
./app/controllers/application_controller.rb:23:19: warning[unresolved_type]: local read `exception` has unresolved type
./app/controllers/application_controller.rb:24:11: warning[unresolved_type]: local read `exception` has unresolved type
./app/controllers/concerns/localizable.rb:47:8: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:58:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:62:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:66:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:68:34: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:68:34: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:70:5: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:71:31: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:71:45: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:71:14: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:78:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:87:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/localizable.rb:92:18: warning[unresolved_type]: local read `locale` has unresolved type
./app/controllers/concerns/localizable.rb:92:36: warning[unresolved_type]: local read `locale` has unresolved type
./app/controllers/concerns/authenticatable.rb:22:54: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/concerns/authenticatable.rb:26:42: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/concerns/authenticatable.rb:34:66: warning[unresolved_type]: local read `path` has unresolved type
./app/controllers/concerns/authenticatable.rb:34:87: warning[unresolved_type]: local read `path` has unresolved type
./app/controllers/concerns/authenticatable.rb:34:27: warning[unresolved_type]: local read `path` has unresolved type
./app/controllers/concerns/authenticatable.rb:40:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/authenticatable.rb:54:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/authenticatable.rb:77:53: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/concerns/authenticatable.rb:91:61: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/curator/admin/content_changes_controller.rb:12:79: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:12:59: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:13:82: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:13:64: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:14:72: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:27:9: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:28:11: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:28:39: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:28:60: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:30:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:30:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:31:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:33:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:33:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:34:24: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:35:24: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:38:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:38:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:39:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:44:9: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:45:11: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:45:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:45:59: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:47:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:47:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:48:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:50:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:50:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:51:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:54:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:54:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:55:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:62:46: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:66:24: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:67:38: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/content_changes_controller.rb:68:45: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:12:73: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:12:53: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:25:9: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:26:11: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:26:36: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:28:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:28:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:29:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:31:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:31:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:32:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:35:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:35:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:36:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:41:9: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:42:11: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:42:35: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:42:49: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:44:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:44:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:45:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:47:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:47:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:48:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:51:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:51:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:52:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/curator_applications_controller.rb:59:62: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:12:83: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:12:63: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:25:9: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:26:11: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:26:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:26:62: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:28:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:28:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:29:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:31:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:31:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:32:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:35:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:35:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:36:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:41:9: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:42:11: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:42:40: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:42:61: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:44:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:44:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:45:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:47:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:47:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:48:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:51:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:51:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:52:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/photo_suggestions_controller.rb:59:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:12:82: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:12:42: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:13:74: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:32:9: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:32:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:33:81: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:34:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:34:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:35:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:37:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:42:9: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:45:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:45:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:46:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:48:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:48:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:49:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:56:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:60:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:64:9: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/admin/users_controller.rb:64:52: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:8:65: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:8:45: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:10:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:11:56: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:14:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:15:90: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:18:40: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:29:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:29:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:31:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:37:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:37:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:42:57: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:42:33: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:48:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:54:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:54:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:54:10: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:56:57: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:57:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:57:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:57:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:59:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:60:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:60:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:61:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:66:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:66:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:74:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:79:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:80:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:82:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:82:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:82:67: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:84:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:84:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:85:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:93:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:97:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:99:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:99:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:99:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:101:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:101:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:101:54: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:108:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:116:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/audio_tours_controller.rb:120:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/base_controller.rb:15:23: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/curator/base_controller.rb:16:19: warning[unresolved_type]: method call `url_for` has unresolved type
./app/controllers/curator/base_controller.rb:22:23: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/curator/base_controller.rb:30:17: warning[unresolved_type]: local read `action` has unresolved type
./app/controllers/curator/base_controller.rb:31:21: warning[unresolved_type]: local read `recordable` has unresolved type
./app/controllers/curator/base_controller.rb:32:19: warning[unresolved_type]: local read `metadata` has unresolved type
./app/controllers/curator/base_controller.rb:43:25: warning[unresolved_type]: local read `resource` has unresolved type
./app/controllers/curator/base_controller.rb:46:26: warning[unresolved_type]: local read `resource` has unresolved type
./app/controllers/curator/base_controller.rb:47:24: warning[unresolved_type]: local read `resource` has unresolved type
./app/controllers/curator/dashboard_controller.rb:13:25: error[send_dispatch_failed]: no known method `average` on Review
./app/controllers/curator/dashboard_controller.rb:14:57: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:10:71: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:10:48: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:11:72: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:11:47: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:12:97: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:12:74: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:14:14: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:14:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:14:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:17:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:17:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:18:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:25:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:25:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:27:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:33:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:33:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:42:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:48:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:48:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:48:10: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:49:57: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:50:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:50:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:50:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:52:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:53:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:53:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:54:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:59:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:59:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:66:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:71:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:72:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:74:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:74:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:74:67: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:76:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:76:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:77:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:85:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:89:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:91:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:91:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:91:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:93:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:93:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:93:54: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:100:51: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:115:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:118:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:119:34: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:119:79: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/experiences_controller.rb:129:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:11:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:13:62: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:13:39: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:14:65: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:14:43: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:15:90: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:15:67: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:17:14: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:17:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:17:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:20:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:20:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:21:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:28:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:28:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:30:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:44:61: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:44:43: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:47:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:48:85: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:51:14: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:51:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:51:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:55:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:55:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:56:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:63:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:63:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:72:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:78:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:78:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:78:10: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:79:57: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:80:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:80:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:80:53: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:82:34: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:83:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:83:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:84:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:89:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:89:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:92:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:93:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:93:100: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:94:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:94:57: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:95:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:101:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:106:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:108:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:109:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:111:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:111:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:111:63: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:113:105: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:114:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:115:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:118:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:118:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:119:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:126:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:130:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:132:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:132:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:132:53: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:134:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:134:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:134:52: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:144:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:144:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:144:61: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:150:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:150:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:150:61: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:156:47: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:166:39: error[send_dispatch_failed]: no known method `location_category_ids` on Location
./app/controllers/curator/locations_controller.rb:171:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:174:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:175:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:175:91: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:175:105: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:180:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:181:40: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:181:89: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:191:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:204:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:204:10: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:205:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:205:9: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:205:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:205:28: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:205:67: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:205:67: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:205:80: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:205:80: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:205:99: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:207:7: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:210:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:210:10: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:211:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:211:9: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:211:36: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:211:36: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:211:77: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:216:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:216:10: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:217:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:217:15: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:218:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:218:79: warning[unresolved_type]: local read `h` has unresolved type
./app/controllers/curator/locations_controller.rb:218:81: warning[unresolved_type]: local read `f` has unresolved type
./app/controllers/curator/locations_controller.rb:219:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:219:15: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:221:52: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:221:52: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:221:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:221:11: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:221:26: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:221:26: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:223:9: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:223:24: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:223:24: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:224:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:224:9: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:224:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/locations_controller.rb:227:7: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:14:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:14:76: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:26:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:26:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:26:49: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:32:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:32:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:32:49: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:38:67: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:39:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/moments_controller.rb:45:43: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:25:3: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:26:12: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:28:57: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:29:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:29:32: warning[unresolved_type]: local read `public` has unresolved type
./app/controllers/concerns/serves_moment_photos.rb:30:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:30:15: error[send_dispatch_failed]: no known method `download` on ActiveStorage::VariantWithRecord
./app/controllers/concerns/serves_moment_photos.rb:33:47: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:35:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:35:67: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:36:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:41:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:41:74: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:42:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:9:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:9:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:12:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:23:61: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:24:32: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:26:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:30:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:30:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:30:79: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:32:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:33:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:40:47: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:44:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:44:63: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/photo_suggestions_controller.rb:48:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:8:39: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:9:40: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:10:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:10:32: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:12:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:13:52: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:16:14: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:16:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:16:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:19:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:19:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:20:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:33:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:33:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:35:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:41:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:41:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:50:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:56:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:56:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:56:10: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:57:57: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:58:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:58:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:58:49: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:60:26: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:61:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:61:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:62:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:67:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:67:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:74:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:79:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:80:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:82:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:82:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:82:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:84:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:84:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:85:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:93:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:97:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:99:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:99:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:99:49: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:101:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:101:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:101:48: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:108:39: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:126:14: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:134:14: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:140:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:146:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:147:35: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:151:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:152:33: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:156:44: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:156:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:162:51: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:162:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:163:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:163:30: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:164:28: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:164:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:164:63: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:165:63: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:165:31: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/plans_controller.rb:170:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:10:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:13:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:14:52: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:18:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:19:56: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:20:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:26:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:30:49: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:31:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:33:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:38:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:38:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:38:63: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:40:68: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:41:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:42:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:49:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/proposals_controller.rb:53:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:8:57: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:8:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:9:68: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:9:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:11:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:12:81: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:12:105: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:15:32: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:19:25: error[send_dispatch_failed]: no known method `average` on Review
./app/controllers/curator/reviews_controller.rb:26:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:26:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:39:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:43:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:44:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:44:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:44:51: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:46:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:46:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:46:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:55:43: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:59:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator/reviews_controller.rb:59:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/curator_applications_controller.rb:18:17: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/curator_applications_controller.rb:37:39: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/curator_applications_controller.rb:39:39: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/explore_bosnia_controller.rb:29:67: warning[unresolved_type]: local read `lat` has unresolved type
./app/controllers/explore_bosnia_controller.rb:29:80: warning[unresolved_type]: local read `lat` has unresolved type
./app/controllers/explore_bosnia_controller.rb:29:90: warning[unresolved_type]: local read `lng` has unresolved type
./app/controllers/explore_bosnia_controller.rb:35:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:35:23: warning[unresolved_type]: method call `Array` has unresolved type
./app/controllers/explore_bosnia_controller.rb:35:83: warning[unresolved_type]: local read `key` has unresolved type
./app/controllers/explore_bosnia_controller.rb:36:23: warning[unresolved_type]: method call `Array` has unresolved type
./app/controllers/explore_bosnia_controller.rb:37:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:37:64: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:41:23: error[ivar_unresolved]: @lat has no known type
./app/controllers/explore_bosnia_controller.rb:44:54: error[ivar_unresolved]: @lat has no known type
./app/controllers/explore_bosnia_controller.rb:49:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:50:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:51:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:58:34: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:58:60: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:77:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:78:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:81:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:85:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:85:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:93:49: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:93:33: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:98:60: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:109:12: warning[unresolved_type]: local read `name` has unresolved type
./app/controllers/explore_bosnia_controller.rb:110:25: warning[unresolved_type]: local read `value` has unresolved type
./app/controllers/explore_bosnia_controller.rb:111:25: warning[unresolved_type]: local read `value` has unresolved type
./app/controllers/explore_bosnia_controller.rb:120:30: error[ivar_unresolved]: @lat has no known type
./app/controllers/explore_bosnia_controller.rb:120:41: error[ivar_unresolved]: @lng has no known type
./app/controllers/explore_bosnia_controller.rb:120:63: warning[unresolved_type]: local read `distance` has unresolved type
./app/controllers/explore_bosnia_controller.rb:120:83: warning[unresolved_type]: local read `id` has unresolved type
./app/controllers/explore_bosnia_controller.rb:125:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:126:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:127:23: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:127:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:127:35: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:129:7: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:129:22: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:138:51: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:138:51: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/controllers/explore_bosnia_controller.rb:139:83: warning[unresolved_type]: local read `skip_visited` has unresolved type
./app/controllers/explore_bosnia_controller.rb:141:13: note[send_dispatch_failed]: no known method `near` on Relation[Location] — likely roundhouse coverage, not an app error (the `geocoder` gem is in the Gemfile and roundhouse does not model it)
./app/controllers/explore_bosnia_controller.rb:142:26: error[ivar_unresolved]: @lat has no known type
./app/controllers/explore_bosnia_controller.rb:142:32: error[ivar_unresolved]: @lng has no known type
./app/controllers/explore_bosnia_controller.rb:145:8: warning[unresolved_type]: local read `cursor` has unresolved type
./app/controllers/explore_bosnia_controller.rb:148:22: error[send_dispatch_failed]: no known method `distance_from_sql` on Location
./app/controllers/explore_bosnia_controller.rb:148:51: error[ivar_unresolved]: @lat has no known type
./app/controllers/explore_bosnia_controller.rb:148:57: error[ivar_unresolved]: @lng has no known type
./app/controllers/explore_bosnia_controller.rb:149:15: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/explore_bosnia_controller.rb:149:31: warning[unresolved_type]: local read `distance_sql` has unresolved type
./app/controllers/explore_bosnia_controller.rb:149:72: warning[unresolved_type]: local read `cursor` has unresolved type
./app/controllers/explore_bosnia_controller.rb:152:12: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/explore_bosnia_controller.rb:159:49: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/controllers/locations_controller.rb:52:19: warning[unresolved_type]: method call `stale?` has unresolved type
./app/controllers/locations_controller.rb:54:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/locations_controller.rb:54:67: warning[gradual_untyped]: constant read resolves to RBS `untyped` (gradual escape)
./app/controllers/locations_controller.rb:58:18: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/locations_controller.rb:79:44: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/locations_controller.rb:90:17: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/locations_controller.rb:94:17: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/locations_controller.rb:101:8: warning[unresolved_type]: method call `turbo_frame_request?` has unresolved type
./app/controllers/locations_controller.rb:103:33: warning[unresolved_type]: local read `message` has unresolved type
./app/controllers/locations_controller.rb:105:40: warning[unresolved_type]: local read `message` has unresolved type
./app/controllers/map_routes_controller.rb:14:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/map_routes_controller.rb:14:76: warning[gradual_untyped]: constant read resolves to RBS `untyped` (gradual escape)
./app/controllers/map_routes_controller.rb:15:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/map_routes_controller.rb:17:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/map_routes_controller.rb:19:18: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/map_routes_controller.rb:28:63: warning[unresolved_type]: method call `Float` has unresolved type
./app/controllers/map_routes_controller.rb:29:23: warning[unresolved_type]: local read `from_lat` has unresolved type
./app/controllers/map_routes_controller.rb:29:45: warning[unresolved_type]: local read `to_lat` has unresolved type
./app/controllers/map_routes_controller.rb:29:65: warning[unresolved_type]: local read `from_lng` has unresolved type
./app/controllers/map_routes_controller.rb:29:88: warning[unresolved_type]: local read `to_lng` has unresolved type
./app/controllers/map_routes_controller.rb:31:17: warning[unresolved_type]: local read `from_lat` has unresolved type
./app/controllers/map_routes_controller.rb:31:61: warning[unresolved_type]: local read `from_lng` has unresolved type
./app/controllers/map_routes_controller.rb:32:15: warning[unresolved_type]: local read `to_lat` has unresolved type
./app/controllers/map_routes_controller.rb:32:31: warning[unresolved_type]: local read `to_lng` has unresolved type
./app/controllers/mine_check_public_controller.rb:20:12: error[send_dispatch_failed]: no known method `between?` on Float
./app/controllers/mine_check_public_controller.rb:20:41: error[send_dispatch_failed]: no known method `between?` on Float
./app/controllers/mine_check_public_controller.rb:41:12: error[incompatible_binop]: `<=` with incompatible operand types: Float <= Float?
./app/controllers/mine_check_public_controller.rb:41:53: error[incompatible_binop]: `<=` with incompatible operand types: Float <= Float?
./app/controllers/mine_check_public_controller.rb:73:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/minesweeper_controller.rb:41:50: warning[unresolved_type]: method call `bbox_contains?` has unresolved type
./app/controllers/minesweeper_controller.rb:60:13: error[incompatible_binop]: `/` with incompatible operand types: Integer? / Float
./app/controllers/minesweeper_controller.rb:61:13: error[incompatible_binop]: `/` with incompatible operand types: Integer? / Float
./app/controllers/minesweeper_controller.rb:61:58: error[incompatible_binop]: `/` with incompatible operand types: Float | String / Integer
./app/controllers/minesweeper_controller.rb:62:30: error[incompatible_binop]: `*` with incompatible operand types: Integer? * Integer
./app/controllers/minesweeper_controller.rb:63:29: error[incompatible_binop]: `*` with incompatible operand types: Integer? * Integer
./app/controllers/minesweeper_controller.rb:82:32: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/minesweeper_controller.rb:83:5: error[send_dispatch_failed]: no known method `between?` on Float
./app/controllers/minesweeper_controller.rb:83:18: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/minesweeper_controller.rb:83:24: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/minesweeper_controller.rb:83:33: error[send_dispatch_failed]: no known method `between?` on Float
./app/controllers/minesweeper_controller.rb:83:46: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/minesweeper_controller.rb:83:53: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/moments/likes_controller.rb:31:21: warning[unresolved_type]: method call `redirect_back` has unresolved type
./app/controllers/moments/likes_controller.rb:36:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments/likes_controller.rb:38:7: warning[unresolved_type]: method call `tile_stream` has unresolved type
./app/controllers/moments/likes_controller.rb:39:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments/likes_controller.rb:48:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments/likes_controller.rb:48:40: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments/likes_controller.rb:55:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments/likes_controller.rb:55:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments/likes_controller.rb:59:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments/likes_controller.rb:59:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments/likes_controller.rb:63:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments/likes_controller.rb:63:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments_controller.rb:42:89: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments_controller.rb:48:23: warning[unresolved_type]: method call `redirect_back` has unresolved type
./app/controllers/moments_controller.rb:48:82: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/moments_controller.rb:51:23: warning[unresolved_type]: method call `redirect_back` has unresolved type
./app/controllers/moments_controller.rb:69:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments_controller.rb:72:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments_controller.rb:72:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments_controller.rb:75:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments_controller.rb:78:47: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/moments_controller.rb:86:37: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/moments_controller.rb:92:37: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/moments_controller.rb:98:12: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments_controller.rb:102:21: warning[unresolved_type]: method call `redirect_back` has unresolved type
./app/controllers/moments_controller.rb:102:80: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/moments_controller.rb:105:32: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments_controller.rb:105:52: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/moments_controller.rb:126:21: warning[unresolved_type]: method call `redirect_back` has unresolved type
./app/controllers/moments_controller.rb:126:80: warning[unresolved_type]: local read `notice` has unresolved type
./app/controllers/moments_controller.rb:139:28: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments_controller.rb:139:49: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/moments_controller.rb:143:28: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/controllers/moments_controller.rb:143:49: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/serves_moment_photos.rb:30:5: warning[unresolved_type]: method call `send_data` has unresolved type
./app/controllers/new_design_controller.rb:20:27: error[send_dispatch_failed]: no known method `with_attached_photos` on Relation[Location]
./app/controllers/new_design_controller.rb:30:8: error[ivar_unresolved]: @trending_locations has no known type
./app/controllers/new_design_controller.rb:31:29: error[send_dispatch_failed]: no known method `with_attached_photos` on Relation[Location]
./app/controllers/new_design_controller.rb:60:14: warning[unresolved_type]: method call `Array` has unresolved type
./app/controllers/new_design_controller.rb:60:44: warning[unresolved_type]: local read `x` has unresolved type
./app/controllers/new_design_controller.rb:69:12: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/new_design_controller.rb:70:12: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/new_design_controller.rb:71:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/new_design_controller.rb:72:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/new_design_controller.rb:94:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/new_design_controller.rb:94:20: error[ivar_unresolved]: @types has no known type
./app/controllers/new_design_controller.rb:166:8: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/new_design_controller.rb:170:8: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/new_design_controller.rb:174:8: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/new_design_controller.rb:178:8: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/new_design_controller.rb:225:16: error[incompatible_binop]: `-` with incompatible operand types: Array[Integer] - Array[Moment | Integer]
./app/controllers/new_design_controller.rb:234:28: error[send_dispatch_failed]: no known method `sanitize_sql_array` on ActiveRecord::Base
./app/controllers/new_design_controller.rb:268:34: error[send_dispatch_failed]: no known method `sanitize_sql_array` on ActiveRecord::Base
./app/controllers/new_design_controller.rb:281:13: error[send_dispatch_failed]: no known method `with_attached_photos` on Relation[Location]
./app/controllers/new_design_controller.rb:288:15: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:293:13: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:293:34: error[send_dispatch_failed]: no known method `sanitize_sql_array` on ActiveRecord::Base
./app/controllers/new_design_controller.rb:294:13: warning[unresolved_type]: method call `apply_location_sort` has unresolved type
./app/controllers/new_design_controller.rb:294:33: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:296:5: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:319:34: error[send_dispatch_failed]: no known method `sanitize_sql_array` on ActiveRecord::Base
./app/controllers/new_design_controller.rb:344:34: error[send_dispatch_failed]: no known method `sanitize_sql_array` on ActiveRecord::Base
./app/controllers/new_design_controller.rb:365:13: error[send_dispatch_failed]: no known method `with_attached_photos` on Relation[Location]
./app/controllers/new_design_controller.rb:369:15: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:378:15: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:383:15: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:388:15: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:394:15: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:399:15: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:403:13: warning[unresolved_type]: method call `apply_location_sort` has unresolved type
./app/controllers/new_design_controller.rb:403:33: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:405:5: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:480:7: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:482:7: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:484:7: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:488:27: error[send_dispatch_failed]: no known method `sanitize_sql_like` on ActiveRecord::Base
./app/controllers/new_design_controller.rb:489:9: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:489:30: error[send_dispatch_failed]: no known method `sanitize_sql_array` on ActiveRecord::Base
./app/controllers/new_design_controller.rb:489:133: warning[unresolved_type]: local read `sanitized_query` has unresolved type
./app/controllers/new_design_controller.rb:491:9: warning[unresolved_type]: local read `scope` has unresolved type
./app/controllers/new_design_controller.rb:509:27: error[send_dispatch_failed]: no known method `sanitize_sql_like` on ActiveRecord::Base
./app/controllers/new_design_controller.rb:510:30: error[send_dispatch_failed]: no known method `sanitize_sql_array` on ActiveRecord::Base
./app/controllers/new_design_controller.rb:510:136: warning[unresolved_type]: local read `sanitized_query` has unresolved type
./app/controllers/plans/visits_controller.rb:13:47: warning[unresolved_type]: local read `reason` has unresolved type
./app/controllers/plans/visits_controller.rb:25:12: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/plans/visits_controller.rb:29:12: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/plans/visits_controller.rb:30:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans/visits_controller.rb:32:5: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/plans/visits_controller.rb:37:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans/visits_controller.rb:37:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans/visits_controller.rb:37:40: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans/visits_controller.rb:37:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans/visits_controller.rb:42:21: warning[unresolved_type]: method call `redirect_back` has unresolved type
./app/controllers/plans/visits_controller.rb:42:85: warning[unresolved_type]: local read `alert` has unresolved type
./app/controllers/plans/visits_controller.rb:43:101: warning[unresolved_type]: local read `alert` has unresolved type
./app/controllers/concerns/records_visits.rb:14:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/records_visits.rb:14:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/records_visits.rb:14:35: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/records_visits.rb:18:6: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:59:24: note[send_dispatch_failed]: no known method `near` on Relation[Location] — likely roundhouse coverage, not an app error (the `geocoder` gem is in the Gemfile and roundhouse does not model it)
./app/controllers/plans_controller.rb:64:8: warning[unresolved_type]: local read `nearest_location` has unresolved type
./app/controllers/plans_controller.rb:66:20: warning[unresolved_type]: local read `nearest_location` has unresolved type
./app/controllers/plans_controller.rb:68:15: warning[unresolved_type]: local read `nearest_location` has unresolved type
./app/controllers/plans_controller.rb:69:17: warning[unresolved_type]: local read `nearest_location` has unresolved type
./app/controllers/plans_controller.rb:70:17: warning[unresolved_type]: local read `nearest_location` has unresolved type
./app/controllers/plans_controller.rb:120:58: error[send_dispatch_failed]: no known method `to_sql` on Relation[Experience]
./app/controllers/plans_controller.rb:242:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:272:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:282:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:282:36: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:282:36: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:283:27: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:307:52: warning[unresolved_type]: local read `accessibility_required` has unresolved type
./app/controllers/plans_controller.rb:323:14: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:323:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:323:45: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:333:8: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:351:44: error[send_dispatch_failed]: no known method `to_sql` on Relation[Experience]
./app/controllers/plans_controller.rb:374:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:374:52: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:375:42: warning[unresolved_type]: local read `d` has unresolved type
./app/controllers/plans_controller.rb:376:50: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:387:33: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:388:51: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:424:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:424:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:424:38: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:424:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:424:55: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:425:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:425:21: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:427:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:427:11: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:427:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:427:28: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:427:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:427:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:428:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:428:11: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:428:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:428:28: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:428:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:428:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:438:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:438:31: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:450:21: warning[unresolved_type]: local read `i` has unresolved type
./app/controllers/plans_controller.rb:451:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:451:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:451:29: warning[unresolved_type]: local read `i` has unresolved type
./app/controllers/plans_controller.rb:459:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:459:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:464:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:468:10: warning[unresolved_type]: local read `day` has unresolved type
./app/controllers/plans_controller.rb:472:46: warning[unresolved_type]: local read `day` has unresolved type
./app/controllers/plans_controller.rb:475:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/plans_controller.rb:482:21: warning[unresolved_type]: local read `day` has unresolved type
./app/controllers/plans_controller.rb:483:15: warning[unresolved_type]: local read `day` has unresolved type
./app/controllers/plans_controller.rb:484:33: warning[unresolved_type]: local read `day` has unresolved type
./app/controllers/plans_controller.rb:485:51: warning[unresolved_type]: local read `day` has unresolved type
./app/controllers/plans_controller.rb:486:22: warning[unresolved_type]: local read `day` has unresolved type
./app/controllers/plans_controller.rb:486:73: warning[unresolved_type]: local read `exp` has unresolved type
./app/controllers/plans_controller.rb:494:11: warning[unresolved_type]: local read `exp` has unresolved type
./app/controllers/plans_controller.rb:495:13: warning[unresolved_type]: local read `exp` has unresolved type
./app/controllers/plans_controller.rb:496:14: warning[unresolved_type]: local read `exp` has unresolved type
./app/controllers/plans_controller.rb:497:20: warning[unresolved_type]: local read `exp` has unresolved type
./app/controllers/plans_controller.rb:498:27: warning[unresolved_type]: local read `exp` has unresolved type
./app/controllers/plans_controller.rb:499:27: warning[unresolved_type]: local read `exp` has unresolved type
./app/controllers/plans_controller.rb:500:18: warning[unresolved_type]: local read `exp` has unresolved type
./app/controllers/plans_controller.rb:502:15: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:503:17: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:504:17: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:505:24: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:506:21: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:507:23: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:508:19: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:509:16: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:510:16: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:511:17: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/plans_controller.rb:512:33: warning[unresolved_type]: local read `loc` has unresolved type
./app/controllers/reviews_controller.rb:9:17: error[incompatible_binop]: `<` with incompatible operand types: Integer < Integer?
./app/controllers/reviews_controller.rb:13:12: warning[unresolved_type]: method call `turbo_frame_request?` has unresolved type
./app/controllers/reviews_controller.rb:16:23: warning[unresolved_type]: method call `polymorphic_path` has unresolved type
./app/controllers/reviews_controller.rb:29:23: warning[unresolved_type]: method call `redirect_back` has unresolved type
./app/controllers/reviews_controller.rb:29:75: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/reviews_controller.rb:31:23: warning[unresolved_type]: method call `redirect_back` has unresolved type
./app/controllers/sessions_controller.rb:20:84: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/sessions_controller.rb:26:31: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/sessions_controller.rb:29:61: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/sessions_controller.rb:37:52: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/sessions_controller.rb:48:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/syncs_local_data.rb:14:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/syncs_local_data.rb:15:45: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/syncs_local_data.rb:28:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/concerns/syncs_local_data.rb:36:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/travel_profiles_controller.rb:63:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/travel_profiles_controller.rb:64:11: note[send_dispatch_failed]: no known method `to_unsafe_h` on String? — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/travel_profiles_controller.rb:67:60: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/travel_profiles_controller.rb:73:9: note[send_dispatch_failed]: no known method `error` on Rollbar — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/travel_profiles_controller.rb:74:47: note[unresolved_type]: method call `t` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/travel_profiles_controller.rb:86:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/travel_profiles_controller.rb:87:11: note[send_dispatch_failed]: no known method `to_unsafe_h` on String? — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/travel_profiles_controller.rb:92:32: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/travel_profiles_controller.rb:102:30: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/user_plans_controller.rb:38:44: note[unresolved_type]: local read `x` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/user_plans_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/user_plans_controller.rb:134:8: note[unresolved_type]: local read `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/user_plans_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/user_plans_controller.rb:135:7: note[unresolved_type]: local read `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/user_plans_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/user_plans_controller.rb:139:18: note[unresolved_type]: local read `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/user_plans_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/user_plans_controller.rb:140:29: note[unresolved_type]: local read `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/user_plans_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/user_plans_controller.rb:141:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/user_plans_controller.rb:144:19: note[unresolved_type]: local read `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/user_plans_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/user_plans_controller.rb:145:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/user_plans_controller.rb:146:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/user_plans_controller.rb:149:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/user_plans_controller.rb:150:5: note[send_dispatch_failed]: no known method `error` on Rollbar — likely roundhouse coverage, not an app error (ingest gap in app/controllers/user_plans_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/controllers/users_controller.rb:23:84: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/users_controller.rb:40:64: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/users_controller.rb:51:61: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/users_controller.rb:61:62: warning[unresolved_type]: method call `t` has unresolved type
./app/controllers/users_controller.rb:82:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/controllers/users_controller.rb:89:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/ai_generation.rb:24:53: warning[unresolved_type]: local read `type` has unresolved type
./app/models/ai_generation.rb:37:26: warning[unresolved_type]: local read `locations_count` has unresolved type
./app/models/ai_generation.rb:38:28: warning[unresolved_type]: local read `experiences_count` has unresolved type
./app/models/ai_generation.rb:39:17: error[send_dispatch_failed]: no known method `merge` on String?
./app/models/ai_generation.rb:39:32: warning[unresolved_type]: local read `meta` has unresolved type
./app/models/ai_generation.rb:48:22: warning[unresolved_type]: local read `error` has unresolved type
./app/models/ai_generation.rb:48:50: warning[unresolved_type]: local read `error` has unresolved type
./app/models/ai_generation.rb:48:66: warning[unresolved_type]: local read `error` has unresolved type
./app/models/ai_generation.rb:48:84: warning[unresolved_type]: local read `error` has unresolved type
./app/models/ai_generation.rb:55:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/audio_tour.rb:37:48: warning[unresolved_type]: local read `locale` has unresolved type
./app/models/audio_tour.rb:53:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/audio_tour.rb:59:46: error[incompatible_binop]: `>` with incompatible operand types: Integer? > Integer
./app/models/audio_tour.rb:61:16: error[incompatible_binop]: `/` with incompatible operand types: Integer? / Float
./app/models/audio_tour.rb:82:5: error[send_dispatch_failed]: no known method `associated` on Relation[AudioTour]
./app/models/audio_tour.rb:82:21: warning[unresolved_type]: local read `location` has unresolved type
./app/models/audio_tour.rb:87:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/audio_tour.rb:87:39: warning[unresolved_type]: local read `location` has unresolved type
./app/models/audio_tour.rb:88:5: warning[unresolved_type]: local read `target_locales` has unresolved type
./app/models/audio_tour.rb:88:25: warning[unresolved_type]: local read `x` has unresolved type
./app/models/audio_tour.rb:88:34: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:48:38: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:50:21: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:59:25: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:59:106: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:66:27: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:70:7: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:70:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:70:7: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:71:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/concerns/identifiable.rb:71:9: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/browse.rb:18:19: warning[unresolved_type]: local read `query` has unresolved type
./app/models/browse.rb:20:23: warning[unresolved_type]: method call `sanitize_sql_like` has unresolved type
./app/models/browse.rb:20:41: warning[unresolved_type]: local read `query` has unresolved type
./app/models/browse.rb:23:17: warning[unresolved_type]: method call `sanitize_sql_array` has unresolved type
./app/models/browse.rb:23:96: warning[unresolved_type]: local read `sanitized_query` has unresolved type
./app/models/browse.rb:24:57: warning[unresolved_type]: local read `sanitized_query` has unresolved type
./app/models/browse.rb:25:23: warning[unresolved_type]: local read `order_sql` has unresolved type
./app/models/browse.rb:30:19: warning[unresolved_type]: local read `query` has unresolved type
./app/models/browse.rb:32:19: warning[unresolved_type]: method call `sanitize_sql_like` has unresolved type
./app/models/browse.rb:32:37: warning[unresolved_type]: local read `query` has unresolved type
./app/models/browse.rb:38:19: warning[unresolved_type]: local read `query` has unresolved type
./app/models/browse.rb:40:26: warning[unresolved_type]: local read `query` has unresolved type
./app/models/browse.rb:41:54: warning[unresolved_type]: local read `query` has unresolved type
./app/models/browse.rb:49:19: warning[unresolved_type]: local read `city_name` has unresolved type
./app/models/browse.rb:54:33: warning[unresolved_type]: local read `city_name` has unresolved type
./app/models/browse.rb:64:15: warning[unresolved_type]: local read `city_name` has unresolved type
./app/models/browse.rb:68:15: warning[unresolved_type]: local read `city_name` has unresolved type
./app/models/browse.rb:72:15: warning[unresolved_type]: local read `city_name` has unresolved type
./app/models/browse.rb:85:19: warning[unresolved_type]: local read `min_rating` has unresolved type
./app/models/browse.rb:86:34: warning[unresolved_type]: local read `min_rating` has unresolved type
./app/models/browse.rb:91:19: warning[unresolved_type]: local read `subtype` has unresolved type
./app/models/browse.rb:92:30: warning[unresolved_type]: local read `subtype` has unresolved type
./app/models/browse.rb:98:19: warning[unresolved_type]: local read `budget` has unresolved type
./app/models/browse.rb:99:37: warning[unresolved_type]: local read `budget` has unresolved type
./app/models/browse.rb:106:19: warning[unresolved_type]: local read `category_key` has unresolved type
./app/models/browse.rb:107:35: warning[unresolved_type]: local read `category_key` has unresolved type
./app/models/browse.rb:114:10: warning[unresolved_type]: local read `origin` has unresolved type
./app/models/browse.rb:126:23: warning[unresolved_type]: local read `accessible` has unresolved type
./app/models/browse.rb:126:46: warning[unresolved_type]: local read `accessible` has unresolved type
./app/models/browse.rb:133:19: warning[unresolved_type]: local read `season` has unresolved type
./app/models/browse.rb:134:54: warning[unresolved_type]: local read `season` has unresolved type
./app/models/browse.rb:139:19: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/browse.rb:140:15: warning[unresolved_type]: method call `Array` has unresolved type
./app/models/browse.rb:140:21: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/browse.rb:140:35: warning[unresolved_type]: local read `x` has unresolved type
./app/models/browse.rb:141:18: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/browse.rb:142:39: warning[unresolved_type]: local read `conditions` has unresolved type
./app/models/browse.rb:142:67: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/browse.rb:142:87: warning[unresolved_type]: local read `s` has unresolved type
./app/models/browse.rb:148:19: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/browse.rb:148:33: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/browse.rb:150:11: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/browse.rb:151:11: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/browse.rb:154:17: warning[unresolved_type]: local read `radius_km` has unresolved type
./app/models/browse.rb:155:17: warning[unresolved_type]: local read `radius_km` has unresolved type
./app/models/browse.rb:155:47: error[incompatible_binop]: `*` with incompatible operand types: Float * Math::PI
./app/models/browse.rb:157:21: warning[unresolved_type]: local read `lat_delta` has unresolved type
./app/models/browse.rb:158:21: warning[unresolved_type]: local read `lat_delta` has unresolved type
./app/models/browse.rb:159:21: warning[unresolved_type]: local read `lng_delta` has unresolved type
./app/models/browse.rb:160:21: warning[unresolved_type]: local read `lng_delta` has unresolved type
./app/models/browse.rb:272:10: error[send_dispatch_failed]: no known method `archived?` on Browsable
./app/models/browse.rb:276:9: error[send_dispatch_failed]: no known method `visibility_public_plan?` on Browsable
./app/models/browse.rb:278:9: error[send_dispatch_failed]: no known method `visibility_public_moment?` on Browsable
./app/models/browse.rb:278:45: error[send_dispatch_failed]: no known method `approved?` on Browsable
./app/models/browse.rb:291:23: warning[unresolved_type]: local read `loc` has unresolved type
./app/models/browse.rb:295:50: warning[unresolved_type]: local read `exp` has unresolved type
./app/models/browse.rb:298:58: warning[unresolved_type]: local read `plan` has unresolved type
./app/models/browse.rb:301:66: warning[unresolved_type]: local read `moment` has unresolved type
./app/models/content_change.rb:35:43: warning[unresolved_type]: local read `user` has unresolved type
./app/models/content_change.rb:48:39: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:53:15: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:71:39: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:76:15: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:86:62: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:102:7: error[send_dispatch_failed]: no known method `merge!` on String
./app/models/content_change.rb:102:21: error[send_dispatch_failed]: no known method `compact_blank` on String?
./app/models/content_change.rb:112:12: error[send_dispatch_failed]: no known method `to_sym` on Integer
./app/models/content_change.rb:118:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:123:22: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:125:22: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:131:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:134:71: error[send_dispatch_failed]: no known method `errors` on Changeable?
./app/models/content_change.rb:134:71: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:134:23: error[send_dispatch_failed]: no known method `errors` on Changeable?
./app/models/content_change.rb:144:20: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:146:20: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:152:100: error[send_dispatch_failed]: no known method `title` on Changeable?
./app/models/content_change.rb:154:10: error[send_dispatch_failed]: no known method `to_sym` on Integer
./app/models/content_change.rb:170:5: error[send_dispatch_failed]: no known method `each` on String?
./app/models/content_change.rb:171:33: warning[unresolved_type]: local read `key` has unresolved type
./app/models/content_change.rb:172:23: warning[unresolved_type]: local read `new_value` has unresolved type
./app/models/content_change.rb:173:14: warning[unresolved_type]: local read `key` has unresolved type
./app/models/content_change.rb:173:44: warning[unresolved_type]: local read `new_value` has unresolved type
./app/models/content_change.rb:198:26: error[send_dispatch_failed]: no known method `transform_values` on String?
./app/models/content_change.rb:199:12: warning[unresolved_type]: local read `value` has unresolved type
./app/models/content_change.rb:201:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:201:49: warning[unresolved_type]: local read `value` has unresolved type
./app/models/content_change.rb:203:9: warning[unresolved_type]: local read `value` has unresolved type
./app/models/content_change.rb:203:25: warning[unresolved_type]: local read `v` has unresolved type
./app/models/content_change.rb:203:43: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/content_change.rb:203:83: warning[unresolved_type]: local read `v` has unresolved type
./app/models/content_change.rb:203:114: warning[unresolved_type]: local read `v` has unresolved type
./app/models/content_change.rb:205:9: warning[unresolved_type]: local read `value` has unresolved type
./app/models/content_change.rb:211:13: error[send_dispatch_failed]: no known method `constantize` on String?
./app/models/content_change.rb:213:41: warning[unresolved_type]: local read `klass` has unresolved type
./app/models/content_change.rb:217:8: warning[unresolved_type]: local read `klass` has unresolved type
./app/models/content_change.rb:220:16: warning[unresolved_type]: local read `klass` has unresolved type
./app/models/content_change.rb:223:25: warning[unresolved_type]: local read `record` has unresolved type
./app/models/content_change.rb:226:31: warning[unresolved_type]: local read `record` has unresolved type
./app/models/content_change.rb:238:7: error[send_dispatch_failed]: no known method `update!` on Changeable?
./app/models/content_change.rb:251:7: error[send_dispatch_failed]: no known method `destroy_with_traveller_records!` on Changeable?
./app/models/content_change.rb:253:7: error[send_dispatch_failed]: no known method `destroy!` on Changeable?
./app/models/content_change.rb:263:5: error[send_dispatch_failed]: no known method `update_column` on Changeable?
./app/models/content_change_contribution.rb:20:26: error[send_dispatch_failed]: no known method `transform_values` on String?
./app/models/content_change_contribution.rb:21:12: warning[unresolved_type]: local read `value` has unresolved type
./app/models/content_change_contribution.rb:23:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/content_change_contribution.rb:23:49: warning[unresolved_type]: local read `value` has unresolved type
./app/models/content_change_contribution.rb:25:9: warning[unresolved_type]: local read `value` has unresolved type
./app/models/content_change_contribution.rb:25:25: warning[unresolved_type]: local read `v` has unresolved type
./app/models/content_change_contribution.rb:25:43: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/content_change_contribution.rb:25:83: warning[unresolved_type]: local read `v` has unresolved type
./app/models/content_change_contribution.rb:25:114: warning[unresolved_type]: local read `v` has unresolved type
./app/models/content_change_contribution.rb:27:9: warning[unresolved_type]: local read `value` has unresolved type
./app/models/curator_activity.rb:36:42: warning[unresolved_type]: local read `user` has unresolved type
./app/models/curator_activity.rb:37:48: warning[unresolved_type]: local read `action` has unresolved type
./app/models/curator_activity.rb:39:51: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/curator_activity.rb:47:15: warning[unresolved_type]: local read `action` has unresolved type
./app/models/curator_activity.rb:48:19: warning[unresolved_type]: local read `recordable` has unresolved type
./app/models/curator_activity.rb:49:17: warning[unresolved_type]: local read `metadata` has unresolved type
./app/models/curator_activity.rb:54:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/curator_activity.rb:119:22: error[send_dispatch_failed]: no known method `title` on Recordable?
./app/models/curator_activity.rb:121:16: error[send_dispatch_failed]: no known method `title` on Recordable?
./app/models/curator_activity.rb:123:22: error[send_dispatch_failed]: no known method `location` on Recordable?
./app/models/curator_activity.rb:123:52: error[send_dispatch_failed]: no known method `locale` on Recordable?
./app/models/curator_activity.rb:125:7: error[send_dispatch_failed]: no known method `description` on Recordable?
./app/models/curator_activity.rb:127:20: error[send_dispatch_failed]: no known method `location` on Recordable?
./app/models/curator_application.rb:24:22: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/curator_application.rb:34:20: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/curator_application.rb:36:20: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/curator_review.rb:24:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/concerns/reviewable.rb:15:21: warning[unresolved_type]: local read `days` has unresolved type
./app/models/concerns/reviewable.rb:18:43: warning[unresolved_type]: local read `recent_date` has unresolved type
./app/models/concerns/reviewable.rb:30:39: warning[unresolved_type]: local read `days` has unresolved type
./app/models/experience.rb:31:8: warning[unresolved_type]: local read `category` has unresolved type
./app/models/experience.rb:32:37: warning[unresolved_type]: local read `category` has unresolved type
./app/models/experience.rb:35:50: warning[unresolved_type]: local read `category` has unresolved type
./app/models/experience.rb:44:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:44:30: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/experience.rb:44:35: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/experience.rb:44:51: warning[unresolved_type]: local read `radius_km` has unresolved type
./app/models/experience.rb:50:10: warning[unresolved_type]: local read `duration_filter` has unresolved type
./app/models/experience.rb:64:46: warning[unresolved_type]: local read `min_rating` has unresolved type
./app/models/experience.rb:69:48: warning[unresolved_type]: local read `city_name` has unresolved type
./app/models/experience.rb:74:19: warning[unresolved_type]: local read `season` has unresolved type
./app/models/experience.rb:75:54: warning[unresolved_type]: local read `season` has unresolved type
./app/models/experience.rb:80:19: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/experience.rb:81:15: warning[unresolved_type]: method call `Array` has unresolved type
./app/models/experience.rb:81:21: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/experience.rb:81:35: warning[unresolved_type]: local read `x` has unresolved type
./app/models/experience.rb:82:18: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/experience.rb:83:39: warning[unresolved_type]: local read `conditions` has unresolved type
./app/models/experience.rb:83:67: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/experience.rb:83:87: warning[unresolved_type]: local read `s` has unresolved type
./app/models/experience.rb:104:44: warning[unresolved_type]: local read `location` has unresolved type
./app/models/experience.rb:109:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:110:7: warning[unresolved_type]: local read `location_ids` has unresolved type
./app/models/experience.rb:111:51: warning[unresolved_type]: local read `loc_id` has unresolved type
./app/models/experience.rb:111:77: warning[unresolved_type]: local read `index` has unresolved type
./app/models/experience.rb:123:15: warning[unresolved_type]: local read `uuids` has unresolved type
./app/models/experience.rb:125:45: warning[unresolved_type]: local read `uuids` has unresolved type
./app/models/experience.rb:138:13: error[incompatible_binop]: `/` with incompatible operand types: Integer? / Integer
./app/models/experience.rb:139:15: error[incompatible_binop]: `%` with incompatible operand types: Integer? % Integer
./app/models/experience.rb:179:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:184:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:184:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:184:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:184:40: warning[unresolved_type]: local read `season` has unresolved type
./app/models/experience.rb:189:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:194:14: warning[unresolved_type]: local read `season` has unresolved type
./app/models/experience.rb:196:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:196:21: error[incompatible_binop]: `+` with incompatible operand types: String? + Array[String]
./app/models/experience.rb:196:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:201:20: error[incompatible_binop]: `-` with incompatible operand types: String? - Array[String]
./app/models/experience.rb:201:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:201:32: warning[unresolved_type]: local read `season` has unresolved type
./app/models/experience.rb:211:32: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:212:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/experience.rb:212:18: warning[unresolved_type]: local read `x` has unresolved type
./app/models/experience.rb:234:5: error[send_dispatch_failed]: no known method `photos` on Location?
./app/models/concerns/translatable.rb:54:7: error[send_dispatch_failed]: no known method `translatable_fields=` on Experience
./app/models/concerns/translatable.rb:54:34: warning[unresolved_type]: local read `fields` has unresolved type
./app/models/concerns/translatable.rb:54:46: warning[unresolved_type]: local read `x` has unresolved type
./app/models/concerns/translatable.rb:56:7: warning[unresolved_type]: local read `fields` has unresolved type
./app/models/concerns/translatable.rb:61:11: warning[unresolved_type]: method call `define_method` has unresolved type
./app/models/concerns/translatable.rb:61:28: warning[unresolved_type]: local read `field` has unresolved type
./app/models/concerns/translatable.rb:62:23: warning[unresolved_type]: local read `field` has unresolved type
./app/models/concerns/translatable.rb:66:11: warning[unresolved_type]: method call `define_method` has unresolved type
./app/models/concerns/translatable.rb:66:28: warning[unresolved_type]: local read `field` has unresolved type
./app/models/concerns/translatable.rb:67:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/concerns/translatable.rb:67:29: warning[unresolved_type]: local read `field` has unresolved type
./app/models/concerns/translatable.rb:67:36: warning[unresolved_type]: local read `value` has unresolved type
./app/models/experience_category.rb:36:7: warning[unresolved_type]: local read `ect` has unresolved type
./app/models/experience_category.rb:42:56: warning[unresolved_type]: local read `experience_type` has unresolved type
./app/models/concerns/identifiable.rb:48:38: warning[unresolved_type]: local read `uuid` has unresolved type
./app/models/concerns/identifiable.rb:50:21: warning[unresolved_type]: local read `uuid` has unresolved type
./app/models/concerns/identifiable.rb:59:25: warning[unresolved_type]: local read `uuid` has unresolved type
./app/models/concerns/identifiable.rb:59:106: warning[unresolved_type]: local read `uuid` has unresolved type
./app/models/concerns/identifiable.rb:66:27: warning[unresolved_type]: local read `str` has unresolved type
./app/models/concerns/identifiable.rb:70:7: warning[unresolved_type]: local read `str` has unresolved type
./app/models/concerns/identifiable.rb:71:9: warning[unresolved_type]: local read `str` has unresolved type
./app/models/concerns/translatable.rb:54:7: error[send_dispatch_failed]: no known method `translatable_fields=` on ExperienceCategory
./app/models/experience_location.rb:18:27: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/experience_location.rb:21:10: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/experience_location.rb:24:44: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/experience_location.rb:29:28: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/experience_location.rb:32:25: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/experience_location.rb:42:21: error[incompatible_binop]: `+` with incompatible operand types: Array[ExperienceLocation] | Experience | Integer + Integer
./app/models/experience_type.rb:39:31: warning[unresolved_type]: local read `key` has unresolved type
./app/models/concerns/translatable.rb:54:7: error[send_dispatch_failed]: no known method `translatable_fields=` on ExperienceType
./app/models/like.rb:18:15: warning[unresolved_type]: method call `destroyed_by_association` has unresolved type
./app/models/locale.rb:34:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/locale.rb:35:7: warning[unresolved_type]: local read `hash` has unresolved type
./app/models/locale.rb:35:12: warning[unresolved_type]: local read `locale` has unresolved type
./app/models/locale.rb:36:15: warning[unresolved_type]: local read `locale` has unresolved type
./app/models/locale.rb:37:22: warning[unresolved_type]: local read `locale` has unresolved type
./app/models/locale.rb:38:15: warning[unresolved_type]: local read `locale` has unresolved type
./app/models/location.rb:82:47: warning[unresolved_type]: local read `city_name` has unresolved type
./app/models/location.rb:84:61: warning[unresolved_type]: local read `experience` has unresolved type
./app/models/location.rb:86:51: warning[unresolved_type]: local read `tag` has unresolved type
./app/models/location.rb:143:19: warning[unresolved_type]: local read `category_key` has unresolved type
./app/models/location.rb:147:63: warning[unresolved_type]: local read `category_key` has unresolved type
./app/models/location.rb:154:19: warning[unresolved_type]: local read `type` has unresolved type
./app/models/location.rb:155:45: warning[unresolved_type]: local read `type` has unresolved type
./app/models/location.rb:170:19: warning[unresolved_type]: local read `budget` has unresolved type
./app/models/location.rb:171:28: warning[unresolved_type]: local read `budget` has unresolved type
./app/models/location.rb:178:44: warning[unresolved_type]: local read `min_rating` has unresolved type
./app/models/location.rb:190:19: warning[unresolved_type]: local read `season` has unresolved type
./app/models/location.rb:191:54: warning[unresolved_type]: local read `season` has unresolved type
./app/models/location.rb:196:19: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/location.rb:197:15: warning[unresolved_type]: method call `Array` has unresolved type
./app/models/location.rb:197:21: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/location.rb:197:35: warning[unresolved_type]: local read `x` has unresolved type
./app/models/location.rb:198:18: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/location.rb:199:39: warning[unresolved_type]: local read `conditions` has unresolved type
./app/models/location.rb:199:67: warning[unresolved_type]: local read `seasons` has unresolved type
./app/models/location.rb:199:87: warning[unresolved_type]: local read `s` has unresolved type
./app/models/location.rb:25:5: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/location.rb:25:29: warning[unresolved_type]: local read `photo` has unresolved type
./app/models/location.rb:228:63: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:234:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:258:8: error[send_dispatch_failed]: no known method `loaded?` on Array[ExperienceType]
./app/models/location.rb:269:33: warning[unresolved_type]: method call `Array` has unresolved type
./app/models/location.rb:269:39: warning[unresolved_type]: local read `values` has unresolved type
./app/models/location.rb:269:52: warning[unresolved_type]: local read `x` has unresolved type
./app/models/location.rb:269:64: warning[unresolved_type]: local read `x` has unresolved type
./app/models/location.rb:271:26: error[ivar_unresolved]: @pending_experience_types has no known type
./app/models/location.rb:278:12: warning[unresolved_type]: method call `Array` has unresolved type
./app/models/location.rb:278:29: warning[unresolved_type]: local read `x` has unresolved type
./app/models/location.rb:278:41: warning[unresolved_type]: local read `x` has unresolved type
./app/models/location.rb:278:65: warning[unresolved_type]: local read `x` has unresolved type
./app/models/location.rb:281:13: warning[unresolved_type]: local read `keys` has unresolved type
./app/models/location.rb:282:46: warning[unresolved_type]: local read `key` has unresolved type
./app/models/location.rb:283:9: warning[unresolved_type]: local read `et` has unresolved type
./app/models/location.rb:283:19: warning[unresolved_type]: local read `key` has unresolved type
./app/models/location.rb:284:9: warning[unresolved_type]: local read `et` has unresolved type
./app/models/location.rb:285:9: warning[unresolved_type]: local read `et` has unresolved type
./app/models/location.rb:285:23: error[send_dispatch_failed]: no known method `maximum` on ExperienceType
./app/models/location.rb:290:29: warning[unresolved_type]: local read `types` has unresolved type
./app/models/location.rb:298:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:298:18: error[incompatible_binop]: `+` with incompatible operand types: String? + Array[String]
./app/models/location.rb:298:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:298:27: warning[unresolved_type]: local read `tag` has unresolved type
./app/models/location.rb:303:17: error[incompatible_binop]: `-` with incompatible operand types: String? - Array[String]
./app/models/location.rb:303:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:303:26: warning[unresolved_type]: local read `tag` has unresolved type
./app/models/location.rb:318:9: warning[unresolved_type]: local read `et` has unresolved type
./app/models/location.rb:319:9: warning[unresolved_type]: local read `et` has unresolved type
./app/models/location.rb:320:9: warning[unresolved_type]: local read `et` has unresolved type
./app/models/location.rb:320:23: error[send_dispatch_failed]: no known method `maximum` on ExperienceType
./app/models/location.rb:335:16: warning[unresolved_type]: local read `experience_type_or_key` has unresolved type
./app/models/location.rb:336:7: warning[unresolved_type]: local read `experience_type_or_key` has unresolved type
./app/models/location.rb:337:34: warning[unresolved_type]: local read `experience_type_or_key` has unresolved type
./app/models/location.rb:349:25: warning[unresolved_type]: local read `experience` has unresolved type
./app/models/location.rb:354:28: warning[unresolved_type]: local read `experience` has unresolved type
./app/models/location.rb:359:11: warning[unresolved_type]: local read `experience_type_or_key` has unresolved type
./app/models/location.rb:360:7: warning[unresolved_type]: local read `experience_type_or_key` has unresolved type
./app/models/location.rb:361:7: warning[unresolved_type]: local read `experience_type_or_key` has unresolved type
./app/models/location.rb:368:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:373:20: warning[unresolved_type]: local read `platform` has unresolved type
./app/models/location.rb:375:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:377:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:377:60: warning[unresolved_type]: local read `url` has unresolved type
./app/models/location.rb:382:20: warning[unresolved_type]: local read `platform` has unresolved type
./app/models/location.rb:383:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:388:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:388:18: warning[unresolved_type]: local read `platform` has unresolved type
./app/models/location.rb:395:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:400:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:400:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:400:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:400:40: warning[unresolved_type]: local read `season` has unresolved type
./app/models/location.rb:405:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:410:14: warning[unresolved_type]: local read `season` has unresolved type
./app/models/location.rb:412:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:412:21: error[incompatible_binop]: `+` with incompatible operand types: String + Array[String]
./app/models/location.rb:412:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:417:20: error[incompatible_binop]: `-` with incompatible operand types: String - Array[String]
./app/models/location.rb:417:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:417:32: warning[unresolved_type]: local read `season` has unresolved type
./app/models/location.rb:427:32: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:428:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:428:18: warning[unresolved_type]: local read `x` has unresolved type
./app/models/location.rb:443:5: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:448:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:453:13: warning[unresolved_type]: local read `level` has unresolved type
./app/models/location.rb:455:26: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:465:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:470:15: warning[unresolved_type]: local read `feature` has unresolved type
./app/models/location.rb:472:26: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:472:57: warning[unresolved_type]: local read `value` has unresolved type
./app/models/location.rb:477:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:482:26: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:482:57: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:482:57: warning[unresolved_type]: local read `text` has unresolved type
./app/models/location.rb:491:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:498:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:499:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:520:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:520:48: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/location.rb:520:63: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/location.rb:598:16: warning[unresolved_type]: local read `category_or_key` has unresolved type
./app/models/location.rb:599:7: warning[unresolved_type]: local read `category_or_key` has unresolved type
./app/models/location.rb:600:36: warning[unresolved_type]: local read `category_or_key` has unresolved type
./app/models/location.rb:608:11: warning[unresolved_type]: local read `category_or_key` has unresolved type
./app/models/location.rb:609:7: warning[unresolved_type]: local read `category_or_key` has unresolved type
./app/models/location.rb:610:7: warning[unresolved_type]: local read `category_or_key` has unresolved type
./app/models/location.rb:630:57: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/location.rb:630:71: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/location.rb:630:16: warning[unresolved_type]: local read `attributes` has unresolved type
./app/models/location.rb:630:38: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/location.rb:630:48: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/location.rb:632:29: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/location.rb:632:44: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/location.rb:633:21: warning[unresolved_type]: local read `attributes` has unresolved type
./app/models/location.rb:633:43: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/location.rb:633:58: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/location.rb:642:50: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/location.rb:642:55: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/location.rb:642:60: warning[unresolved_type]: local read `attributes` has unresolved type
./app/models/location.rb:654:19: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/location.rb:654:33: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/location.rb:658:7: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/location.rb:658:18: warning[unresolved_type]: local read `tolerance` has unresolved type
./app/models/location.rb:658:29: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/location.rb:658:40: warning[unresolved_type]: local read `tolerance` has unresolved type
./app/models/location.rb:659:7: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/location.rb:659:18: warning[unresolved_type]: local read `tolerance` has unresolved type
./app/models/location.rb:659:29: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/location.rb:659:40: warning[unresolved_type]: local read `tolerance` has unresolved type
./app/models/location.rb:665:5: note[send_dispatch_failed]: no known method `near` on Relation[Location] — likely roundhouse coverage, not an app error (the `geocoder` gem is in the Gemfile and roundhouse does not model it)
./app/models/location.rb:665:54: warning[unresolved_type]: local read `radius_km` has unresolved type
./app/models/location.rb:677:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:677:44: warning[unresolved_type]: local read `radius_km` has unresolved type
./app/models/location.rb:679:22: warning[unresolved_type]: local read `limit` has unresolved type
./app/models/location.rb:716:5: note[send_dispatch_failed]: no known method `distance_between` on Geocoder::Calculations — likely roundhouse coverage, not an app error (the `geocoder` gem is in the Gemfile and roundhouse does not model it)
./app/models/location.rb:727:72: error[send_dispatch_failed]: no known method `loaded?` on Array[AudioTour]
./app/models/location.rb:743:69: error[send_dispatch_failed]: no known method `loaded?` on Array[AudioTour]
./app/models/location.rb:755:27: warning[unresolved_type]: local read `locale` has unresolved type
./app/models/location.rb:781:32: error[send_dispatch_failed]: no known method `loaded?` on Array[ExperienceType]
./app/models/location.rb:802:71: error[send_dispatch_failed]: no known method `loaded?` on Array[AudioTour]
./app/models/location.rb:822:14: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:823:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:823:10: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:825:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/location.rb:825:66: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/concerns/translatable.rb:54:7: error[send_dispatch_failed]: no known method `translatable_fields=` on Location
./app/models/location_category.rb:34:28: warning[unresolved_type]: local read `key` has unresolved type
./app/models/location_category.rb:38:12: warning[unresolved_type]: local read `key` has unresolved type
./app/models/location_category.rb:39:13: warning[unresolved_type]: local read `name` has unresolved type
./app/models/location_category.rb:39:21: warning[unresolved_type]: local read `key` has unresolved type
./app/models/location_category.rb:40:13: warning[unresolved_type]: local read `icon` has unresolved type
./app/models/location_category.rb:42:17: warning[unresolved_type]: method call `maximum` has unresolved type
./app/models/concerns/translatable.rb:54:7: error[send_dispatch_failed]: no known method `translatable_fields=` on LocationCategory
./app/models/moment.rb:41:60: warning[unresolved_type]: local read `user` has unresolved type
./app/models/moment.rb:41:48: warning[unresolved_type]: local read `user` has unresolved type
./app/models/moment.rb:77:21: warning[unresolved_type]: local read `user` has unresolved type
./app/models/moment.rb:79:28: warning[unresolved_type]: local read `user` has unresolved type
./app/models/moment.rb:95:31: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/photo_suggestion.rb:51:55: warning[unresolved_type]: local read `location` has unresolved type
./app/models/photo_suggestion.rb:24:19: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:26:5: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:28:10: warning[unresolved_type]: local read `photo` has unresolved type
./app/models/photo_suggestion.rb:28:33: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/photo_suggestion.rb:35:40: warning[unresolved_type]: local read `photo` has unresolved type
./app/models/photo_suggestion.rb:42:8: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:57:10: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:58:9: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:59:11: error[send_dispatch_failed]: no known method `photos` on Location?
./app/models/photo_suggestion.rb:59:34: warning[unresolved_type]: local read `photo` has unresolved type
./app/models/photo_suggestion.rb:68:22: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/photo_suggestion.rb:70:22: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/photo_suggestion.rb:76:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/photo_suggestion.rb:87:23: error[send_dispatch_failed]: no known method `open` on URI
./app/models/photo_suggestion.rb:91:39: warning[unresolved_type]: local read `downloaded_file` has unresolved type
./app/models/photo_suggestion.rb:93:5: error[send_dispatch_failed]: no known method `photos` on Location?
./app/models/photo_suggestion.rb:94:11: warning[unresolved_type]: local read `downloaded_file` has unresolved type
./app/models/photo_suggestion.rb:96:43: warning[unresolved_type]: local read `downloaded_file` has unresolved type
./app/models/photo_suggestion.rb:99:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/photo_suggestion.rb:108:20: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/photo_suggestion.rb:110:20: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/photo_suggestion.rb:115:8: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:116:7: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:116:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/photo_suggestion.rb:116:81: warning[unresolved_type]: local read `photo` has unresolved type
./app/models/photo_suggestion.rb:130:8: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:131:7: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:144:22: warning[unresolved_type]: local read `content_type` has unresolved type
./app/models/photo_suggestion.rb:157:28: warning[unresolved_type]: local read `content_type` has unresolved type
./app/models/photo_suggestion.rb:157:54: warning[unresolved_type]: local read `content_type` has unresolved type
./app/models/photo_suggestion.rb:161:12: warning[unresolved_type]: method call `photos` has unresolved type
./app/models/photo_suggestion.rb:169:24: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:128:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:129:43: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:130:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:130:80: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:131:53: warning[unresolved_type]: local read `city_name` has unresolved type
./app/models/plan.rb:132:57: warning[unresolved_type]: local read `city_name` has unresolved type
./app/models/plan.rb:134:43: warning[unresolved_type]: local read `user` has unresolved type
./app/models/plan.rb:160:20: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/plan.rb:160:34: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/plan.rb:163:17: warning[unresolved_type]: local read `radius_km` has unresolved type
./app/models/plan.rb:164:17: warning[unresolved_type]: local read `radius_km` has unresolved type
./app/models/plan.rb:164:47: error[incompatible_binop]: `*` with incompatible operand types: Float * Math::PI
./app/models/plan.rb:164:47: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/plan.rb:166:15: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/plan.rb:166:26: warning[unresolved_type]: local read `lat_delta` has unresolved type
./app/models/plan.rb:167:15: warning[unresolved_type]: local read `lat` has unresolved type
./app/models/plan.rb:167:26: warning[unresolved_type]: local read `lat_delta` has unresolved type
./app/models/plan.rb:168:15: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/plan.rb:168:26: warning[unresolved_type]: local read `lng_delta` has unresolved type
./app/models/plan.rb:169:15: warning[unresolved_type]: local read `lng` has unresolved type
./app/models/plan.rb:169:26: warning[unresolved_type]: local read `lng_delta` has unresolved type
./app/models/plan.rb:188:19: warning[unresolved_type]: local read `query` has unresolved type
./app/models/plan.rb:190:27: warning[unresolved_type]: local read `query` has unresolved type
./app/models/plan.rb:218:10: warning[unresolved_type]: local read `duration_filter` has unresolved type
./app/models/plan.rb:20:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:49:15: warning[unresolved_type]: local read `days_hash` has unresolved type
./app/models/plan.rb:51:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:56:7: warning[unresolved_type]: local read `days_hash` has unresolved type
./app/models/plan.rb:57:17: warning[unresolved_type]: local read `experience_uuids` has unresolved type
./app/models/plan.rb:59:9: warning[unresolved_type]: local read `experience_uuids` has unresolved type
./app/models/plan.rb:60:19: warning[unresolved_type]: local read `uuid` has unresolved type
./app/models/plan.rb:61:49: warning[unresolved_type]: local read `uuid` has unresolved type
./app/models/plan.rb:66:25: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:67:23: warning[unresolved_type]: local read `position` has unresolved type
./app/models/plan.rb:78:12: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:86:15: warning[unresolved_type]: local read `days_hash` has unresolved type
./app/models/plan.rb:88:36: warning[unresolved_type]: local read `days_hash` has unresolved type
./app/models/plan.rb:88:86: warning[unresolved_type]: local read `x` has unresolved type
./app/models/plan.rb:90:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:95:7: warning[unresolved_type]: local read `days_hash` has unresolved type
./app/models/plan.rb:96:17: warning[unresolved_type]: local read `location_uuids` has unresolved type
./app/models/plan.rb:98:9: warning[unresolved_type]: local read `location_uuids` has unresolved type
./app/models/plan.rb:99:19: warning[unresolved_type]: local read `uuid` has unresolved type
./app/models/plan.rb:100:30: warning[unresolved_type]: local read `uuid` has unresolved type
./app/models/plan.rb:105:25: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:106:23: warning[unresolved_type]: local read `position` has unresolved type
./app/models/plan.rb:117:12: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:245:6: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:250:40: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:255:40: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:260:26: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:262:11: warning[unresolved_type]: local read `position` has unresolved type
./app/models/plan.rb:262:45: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:263:41: warning[unresolved_type]: local read `experience` has unresolved type
./app/models/plan.rb:263:65: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:268:42: warning[unresolved_type]: local read `experience` has unresolved type
./app/models/plan.rb:273:38: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:279:80: warning[unresolved_type]: local read `x` has unresolved type
./app/models/plan.rb:280:48: warning[unresolved_type]: local read `id` has unresolved type
./app/models/plan.rb:292:39: warning[unresolved_type]: local read `hash` has unresolved type
./app/models/plan.rb:292:44: warning[unresolved_type]: local read `day` has unresolved type
./app/models/plan.rb:295:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:299:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:302:48: warning[unresolved_type]: local read `day` has unresolved type
./app/models/plan.rb:308:26: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:310:11: warning[unresolved_type]: local read `position` has unresolved type
./app/models/plan.rb:310:54: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:311:37: warning[unresolved_type]: local read `location` has unresolved type
./app/models/plan.rb:311:59: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:316:38: warning[unresolved_type]: local read `location` has unresolved type
./app/models/plan.rb:321:26: warning[unresolved_type]: local read `new_day_number` has unresolved type
./app/models/plan.rb:323:53: warning[unresolved_type]: local read `experience` has unresolved type
./app/models/plan.rb:326:11: warning[unresolved_type]: local read `position` has unresolved type
./app/models/plan.rb:326:45: warning[unresolved_type]: local read `new_day_number` has unresolved type
./app/models/plan.rb:327:33: warning[unresolved_type]: local read `new_day_number` has unresolved type
./app/models/plan.rb:333:23: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:335:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:335:19: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:341:23: warning[unresolved_type]: local read `date` has unresolved type
./app/models/plan.rb:343:6: warning[unresolved_type]: local read `date` has unresolved type
./app/models/plan.rb:353:25: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:358:36: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:376:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:382:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:388:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:393:5: error[send_dispatch_failed]: no known method `map` on Range[Integer]
./app/models/plan.rb:395:21: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:396:28: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:397:42: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:398:38: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:399:48: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:454:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:466:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:468:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:486:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:486:74: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:488:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:493:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:497:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:497:7: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:501:48: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:509:20: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:518:22: warning[unresolved_type]: local read `day_data` has unresolved type
./app/models/plan.rb:519:10: warning[unresolved_type]: local read `day_data` has unresolved type
./app/models/plan.rb:521:53: warning[unresolved_type]: local read `exp_data` has unresolved type
./app/models/plan.rb:524:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:524:58: warning[unresolved_type]: local read `exp_data` has unresolved type
./app/models/plan.rb:536:10: warning[unresolved_type]: local read `day_data` has unresolved type
./app/models/plan.rb:537:49: warning[unresolved_type]: local read `loc_data` has unresolved type
./app/models/plan.rb:540:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:540:56: warning[unresolved_type]: local read `loc_data` has unresolved type
./app/models/plan.rb:578:26: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:583:9: error[send_dispatch_failed]: no known method `[]=` on String?
./app/models/plan.rb:588:47: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:596:22: warning[unresolved_type]: local read `day_data` has unresolved type
./app/models/plan.rb:597:10: warning[unresolved_type]: local read `day_data` has unresolved type
./app/models/plan.rb:599:53: warning[unresolved_type]: local read `exp_data` has unresolved type
./app/models/plan.rb:602:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:602:58: warning[unresolved_type]: local read `exp_data` has unresolved type
./app/models/plan.rb:614:10: warning[unresolved_type]: local read `day_data` has unresolved type
./app/models/plan.rb:615:49: warning[unresolved_type]: local read `loc_data` has unresolved type
./app/models/plan.rb:618:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:618:56: warning[unresolved_type]: local read `loc_data` has unresolved type
./app/models/plan.rb:640:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:642:5: warning[unresolved_type]: local read `result` has unresolved type
./app/models/plan.rb:659:45: warning[unresolved_type]: local read `traveller` has unresolved type
./app/models/plan.rb:662:30: warning[unresolved_type]: local read `traveller` has unresolved type
./app/models/plan.rb:663:25: warning[unresolved_type]: local read `traveller` has unresolved type
./app/models/plan.rb:672:51: warning[unresolved_type]: local read `traveller` has unresolved type
./app/models/plan.rb:672:75: warning[unresolved_type]: local read `x` has unresolved type
./app/models/plan.rb:674:32: warning[unresolved_type]: local read `traveller` has unresolved type
./app/models/plan.rb:675:24: warning[unresolved_type]: local read `visit` has unresolved type
./app/models/plan.rb:680:67: warning[unresolved_type]: local read `visit` has unresolved type
./app/models/plan.rb:680:46: warning[unresolved_type]: local read `visit` has unresolved type
./app/models/plan.rb:682:9: warning[unresolved_type]: local read `visit` has unresolved type
./app/models/plan.rb:693:5: error[send_dispatch_failed]: no known method `map` on Range[Integer]
./app/models/plan.rb:694:50: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:695:56: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:698:21: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:699:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:699:51: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:699:62: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/plan.rb:699:76: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan.rb:734:8: error[incompatible_binop]: `<` with incompatible operand types: Time? < Time?
./app/models/plan.rb:740:12: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:746:41: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/plan.rb:750:39: warning[unresolved_type]: local read `day_number` has unresolved type
./app/models/concerns/translatable.rb:54:7: error[send_dispatch_failed]: no known method `translatable_fields=` on Plan
./app/models/plan_experience.rb:14:51: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan_experience.rb:21:27: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_experience.rb:24:10: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_experience.rb:26:68: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_experience.rb:30:52: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_experience.rb:33:25: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_experience.rb:39:29: warning[unresolved_type]: local read `new_day_number` has unresolved type
./app/models/plan_experience.rb:39:48: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_experience.rb:39:81: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_experience.rb:49:13: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_experience.rb:49:51: warning[unresolved_type]: local read `new_day_number` has unresolved type
./app/models/plan_experience.rb:51:27: warning[unresolved_type]: local read `new_day_number` has unresolved type
./app/models/plan_experience.rb:69:5: error[incompatible_binop]: `+` with incompatible operand types: Array[PlanExperience] | Plan | Integer | Relation[Plan] + Integer
./app/models/plan_location.rb:14:51: warning[unresolved_type]: local read `day_num` has unresolved type
./app/models/plan_location.rb:21:27: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_location.rb:24:10: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_location.rb:26:68: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_location.rb:30:52: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_location.rb:33:25: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_location.rb:39:29: warning[unresolved_type]: local read `new_day_number` has unresolved type
./app/models/plan_location.rb:39:48: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_location.rb:39:81: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_location.rb:49:13: warning[unresolved_type]: local read `new_position` has unresolved type
./app/models/plan_location.rb:49:51: warning[unresolved_type]: local read `new_day_number` has unresolved type
./app/models/plan_location.rb:51:27: warning[unresolved_type]: local read `new_day_number` has unresolved type
./app/models/plan_location.rb:69:5: error[incompatible_binop]: `+` with incompatible operand types: Array[PlanLocation] | Plan | Integer | Relation[Plan] + Integer
./app/models/review.rb:16:48: warning[unresolved_type]: local read `rating` has unresolved type
./app/models/review.rb:24:11: error[send_dispatch_failed]: no known method `reviews` on Reviewable?
./app/models/review.rb:25:5: error[send_dispatch_failed]: no known method `update_column` on Reviewable?
./app/models/setting.rb:17:54: warning[unresolved_type]: local read `category` has unresolved type
./app/models/setting.rb:48:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/setting.rb:50:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/setting.rb:60:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/setting.rb:60:17: warning[unresolved_type]: local read `category` has unresolved type
./app/models/setting.rb:61:7: warning[unresolved_type]: local read `hash` has unresolved type
./app/models/setting.rb:61:12: warning[unresolved_type]: local read `setting` has unresolved type
./app/models/setting.rb:61:27: warning[unresolved_type]: local read `setting` has unresolved type
./app/models/setting.rb:67:5: warning[unresolved_type]: local read `settings_hash` has unresolved type
./app/models/setting.rb:69:9: warning[unresolved_type]: local read `key` has unresolved type
./app/models/setting.rb:70:9: warning[unresolved_type]: local read `config` has unresolved type
./app/models/setting.rb:71:15: warning[unresolved_type]: local read `config` has unresolved type
./app/models/setting.rb:72:19: warning[unresolved_type]: local read `category` has unresolved type
./app/models/setting.rb:73:22: warning[unresolved_type]: local read `config` has unresolved type
./app/models/translation.rb:22:49: warning[unresolved_type]: local read `locale` has unresolved type
./app/models/translation.rb:23:51: warning[unresolved_type]: local read `field` has unresolved type
./app/models/translation.rb:29:16: warning[unresolved_type]: local read `locale` has unresolved type
./app/models/user.rb:66:8: error[incompatible_binop]: `>` with incompatible operand types: Time? > Time
./app/models/user.rb:85:11: error[incompatible_binop]: `>=` with incompatible operand types: Integer? >= Integer
./app/models/user.rb:92:5: warning[unresolved_type]: method call `increment!` has unresolved type
./app/models/user.rb:98:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:98:27: warning[gradual_untyped]: constant read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:123:5: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:123:6: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:123:6: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:130:18: warning[unresolved_type]: local read `x` has unresolved type
./app/models/user.rb:147:37: warning[unresolved_type]: local read `x` has unresolved type
./app/models/user.rb:148:54: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:160:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:162:24: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:162:24: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:162:51: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:164:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:164:38: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:165:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:165:28: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:165:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:166:43: warning[unresolved_type]: local read `item` has unresolved type
./app/models/user.rb:167:46: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:167:46: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:170:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:170:38: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:170:62: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:171:42: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:171:42: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:171:70: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:187:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:188:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:188:15: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:189:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:190:12: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:192:24: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:192:55: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:196:39: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:199:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:199:38: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:206:18: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:212:40: error[incompatible_binop]: `<` with incompatible operand types: Time? < Time
./app/models/user.rb:238:17: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:238:29: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:239:32: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:239:32: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/models/user.rb:248:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/admin/content_changes/index.html.erb:59:42: warning[unresolved_type]: method call `approve_curator_admin_content_change_path` has unresolved type
./app/views/curator/admin/content_changes/index.html.erb:60:41: warning[unresolved_type]: method call `reject_curator_admin_content_change_path` has unresolved type
./app/views/curator/admin/content_changes/show.html.erb:30:73: error[send_dispatch_failed]: no known method `humanize` on Integer
./app/views/curator/admin/content_changes/show.html.erb:35:32: warning[unresolved_type]: method call `approve_curator_admin_content_change_path` has unresolved type
./app/views/curator/admin/content_changes/show.html.erb:43:32: warning[unresolved_type]: method call `reject_curator_admin_content_change_path` has unresolved type
./app/views/curator/admin/content_changes/show.html.erb:71:83: warning[unresolved_type]: local read `key` has unresolved type
./app/views/curator/admin/content_changes/show.html.erb:75:113: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/admin/content_changes/show.html.erb:79:117: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/admin/content_changes/show.html.erb:91:227: error[send_dispatch_failed]: no known method `id` on Changeable?
./app/views/curator/admin/curator_applications/index.html.erb:57:42: warning[unresolved_type]: method call `approve_curator_admin_curator_application_path` has unresolved type
./app/views/curator/admin/curator_applications/index.html.erb:58:41: warning[unresolved_type]: method call `reject_curator_admin_curator_application_path` has unresolved type
./app/views/curator/admin/curator_applications/show.html.erb:33:32: warning[unresolved_type]: method call `approve_curator_admin_curator_application_path` has unresolved type
./app/views/curator/admin/curator_applications/show.html.erb:38:32: warning[unresolved_type]: method call `reject_curator_admin_curator_application_path` has unresolved type
./app/views/curator/admin/photo_suggestions/index.html.erb:40:17: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/index.html.erb:41:27: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/index.html.erb:42:19: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/index.html.erb:44:22: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/show.html.erb:15:13: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/show.html.erb:16:15: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/show.html.erb:18:27: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/show.html.erb:22:16: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/show.html.erb:24:31: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/admin/photo_suggestions/show.html.erb:26:23: warning[unresolved_type]: local read `index` has unresolved type
./app/views/curator/admin/photo_suggestions/show.html.erb:33:66: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/show.html.erb:77:21: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/show.html.erb:78:72: error[send_dispatch_failed]: no known method `photos` on PhotoSuggestion
./app/views/curator/admin/photo_suggestions/show.html.erb:88:32: warning[unresolved_type]: method call `approve_curator_admin_photo_suggestion_path` has unresolved type
./app/views/curator/admin/photo_suggestions/show.html.erb:97:32: warning[unresolved_type]: method call `reject_curator_admin_photo_suggestion_path` has unresolved type
./app/views/curator/admin/users/show.html.erb:52:28: warning[unresolved_type]: method call `unblock_curator_admin_user_path` has unresolved type
./app/views/curator/audio_tours/_form.html.erb:80:30: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/audio_tours/index.html.erb:4:11: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/audio_tours/index.html.erb:11:69: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/audio_tours/index.html.erb:30:12: error[send_dispatch_failed]: no known method `first` on Hash[String, Integer] | Integer?
./app/views/curator/audio_tours/index.html.erb:31:35: warning[unresolved_type]: local read `locale` has unresolved type
./app/views/curator/audio_tours/index.html.erb:31:57: warning[unresolved_type]: local read `count` has unresolved type
./app/views/curator/audio_tours/index.html.erb:98:21: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/audio_tours/index.html.erb:161:17: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/audio_tours/index.html.erb:184:9: error[send_dispatch_failed]: no known method `total_pages` on Relation[AudioTour]
./app/views/curator/audio_tours/show.html.erb:2:74: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/audio_tours/show.html.erb:7:13: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/audio_tours/show.html.erb:84:34: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/dashboard/index.html.erb:66:15: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/dashboard/index.html.erb:84:21: warning[unresolved_type]: method call `needs_photos_curator_locations_path` has unresolved type
./app/views/curator/dashboard/index.html.erb:177:79: error[send_dispatch_failed]: no known method `city_name` on Experience
./app/views/curator/dashboard/index.html.erb:177:110: error[send_dispatch_failed]: no known method `user` on Experience
./app/views/curator/experiences/_experience_item.html.erb:4:16: error[send_dispatch_failed]: no known method `display_cover_photo` on nil
./app/views/curator/experiences/_experience_item.html.erb:5:11: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/experiences/_experience_item.html.erb:6:13: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/experiences/_experience_item.html.erb:7:23: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/experiences/_experience_item.html.erb:8:18: error[send_dispatch_failed]: no known method `title` on nil
./app/views/curator/experiences/_experience_item.html.erb:12:23: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/experiences/_experience_item.html.erb:13:18: error[send_dispatch_failed]: no known method `title` on nil
./app/views/curator/experiences/_experience_item.html.erb:25:11: error[send_dispatch_failed]: no known method `experience_category` on nil
./app/views/curator/experiences/_experience_item.html.erb:28:15: error[send_dispatch_failed]: no known method `experience_category` on nil
./app/views/curator/experiences/_experience_item.html.erb:36:125: error[send_dispatch_failed]: no known method `title` on nil
./app/views/curator/experiences/_experience_item.html.erb:38:11: error[send_dispatch_failed]: no known method `city` on nil
./app/views/curator/experiences/_experience_item.html.erb:43:36: error[send_dispatch_failed]: no known method `city` on nil
./app/views/curator/experiences/_experience_item.html.erb:47:11: error[send_dispatch_failed]: no known method `description` on nil
./app/views/curator/experiences/_experience_item.html.erb:48:101: error[send_dispatch_failed]: no known method `description` on nil
./app/views/curator/experiences/_experience_item.html.erb:53:13: error[send_dispatch_failed]: no known method `average_rating` on nil
./app/views/curator/experiences/_experience_item.html.erb:58:93: error[send_dispatch_failed]: no known method `average_rating` on nil
./app/views/curator/experiences/_experience_item.html.erb:59:68: error[send_dispatch_failed]: no known method `reviews_count` on nil
./app/views/curator/experiences/_experience_item.html.erb:64:13: error[send_dispatch_failed]: no known method `formatted_duration` on nil
./app/views/curator/experiences/_experience_item.html.erb:69:15: error[send_dispatch_failed]: no known method `formatted_duration` on nil
./app/views/curator/experiences/_form.html.erb:44:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/experiences/_form.html.erb:46:79: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/experiences/_form.html.erb:70:25: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/experiences/_form.html.erb:247:29: error[send_dispatch_failed]: no known method `to_json` on String
./app/views/curator/experiences/index.html.erb:4:11: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/experiences/index.html.erb:11:69: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/experiences/index.html.erb:89:53: error[send_dispatch_failed]: no known method `total_count` on Relation[Experience]
./app/views/curator/experiences/index.html.erb:89:91: error[send_dispatch_failed]: no known method `total_count` on Relation[Experience]
./app/views/curator/experiences/index.html.erb:97:46: error[send_dispatch_failed]: no known method `total_count` on Relation[Experience]
./app/views/curator/experiences/index.html.erb:111:11: error[send_dispatch_failed]: no known method `total_pages` on Relation[Experience]
./app/views/curator/experiences/show.html.erb:2:74: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/experiences/show.html.erb:15:13: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/experiences/show.html.erb:49:23: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/experiences/show.html.erb:65:70: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/experiences/show.html.erb:86:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/experiences/show.html.erb:88:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/experiences/show.html.erb:94:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/experiences/show.html.erb:94:49: warning[unresolved_type]: local read `season` has unresolved type
./app/views/curator/experiences/show.html.erb:130:21: error[send_dispatch_failed]: no known method `photos` on Location?
./app/views/curator/experiences/show.html.erb:131:31: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/experiences/show.html.erb:131:47: error[send_dispatch_failed]: no known method `photos` on Location?
./app/views/curator/experiences/show.html.erb:200:109: error[incompatible_binop]: `>` with incompatible operand types: Float? > Integer
./app/views/curator/locations/_form.html.erb:108:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
warning[unresolved_type]: local read `location_categories` has unresolved type
./app/views/curator/locations/_form.html.erb:117:42: warning[unresolved_type]: method call `location_categories` has unresolved type
./app/views/curator/locations/_form.html.erb:122:10: warning[unresolved_type]: method call `location_categories` has unresolved type
./app/views/curator/locations/_form.html.erb:124:66: warning[unresolved_type]: local read `category` has unresolved type
./app/views/curator/locations/_form.html.erb:124:79: error[send_dispatch_failed]: no known method `location_category_ids` on Location
./app/views/curator/locations/_form.html.erb:124:119: warning[unresolved_type]: local read `category` has unresolved type
./app/views/curator/locations/_form.html.erb:125:70: warning[unresolved_type]: local read `category` has unresolved type
./app/views/curator/locations/_form.html.erb:152:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/_form.html.erb:204:74: warning[unresolved_type]: local read `label` has unresolved type
./app/views/curator/locations/_form.html.erb:214:20: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/_form.html.erb:226:34: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/curator/locations/_form.html.erb:228:143: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/curator/locations/_form.html.erb:230:14: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/curator/locations/_form.html.erb:232:29: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/locations/_form.html.erb:232:45: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/locations/_form.html.erb:234:67: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/locations/_form.html.erb:285:117: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/_location_item.html.erb:1:35: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:4:11: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:4:40: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:5:18: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:6:13: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/locations/_location_item.html.erb:7:23: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/locations/_location_item.html.erb:8:18: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:12:23: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/locations/_location_item.html.erb:13:18: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:27:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/_location_item.html.erb:27:33: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:34:125: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:36:11: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:41:36: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:45:11: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:46:101: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:51:13: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:56:93: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:57:68: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_location_item.html.erb:62:66: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_needs_photo_item.html.erb:3:17: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_needs_photo_item.html.erb:3:54: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_needs_photo_item.html.erb:5:70: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_needs_photo_item.html.erb:8:21: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/_needs_photo_item.html.erb:14:58: warning[unresolved_type]: method call `location` has unresolved type
./app/views/curator/locations/index.html.erb:4:11: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/locations/index.html.erb:11:69: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/index.html.erb:97:51: error[send_dispatch_failed]: no known method `total_count` on Relation[Location]
./app/views/curator/locations/index.html.erb:97:87: error[send_dispatch_failed]: no known method `total_count` on Relation[Location]
./app/views/curator/locations/index.html.erb:105:46: error[send_dispatch_failed]: no known method `total_count` on Relation[Location]
./app/views/curator/locations/index.html.erb:119:11: error[send_dispatch_failed]: no known method `total_pages` on Relation[Location]
./app/views/curator/locations/needs_photos.html.erb:14:24: warning[unresolved_type]: method call `needs_photos_curator_locations_path` has unresolved type
./app/views/curator/locations/needs_photos.html.erb:36:40: warning[unresolved_type]: method call `needs_photos_curator_locations_path` has unresolved type
./app/views/curator/locations/needs_photos.html.erb:39:48: error[send_dispatch_failed]: no known method `total_count` on Relation[Location]
./app/views/curator/locations/show.html.erb:2:74: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/show.html.erb:15:13: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/locations/show.html.erb:26:25: warning[unresolved_type]: method call `restore_curator_location_path` has unresolved type
./app/views/curator/locations/show.html.erb:35:25: warning[unresolved_type]: method call `archive_curator_location_path` has unresolved type
./app/views/curator/locations/show.html.erb:74:9: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/curator/locations/show.html.erb:77:146: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/curator/locations/show.html.erb:79:14: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/curator/locations/show.html.erb:80:27: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/locations/show.html.erb:80:43: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/curator/locations/show.html.erb:98:70: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/show.html.erb:104:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/show.html.erb:112:70: error[send_dispatch_failed]: no known method `humanize` on Integer?
./app/views/curator/locations/show.html.erb:208:44: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/show.html.erb:214:24: warning[unresolved_type]: local read `url` has unresolved type
./app/views/curator/locations/show.html.erb:216:106: warning[unresolved_type]: local read `platform` has unresolved type
./app/views/curator/locations/show.html.erb:216:127: warning[unresolved_type]: local read `platform` has unresolved type
./app/views/curator/locations/show.html.erb:218:29: warning[unresolved_type]: local read `url` has unresolved type
./app/views/curator/locations/show.html.erb:218:34: warning[unresolved_type]: local read `url` has unresolved type
./app/views/curator/locations/show.html.erb:244:36: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/show.html.erb:251:19: warning[unresolved_type]: local read `tag` has unresolved type
./app/views/curator/locations/show.html.erb:280:63: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/show.html.erb:301:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/show.html.erb:304:72: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/locations/show.html.erb:317:61: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/moments/index.html.erb:24:27: warning[unresolved_type]: method call `photo_curator_moment_path` has unresolved type
./app/views/curator/moments/index.html.erb:44:61: warning[unresolved_type]: method call `approve_curator_moment_path` has unresolved type
./app/views/curator/moments/index.html.erb:49:60: warning[unresolved_type]: method call `reject_curator_moment_path` has unresolved type
./app/views/curator/photo_suggestions/index.html.erb:6:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:6:9: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:9:12: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:14:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:14:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:15:33: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/photo_suggestions/index.html.erb:15:49: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:15:49: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:17:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:17:25: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:19:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:19:27: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:22:26: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:22:26: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:23:33: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:23:33: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:37:31: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:37:31: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:37:79: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:37:79: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:39:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:39:27: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:54:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:54:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:55:89: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:55:89: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:58:73: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:58:73: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:60:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:60:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:63:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:63:25: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/index.html.erb:73:18: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:16:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:16:13: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:17:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:17:15: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:20:27: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/photo_suggestions/show.html.erb:20:43: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:20:43: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:26:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:26:16: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:28:31: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/curator/photo_suggestions/show.html.erb:28:47: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:31:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:31:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:38:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:38:66: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:40:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:40:16: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:42:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:42:25: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:62:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:62:23: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:62:78: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:62:78: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:64:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:64:19: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:80:65: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:80:65: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:84:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:84:13: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:87:64: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:87:64: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:91:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:91:13: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:94:82: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:94:82: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:98:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:98:13: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:99:45: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:99:45: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:100:46: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:100:46: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:103:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:103:38: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:104:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:104:17: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:106:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:106:17: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:107:40: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:107:40: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:108:68: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/photo_suggestions/show.html.erb:108:68: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/plans/_form.html.erb:84:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/plans/_form.html.erb:99:18: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/plans/_form.html.erb:107:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/plans/_form.html.erb:124:32: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/plans/_form.html.erb:127:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/plans/_form.html.erb:146:89: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/plans/_form.html.erb:149:47: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/plans/_form.html.erb:151:53: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/plans/_form.html.erb:189:95: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/plans/_form.html.erb:192:47: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/plans/_form.html.erb:194:51: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:1:31: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:8:58: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:8:95: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:12:13: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:26:125: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:28:11: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:33:36: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:38:11: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:39:13: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:40:22: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:46:13: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:51:93: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:52:68: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/_plan_item.html.erb:57:66: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/curator/plans/index.html.erb:4:11: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/plans/index.html.erb:11:69: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/plans/index.html.erb:66:47: error[send_dispatch_failed]: no known method `total_count` on Relation[Plan]
./app/views/curator/plans/index.html.erb:66:79: error[send_dispatch_failed]: no known method `total_count` on Relation[Plan]
./app/views/curator/plans/index.html.erb:74:46: error[send_dispatch_failed]: no known method `total_count` on Relation[Plan]
./app/views/curator/plans/index.html.erb:88:11: error[send_dispatch_failed]: no known method `total_pages` on Relation[Plan]
./app/views/curator/plans/show.html.erb:2:74: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/plans/show.html.erb:22:13: note[send_dispatch_failed]: no known method `enabled?` on Flipper — likely roundhouse coverage, not an app error (the `flipper` gem is in the Gemfile and roundhouse does not model it)
./app/views/curator/plans/show.html.erb:106:63: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/plans/show.html.erb:109:119: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/plans/show.html.erb:135:69: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/plans/show.html.erb:138:119: warning[unresolved_type]: local read `day_num` has unresolved type
./app/views/curator/proposals/index.html.erb:72:27: error[incompatible_binop]: `>` with incompatible operand types: Integer? > Integer
./app/views/curator/proposals/index.html.erb:72:52: error[incompatible_binop]: `>` with incompatible operand types: Integer? > Integer
./app/views/curator/proposals/index.html.erb:74:31: error[incompatible_binop]: `>` with incompatible operand types: Integer? > Integer
./app/views/curator/proposals/index.html.erb:82:31: error[incompatible_binop]: `>` with incompatible operand types: Integer? > Integer
./app/views/curator/proposals/show.html.erb:46:25: warning[unresolved_type]: local read `key` has unresolved type
./app/views/curator/proposals/show.html.erb:51:92: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/proposals/show.html.erb:55:89: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/proposals/show.html.erb:64:18: error[send_dispatch_failed]: no known method `each` on String?
./app/views/curator/proposals/show.html.erb:66:88: warning[unresolved_type]: local read `key` has unresolved type
./app/views/curator/proposals/show.html.erb:68:27: warning[unresolved_type]: local read `value` has unresolved type
./app/views/curator/proposals/show.html.erb:69:27: warning[unresolved_type]: local read `value` has unresolved type
./app/views/curator/proposals/show.html.erb:70:30: warning[unresolved_type]: local read `value` has unresolved type
./app/views/curator/proposals/show.html.erb:71:109: warning[unresolved_type]: local read `value` has unresolved type
./app/views/curator/proposals/show.html.erb:73:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/proposals/show.html.erb:73:27: warning[unresolved_type]: local read `value` has unresolved type
./app/views/curator/proposals/show.html.erb:126:30: error[send_dispatch_failed]: no known method `each` on String?
./app/views/curator/proposals/show.html.erb:127:90: warning[unresolved_type]: local read `key` has unresolved type
./app/views/curator/proposals/show.html.erb:127:111: warning[unresolved_type]: local read `value` has unresolved type
./app/views/curator/proposals/show.html.erb:127:132: warning[unresolved_type]: local read `value` has unresolved type
./app/views/curator/proposals/show.html.erb:127:151: warning[unresolved_type]: local read `value` has unresolved type
./app/views/curator/proposals/show.html.erb:205:50: warning[unresolved_type]: method call `add_review_curator_proposal_path` has unresolved type
./app/views/curator/proposals/show.html.erb:282:33: error[send_dispatch_failed]: no known method `title` on Changeable?
./app/views/curator/proposals/show.html.erb:284:33: error[send_dispatch_failed]: no known method `title` on Changeable?
./app/views/curator/proposals/show.html.erb:286:36: error[send_dispatch_failed]: no known method `location` on Changeable?
./app/views/curator/proposals/show.html.erb:286:76: error[send_dispatch_failed]: no known method `locale` on Changeable?
./app/views/curator/reviews/index.html.erb:7:69: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/index.html.erb:95:74: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/index.html.erb:97:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/index.html.erb:102:27: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/index.html.erb:102:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/index.html.erb:102:59: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/index.html.erb:131:9: error[send_dispatch_failed]: no known method `total_pages` on Relation[Review]
./app/views/curator/reviews/show.html.erb:47:70: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/show.html.erb:57:19: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/show.html.erb:57:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/show.html.erb:57:52: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/reviews/show.html.erb:69:70: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_activity_feed.html.erb:14:21: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_activity_feed.html.erb:50:33: warning[unresolved_type]: local read `link_path` has unresolved type
./app/views/curator/shared/_activity_icon.html.erb:2:9: warning[unresolved_type]: method call `activity` has unresolved type
./app/views/curator/shared/_pending_proposal_banner.html.erb:4:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposal_banner.html.erb:19:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposal_banner.html.erb:20:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposal_banner.html.erb:21:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposal_banner.html.erb:23:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposal_banner.html.erb:25:68: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposal_banner.html.erb:30:45: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposals.html.erb:1:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposals.html.erb:10:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposals.html.erb:15:12: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposals.html.erb:18:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposals.html.erb:18:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposals.html.erb:33:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposals.html.erb:33:21: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposals.html.erb:37:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/curator/shared/_pending_proposals.html.erb:37:19: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/experiences/show.html.erb:6:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/experiences/show.html.erb:49:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/experiences/show.html.erb:152:58: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/experiences/show.html.erb:185:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/experiences/show.html.erb:185:29: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/experiences/show.html.erb:225:33: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/experiences/show.html.erb:227:45: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/experiences/show.html.erb:435:64: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/experiences/show.html.erb:459:65: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/_deck_cards.html.erb:9:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/_deck_cards.html.erb:11:27: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/_deck_cards.html.erb:11:61: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/_deck_cards.html.erb:11:61: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/_filters.html.erb:8:35: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/_filters.html.erb:12:35: warning[unresolved_type]: method call `lat` has unresolved type
./app/views/explore_bosnia/_filters.html.erb:13:35: warning[unresolved_type]: method call `lng` has unresolved type
./app/views/explore_bosnia/_filters.html.erb:21:35: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/_filters.html.erb:44:19: warning[unresolved_type]: local read `label` has unresolved type
./app/views/explore_bosnia/_filters.html.erb:54:57: warning[unresolved_type]: method call `lat` has unresolved type
./app/views/explore_bosnia/_filters.html.erb:54:67: warning[unresolved_type]: method call `lng` has unresolved type
./app/views/explore_bosnia/experience.html.erb:1:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/experience.html.erb:1:44: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/experience.html.erb:1:98: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/experience.html.erb:56:18: error[ivar_unresolved]: @lat has no known type
./app/views/explore_bosnia/experience.html.erb:56:29: error[ivar_unresolved]: @lng has no known type
./app/views/explore_bosnia/experience.html.erb:57:25: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/experience.html.erb:69:20: error[ivar_unresolved]: @lat has no known type
./app/views/explore_bosnia/experience.html.erb:69:31: error[ivar_unresolved]: @lng has no known type
./app/views/explore_bosnia/experience.html.erb:70:27: warning[gradual_untyped]: ivar read resolves to RBS `untyped` (gradual escape)
./app/views/explore_bosnia/experience.turbo_stream.erb:5:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/explore_bosnia/experience.turbo_stream.erb:10:5: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/layouts/application.html.erb:9:9: note[unresolved_type]: method call `content_for?` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/layouts/application.html.erb:9:52: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/layouts/new_design.html.erb:8:9: note[unresolved_type]: method call `content_for?` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/layouts/new_design.html.erb:8:52: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/_gone_panel.html.erb:24:61: warning[unresolved_type]: method call `message` has unresolved type
./app/views/locations/_map_panel.html.erb:6:13: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:7:23: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:20:71: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:20:91: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:30:35: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:32:17: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:36:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/_map_panel.html.erb:36:37: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:36:61: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:38:15: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:40:54: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:42:41: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:48:13: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:51:17: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:58:37: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:59:53: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:69:20: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/_map_panel.html.erb:78:61: warning[unresolved_type]: method call `location` has unresolved type
./app/views/locations/audio_tour.html.erb:61:49: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/locations/audio_tour.html.erb:87:30: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/locations/show.html.erb:5:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:8:16: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/locations/show.html.erb:8:65: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/locations/show.html.erb:19:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:53:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:64:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:175:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:176:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:176:9: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:187:90: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:187:90: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:202:14: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:204:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:206:171: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:207:76: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:207:76: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:208:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:208:29: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:208:174: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:208:174: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:214:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:214:50: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:214:84: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:246:31: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:246:31: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:247:21: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:249:58: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:272:56: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:272:102: warning[unresolved_type]: local read `h` has unresolved type
./app/views/locations/show.html.erb:272:104: warning[unresolved_type]: local read `t` has unresolved type
./app/views/locations/show.html.erb:272:116: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/locations/show.html.erb:272:132: warning[unresolved_type]: local read `t` has unresolved type
./app/views/locations/show.html.erb:310:53: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/locations/show.html.erb:333:34: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/locations/show.html.erb:401:75: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:418:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:423:27: warning[unresolved_type]: local read `tag` has unresolved type
./app/views/locations/show.html.erb:451:67: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:470:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:473:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:528:27: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/locations/show.html.erb:529:37: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/locations/show.html.erb:545:86: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/locations/show.html.erb:645:64: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/minesweeper/show.html.erb:46:44: warning[unresolved_type]: local read `level` has unresolved type
./app/views/minesweeper/show.html.erb:46:100: warning[unresolved_type]: local read `level` has unresolved type
./app/views/minesweeper/show.html.erb:47:86: warning[unresolved_type]: local read `level` has unresolved type
./app/views/moments/update.turbo_stream.erb:5:54: warning[unresolved_type]: method call `location` has unresolved type
./app/views/moments/update.turbo_stream.erb:9:52: warning[unresolved_type]: method call `location` has unresolved type
./app/views/moments/update.turbo_stream.erb:11:71: warning[unresolved_type]: method call `location` has unresolved type
./app/views/moments/update.turbo_stream.erb:14:5: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/moments/update.turbo_stream.erb:14:33: warning[unresolved_type]: method call `location` has unresolved type
./app/views/moments/update.turbo_stream.erb:17:19: warning[unresolved_type]: method call `location` has unresolved type
./app/views/moments/update.turbo_stream.erb:26:5: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/moments/update.turbo_stream.erb:26:33: warning[unresolved_type]: method call `location` has unresolved type
./app/views/moments/update.turbo_stream.erb:27:23: warning[unresolved_type]: method call `location` has unresolved type
./app/views/moments/update.turbo_stream.erb:30:21: warning[unresolved_type]: method call `location` has unresolved type
./app/views/moments/update.turbo_stream.erb:32:53: warning[unresolved_type]: method call `location` has unresolved type
./app/views/moments/update.turbo_stream.erb:40:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/moments/update.turbo_stream.erb:48:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/new_design/_header.html.erb:111:16: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/_header.html.erb:112:43: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/new_design/_header.html.erb:113:71: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/new_design/_header.html.erb:114:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/new_design/_header.html.erb:121:33: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_experiences_items.html.erb:1:4: warning[unresolved_type]: method call `experiences` has unresolved type
./app/views/new_design/explore/_experiences_items.html.erb:2:64: warning[unresolved_type]: local read `experience` has unresolved type
./app/views/new_design/explore/_location_card.html.erb:8:11: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/new_design/explore/_location_card.html.erb:8:40: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/new_design/explore/_location_card.html.erb:9:18: error[send_dispatch_failed]: no known method `photos` on Location
./app/views/new_design/explore/_location_card.html.erb:10:13: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/new_design/explore/_location_card.html.erb:11:23: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/new_design/explore/_location_card.html.erb:16:23: warning[unresolved_type]: local read `photo` has unresolved type
./app/views/new_design/explore/_locations_items.html.erb:1:4: warning[unresolved_type]: method call `locations` has unresolved type
./app/views/new_design/explore/_locations_items.html.erb:2:60: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/explore/_moment_card.html.erb:36:92: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/new_design/explore/_moment_card.html.erb:46:74: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_moment_card.html.erb:53:78: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_moment_card_body.html.erb:8:11: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_body.html.erb:11:11: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_body.html.erb:16:36: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_body.html.erb:22:31: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_body.html.erb:29:9: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_body.html.erb:30:91: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_body.html.erb:34:66: warning[unresolved_type]: method call `byline` has unresolved type
./app/views/new_design/explore/_moment_card_likes.html.erb:3:24: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/new_design/explore/_moment_card_likes.html.erb:3:40: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_likes.html.erb:4:9: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_likes.html.erb:6:40: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_likes.html.erb:11:18: warning[unresolved_type]: method call `moment_like_path` has unresolved type
./app/views/new_design/explore/_moment_card_likes.html.erb:11:35: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_likes.html.erb:11:52: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/new_design/explore/_moment_card_likes.html.erb:32:13: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moment_card_likes.html.erb:32:44: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_moments_items.html.erb:1:4: warning[unresolved_type]: method call `moments` has unresolved type
./app/views/new_design/explore/_moments_items.html.erb:2:56: warning[unresolved_type]: local read `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:3:28: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:7:44: warning[unresolved_type]: method call `photo_plan_moment_path` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:7:67: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:7:80: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:8:50: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:9:31: warning[unresolved_type]: method call `photo_plan_moment_path` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:9:54: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:9:67: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:11:19: warning[unresolved_type]: method call `photo_plan_moment_path` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:11:42: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:11:55: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:12:16: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:16:22: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:16:94: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:17:11: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:17:81: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:21:61: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:24:64: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_my_moment_card.html.erb:26:64: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_my_moment_card.html.erb:26:83: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/new_design/explore/_plan_card.html.erb:46:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_plan_card.html.erb:49:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_plan_card.html.erb:50:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_plan_card.html.erb:56:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_plan_card.html.erb:56:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_plan_card.html.erb:56:121: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore/_plans_items.html.erb:1:4: warning[unresolved_type]: method call `plans` has unresolved type
./app/views/new_design/explore/_plans_items.html.erb:2:52: warning[unresolved_type]: local read `plan` has unresolved type
./app/views/new_design/explore.html.erb:13:11: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore.html.erb:15:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore.html.erb:99:41: error[ivar_unresolved]: @types has no known type
./app/views/new_design/explore.html.erb:115:41: error[ivar_unresolved]: @types has no known type
./app/views/new_design/explore.html.erb:131:41: error[ivar_unresolved]: @types has no known type
./app/views/new_design/explore.html.erb:147:41: error[ivar_unresolved]: @types has no known type
./app/views/new_design/explore.html.erb:190:43: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore.html.erb:191:44: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore.html.erb:192:44: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore.html.erb:193:44: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore.html.erb:194:45: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/explore.html.erb:249:29: warning[unresolved_type]: local read `label` has unresolved type
./app/views/new_design/explore.html.erb:286:58: warning[unresolved_type]: local read `symbol` has unresolved type
./app/views/new_design/explore.html.erb:286:79: warning[unresolved_type]: local read `label` has unresolved type
./app/views/new_design/explore.html.erb:325:29: warning[unresolved_type]: local read `label` has unresolved type
./app/views/new_design/explore.html.erb:365:29: warning[unresolved_type]: local read `label` has unresolved type
./app/views/new_design/explore.html.erb:409:29: warning[unresolved_type]: local read `label` has unresolved type
./app/views/new_design/explore.html.erb:446:29: warning[unresolved_type]: local read `label` has unresolved type
./app/views/new_design/explore.html.erb:530:30: error[send_dispatch_failed]: no known method `total_count` on Relation[Location]
./app/views/new_design/explore.html.erb:530:55: error[send_dispatch_failed]: no known method `total_count` on Relation[Experience]
./app/views/new_design/explore.html.erb:530:82: error[send_dispatch_failed]: no known method `total_count` on Relation[Plan]
./app/views/new_design/explore.html.erb:530:103: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:530:126: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:531:51: warning[unresolved_type]: local read `total_count` has unresolved type
./app/views/new_design/explore.html.erb:540:56: error[send_dispatch_failed]: no known method `total_count` on Relation[Location]
./app/views/new_design/explore.html.erb:548:90: error[send_dispatch_failed]: no known method `total_count` on Relation[Location]
./app/views/new_design/explore.html.erb:556:21: error[send_dispatch_failed]: no known method `total_count` on Relation[Location]
./app/views/new_design/explore.html.erb:584:56: error[send_dispatch_failed]: no known method `total_count` on Relation[Experience]
./app/views/new_design/explore.html.erb:592:92: error[send_dispatch_failed]: no known method `total_count` on Relation[Experience]
./app/views/new_design/explore.html.erb:600:21: error[send_dispatch_failed]: no known method `total_count` on Relation[Experience]
./app/views/new_design/explore.html.erb:628:56: error[send_dispatch_failed]: no known method `total_count` on Relation[Plan]
./app/views/new_design/explore.html.erb:636:86: error[send_dispatch_failed]: no known method `total_count` on Relation[Plan]
./app/views/new_design/explore.html.erb:644:21: error[send_dispatch_failed]: no known method `total_count` on Relation[Plan]
./app/views/new_design/explore.html.erb:670:54: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:677:56: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:685:91: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:693:58: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:695:21: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:721:54: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:728:56: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:737:88: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:746:58: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:747:21: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/new_design/explore.html.erb:779:40: error[ivar_unresolved]: @types has no known type
./app/views/new_design/home.html.erb:13:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/home.html.erb:14:33: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/new_design/home.html.erb:15:21: error[send_dispatch_failed]: no known method `shuffle` on Array[String]
./app/views/new_design/home.html.erb:16:19: warning[unresolved_type]: local read `shuffled_images` has unresolved type
./app/views/new_design/home.html.erb:17:26: warning[unresolved_type]: local read `shuffled_images` has unresolved type
./app/views/new_design/home.html.erb:17:48: warning[unresolved_type]: local read `shuffled_images` has unresolved type
./app/views/new_design/home.html.erb:18:26: warning[unresolved_type]: local read `shuffled_images` has unresolved type
./app/views/new_design/home.html.erb:18:48: warning[unresolved_type]: local read `shuffled_images` has unresolved type
./app/views/new_design/home.html.erb:18:74: warning[unresolved_type]: local read `shuffled_images` has unresolved type
./app/views/new_design/home.html.erb:76:53: warning[unresolved_type]: local read `random_images` has unresolved type
./app/views/new_design/home.html.erb:82:53: warning[unresolved_type]: local read `random_images` has unresolved type
./app/views/new_design/home.html.erb:86:53: warning[unresolved_type]: local read `random_images` has unresolved type
./app/views/new_design/home.html.erb:92:53: warning[unresolved_type]: local read `random_images` has unresolved type
./app/views/new_design/home.html.erb:96:53: warning[unresolved_type]: local read `random_images` has unresolved type
./app/views/new_design/home.html.erb:157:53: warning[unresolved_type]: local read `bento_location_image` has unresolved type
./app/views/new_design/home.html.erb:292:38: error[send_dispatch_failed]: no known method `each` on String
./app/views/new_design/home.html.erb:293:100: warning[unresolved_type]: local read `item` has unresolved type
./app/views/new_design/home.html.erb:318:38: error[send_dispatch_failed]: no known method `each` on String
./app/views/new_design/home.html.erb:319:100: warning[unresolved_type]: local read `item` has unresolved type
./app/views/new_design/home.html.erb:343:38: error[send_dispatch_failed]: no known method `each` on String
./app/views/new_design/home.html.erb:344:100: warning[unresolved_type]: local read `item` has unresolved type
./app/views/new_design/home.html.erb:368:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/home.html.erb:369:25: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/new_design/home.html.erb:385:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/new_design/home.html.erb:386:19: error[send_dispatch_failed]: no known method `shuffle` on Array[String]
./app/views/new_design/home.html.erb:386:31: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/new_design/home.html.erb:451:39: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/new_design/home.html.erb:470:41: warning[unresolved_type]: method call `polymorphic_path` has unresolved type
./app/views/new_design/home.html.erb:481:39: error[send_dispatch_failed]: no known method `translate` on Reviewable?
./app/views/new_design/home.html.erb:481:90: error[send_dispatch_failed]: no known method `translate` on Reviewable?
./app/views/new_design/home.html.erb:485:39: error[send_dispatch_failed]: no known method `title` on Reviewable?
./app/views/new_design/home.html.erb:527:19: warning[unresolved_type]: local read `season_images` has unresolved type
./app/views/new_design/home.html.erb:529:61: warning[unresolved_type]: local read `season_images` has unresolved type
./app/views/new_design/home.html.erb:533:63: warning[unresolved_type]: local read `season_images` has unresolved type
./app/views/new_design/home.html.erb:536:63: warning[unresolved_type]: local read `season_images` has unresolved type
./app/views/new_design/home.html.erb:539:63: warning[unresolved_type]: local read `season_images` has unresolved type
./app/views/new_design/home.html.erb:545:51: warning[unresolved_type]: local read `random_images` has unresolved type
./app/views/new_design/home.html.erb:549:53: warning[unresolved_type]: local read `random_images` has unresolved type
./app/views/new_design/home.html.erb:552:53: warning[unresolved_type]: local read `random_images` has unresolved type
./app/views/new_design/home.html.erb:555:53: warning[unresolved_type]: local read `random_images` has unresolved type
./app/views/new_design/home.html.erb:565:11: error[ivar_unresolved]: @trending_locations has no known type
./app/views/new_design/home.html.erb:571:14: error[ivar_unresolved]: @trending_locations has no known type
./app/views/new_design/home.html.erb:573:19: warning[unresolved_type]: local read `index` has unresolved type
./app/views/new_design/home.html.erb:576:43: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:577:25: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:578:35: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/new_design/home.html.erb:578:51: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:578:97: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:594:106: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:595:115: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:597:29: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:602:125: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:605:29: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:606:84: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:615:22: warning[unresolved_type]: local read `index` has unresolved type
./app/views/new_design/home.html.erb:618:43: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:619:25: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:620:35: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/new_design/home.html.erb:620:51: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:620:97: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:636:106: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:637:115: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:639:29: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:644:125: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:647:29: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:648:84: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:657:22: warning[unresolved_type]: local read `index` has unresolved type
./app/views/new_design/home.html.erb:660:43: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:661:25: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:662:35: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/new_design/home.html.erb:662:51: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:662:97: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:678:106: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:679:115: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:681:29: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:686:125: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:689:29: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:690:84: warning[unresolved_type]: local read `location` has unresolved type
./app/views/new_design/home.html.erb:707:33: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/new_design/home.html.erb:744:33: error[ivar_unresolved]: @trending_locations has no known type
./app/views/new_design/home.html.erb:775:17: warning[unresolved_type]: local read `cta_background_image` has unresolved type
./app/views/new_design/home.html.erb:776:47: warning[unresolved_type]: local read `cta_background_image` has unresolved type
./app/views/pages/privacy.html.erb:70:83: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/pages/terms.html.erb:70:81: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery.html.erb:11:12: error[send_dispatch_failed]: no known method `total_count` on Array[Moment]
./app/views/plans/_moment_gallery.html.erb:11:34: error[send_dispatch_failed]: no known method `total_count` on Relation[Moment]
./app/views/plans/_moment_gallery.html.erb:16:42: warning[unresolved_type]: local read `total` has unresolved type
./app/views/plans/_moment_gallery.html.erb:18:58: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_moment_gallery.html.erb:21:44: warning[unresolved_type]: local read `total` has unresolved type
./app/views/plans/_moment_gallery.html.erb:32:70: warning[unresolved_type]: local read `total` has unresolved type
./app/views/plans/_moment_gallery.html.erb:36:13: warning[unresolved_type]: local read `total` has unresolved type
./app/views/plans/_moment_gallery.html.erb:50:69: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_moment_gallery.html.erb:60:9: warning[unresolved_type]: local read `total` has unresolved type
./app/views/plans/_moment_gallery.html.erb:80:9: warning[unresolved_type]: local read `total` has unresolved type
./app/views/plans/_moment_gallery.html.erb:87:83: warning[unresolved_type]: local read `total` has unresolved type
./app/views/plans/_moment_gallery.html.erb:87:46: warning[unresolved_type]: local read `total` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:4:25: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:5:19: warning[unresolved_type]: method call `photo_plan_moment_path` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:5:42: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:5:55: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:5:69: warning[unresolved_type]: method call `tile` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:5:92: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:5:129: warning[unresolved_type]: method call `tile` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:6:18: warning[unresolved_type]: method call `photo_plan_moment_path` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:6:41: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:6:54: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:6:87: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:7:22: warning[unresolved_type]: method call `photo_plan_moment_path` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:7:45: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:7:58: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:7:110: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:7:126: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:8:40: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:8:58: warning[unresolved_type]: method call `tile` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:13:50: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:13:104: warning[unresolved_type]: local read `download` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:16:36: warning[unresolved_type]: method call `tile` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:20:24: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:20:96: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:21:13: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:21:83: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:26:67: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:27:13: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:27:33: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:32:15: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:38:17: warning[unresolved_type]: method call `tile` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:40:13: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:41:55: warning[unresolved_type]: method call `publish_plan_moment_path` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:41:80: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:41:93: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:42:50: warning[unresolved_type]: method call `context` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:45:69: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:45:82: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/plans/_moment_gallery_item.html.erb:46:49: warning[unresolved_type]: method call `context` has unresolved type
./app/views/plans/_moment_gallery_items.html.erb:3:10: warning[unresolved_type]: method call `moments` has unresolved type
./app/views/plans/_moment_gallery_items.html.erb:3:31: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery_items.html.erb:3:31: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery_items.html.erb:3:62: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery_items.html.erb:3:62: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery_items.html.erb:3:101: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery_items.html.erb:3:101: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery_items.html.erb:4:13: warning[unresolved_type]: method call `public_moments` has unresolved type
./app/views/plans/_moment_gallery_items.html.erb:4:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery_items.html.erb:4:41: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery_items.html.erb:6:51: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_gallery_items.html.erb:6:68: warning[unresolved_type]: method call `context` has unresolved type
./app/views/plans/_moment_gallery_items.html.erb:6:83: warning[unresolved_type]: method call `tile` has unresolved type
./app/views/plans/_moment_instant_form.html.erb:8:12: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_moment_instant_form.html.erb:17:38: warning[unresolved_type]: method call `plan` has unresolved type
./app/views/plans/_moment_instant_form.html.erb:21:47: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_plan_location.html.erb:13:35: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_plan_location.html.erb:23:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_plan_location.html.erb:25:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_plan_location.html.erb:28:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_plan_location.html.erb:28:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_plan_location.html.erb:28:58: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_plan_location.html.erb:28:91: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/_plan_step.html.erb:4:20: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_plan_step.html.erb:7:21: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_plan_step.html.erb:27:55: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_plan_step.html.erb:28:23: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_plan_step.html.erb:30:37: warning[unresolved_type]: local read `location_name` has unresolved type
./app/views/plans/_plan_step.html.erb:36:82: warning[unresolved_type]: local read `location_name` has unresolved type
./app/views/plans/_plan_step.html.erb:50:23: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_plan_step.html.erb:50:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_plan_step.html.erb:50:58: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_plan_step.html.erb:69:47: warning[unresolved_type]: method call `location` has unresolved type
./app/views/plans/_walk_card.html.erb:17:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_walk_card.html.erb:18:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/_walk_card.html.erb:50:72: warning[unresolved_type]: method call `rails_blob_path` has unresolved type
./app/views/plans/show.html.erb:11:7: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:54:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:229:12: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:234:51: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:234:51: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:236:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:236:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:241:58: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:241:58: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:245:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:245:21: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:247:25: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:247:25: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:247:59: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:247:59: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:252:19: warning[gradual_untyped]: expression resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:252:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:252:19: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:252:45: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:252:45: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:255:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:255:22: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:257:35: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:257:42: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:257:42: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:257:75: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:257:75: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:267:52: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:267:52: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:268:35: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:269:59: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:270:47: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:270:47: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:270:186: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:270:186: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:273:59: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:283:59: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:285:39: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:285:39: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:288:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:288:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:290:39: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:290:39: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:295:39: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:295:39: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:300:41: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:300:41: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:303:39: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:303:39: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:308:63: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:308:63: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:314:35: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:314:35: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:319:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:319:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:328:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:328:22: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:329:65: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:329:85: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:329:93: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:329:93: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:377:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:377:66: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:377:66: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:378:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:378:15: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:379:34: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:379:75: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:379:75: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:380:34: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:380:34: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:380:60: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:380:81: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:380:81: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:381:28: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:382:26: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:394:30: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:394:30: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:395:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:395:29: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:396:23: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:396:23: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:396:38: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:396:58: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:396:58: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:396:73: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:411:22: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:412:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:412:38: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:413:39: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:413:58: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:414:40: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:414:40: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:414:54: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:415:36: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:415:68: error[incompatible_binop]: `>` with incompatible operand types: Float | Integer? > Integer
./app/views/plans/show.html.erb:417:115: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:417:115: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:421:48: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:422:38: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:422:38: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:423:37: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:423:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:424:29: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:424:29: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:424:46: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:424:68: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:424:68: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:424:84: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:424:97: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/show.html.erb:484:64: error[send_dispatch_failed]: no known method `any?` on String
./app/views/plans/show.html.erb:494:26: error[send_dispatch_failed]: no known method `each` on String
./app/views/plans/show.html.erb:496:56: warning[unresolved_type]: local read `interest` has unresolved type
./app/views/plans/show.html.erb:496:77: warning[unresolved_type]: local read `interest` has unresolved type
./app/views/plans/start.html.erb:41:69: error[send_dispatch_failed]: no known method `distance` on Location
./app/views/plans/wizard.html.erb:357:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/wizard.html.erb:360:35: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/plans/wizard.html.erb:361:36: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/reviews/_form.html.erb:4:21: warning[unresolved_type]: method call `reviewable` has unresolved type
./app/views/reviews/_form.html.erb:11:25: warning[unresolved_type]: method call `reviewable` has unresolved type
./app/views/reviews/_form.html.erb:11:37: warning[unresolved_type]: method call `review` has unresolved type
./app/views/reviews/_form.html.erb:11:64: warning[unresolved_type]: method call `reviewable` has unresolved type
./app/views/reviews/_form.html.erb:12:11: warning[unresolved_type]: method call `review` has unresolved type
./app/views/reviews/_form.html.erb:15:15: warning[unresolved_type]: method call `review` has unresolved type
./app/views/reviews/_form.html.erb:37:83: warning[unresolved_type]: method call `review` has unresolved type
./app/views/reviews/_review_card.html.erb:9:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/reviews/_reviews_section.html.erb:7:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/reviews/_reviews_section.html.erb:9:14: error[incompatible_binop]: `>` with incompatible operand types: Integer? > Integer
./app/views/reviews/_reviews_section.html.erb:10:18: warning[unresolved_type]: method call `polymorphic_path` has unresolved type
./app/views/reviews/_reviews_section.html.erb:29:9: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/reviews/_reviews_section.html.erb:29:9: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/reviews/_reviews_section.html.erb:31:10: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/reviews/_reviews_section.html.erb:32:51: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/reviews/_reviews_section.html.erb:39:24: warning[unresolved_type]: local read `reviews_path` has unresolved type
./app/views/reviews/_reviews_section.html.erb:46:68: error[incompatible_binop]: `-` with incompatible operand types: Integer? - Integer
./app/views/reviews/create.turbo_stream.erb:2:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/reviews/create.turbo_stream.erb:5:7: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/reviews/index.turbo_stream.erb:2:5: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/reviews/index.turbo_stream.erb:9:5: warning[unresolved_type]: method call `turbo_stream` has unresolved type
./app/views/reviews/index.turbo_stream.erb:13:19: error[incompatible_binop]: `-` with incompatible operand types: Integer? - Integer
./app/views/reviews/index.turbo_stream.erb:14:22: warning[unresolved_type]: method call `polymorphic_path` has unresolved type
./app/views/reviews/index.turbo_stream.erb:17:22: warning[unresolved_type]: local read `reviews_path` has unresolved type
./app/views/shared/_check_in.html.erb:20:21: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/shared/_check_in.html.erb:36:55: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/shared/_language_selector.html.erb:21:10: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/shared/_language_selector.html.erb:22:37: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/shared/_language_selector.html.erb:23:65: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/shared/_language_selector.html.erb:24:17: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/shared/_language_selector.html.erb:31:27: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/shared/_map_canvas.html.erb:8:25: warning[unresolved_type]: method call `location` has unresolved type
./app/views/shared/_map_canvas.html.erb:8:45: warning[unresolved_type]: method call `location` has unresolved type
./app/views/shared/_map_canvas.html.erb:8:69: warning[unresolved_type]: method call `location` has unresolved type
./app/views/shared/_map_canvas.html.erb:9:27: warning[unresolved_type]: method call `location` has unresolved type
./app/views/shared/_map_canvas.html.erb:12:11: warning[unresolved_type]: method call `content_for?` has unresolved type
./app/views/shared/_map_canvas.html.erb:21:21: warning[unresolved_type]: method call `content_for?` has unresolved type
./app/views/shared/_map_canvas.html.erb:29:30: warning[unresolved_type]: method call `location` has unresolved type
./app/views/shared/_map_canvas.html.erb:30:30: warning[unresolved_type]: method call `location` has unresolved type
./app/views/shared/_map_canvas.html.erb:33:56: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/shared/_map_canvas.html.erb:45:35: warning[unresolved_type]: method call `location` has unresolved type
./app/views/shared/_map_canvas.html.erb:52:69: warning[unresolved_type]: method call `location` has unresolved type
./app/views/shared/_map_canvas.html.erb:52:89: warning[unresolved_type]: method call `location` has unresolved type
./app/views/shared/_moment_caption.html.erb:36:47: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/shared/_moment_caption.html.erb:40:54: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/shared/_moment_caption.html.erb:41:52: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/shared/_moment_caption.html.erb:55:60: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/shared/_moment_caption.html.erb:78:56: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/shared/_moment_caption.html.erb:91:56: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/shared/_moment_like.html.erb:3:12: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/shared/_moment_like.html.erb:3:36: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/shared/_moment_like.html.erb:4:14: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/shared/_moment_like.html.erb:5:16: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/shared/_moment_like.html.erb:5:25: warning[unresolved_type]: method call `moment_like_path` has unresolved type
./app/views/shared/_moment_like.html.erb:5:42: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/shared/_moment_like.html.erb:5:59: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/shared/_moment_like.html.erb:19:9: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/shared/_moment_like.html.erb:19:46: warning[unresolved_type]: method call `moment` has unresolved type
./app/views/shared/_moment_status.html.erb:2:12: warning[unresolved_type]: method call `scope` has unresolved type
./app/views/shared/_moment_status.html.erb:3:65: warning[unresolved_type]: method call `message` has unresolved type
./app/views/shared/_moment_status.html.erb:4:7: warning[unresolved_type]: method call `message` has unresolved type
./app/views/shared/_photo_lightbox.html.erb:49:35: warning[unresolved_type]: local read `index` has unresolved type
./app/views/shared/_photo_lightbox.html.erb:51:121: warning[unresolved_type]: local read `index` has unresolved type
./app/views/shared/_photo_lightbox.html.erb:52:75: warning[unresolved_type]: local read `index` has unresolved type
./app/views/shared/_photo_lightbox.html.erb:53:27: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/shared/_photo_lightbox.html.erb:53:27: warning[gradual_untyped]: local read resolves to RBS `untyped` (gradual escape)
./app/views/shared/_photo_lightbox.html.erb:53:126: warning[unresolved_type]: local read `index` has unresolved type
./app/views/travel_profiles/_my_moment_tile.html.erb:5:20: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:7:28: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:11:44: note[unresolved_type]: method call `photo_plan_moment_path` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:11:67: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:11:80: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:12:50: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:13:31: note[unresolved_type]: method call `photo_plan_moment_path` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:13:54: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:13:67: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:14:19: note[unresolved_type]: method call `photo_plan_moment_path` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:14:42: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:14:55: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:15:77: note[unresolved_type]: local read `location_name` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:18:22: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:19:13: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:24:31: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:25:11: note[unresolved_type]: local read `location_name` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:25:63: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moment_tile.html.erb:25:37: note[unresolved_type]: method call `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moments_content.html.erb:6:9: note[unresolved_type]: method call `moments` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moments_content.html.erb:9:46: note[unresolved_type]: method call `moments` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moments_content.html.erb:14:48: note[unresolved_type]: method call `moments` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moments_content.html.erb:18:65: note[unresolved_type]: method call `moments` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moments_content.html.erb:21:50: note[unresolved_type]: method call `moments` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moments_content.html.erb:27:13: note[unresolved_type]: method call `moments` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moments_items.html.erb:2:4: note[unresolved_type]: method call `moments` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moments_items.html.erb:3:18: note[unresolved_type]: local read `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_moments_items.html.erb:4:56: note[unresolved_type]: local read `moment` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:5:32: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:5:49: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:20:13: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/travel_profiles/_my_plan_card.html.erb:20:13: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:24:19: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/travel_profiles/_my_plan_card.html.erb:24:19: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:24:44: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:30:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/travel_profiles/_my_plan_card.html.erb:31:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/travel_profiles/_my_plan_card.html.erb:31:50: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/travel_profiles/_my_plan_card.html.erb:31:121: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./app/views/travel_profiles/_my_plan_card.html.erb:44:15: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:48:32: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:49:15: note[unresolved_type]: local read `experiences_count` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:54:17: note[unresolved_type]: local read `experiences_count` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:59:15: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:83:52: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:83:109: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plan_card.html.erb:86:27: note[unresolved_type]: method call `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:3:9: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:6:10: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:7:58: note[unresolved_type]: local read `plan` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:12:11: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:18:19: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:26:52: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:38:19: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:38:47: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:42:19: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:50:52: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:64:25: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:65:24: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:65:45: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:65:64: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:66:26: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:67:31: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:67:58: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:67:79: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:67:98: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./app/views/travel_profiles/_my_plans_content.html.erb:67:127: note[unresolved_type]: method call `plans` has unresolved type — likely roundhouse coverage, not an app error (ingest gap in app/controllers/travel_profiles_controller.rb: `defined?` only supports bareword targets today: ConstantReadNode)
./db/seeds.rb:33:5: warning[unresolved_type]: local read `locale` has unresolved type
./db/seeds.rb:34:5: warning[unresolved_type]: local read `locale` has unresolved type
./db/seeds.rb:35:5: warning[unresolved_type]: local read `locale` has unresolved type
./db/seeds.rb:36:5: warning[unresolved_type]: local read `locale` has unresolved type
./db/seeds.rb:37:5: warning[unresolved_type]: local read `locale` has unresolved type
./db/seeds.rb:38:5: warning[unresolved_type]: local read `locale` has unresolved type
./db/seeds.rb:66:5: warning[unresolved_type]: local read `exp_type` has unresolved type
./db/seeds.rb:67:5: warning[unresolved_type]: local read `exp_type` has unresolved type
./db/seeds.rb:68:5: warning[unresolved_type]: local read `exp_type` has unresolved type
./db/seeds.rb:69:5: warning[unresolved_type]: local read `exp_type` has unresolved type
./db/seeds.rb:70:5: warning[unresolved_type]: local read `exp_type` has unresolved type
./db/seeds.rb:172:5: warning[unresolved_type]: local read `cat` has unresolved type
./db/seeds.rb:173:5: warning[unresolved_type]: local read `cat` has unresolved type
./db/seeds.rb:174:5: warning[unresolved_type]: local read `cat` has unresolved type
./db/seeds.rb:175:5: warning[unresolved_type]: local read `cat` has unresolved type
./db/seeds.rb:176:5: warning[unresolved_type]: local read `cat` has unresolved type
./db/seeds.rb:243:5: warning[unresolved_type]: local read `user` has unresolved type
./db/seeds.rb:244:5: warning[unresolved_type]: local read `user` has unresolved type
./db/seeds.rb:541:5: warning[unresolved_type]: local read `loc` has unresolved type
./db/seeds.rb:542:5: warning[unresolved_type]: local read `loc` has unresolved type
./db/seeds.rb:543:5: warning[unresolved_type]: local read `loc` has unresolved type
./db/seeds.rb:544:5: warning[unresolved_type]: local read `loc` has unresolved type
./db/seeds.rb:545:5: warning[unresolved_type]: local read `loc` has unresolved type
./db/seeds.rb:546:5: warning[unresolved_type]: local read `loc` has unresolved type
./db/seeds.rb:547:5: warning[unresolved_type]: local read `loc` has unresolved type
./db/seeds.rb:548:5: warning[unresolved_type]: local read `loc` has unresolved type
./db/seeds.rb:549:5: warning[unresolved_type]: local read `loc` has unresolved type
./db/seeds.rb:660:5: warning[unresolved_type]: local read `exp` has unresolved type
./db/seeds.rb:661:5: warning[unresolved_type]: local read `exp` has unresolved type
./db/seeds.rb:662:5: warning[unresolved_type]: local read `exp` has unresolved type
./db/seeds.rb:684:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./db/seeds.rb:685:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./db/seeds.rb:698:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./db/seeds.rb:699:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./db/seeds.rb:711:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./db/seeds.rb:712:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./db/seeds.rb:724:17: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./db/seeds.rb:725:15: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./db/seeds.rb:739:5: warning[unresolved_type]: local read `p` has unresolved type
./db/seeds.rb:740:5: warning[unresolved_type]: local read `p` has unresolved type
./db/seeds.rb:741:5: warning[unresolved_type]: local read `p` has unresolved type
./db/seeds.rb:742:5: warning[unresolved_type]: local read `p` has unresolved type
./db/seeds.rb:743:5: warning[unresolved_type]: local read `p` has unresolved type
./db/seeds.rb:744:5: warning[unresolved_type]: local read `p` has unresolved type
./db/seeds.rb:747:3: warning[gradual_untyped]: method call resolves to RBS `untyped` (gradual escape)
./db/seeds.rb:752:11: warning[unresolved_type]: local read `pe` has unresolved type
./db/seeds.rb:792:11: warning[unresolved_type]: local read `experience` has unresolved type
./db/seeds.rb:794:39: warning[unresolved_type]: local read `experience` has unresolved type
./db/seeds.rb:795:16: warning[unresolved_type]: method call `download_picsum_image` has unresolved type
./db/seeds.rb:795:77: warning[unresolved_type]: local read `experience` has unresolved type
./db/seeds.rb:796:6: warning[unresolved_type]: local read `image_data` has unresolved type
./db/seeds.rb:797:5: warning[unresolved_type]: local read `experience` has unresolved type
./db/seeds.rb:797:35: warning[unresolved_type]: local read `image_data` has unresolved type
./db/seeds.rb:799:3: warning[unresolved_type]: method call `sleep` has unresolved type
./db/seeds.rb:804:11: warning[unresolved_type]: local read `location` has unresolved type
./db/seeds.rb:806:17: warning[unresolved_type]: method call `rand` has unresolved type
./db/seeds.rb:807:23: warning[unresolved_type]: local read `photo_count` has unresolved type
./db/seeds.rb:807:49: warning[unresolved_type]: local read `location` has unresolved type
./db/seeds.rb:809:3: warning[unresolved_type]: local read `photo_count` has unresolved type
./db/seeds.rb:810:18: warning[unresolved_type]: method call `download_picsum_image` has unresolved type
./db/seeds.rb:810:78: warning[unresolved_type]: local read `location` has unresolved type
./db/seeds.rb:810:93: warning[unresolved_type]: local read `i` has unresolved type
./db/seeds.rb:811:8: warning[unresolved_type]: local read `image_data` has unresolved type
./db/seeds.rb:812:7: warning[unresolved_type]: local read `location` has unresolved type
./db/seeds.rb:812:30: warning[unresolved_type]: local read `image_data` has unresolved type
./db/seeds.rb:814:5: warning[unresolved_type]: method call `sleep` has unresolved type
./db/seeds.rb:853:16: warning[unresolved_type]: method call `download_sample_audio` has unresolved type
./db/seeds.rb:854:6: warning[unresolved_type]: local read `audio_data` has unresolved type
./db/seeds.rb:856:34: warning[unresolved_type]: local read `audio_data` has unresolved type
./db/seeds.rb:858:3: warning[unresolved_type]: method call `sleep` has unresolved type
./db/seeds.rb:898:3: warning[unresolved_type]: method call `rand` has unresolved type
./db/seeds.rb:907:19: warning[unresolved_type]: method call `rand` has unresolved type
./db/seeds.rb:914:3: warning[unresolved_type]: method call `rand` has unresolved type
./db/seeds.rb:923:19: warning[unresolved_type]: method call `rand` has unresolved type
./db/seeds.rb:930:3: warning[unresolved_type]: method call `rand` has unresolved type
./db/seeds.rb:939:19: warning[unresolved_type]: method call `rand` has unresolved type
./app/views/curator/admin/photo_suggestions/index.html.erb:40:17: warning[missing_preload]: iterating this relation reads `suggestion.photos`, but the query at ./app/controllers/curator/admin/photo_suggestions_controller.rb:11 does not preload :photos_attachments — add `.with_attached_photos` (or `.includes(photos_attachments: :blob)`)
./app/views/curator/admin/photo_suggestions/index.html.erb:42:19: warning[missing_preload]: iterating this relation runs `suggestion.photos.count` per row — a query that preloading :photos_attachments at ./app/controllers/curator/admin/photo_suggestions_controller.rb:11 would not avoid; read `.size` over `.includes(:photos_attachments)`, or add a `counter_cache`
./app/views/experiences/show.html.erb:152:58: warning[missing_preload]: iterating this relation reads `loc.photos`, but the query at ./app/views/experiences/show.html.erb:152 does not preload :photos_attachments — add `.with_attached_photos` (or `.includes(photos_attachments: :blob)`)
./app/views/experiences/show.html.erb:225:33: warning[missing_preload]: iterating this relation reads `location.photos`, but the query at ./app/views/experiences/show.html.erb:214 does not preload :photos_attachments — add `.with_attached_photos` (or `.includes(photos_attachments: :blob)`)

── Survey: 55 ingest gap(s), 7 distinct kind(s) ──
  [32×] unsupported expression node: GlobalVariableWriteNode
        ./test/lib/platform/cli_test.rb
        ./test/lib/platform/mcp_server_test.rb
  [12×] `defined?` only supports bareword targets today: ConstantReadNode
        ./app/controllers/travel_profiles_controller.rb
        ./app/controllers/user_plans_controller.rb
        ./app/services/ai/audio_tour_generator.rb
        ./app/services/ai/concerns/error_reporting.rb
        … and 3 more file(s)
  [4×] `defined?` only supports bareword targets today: ConstantPathNode
        ./lib/platform/dsl/executors/infrastructure.rb
        ./test/lib/platform/dsl/executors/infrastructure_test.rb
  [4×] unsupported expression node: InterpolatedXStringNode
        ./lib/platform/dsl/executors/infrastructure.rb
        ./test/lib/platform/dsl/executors/infrastructure_test.rb
  [1×] column dropped: browses.searchable has unsupported type `virtual`
        ./db/schema.rb
  [1×] controller class-body macro not recognized: `protect_from_forgery`
        UserPlansController
  [1×] resources :moments `only:` is not a literal list of actions
        ./config/routes.rb

roundhouse-check: 46 gems: 10 framework, 3 modeled, 20 infrastructure, 13 unknown (better_html, erb_lint, faraday, faraday-follow_redirects, flipper, flipper-active_record, geocoder, neighbor, parslet, rollbar, ruby_llm, rubyzip, undercover)
roundhouse-check: . — 0 parse error(s), 243 error(s), 2263 warning(s), 90 gap-attributed note(s), 55 survey gap(s)

real	0m3.948s
user	0m3.288s
sys	0m0.181s
```
