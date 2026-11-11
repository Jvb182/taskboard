# Taskboard roadmap

This is a list of ideas under consideration, not a release schedule or a promise that every item will ship. The goal is to make Taskboard useful during play without creating noisy or misleading alerts.

## Exploring

### Add a mail task automatically

When the WoW Forever client reports new mail, Taskboard could offer to create—or, if enabled, automatically maintain—one **Check mail** task. The task should not multiply on repeated notifications or overwrite a player's own mail cards. Opening a mailbox should complete the generated check-mail task only when automatic completion is enabled.

**Before building:** verify what mail state the Forever client exposes away from a mailbox, when that state updates, and how it behaves across login and character changes. Make the behavior opt-in if reliable detection is available.

**Today:** players can make a mail task manually. Taskboard learns mailbox locations when opened and can remind near a learned mailbox; opening mail can complete an eligible plain check-mail task.

### Map pings for task locations

Offer optional map pings or markers for tasks with locations, so a player can see where a relevant errand is. Use a precise point only when Taskboard has real coordinates, such as a user pin or a learned service location. A zone-only reminder like `@Goldshire` should not pretend to know the exact NPC or shop. Explore when a ping should appear, how long it lasts, and how to prevent repeated pings from becoming distracting.

**Before building:** confirm the map and ping APIs available in WoW Forever 1.60.1, their behavior in combat and across zones, and whether a persistent marker is more useful than a transient ping. Keep this feature optional.

**Today:** `@location` tasks can trigger arrival reminders, and nearby tasks can pulse in the on-screen tracker. They do not create map pings.

### NPC-aware reminders

Understand task text such as `/tb train in swords` and connect it to the **weapon masters who actually teach swords**. Extend the same idea to other trainer and service errands only when Taskboard can identify the right NPC or a verified location. If more than one target matches, let the player choose; always allow a manual location override. A generic trainer should not trigger a swords reminder.

**Before building:** verify what nearby-NPC and distance information WoW Forever exposes, and how to maintain accurate, localized trainer/weapon-skill data. Avoid false alerts from NPCs who cannot provide the requested service. Decide separately whether visiting or training can be detected for completion.

**Today:** `@trainer` can remind when a trainer window opens, and `@location` can remind on zone arrival. Taskboard does not identify a specific nearby NPC from free-form task text.

## Help shape the next update

[Open a GitHub issue](https://github.com/Jvb182/taskboard/issues/new) with the task you were trying to do, what you expected Taskboard to show, and whether you would want the new behavior on by default. Bug reports are welcome there too.
