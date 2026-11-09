# Taskboard welcome preview

This optional test addon opens Taskboard's current welcome card in its editor on the next full WoW client launch and character login. It is for reviewing the wording and layout with an existing board. It is **not** a fresh-install or saved-data migration test.

Copy this `TaskboardWelcomePreview` folder into `Interface/AddOns/` beside `Taskboard`, then fully restart WoW. On the first login it creates one welcome card on the current character's board if none with the current welcome title exists, opens the board and card editor, and records that it has shown the card. Existing cards and settings are not reset. It does not run again on later logins.

After reviewing the card, disable or remove `TaskboardWelcomePreview`. The card it added stays on the board until you delete it yourself. To repeat the preview, clear only `TaskboardWelcomePreviewDB` from this helper's SavedVariables while WoW is closed. Do not clear `TaskboardDB`.

The release package built by `tests/tools/package.py` includes only files named in `Taskboard.toc`, so it does not include this helper.
